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
@IsTest
private class GoogleFileVersionLabelJobTest {
	private static final String DOCX_MIME_TYPE = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
	private static final String WARN_LEVEL = 'WARN';
	private static final String ERROR_LEVEL = 'ERROR';
	private static final String TIMEOUT_REASON = 'Read timed out';
	private static final String LABEL_DEFINITIONS = '[{"name":"Invoice","labelId":"LABEL_INVOICE","description":"A bill requesting payment for goods or services"}]';

	private static GoogleClientConfig__mdt buildFinalizeDisabledConfig() {
		return new GoogleClientConfig__mdt(
			IsFilePreviewDisabled__c = true
		);
	}

	private static GoogleFileLabelResultDTO buildTestResult(Boolean success, Boolean blocked, Boolean applied, String labelName, Integer confidence, String errorMessage) {
		GoogleFileLabelResultDTO result = new GoogleFileLabelResultDTO();
		result.success = success;
		result.blocked = blocked;
		result.applied = applied;
		result.provider = 'Gemini';
		result.labelName = labelName;
		result.labelId = labelName == null ? null : 'LABEL_' + labelName.toUpperCase();
		result.confidence = confidence;
		result.errorMessage = errorMessage;
		return result;
	}

	private static GoogleFileVersion__c createLabelCandidate(String fileName) {
		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName(fileName)
			.insertRecord();

		return GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName(fileName + '.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(2048)
			.withDocsId('DOCS_' + fileName)
			.insertRecord();
	}

	private static GoogleFileLabelResultDTO buildRetryableResult(String reason) {
		GoogleFileLabelResultDTO result = buildTestResult(null, null, null, null, null, reason);
		result.retryable = true;
		return result;
	}

	private static void prepareRetryContext() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();
		GoogleFileVersionLabelJob.clearTestResults();
		GoogleCalloutTimeResolver.elapsedMillisOverride = 0L;
		GoogleTransientFailureResolver.retrySpreadOverride = 0;
	}

	private static GoogleFileVersion__c createAnalysisCandidate(String fileName, Boolean withWorkspaceCopy) {
		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName(fileName)
			.insertRecord();

		return GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName(fileName + '.docx')
			.withType(DOCX_MIME_TYPE)
			.withSize(2048)
			.withDriveId('GD_' + fileName)
			.withDocsId(withWorkspaceCopy ? 'DOCS_' + fileName : null)
			.insertRecord();
	}

	private static List<GoogleFileVersionLabelJob> chainedLabelJobs(GQueueableChain chain) {
		List<GoogleFileVersionLabelJob> labelJobs = new List<GoogleFileVersionLabelJob>();
		for (GQueueableJob chainedJob : chain.getJobs()) {
			if (chainedJob instanceof GoogleFileVersionLabelJob) labelJobs.add((GoogleFileVersionLabelJob) chainedJob);
		}

		return labelJobs;
	}

	private static List<String> loggedEntries(String level) {
		List<String> entries = new List<String>();
		if (GoogleFileVersionLabelJob.loggedFailures == null) return entries;

		for (String entry : GoogleFileVersionLabelJob.loggedFailures) {
			if (entry != null && entry.startsWith(level + ' ')) entries.add(entry);
		}

		return entries;
	}

	private static Boolean hasLoggedFailures() {
		return GoogleFileVersionLabelJob.loggedFailures != null && !GoogleFileVersionLabelJob.loggedFailures.isEmpty();
	}

	private static GoogleFileVersionLabel__c loadLabel(Id versionId) {
		List<GoogleFileVersionLabel__c> versionLabels = [
			SELECT Name, GoogleDriveLabelId__c, Confidence__c
			FROM GoogleFileVersionLabel__c
			WHERE GoogleFileVersionId__c = :versionId
		];

		return versionLabels.isEmpty() ? null : versionLabels[0];
	}

