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
 * Writes the summary of each new file. A version that fails is logged and skipped rather than failing the
 * whole batch, because one document the model dislikes should not cost the others their summary. A
 * version that failed for a passing reason, such as the AI service timing out, is queued again on its own
 * a few minutes later, up to three attempts in all, and the versions there was no callout time left for
 * continue in a follow-up job that runs next, ahead of whatever else waits in the chain, because those
 * versions never failed.
 */
public without sharing class GoogleFileVersionSummaryJob extends GQueueableJob.AllowsCallouts {
	public class GoogleFileVersionSummaryJobException extends Exception {}

	private static final Integer FIRST_ATTEMPT = 1;
	private static final Integer FOLLOW_UP_PRIORITY = 1;
	private static final String WARN_LEVEL = 'WARN';
	private static final String ERROR_LEVEL = 'ERROR';

	@TestVisible
	private static Boolean skipExecution = false;

	@TestVisible
	private static Map<Id, GoogleFileAnalysisResultDTO> testResultsByVersionId = new Map<Id, GoogleFileAnalysisResultDTO>();

	@TestVisible
	private static List<String> loggedFailures = new List<String>();
	private static Boolean hasUnsavedFailures = false;

	@TestVisible
	private final Set<Id> versionIds;
	@TestVisible
	private final Integer attempt;
	private final Map<Id, GoogleFileAnalysisResultDTO> capturedTestResultsByVersionId;

	/**
	 * Builds the job for a set of versions, as their first attempt.
	 *
	 * @param versionIds The versions to summarize.
	 */
	public GoogleFileVersionSummaryJob(Set<Id> versionIds) {
		this(versionIds, FIRST_ATTEMPT);
	}

	/**
	 * Builds the job for a later attempt, which is how a retry and a follow-up carry their count.
	 *
	 * @param versionIds The versions to summarize.
	 * @param attempt Which attempt this is, counting from one. Null counts as the first.
	 */
	public GoogleFileVersionSummaryJob(Set<Id> versionIds, Integer attempt) {
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
		return (GQueueableJob) JSON.deserialize(JSON.serialize(this), GoogleFileVersionSummaryJob.class);
	}

	/**
	 * Summarizes each version and saves the ones that worked in a single commit, then queues what is left:
	 * the versions there was no time for in a follow-up job, the ones that failed for a passing reason in a
	 * delayed retry. A failed save is logged rather than thrown, so the job always hands over what it owes.
	 * With AI unavailable it simply returns, leaving the files without summaries.
	 */
	public override void work() {
		if (skipExecution) return;
		if (this.versionIds.isEmpty()) return;

		Logger.info('Queueable Job to generate summaries for: ' + String.join(this.versionIds, ', ')).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

		IGoogleFileIntelligenceStrategy intelligenceStrategy = null;
		if (this.capturedTestResultsByVersionId.isEmpty()) {
			try {
				intelligenceStrategy = new GoogleFileIntelligenceFactory().create();
			} catch (Exception ex) {
				logStoppedRetry();
				return;
			}
		}

		GoogleCalloutTimeResolver calloutClock = new GoogleCalloutTimeResolver();
		calloutClock.startClock();

		Map<Id, String> summariesByVersionId = new Map<Id, String>();
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
				GoogleFileAnalysisResultDTO summaryResult = resolveSummaryResult(candidateVersion.Id, intelligenceStrategy);
				if (summaryResult == null || summaryResult.blocked == true) continue;

				if (summaryResult.success == true && String.isNotBlank(summaryResult.text)) {
					summariesByVersionId.put(candidateVersion.Id, summaryResult.text);
					continue;
				}

				if (summaryResult.retryable == true) {
					retryReasonsByVersionId.put(candidateVersion.Id, describeResult(summaryResult));
					continue;
				}

				recordFailure(ERROR_LEVEL, buildGaveUpMessage(candidateVersion.Id, describeResult(summaryResult)));
			} catch (Exception ex) {
				recordFailure(ERROR_LEVEL, buildGaveUpMessage(candidateVersion.Id, 'Message=' + ex.getMessage()));
			}
		}

		commitSummaries(summariesByVersionId);
		chainFollowUp(deferredVersionIds);
		chainRetry(retryReasonsByVersionId);
		saveRecordedFailures();
	}

	@TestVisible
	private static void setTestResult(Id versionId, GoogleFileAnalysisResultDTO testResult) {
		if (versionId == null || testResult == null) return;
		testResultsByVersionId.put(versionId, testResult);
	}

	@TestVisible
	private static void clearTestResults() {
		testResultsByVersionId.clear();
	}

	private Map<Id, GoogleFileAnalysisResultDTO> captureTestResultsByVersionId() {
		if (testResultsByVersionId == null || testResultsByVersionId.isEmpty()) {
			return new Map<Id, GoogleFileAnalysisResultDTO>();
		}

		return new Map<Id, GoogleFileAnalysisResultDTO>(testResultsByVersionId);
	}

	private Integer resolveAttempt() {
		return this.attempt == null || this.attempt < FIRST_ATTEMPT ? FIRST_ATTEMPT : this.attempt;
	}

	private List<GoogleFileVersion__c> loadAnalysisCandidates() {
		Boolean isPreviewDisabled = new GoogleMetadataConfigService().isPreviewDisabled();
		List<GoogleFileVersion__c> candidateVersions = new List<GoogleFileVersion__c>();

		for (GoogleFileVersion__c localFileVersion : (List<GoogleFileVersion__c>) GoogleFileVersionSelector.query().withAdvancedFields().byIds(this.versionIds).toList()) {
			if (String.isNotBlank(localFileVersion.Summary__c)) continue;

			if (String.isBlank(localFileVersion.GoogleDocsFileId__c)) {
				if (!isPreviewDisabled && GoogleCloudConstants.FILE_EXTENSION_TO_PREVIEW_TYPE.containsKey(localFileVersion.Type__c)) {
					recordFailure(WARN_LEVEL, 'File Summary Not Possible --> VersionId=' + String.valueOf(localFileVersion.Id) + ', Reason=The Google Workspace copy is missing');
				}
				continue;
			}

			candidateVersions.add(localFileVersion);
		}

		return candidateVersions;
	}

	private GoogleFileAnalysisResultDTO resolveSummaryResult(Id versionId, IGoogleFileIntelligenceStrategy intelligenceStrategy) {
		if (this.capturedTestResultsByVersionId.containsKey(versionId)) {
			return this.capturedTestResultsByVersionId.get(versionId);
		}

		return intelligenceStrategy == null ? null : intelligenceStrategy.summarize(versionId);
	}

	private void commitSummaries(Map<Id, String> summariesByVersionId) {
		if (summariesByVersionId.isEmpty()) return;

		IGoogleUnitOfWork uow = new GoogleCloudUnitOfWork(GoogleCloudConstants.DEFAULT_WRITE_ORDER);
		Set<Id> survivingVersionIds = new Map<Id, GoogleFileVersion__c>((List<GoogleFileVersion__c>) GoogleFileVersionSelector.query().withBaseFields().byIds(summariesByVersionId.keySet()).toList()).keySet();
		for (Id versionId : survivingVersionIds) {
			uow.registerDirty(new GoogleFileVersion__c(
				Id = versionId,
				Summary__c = summariesByVersionId.get(versionId)
			));
		}

		if (survivingVersionIds.isEmpty()) return;

		try {
			uow.commitWork(true);
		} catch (Exception ex) {
			recordFailure(ERROR_LEVEL, 'File Summary Save Failed --> VersionIds=' + String.join(survivingVersionIds, ', ') + ', Message=' + ex.getMessage());
		}
	}

	private void chainFollowUp(Set<Id> deferredVersionIds) {
		if (deferredVersionIds.isEmpty()) return;

		GAsync.queueable()
			.chain(new GoogleFileVersionSummaryJob(deferredVersionIds, resolveAttempt()))
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
			recordFailure(WARN_LEVEL, 'File Summary Retry Scheduled --> VersionId=' + String.valueOf(versionId) + ', NextAttempt=' + nextAttempt + ', InMinutes=' + delayMinutes + ', ' + retryReasonsByVersionId.get(versionId));
		}

		GAsync.queueable()
			.chain(new GoogleFileVersionSummaryJob(retryReasonsByVersionId.keySet(), nextAttempt))
			.deepClone()
			.delay(delayMinutes)
			.enqueue();
	}

	private void logStoppedRetry() {
		if (resolveAttempt() == FIRST_ATTEMPT) return;

		Logger.info('File Summary Retry Stopped --> AI analysis is no longer available for: ' + String.join(this.versionIds, ', ')).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
		Logger.saveLog();
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

	private String buildGaveUpMessage(Id versionId, String reason) {
		return 'File Summary Gave Up --> VersionId=' + String.valueOf(versionId) + ', Attempts=' + resolveAttempt() + ', ' + reason;
	}

	private String describeResult(GoogleFileAnalysisResultDTO summaryResult) {
		return 'Provider=' + String.valueOf(summaryResult.provider)
			+ ', FinishReason=' + String.valueOf(summaryResult.finishReason)
			+ ', Message=' + String.valueOf(summaryResult.errorMessage);
	}
}