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
 * Makes the Google Workspace copy of each new file, which is what previews, Download As, summaries and
 * labeling all read. It runs as a job because the clone is a Drive callout and a callout cannot follow
 * uncommitted DML in the same transaction. Each file is copied on its own, so one copy Drive could not
 * make never costs the others theirs, and a copy that failed for a passing reason is tried again a few
 * minutes later, up to three attempts in all.
 */
public without sharing class GoogleFileVersionPreviewJob extends GQueueableJob.AllowsCallouts {
	public class GoogleFilePreviewJobException extends Exception {}

	private static final Integer FIRST_ATTEMPT = 1;
	private static final String WARN_LEVEL = 'WARN';
	private static final String ERROR_LEVEL = 'ERROR';

	@TestVisible
	private static Boolean skipExecution = false;

	@TestVisible
	private static List<String> loggedFailures = new List<String>();

	@TestVisible
    private final Set<Id> versionIds;
	@TestVisible
	private final Boolean chainIntelligence;
	@TestVisible
	private final Integer attempt;

    /**
     * Builds the job for a set of versions.
     *
     * @param versionIds The versions needing a Workspace copy.
     */
    public GoogleFileVersionPreviewJob(Set<Id> versionIds) {
        this(versionIds, true);
    }

	/**
	 * Builds the job and decides whether AI analysis may follow once the Workspace copy is measured. The
	 * measurement runs transactions later, so passing false here is the only way to keep a file that was
	 * uploaded without analysis from being summarized and labeled through its copy size.
	 *
	 * @param versionIds The versions needing a Workspace copy.
	 * @param chainIntelligence False to measure the copy without analyzing it. Null counts as true.
	 */
	public GoogleFileVersionPreviewJob(Set<Id> versionIds, Boolean chainIntelligence) {
		this(versionIds, chainIntelligence, FIRST_ATTEMPT);
	}

	/**
	 * Builds the job for a later attempt, which is how a retried copy carries its count and the upload's
	 * decision on AI analysis.
	 *
	 * @param versionIds The versions still needing a Workspace copy.
	 * @param chainIntelligence False to measure the copy without analyzing it. Null counts as true.
	 * @param attempt Which attempt this is, counting from one. Null counts as the first.
	 */
	public GoogleFileVersionPreviewJob(Set<Id> versionIds, Boolean chainIntelligence, Integer attempt) {
		this.versionIds = versionIds == null
			? new Set<Id>()
			: new Set<Id>(versionIds);
		this.chainIntelligence = chainIntelligence != false;
		this.attempt = attempt == null || attempt < FIRST_ATTEMPT ? FIRST_ATTEMPT : attempt;
	}

	/**
	 * Clones each version in Drive, stores the copy Id, and queues the size measurement afterwards. The size
	 * is measured later on purpose, since Drive reports a placeholder until it has finished converting. A
	 * copy made on a later attempt also queues its own summary and label, because the ones already in its
	 * chain ran while it was missing. A retry that finds previews turned off makes no copy.
	 */
	public override void work() {
		if (skipExecution) return;
		if (versionIds.isEmpty()) return;

		Integer currentAttempt = resolveAttempt();
		if (currentAttempt > FIRST_ATTEMPT && new GoogleMetadataConfigService().isPreviewDisabled()) {
			Logger.info('Google Workspace Copy Retry Stopped --> Previews are turned off for: ' + String.join(versionIds, ', ')).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			return;
		}

		Logger.info('Queueable Job to generate Google Workspace previews for: ' + String.join(versionIds, ', ')).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

		List<GoogleFileVersion__c> localFileVersions = (List<GoogleFileVersion__c>) GoogleFileVersionSelector.query()
			.withAdvancedFields()
			.byIds(versionIds)
			.toList();

		IGoogleUnitOfWork uow = new GoogleCloudUnitOfWork(GoogleCloudConstants.DEFAULT_WRITE_ORDER);
		GoogleTransientFailureResolver failureResolver = new GoogleTransientFailureResolver();
		List<GoogleFileVersion__c> copiedVersions = new List<GoogleFileVersion__c>();
		Map<Id, String> retryReasonsByVersionId = new Map<Id, String>();
		Boolean hasRecordedFailures = false;
		GoogleDrive remoteGoogleDrive = null;

        for (GoogleFileVersion__c localFileVersion : localFileVersions) {
            if (String.isNotBlank(localFileVersion.GoogleDocsFileId__c)) continue;

			String targetGoogleWorkspaceType = GoogleCloudConstants.FILE_EXTENSION_TO_PREVIEW_TYPE.get(localFileVersion.Type__c);
			if (String.isBlank(targetGoogleWorkspaceType)) continue;

			try {
				if (remoteGoogleDrive == null) {
					remoteGoogleDrive = new GoogleClientApiProvider().retrieveGoogleDriveClient();
				}

				GoogleFileEntity clonedFile = remoteGoogleDrive.files().clone(localFileVersion.GoogleDriveFileId__c)
					.setFields('id')
					.setFileName(localFileVersion.Name)
					.setSupportsAllDrives(true)
					.setMimeType(targetGoogleWorkspaceType)
					.execute();

				uow.registerDirty(new GoogleFileVersion__c(
					Id = localFileVersion.Id,
					GoogleDocsFileId__c = clonedFile.id
				));

				localFileVersion.GoogleDocsFileId__c = clonedFile.id;
				copiedVersions.add(localFileVersion);
			} catch (Exception ex) {
				if (failureResolver.isRetryable(ex)) {
					retryReasonsByVersionId.put(localFileVersion.Id, ex.getMessage());
				} else {
					recordFailure(ERROR_LEVEL, buildGaveUpMessage(localFileVersion.Id, currentAttempt, ex.getMessage()));
					hasRecordedFailures = true;
				}
			}
        }

		if (commitCopies(uow, copiedVersions)) {
			Set<Id> copiedVersionIds = new Map<Id, GoogleFileVersion__c>(copiedVersions).keySet();
			if (currentAttempt > FIRST_ATTEMPT) {
				chainAnalysisForLateCopies(copiedVersions);
			}

			GoogleFileVersionPreviewSizeJob.schedule(copiedVersionIds, this.chainIntelligence != false);
		}

		hasRecordedFailures = chainRetry(retryReasonsByVersionId, currentAttempt, failureResolver) || hasRecordedFailures;
		if (hasRecordedFailures) {
			Logger.saveLog();
		}
    }

	private Integer resolveAttempt() {
		return this.attempt == null || this.attempt < FIRST_ATTEMPT ? FIRST_ATTEMPT : this.attempt;
	}

	private Boolean commitCopies(IGoogleUnitOfWork uow, List<GoogleFileVersion__c> copiedVersions) {
		if (copiedVersions.isEmpty()) return false;

		try {
			GTriggerHandler.setBypass('GoogleFileVersionTriggerHandler', true);
			uow.commitWork(true);
			return true;
		} catch (Exception ex) {
			Logger.error('Google File Version update failed (Local): ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			return false;
		} finally {
			GTriggerHandler.clearAllBypasses();
		}
	}

	private void chainAnalysisForLateCopies(List<GoogleFileVersion__c> copiedVersions) {
		if (this.chainIntelligence == false) return;

		Set<Id> analysisCandidateIds = new GoogleFileVersionContextResolver().collectSummaryCandidateVersionIds(copiedVersions);
		if (analysisCandidateIds.isEmpty()) return;

		GoogleFileIntelligenceFactory intelligenceFactory = new GoogleFileIntelligenceFactory();
		if (!intelligenceFactory.isConfigured()) return;

		GQueueableBuilder analysisChainer = GAsync.queueable()
			.chain(new GoogleFileVersionSummaryJob(analysisCandidateIds))
			.deepClone();

		if (intelligenceFactory.isLabelingConfigured()) {
			analysisChainer.chain(new GoogleFileVersionLabelJob(analysisCandidateIds)).deepClone();
		}

		analysisChainer.enqueue();
	}

	private Boolean chainRetry(Map<Id, String> retryReasonsByVersionId, Integer currentAttempt, GoogleTransientFailureResolver failureResolver) {
		if (retryReasonsByVersionId.isEmpty()) return false;

		if (!failureResolver.hasAttemptsLeft(currentAttempt)) {
			for (Id versionId : retryReasonsByVersionId.keySet()) {
				recordFailure(ERROR_LEVEL, buildGaveUpMessage(versionId, currentAttempt, retryReasonsByVersionId.get(versionId)));
			}
			return true;
		}

		Integer nextAttempt = currentAttempt + 1;
		Integer delayMinutes = failureResolver.resolveRetryDelayMinutes(nextAttempt);
		for (Id versionId : retryReasonsByVersionId.keySet()) {
			recordFailure(WARN_LEVEL, 'Google Workspace Copy Retry Scheduled --> VersionId=' + String.valueOf(versionId) + ', NextAttempt=' + nextAttempt + ', InMinutes=' + delayMinutes + ', Message=' + retryReasonsByVersionId.get(versionId));
		}

		GAsync.queueable()
			.chain(new GoogleFileVersionPreviewJob(retryReasonsByVersionId.keySet(), this.chainIntelligence != false, nextAttempt))
			.deepClone()
			.delay(delayMinutes)
			.enqueue();

		return true;
	}

	private void recordFailure(String level, String message) {
		if (level == ERROR_LEVEL) {
			Logger.error(message).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
		} else {
			Logger.warn(message).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
		}

		loggedFailures.add(level + ' ' + message);
	}

	private String buildGaveUpMessage(Id versionId, Integer currentAttempt, String reason) {
		return 'Google Workspace Copy Gave Up --> VersionId=' + String.valueOf(versionId) + ', Attempts=' + currentAttempt + ', Message=' + reason;
	}
}