	@IsTest
	private static void testExecutePositiveStoresAppliedLabel() {
		GoogleMetadataConfigService.configRecordOverride = buildFinalizeDisabledConfig();
		GoogleFileVersionLabelJob.skipExecution = true;
		GoogleFileVersionLabelJob.clearTestResults();

		GoogleFileVersion__c version = createLabelCandidate('LBLJOB1');

		GoogleFileVersionLabelJob.skipExecution = false;
		GoogleFileVersionLabelJob.setTestResult(version.Id, buildTestResult(true, null, true, 'Invoice', 92, null));

		Test.startTest();
			new GoogleFileVersionLabelJob(new Set<Id>{ version.Id }).work();
		Test.stopTest();
		GoogleFileVersionLabelJob.clearTestResults();

		GoogleFileVersionLabel__c versionLabel = loadLabel(version.Id);
		Assert.isNotNull(versionLabel);
		Assert.areEqual('Invoice', versionLabel.Name);
		Assert.areEqual('LABEL_INVOICE', versionLabel.GoogleDriveLabelId__c);
		Assert.areEqual(92, versionLabel.Confidence__c);
	}

	@IsTest
	private static void testExecutePositiveLeavesFileUnlabeledWhenNotApplied() {
		GoogleMetadataConfigService.configRecordOverride = buildFinalizeDisabledConfig();
		GoogleFileVersionLabelJob.skipExecution = true;
		GoogleFileVersionLabelJob.clearTestResults();

		GoogleFileVersion__c version = createLabelCandidate('LBLJOB2');

		GoogleFileVersionLabelJob.skipExecution = false;
		GoogleFileVersionLabelJob.setTestResult(version.Id, buildTestResult(true, null, false, 'Invoice', 40, null));

		Test.startTest();
			new GoogleFileVersionLabelJob(new Set<Id>{ version.Id }).work();
		Test.stopTest();
		GoogleFileVersionLabelJob.clearTestResults();

		Assert.isNull(loadLabel(version.Id));
	}

	@IsTest
	private static void testExecutePositiveSkipsFailedDriveUpdate() {
		GoogleMetadataConfigService.configRecordOverride = buildFinalizeDisabledConfig();
		GoogleFileVersionLabelJob.skipExecution = true;
		GoogleFileVersionLabelJob.clearTestResults();

		GoogleFileVersion__c version = createLabelCandidate('LBLJOB3');

		GoogleFileVersionLabelJob.skipExecution = false;
		GoogleFileVersionLabelJob.setTestResult(version.Id, buildTestResult(true, null, false, 'Invoice', 95, 'Label access denied'));

		Test.startTest();
			new GoogleFileVersionLabelJob(new Set<Id>{ version.Id }).work();
		Test.stopTest();
		GoogleFileVersionLabelJob.clearTestResults();

		Assert.isNull(loadLabel(version.Id));
	}

	@IsTest
	private static void testExecutePositiveSkipsBlockedResult() {
		GoogleMetadataConfigService.configRecordOverride = buildFinalizeDisabledConfig();
		GoogleFileVersionLabelJob.skipExecution = true;
		GoogleFileVersionLabelJob.clearTestResults();

		GoogleFileVersion__c version = createLabelCandidate('LBLJOB4');

		GoogleFileVersionLabelJob.skipExecution = false;
		GoogleFileVersionLabelJob.setTestResult(version.Id, buildTestResult(null, true, null, null, null, 'Blocked for test'));

		Test.startTest();
			new GoogleFileVersionLabelJob(new Set<Id>{ version.Id }).work();
		Test.stopTest();
		GoogleFileVersionLabelJob.clearTestResults();

		Assert.isNull(loadLabel(version.Id));
	}

	@IsTest
	private static void testExecutePositiveSkipsWhenLabelingIsNotConfigured() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt();
		GoogleFileVersionLabelJob.skipExecution = true;
		GoogleFileVersionLabelJob.clearTestResults();

		GoogleFileVersion__c version = createLabelCandidate('LBLJOB5');

		GoogleFileVersionLabelJob.skipExecution = false;

		Test.startTest();
			new GoogleFileVersionLabelJob(new Set<Id>{ version.Id }).work();
		Test.stopTest();

