/**
 * MIT License
 *
 * Copyright (c) 2026 Andrii Sukhetskyi
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
/**
 * Labels each new file with one of the configured Google Drive labels. It is its own job rather than part
 * of the summary one so every chunk gets its own callout budget, which matters once a thinking budget
 * makes the calls slow. Labels are saved in one commit at the end, after the Drive calls, since DML
 * cannot come before a callout. A label call that failed for a passing reason is queued again on its own
 * a few minutes later, up to three attempts in all; a label Drive refused is not. Versions there was no
 * callout time left for continue in a follow-up job that runs next, ahead of whatever else waits in the
 * chain.
 */
public without sharing class GoogleFileVersionLabelJob extends GQueueableJob.AllowsCallouts {
	public class GoogleFileVersionLabelJobException extends Exception {}

	private static final Integer FIRST_ATTEMPT = 1;
	private static final Integer FOLLOW_UP_PRIORITY = 1;
	private static final String WARN_LEVEL = 'WARN';
	private static final String ERROR_LEVEL = 'ERROR';

	@TestVisible
	private static Boolean skipExecution = false;

	@TestVisible
	private static Map<Id, GoogleFileLabelResultDTO> testResultsByVersionId = new Map<Id, GoogleFileLabelResultDTO>();

	@TestVisible
	private static List<String> loggedFailures = new List<String>();
	private static Boolean hasUnsavedFailures = false;

	@TestVisible
	private final Set<Id> versionIds;
	@TestVisible
	private final Integer attempt;
	private final Map<Id, GoogleFileLabelResultDTO> capturedTestResultsByVersionId;

	/**
	 * Builds the job for a set of versions, as their first attempt.
	 *
	 * @param versionIds The versions to label.
	 */
	public GoogleFileVersionLabelJob(Set<Id> versionIds) {
		this(versionIds, FIRST_ATTEMPT);
	}

	/**
	 * Builds the job for a later attempt, which is how a retry and a follow-up carry their count.
	 *
	 * @param versionIds The versions to label.
	 * @param attempt Which attempt this is, counting from one. Null counts as the first.
	 */
	public GoogleFileVersionLabelJob(Set<Id> versionIds, Integer attempt) {
		this.versionIds = versionIds == null ? new Set<Id>() : new Set<Id>(versionIds);
		this.attempt = attempt == null || attempt < FIRST_ATTEMPT ? FIRST_ATTEMPT : attempt;
		this.capturedTestResultsByVersionId = captureTestResultsByVersionId();
	}

	/**
	 * Copies the job when it is chained, which has to be spelled out because the generic copy cannot resolve
	 * this type on its own.
	 *
	 * @return A copy of this job.
	 */
	public override GQueueableJob cloneForDeepCopy() {
		return (GQueueableJob) JSON.deserialize(JSON.serialize(this), GoogleFileVersionLabelJob.class);
	}

	/**
	 * Labels each version and records the ones Drive accepted, then queues what is left: the versions there
	 * was no time for in a follow-up job, the ones whose call failed for a passing reason in a delayed retry.
	 * A file the model was unsure about is noted and left unlabeled, which is the normal outcome rather than
	 * a failure, and a failed save is logged rather than thrown.
	 */
	public override void work() {
		if (skipExecution) return;
		if (this.versionIds.isEmpty()) return;

		Logger.info('Queueable Job to assign labels for: ' + String.join(this.versionIds, ', ')).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

		IGoogleFileLabelingStrategy labelingStrategy = null;
		if (this.capturedTestResultsByVersionId.isEmpty()) {
			GoogleFileIntelligenceFactory intelligenceFactory = new GoogleFileIntelligenceFactory();
			if (!intelligenceFactory.isLabelingConfigured()) {
				Logger.info('File Label Job Skipped --> AI labeling is not configured for: ' + String.join(this.versionIds, ', ')).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
				Logger.saveLog();
				return;
			}

			try {
				labelingStrategy = intelligenceFactory.createForLabeling();
			} catch (Exception ex) {
				Logger.error('File Label Job Failed --> Labeling strategy unavailable, Message=' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
				Logger.saveLog();
				return;
			}
		}

		GoogleCalloutTimeResolver calloutClock = new GoogleCalloutTimeResolver();
		calloutClock.startClock();

		Map<Id, GoogleFileLabelResultDTO> appliedLabelsByVersionId = new Map<Id, GoogleFileLabelResultDTO>();
		Map<Id, String> retryReasonsByVersionId = new Map<Id, String>();
		Set<Id> deferredVersionIds = new Set<Id>();
		Boolean hasStartedAnalysis = false;

		for (GoogleFileVersion__c candidateVersion : loadAnalysisCandidates()) {
			if (hasStartedAnalysis && !calloutClock.hasTimeForAnotherRequest()) {
				deferredVersionIds.add(candidateVersion.Id);
				continue;
			}

			hasStartedAnalysis = true;
			try {
				GoogleFileLabelResultDTO labelResult = resolveLabelResult(candidateVersion.Id, labelingStrategy);
				if (labelResult == null || labelResult.blocked == true) continue;

				if (labelResult.applied == true && String.isNotBlank(labelResult.labelName)) {
					appliedLabelsByVersionId.put(candidateVersion.Id, labelResult);
					continue;
				}

				if (labelResult.retryable == true) {
					retryReasonsByVersionId.put(candidateVersion.Id, describeResult(labelResult));
					continue;
				}

				if (labelResult.success == true && String.isBlank(labelResult.errorMessage)) {
					Logger.info(buildUnlabeledMessage(candidateVersion.Id, labelResult)).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
					Logger.saveLog();
					continue;
				}

				recordFailure(ERROR_LEVEL, buildGaveUpMessage(candidateVersion.Id, describeResult(labelResult)));
			} catch (Exception ex) {
				recordFailure(ERROR_LEVEL, buildGaveUpMessage(candidateVersion.Id, 'Message=' + ex.getMessage()));
			}
		}

		commitLabels(appliedLabelsByVersionId);
		chainFollowUp(deferredVersionIds);
		chainRetry(retryReasonsByVersionId);
		saveRecordedFailures();
	}

	@TestVisible
	private static void setTestResult(Id versionId, GoogleFileLabelResultDTO testResult) {
		if (versionId == null || testResult == null) return;
		testResultsByVersionId.put(versionId, testResult);
	}

	@TestVisible
	private static void clearTestResults() {
		testResultsByVersionId.clear();
	}

	private Map<Id, GoogleFileLabelResultDTO> captureTestResultsByVersionId() {
		if (testResultsByVersionId == null || testResultsByVersionId.isEmpty()) {
			return new Map<Id, GoogleFileLabelResultDTO>();
		}

		return new Map<Id, GoogleFileLabelResultDTO>(testResultsByVersionId);
	}

	private Integer resolveAttempt() {
		return this.attempt == null || this.attempt < FIRST_ATTEMPT ? FIRST_ATTEMPT : this.attempt;
	}

	private List<GoogleFileVersion__c> loadAnalysisCandidates() {
		Boolean isPreviewDisabled = new GoogleMetadataConfigService().isPreviewDisabled();
		List<GoogleFileVersion__c> candidateVersions = new List<GoogleFileVersion__c>();

		for (GoogleFileVersion__c localFileVersion : (List<GoogleFileVersion__c>) GoogleFileVersionSelector.query().withAdvancedFields().byIds(this.versionIds).toList()) {
			if (String.isNotBlank(localFileVersion.AiLabels__c)) continue;

			if (String.isBlank(localFileVersion.GoogleDocsFileId__c)) {
				if (!isPreviewDisabled && GoogleCloudConstants.FILE_EXTENSION_TO_PREVIEW_TYPE.containsKey(localFileVersion.Type__c)) {
					recordFailure(WARN_LEVEL, 'File Label Not Possible --> VersionId=' + String.valueOf(localFileVersion.Id) + ', Reason=The Google Workspace copy is missing');
				}
				continue;
			}

			candidateVersions.add(localFileVersion);
		}

		return candidateVersions;
	}

	private GoogleFileLabelResultDTO resolveLabelResult(Id versionId, IGoogleFileLabelingStrategy labelingStrategy) {
		if (this.capturedTestResultsByVersionId.containsKey(versionId)) {
			return this.capturedTestResultsByVersionId.get(versionId);
		}

		return labelingStrategy == null ? null : labelingStrategy.label(versionId);
	}

	private void commitLabels(Map<Id, GoogleFileLabelResultDTO> appliedLabelsByVersionId) {
		if (appliedLabelsByVersionId.isEmpty()) return;

		IGoogleUnitOfWork uow = new GoogleCloudUnitOfWork(GoogleCloudConstants.DEFAULT_WRITE_ORDER);
		Set<Id> survivingVersionIds = new Map<Id, GoogleFileVersion__c>((List<GoogleFileVersion__c>) GoogleFileVersionSelector.query().withBaseFields().byIds(appliedLabelsByVersionId.keySet()).toList()).keySet();
		for (Id versionId : survivingVersionIds) {
			GoogleFileLabelResultDTO labelResult = appliedLabelsByVersionId.get(versionId);
			uow.registerNew(new GoogleFileVersionLabel__c(
				Name = labelResult.labelName,
				GoogleFileVersionId__c = versionId,
				GoogleDriveLabelId__c = labelResult.labelId,
				Confidence__c = labelResult.confidence
			));
		}

		if (survivingVersionIds.isEmpty()) return;

		try {
			uow.commitWork(true);
		} catch (Exception ex) {
			recordFailure(ERROR_LEVEL, 'File Label Save Failed --> VersionIds=' + String.join(survivingVersionIds, ', ') + ', Message=' + ex.getMessage());
		}
	}

	private void chainFollowUp(Set<Id> deferredVersionIds) {
		if (deferredVersionIds.isEmpty()) return;

		GAsync.queueable()
			.chain(new GoogleFileVersionLabelJob(deferredVersionIds, resolveAttempt()))
			.deepClone()
			.priority(FOLLOW_UP_PRIORITY)
			.enqueue();
	}

	private void chainRetry(Map<Id, String> retryReasonsByVersionId) {
		if (retryReasonsByVersionId.isEmpty()) return;

		GoogleTransientFailureResolver failureResolver = new GoogleTransientFailureResolver();
		Integer currentAttempt = resolveAttempt();
		if (!failureResolver.hasAttemptsLeft(currentAttempt)) {
			for (Id versionId : retryReasonsByVersionId.keySet()) {
				recordFailure(ERROR_LEVEL, buildGaveUpMessage(versionId, retryReasonsByVersionId.get(versionId)));
			}
			return;
		}

		Integer nextAttempt = currentAttempt + 1;
		Integer delayMinutes = failureResolver.resolveRetryDelayMinutes(nextAttempt);
		for (Id versionId : retryReasonsByVersionId.keySet()) {
			recordFailure(WARN_LEVEL, 'File Label Retry Scheduled --> VersionId=' + String.valueOf(versionId) + ', NextAttempt=' + nextAttempt + ', InMinutes=' + delayMinutes + ', ' + retryReasonsByVersionId.get(versionId));
		}

		GAsync.queueable()
			.chain(new GoogleFileVersionLabelJob(retryReasonsByVersionId.keySet(), nextAttempt))
			.deepClone()
			.delay(delayMinutes)
			.enqueue();
	}

	private void recordFailure(String level, String message) {
		if (level == ERROR_LEVEL) {
			Logger.error(message).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
		} else {
			Logger.warn(message).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
		}

		loggedFailures.add(level + ' ' + message);
		hasUnsavedFailures = true;
	}

	private void saveRecordedFailures() {
		if (!hasUnsavedFailures) return;

		Logger.saveLog();
		hasUnsavedFailures = false;
	}

	private String buildUnlabeledMessage(Id versionId, GoogleFileLabelResultDTO labelResult) {
		return 'File Label Not Assigned --> VersionId=' + String.valueOf(versionId)
			+ ', Provider=' + String.valueOf(labelResult.provider)
			+ ', SuggestedLabel=' + String.valueOf(labelResult.labelName)
			+ ', Confidence=' + String.valueOf(labelResult.confidence);
	}

	private String buildGaveUpMessage(Id versionId, String reason) {
		return 'File Label Gave Up --> VersionId=' + String.valueOf(versionId) + ', Attempts=' + resolveAttempt() + ', ' + reason;
	}

	private String describeResult(GoogleFileLabelResultDTO labelResult) {
		return 'Provider=' + String.valueOf(labelResult.provider)
			+ ', FinishReason=' + String.valueOf(labelResult.finishReason)
			+ ', Message=' + String.valueOf(labelResult.errorMessage);
	}
}