		Assert.isNull(loadLabel(version.Id));
	}

	@IsTest
	private static void testExecutePositiveReturnsEarlyWhenSkippedOrEmpty() {
		GoogleMetadataConfigService.configRecordOverride = buildFinalizeDisabledConfig();
		GoogleFileVersionLabelJob.skipExecution = true;
		GoogleFileVersionLabelJob.clearTestResults();

		GoogleFileVersion__c version = createLabelCandidate('LBLJOB6');
		GoogleFileVersionLabelJob.setTestResult(version.Id, buildTestResult(true, null, true, 'Invoice', 92, null));

		Test.startTest();
			new GoogleFileVersionLabelJob(new Set<Id>{ version.Id }).work();
			GoogleFileVersionLabelJob.skipExecution = false;
			new GoogleFileVersionLabelJob(new Set<Id>()).work();
			new GoogleFileVersionLabelJob(null).work();
		Test.stopTest();
		GoogleFileVersionLabelJob.clearTestResults();

		Assert.isNull(loadLabel(version.Id), 'A skipped job must not store the label it would have applied');
	}

	@IsTest
	private static void testExecutePositiveRetriesOnlyTheFailedVersions() {
		prepareRetryContext();
		GoogleFileVersion__c labeledVersion = createAnalysisCandidate('LBLRTY1', true);
		GoogleFileVersion__c timedOutVersion = createAnalysisCandidate('LBLRTY2', true);
		GoogleFileVersion__c refusedVersion = createAnalysisCandidate('LBLRTY3', true);
		GoogleFileVersionLabelJob.setTestResult(labeledVersion.Id, buildTestResult(true, null, true, 'Invoice', 92, null));
		GoogleFileVersionLabelJob.setTestResult(timedOutVersion.Id, buildRetryableResult(TIMEOUT_REASON));
		GoogleFileVersionLabelJob.setTestResult(refusedVersion.Id, buildTestResult(true, null, false, 'Invoice', 95, 'Label access denied'));
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Test.startTest();
			new GoogleFileVersionLabelJob(new Set<Id>{ labeledVersion.Id, timedOutVersion.Id, refusedVersion.Id }).work();
		Test.stopTest();
		GoogleFileVersionLabelJob.clearTestResults();

		Assert.isNotNull(loadLabel(labeledVersion.Id), 'The labels that worked are saved as usual');
		Assert.isNull(loadLabel(timedOutVersion.Id));
		Assert.isNull(loadLabel(refusedVersion.Id));

		List<GoogleFileVersionLabelJob> retryJobs = chainedLabelJobs(runningChain);
		Assert.areEqual(1, retryJobs.size());
		Assert.areEqual(new Set<Id>{ timedOutVersion.Id }, retryJobs[0].versionIds, 'A label Drive refused is not retried; only the model call that failed for a passing reason is');
		Assert.areEqual(2, retryJobs[0].attempt);
		Assert.areEqual(1, retryJobs[0].delay);

		List<String> warnings = loggedEntries(WARN_LEVEL);
		Assert.areEqual(1, warnings.size());
		Assert.isTrue(warnings[0].contains(timedOutVersion.Id));
		Assert.isTrue(warnings[0].contains(TIMEOUT_REASON));
		List<String> errors = loggedEntries(ERROR_LEVEL);
		Assert.areEqual(1, errors.size(), 'A Drive refusal is given up on at once, as today');
		Assert.isTrue(errors[0].contains(refusedVersion.Id));
	}

	@IsTest
	private static void testExecutePositiveGivesUpAfterTheThirdAttempt() {
		prepareRetryContext();
		GoogleFileVersion__c version = createAnalysisCandidate('LBLRTY4', true);
		GoogleFileVersionLabelJob.setTestResult(version.Id, buildRetryableResult(TIMEOUT_REASON));
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Test.startTest();
			new GoogleFileVersionLabelJob(new Set<Id>{ version.Id }, 3).work();
		Test.stopTest();
		GoogleFileVersionLabelJob.clearTestResults();

		Assert.areEqual(0, runningChain.getJobs().size(), 'Labeling has the same bound of three attempts');
		Assert.areEqual(0, loggedEntries(WARN_LEVEL).size());
		List<String> errors = loggedEntries(ERROR_LEVEL);
		Assert.areEqual(1, errors.size());
		Assert.isTrue(errors[0].contains(version.Id));
	}

	@IsTest
	private static void testExecutePositiveSecondRetryWaitsThreeMinutes() {
		prepareRetryContext();
		GoogleFileVersion__c version = createAnalysisCandidate('LBLRTY5', true);
		GoogleFileVersionLabelJob.setTestResult(version.Id, buildRetryableResult(TIMEOUT_REASON));
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Test.startTest();
			new GoogleFileVersionLabelJob(new Set<Id>{ version.Id }, 2).work();
		Test.stopTest();
		GoogleFileVersionLabelJob.clearTestResults();

		List<GoogleFileVersionLabelJob> retryJobs = chainedLabelJobs(runningChain);
		Assert.areEqual(1, retryJobs.size());
		Assert.areEqual(3, retryJobs[0].attempt);
		Assert.areEqual(3, retryJobs[0].delay);
	}

	@IsTest
	private static void testExecutePositiveDefersVersionsWhenCalloutTimeRunsShort() {
		prepareRetryContext();
		List<GoogleFileVersion__c> versions = new List<GoogleFileVersion__c>{
			createAnalysisCandidate('LBLDEF1', true),
			createAnalysisCandidate('LBLDEF2', true),
			createAnalysisCandidate('LBLDEF3', true)
		};
		for (GoogleFileVersion__c version : versions) {
			GoogleFileVersionLabelJob.setTestResult(version.Id, buildTestResult(true, null, true, 'Invoice', 92, null));
		}
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();
		GoogleCalloutTimeResolver.elapsedMillisOverride = 95000L;
		Set<Id> versionIds = new Map<Id, GoogleFileVersion__c>(versions).keySet();

		Test.startTest();
			new GoogleFileVersionLabelJob(versionIds).work();
		Test.stopTest();
		GoogleFileVersionLabelJob.clearTestResults();

		Assert.areEqual(1, [SELECT COUNT() FROM GoogleFileVersionLabel__c WHERE GoogleFileVersionId__c IN :versionIds], 'The first version always runs; the rest wait for a job with time left');
		List<GoogleFileVersionLabelJob> followUpJobs = chainedLabelJobs(runningChain);
		Assert.areEqual(1, followUpJobs.size());
		Assert.areEqual(2, followUpJobs[0].versionIds.size());
		Assert.areEqual(1, followUpJobs[0].attempt);
		Assert.isNull(followUpJobs[0].delay, 'The follow-up starts straight away');
	}

	@IsTest
	private static void testExecutePositiveStopsWhenLabelingWasTurnedOff() {
		GoogleIntelligenceHttpMock intelligenceMock = new GoogleIntelligenceHttpMock();
		GoogleCloudTestFactory.config()
			.withFileIntelligence(true)
			.withGeminiApiKey('api-key-1')
			.withAiModel('gemini-2.0-flash')
			.withAiLabelDefinitions(LABEL_DEFINITIONS)
			.apply();
		GoogleCloudTestFactory.initMocks(new GoogleCompositeHttpMock(new GoogleDriveHttpMock().withDefaultHappyPath(), intelligenceMock));
		GoogleCloudTestFactory.bypassTriggers();
		GoogleFileVersionLabelJob.clearTestResults();
		GoogleCalloutTimeResolver.elapsedMillisOverride = 0L;
		GoogleFileVersion__c version = createAnalysisCandidate('LBLOFF', true);
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Test.startTest();
			new GoogleFileVersionLabelJob(new Set<Id>{ version.Id }, 2).work();
		Test.stopTest();

		Assert.areEqual(0, intelligenceMock.getRequestCount(), 'A retry finds labeling turned off and sends nothing');
		Assert.areEqual(0, runningChain.getJobs().size());
		Assert.areEqual(0, loggedEntries(WARN_LEVEL).size());
		Assert.areEqual(0, loggedEntries(ERROR_LEVEL).size(), 'Labeling being turned off is not a failure');
	}

	@IsTest
	private static void testExecutePositiveStopsWhenAlreadyLabeled() {
		GoogleIntelligenceHttpMock intelligenceMock = new GoogleIntelligenceHttpMock();
		GoogleCloudTestFactory.config()
			.withFileIntelligence(true)
			.withGeminiApiKey('api-key-1')
			.withAiModel('gemini-2.0-flash')
			.withAiLabeling(true)
			.withAiLabelDefinitions(LABEL_DEFINITIONS)
			.apply();
		GoogleCloudTestFactory.initMocks(new GoogleCompositeHttpMock(new GoogleDriveHttpMock().withDefaultHappyPath(), intelligenceMock));
		GoogleCloudTestFactory.bypassTriggers();
		GoogleFileVersionLabelJob.clearTestResults();
		GoogleCalloutTimeResolver.elapsedMillisOverride = 0L;
		GoogleFileVersion__c version = createAnalysisCandidate('LBLDONE', true);
		update new GoogleFileVersion__c(Id = version.Id, AiLabels__c = 'Invoice');
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Test.startTest();
			new GoogleFileVersionLabelJob(new Set<Id>{ version.Id }, 2).work();
		Test.stopTest();

		Assert.areEqual(0, intelligenceMock.getRequestCount(), 'A version is labeled at most once, retry or not');
		Assert.areEqual(0, runningChain.getJobs().size());
		Assert.isFalse(hasLoggedFailures());
	}

	@IsTest
	private static void testExecutePositiveCommitFailureStillQueuesTheRetry() {
		prepareRetryContext();
		GoogleFileVersion__c oversizedVersion = createAnalysisCandidate('LBLCMT1', true);
		GoogleFileVersion__c timedOutVersion = createAnalysisCandidate('LBLCMT2', true);
		GoogleFileVersionLabelJob.setTestResult(oversizedVersion.Id, buildTestResult(true, null, true, 'L'.repeat(100), 92, null));
		GoogleFileVersionLabelJob.setTestResult(timedOutVersion.Id, buildRetryableResult(TIMEOUT_REASON));
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Exception jobFailure;
		Test.startTest();
			try {
				new GoogleFileVersionLabelJob(new Set<Id>{ oversizedVersion.Id, timedOutVersion.Id }).work();
			} catch (Exception ex) {
				jobFailure = ex;
			}
		Test.stopTest();
		GoogleFileVersionLabelJob.clearTestResults();

		Assert.isNull(jobFailure, 'A failed save is logged rather than thrown');
		List<GoogleFileVersionLabelJob> retryJobs = chainedLabelJobs(runningChain);
		Assert.areEqual(1, retryJobs.size(), 'The retry is queued whatever the save does');
		Assert.areEqual(new Set<Id>{ timedOutVersion.Id }, retryJobs[0].versionIds);
	}

	@IsTest
	private static void testExecutePositiveJobQueuedBeforeTheUpgradeCountsAsTheFirstAttempt() {
		prepareRetryContext();
		GoogleFileVersion__c version = createAnalysisCandidate('LBLUPG', true);
		GoogleFileVersionLabelJob.setTestResult(version.Id, buildRetryableResult(TIMEOUT_REASON));
		Map<String, Object> serializedJob = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(new GoogleFileVersionLabelJob(new Set<Id>{ version.Id })));
		serializedJob.remove('attempt');
		GoogleFileVersionLabelJob queuedBeforeUpgrade = (GoogleFileVersionLabelJob) JSON.deserialize(JSON.serialize(serializedJob), GoogleFileVersionLabelJob.class);
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Test.startTest();
			queuedBeforeUpgrade.work();
		Test.stopTest();
		GoogleFileVersionLabelJob.clearTestResults();

		List<GoogleFileVersionLabelJob> retryJobs = chainedLabelJobs(runningChain);
		Assert.areEqual(1, retryJobs.size());
		Assert.areEqual(2, retryJobs[0].attempt);
	}

	@IsTest
	private static void testExecutePositiveLogsAVersionWithoutWorkspaceCopy() {
		prepareRetryContext();
		GoogleFileVersion__c version = createAnalysisCandidate('LBLNOCPY', false);
		GoogleFileVersionLabelJob.setTestResult(version.Id, buildTestResult(true, null, true, 'Invoice', 92, null));
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Test.startTest();
			new GoogleFileVersionLabelJob(new Set<Id>{ version.Id }).work();
		Test.stopTest();
		GoogleFileVersionLabelJob.clearTestResults();

		Assert.isNull(loadLabel(version.Id));
		List<String> warnings = loggedEntries(WARN_LEVEL);
		Assert.areEqual(1, warnings.size());
		Assert.isTrue(warnings[0].contains(version.Id));
		Assert.areEqual(0, runningChain.getJobs().size());
	}

	@IsTest
	private static void testExecutePositiveLogsNothingNewForAnUnsureAnswer() {
		prepareRetryContext();
		GoogleFileVersion__c version = createAnalysisCandidate('LBLUNSURE', true);
		GoogleFileVersionLabelJob.setTestResult(version.Id, buildTestResult(true, null, false, 'Invoice', 40, null));
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Test.startTest();
			new GoogleFileVersionLabelJob(new Set<Id>{ version.Id }).work();
		Test.stopTest();
		GoogleFileVersionLabelJob.clearTestResults();

		Assert.isNull(loadLabel(version.Id));
		Assert.isFalse(hasLoggedFailures(), 'A file the model is unsure about is the normal way to stay unlabeled, not a failure');
		Assert.areEqual(0, runningChain.getJobs().size());
	}

	@IsTest
	private static void testExecutePositiveRetriesAnAnswerCutAtTheTokenLimit() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		GoogleIntelligenceHttpMock intelligenceMock = new GoogleIntelligenceHttpMock().withResponseBody(buildModelAnswer('Label: Invoice\nConfidence: 10', 'MAX_TOKENS'));
		prepareLabelingThroughTheStrategy(driveMock, intelligenceMock);
		GoogleFileVersion__c version = createAnalysisCandidate('LBLCUTJ1', true);
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Test.startTest();
			new GoogleFileVersionLabelJob(new Set<Id>{ version.Id }).work();
		Test.stopTest();

		Assert.areEqual(1, intelligenceMock.getRequestCount());
		Assert.isNull(loadLabel(version.Id));
		Assert.isFalse(hasModifyLabelsRequest(driveMock), 'A cut answer is never applied in Drive');
		List<GoogleFileVersionLabelJob> retryJobs = chainedLabelJobs(runningChain);
		Assert.areEqual(1, retryJobs.size(), 'A cut answer that led to no label is tried again, not taken as "no label fits"');
		Assert.areEqual(new Set<Id>{ version.Id }, retryJobs[0].versionIds);
		Assert.areEqual(2, retryJobs[0].attempt);
		Assert.areEqual(1, retryJobs[0].delay);
		List<String> warnings = loggedEntries(WARN_LEVEL);
		Assert.areEqual(1, warnings.size());
		Assert.isTrue(warnings[0].contains('File Label Retry Scheduled'));
		Assert.isTrue(warnings[0].contains(version.Id));
		Assert.isTrue(warnings[0].contains('FinishReason=MAX_TOKENS'));
		Assert.areEqual(0, loggedEntries(ERROR_LEVEL).size());
	}

	@IsTest
	private static void testExecutePositiveGivesUpOnAnAnswerCutAtTheThirdAttempt() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		GoogleIntelligenceHttpMock intelligenceMock = new GoogleIntelligenceHttpMock().withResponseBody(buildModelAnswer('Label: Inv', 'MAX_TOKENS'));
		prepareLabelingThroughTheStrategy(driveMock, intelligenceMock);
		GoogleFileVersion__c version = createAnalysisCandidate('LBLCUTJ3', true);
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Test.startTest();
			new GoogleFileVersionLabelJob(new Set<Id>{ version.Id }, 3).work();
		Test.stopTest();

		Assert.areEqual(0, runningChain.getJobs().size(), 'The third cut answer ends the attempts');
		Assert.isNull(loadLabel(version.Id));
		List<String> errors = loggedEntries(ERROR_LEVEL);
		Assert.areEqual(1, errors.size(), 'Giving up on a cut answer is one ERROR line, not a "not assigned" note');
		Assert.isTrue(errors[0].contains('File Label Gave Up'));
		Assert.isTrue(errors[0].contains('Attempts=3'));
		Assert.isTrue(errors[0].contains('FinishReason=MAX_TOKENS'));
	}

	@IsTest
	private static void testExecutePositiveFollowUpRunsStraightAfterTheJobThatDeferredIt() {
		prepareRetryContext();
		List<GoogleFileVersion__c> versions = new List<GoogleFileVersion__c>();
		for (Integer index = 0; index < 3; index++) {
			GoogleFileVersion__c version = createAnalysisCandidate('LBLPRI' + index, true);
			GoogleFileVersionLabelJob.setTestResult(version.Id, buildTestResult(true, null, true, 'Invoice', 92, null));
			versions.add(version);
		}
		Set<Id> versionIds = new Map<Id, GoogleFileVersion__c>(versions).keySet();
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();
		GoogleFileVersionLabelJob labelJob = new GoogleFileVersionLabelJob(versionIds);
		GoogleFileVersionPreviewSizeJob queuedSizeJob = buildQueuedSizeJob(versionIds);
		GoogleFileVersionSummaryJob queuedSummaryRetry = buildQueuedSummaryRetry(versionIds);
		queueUploadChain(runningChain, labelJob, new List<GQueueableJob>{ queuedSizeJob, queuedSummaryRetry });
		GoogleCalloutTimeResolver.elapsedMillisOverride = 90001L;

		Test.startTest();
			labelJob.work();
		Test.stopTest();
		GoogleFileVersionLabelJob.clearTestResults();
		labelJob.isProcessed = true;

		List<GQueueableJob> waitingJobs = pendingJobs(runningChain);
		Assert.areEqual(3, waitingJobs.size());
		Assert.isTrue(waitingJobs[0] instanceof GoogleFileVersionLabelJob, 'The label follow-up runs straight after the job that deferred it, ahead of the size check and an earlier retry');
		GoogleFileVersionLabelJob followUpJob = (GoogleFileVersionLabelJob) waitingJobs[0];
		Assert.areEqual(2, followUpJob.versionIds.size());
		Assert.areEqual(1, followUpJob.attempt);
		Assert.isNull(followUpJob.delay);
		Assert.areEqual(1, followUpJob.priority);
		Assert.isTrue(waitingJobs[1] === queuedSizeJob, 'The size check keeps its place');
		Assert.isTrue(waitingJobs[2] === queuedSummaryRetry, 'The summary retry queued before keeps its place too');
	}

	@IsTest
	private static void testExecutePositiveRetryStillWaitsAtTheEndOfTheChain() {
		prepareRetryContext();
		GoogleFileVersion__c version = createAnalysisCandidate('LBLPRR', true);
		GoogleFileVersionLabelJob.setTestResult(version.Id, buildRetryableResult(TIMEOUT_REASON));
		Set<Id> versionIds = new Set<Id>{ version.Id };
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();
		GoogleFileVersionLabelJob labelJob = new GoogleFileVersionLabelJob(versionIds);
		GoogleFileVersionPreviewSizeJob queuedSizeJob = buildQueuedSizeJob(versionIds);
		GoogleFileVersionSummaryJob queuedSummaryRetry = buildQueuedSummaryRetry(versionIds);
		queueUploadChain(runningChain, labelJob, new List<GQueueableJob>{ queuedSizeJob, queuedSummaryRetry });

		Test.startTest();
			labelJob.work();
		Test.stopTest();
		GoogleFileVersionLabelJob.clearTestResults();
		labelJob.isProcessed = true;

		List<GQueueableJob> waitingJobs = pendingJobs(runningChain);
		Assert.areEqual(3, waitingJobs.size());
		Assert.isTrue(waitingJobs[0] === queuedSizeJob, 'A label retry does not jump the queue');
		Assert.isTrue(waitingJobs[1] === queuedSummaryRetry);
		Assert.isTrue(waitingJobs[2] instanceof GoogleFileVersionLabelJob, 'The label retry is appended at the end');
		GoogleFileVersionLabelJob retryJob = (GoogleFileVersionLabelJob) waitingJobs[2];
		Assert.areEqual(2, retryJob.attempt);
		Assert.areEqual(1, retryJob.delay);
		Assert.isNull(retryJob.priority);
	}

	private static GoogleFileVersionPreviewSizeJob buildQueuedSizeJob(Set<Id> versionIds) {
		GoogleFileVersionPreviewSizeJob sizeJob = new GoogleFileVersionPreviewSizeJob(versionIds);
		sizeJob.delay = 1;
		return sizeJob;
	}

	private static GoogleFileVersionSummaryJob buildQueuedSummaryRetry(Set<Id> versionIds) {
		GoogleFileVersionSummaryJob summaryRetry = new GoogleFileVersionSummaryJob(versionIds, 2);
		summaryRetry.delay = 2;
		return summaryRetry;
	}

	private static void queueUploadChain(GQueueableChain chain, GQueueableJob runningJob, List<GQueueableJob> queuedJobs) {
		GQueueableJob previewJob = new GoogleFileVersionPreviewJob(new Set<Id>());
		previewJob.isProcessed = true;
		GQueueableJob folderJob = new GoogleFileCloudFolderJob(new List<GoogleFileRelocationRequestDTO>());
		folderJob.isProcessed = true;
		GQueueableJob summaryJob = new GoogleFileVersionSummaryJob(new Set<Id>());
		summaryJob.isProcessed = true;
		chain.addJob(previewJob);
		chain.addJob(folderJob);
		chain.addJob(summaryJob);
		chain.addJob(runningJob);
		for (GQueueableJob queuedJob : queuedJobs) {
			chain.addJob(queuedJob);
		}
	}

	private static List<GQueueableJob> pendingJobs(GQueueableChain chain) {
		List<GQueueableJob> waitingJobs = new List<GQueueableJob>();
		for (GQueueableJob chainedJob : chain.getJobs()) {
			if (chainedJob.isProcessed != true) waitingJobs.add(chainedJob);
		}

		return waitingJobs;
	}

	private static void prepareLabelingThroughTheStrategy(GoogleDriveHttpMock driveMock, GoogleIntelligenceHttpMock intelligenceMock) {
		GoogleCloudTestFactory.config()
			.withFileIntelligence(true)
			.withGeminiApiKey('api-key-1')
			.withAiModel('gemini-2.0-flash')
			.withAiLabeling(true)
			.withAiLabelingThinkingBudget(0)
			.withAiLabelDefinitions(LABEL_DEFINITIONS)
			.apply();
		GoogleCloudTestFactory.initMocks(new GoogleCompositeHttpMock(driveMock, intelligenceMock));
		GoogleCloudTestFactory.bypassTriggers();
		GoogleFileVersionLabelJob.clearTestResults();
		GoogleCalloutTimeResolver.elapsedMillisOverride = 0L;
		GoogleTransientFailureResolver.retrySpreadOverride = 0;
	}

	private static String buildModelAnswer(String text, String finishReason) {
		return JSON.serialize(new Map<String, Object>{
			'candidates' => new List<Object>{
				new Map<String, Object>{
					'content' => new Map<String, Object>{
						'parts' => new List<Object>{ new Map<String, Object>{ 'text' => text } },
						'role' => 'model'
					},
					'finishReason' => finishReason
				}
			}
		});
	}

	private static Boolean hasModifyLabelsRequest(GoogleDriveHttpMock driveMock) {
		for (GoogleDriveHttpMock.CapturedRequest capturedRequest : driveMock.getCapturedRequests()) {
			if (capturedRequest.endpoint != null && capturedRequest.endpoint.contains('/modifyLabels')) return true;
		}

		return false;
	}
}
