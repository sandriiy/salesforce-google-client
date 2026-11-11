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
private class GoogleFileVersionSummaryJobTest {
	private static final String DOCX_MIME_TYPE = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
	private static final String WARN_LEVEL = 'WARN';
	private static final String ERROR_LEVEL = 'ERROR';
	private static final String TIMEOUT_REASON = 'Read timed out';
	private static final String INVALID_ARGUMENT_BODY = '{"error":{"code":400,"message":"API key not valid. Please pass a valid API key.","status":"INVALID_ARGUMENT"}}';
	private static final String GENERATED_SUMMARY = 'This file describes a quarterly budget review with revenue targets and staffing updates.';
	private static final String OVERSIZED_SUMMARY = 'S'.repeat(300);

	private static GoogleClientConfig__mdt buildFinalizeDisabledConfig() {
		return new GoogleClientConfig__mdt(
			IsFilePreviewDisabled__c = true
		);
	}

	private static GoogleFileAnalysisResultDTO buildTestResult(Boolean success, Boolean blocked, String text, String finishReason, String errorMessage) {
		GoogleFileAnalysisResultDTO result = new GoogleFileAnalysisResultDTO();
		result.success = success;
		result.blocked = blocked;
		result.provider = 'Gemini';
		result.operationType = 'SUMMARY';
		result.text = text;
		result.finishReason = finishReason;
		result.errorMessage = errorMessage;
		return result;
	}

	private static GoogleFileAnalysisResultDTO buildRetryableResult(String reason) {
		GoogleFileAnalysisResultDTO result = buildTestResult(false, null, null, null, reason);
		result.retryable = true;
		return result;
	}

	private static void prepareRetryContext() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();
		GoogleFileVersionSummaryJob.clearTestResults();
		GoogleCalloutTimeResolver.elapsedMillisOverride = 0L;
		GoogleTransientFailureResolver.retrySpreadOverride = 0;
	}

	private static GoogleIntelligenceHttpMock prepareLiveAnalysis(GoogleIntelligenceHttpMock intelligenceMock) {
		GoogleCloudTestFactory.config()
			.withFileIntelligence(true)
			.withGeminiApiKey('api-key-1')
			.withAiModel('gemini-2.0-flash')
			.apply();
		GoogleCloudTestFactory.initMocks(new GoogleCompositeHttpMock(new GoogleDriveHttpMock().withDefaultHappyPath(), intelligenceMock));
		GoogleCloudTestFactory.bypassTriggers();
		GoogleFileVersionSummaryJob.clearTestResults();
		GoogleCalloutTimeResolver.elapsedMillisOverride = 0L;
		GoogleTransientFailureResolver.retrySpreadOverride = 0;
		return intelligenceMock;
	}

	private static GoogleFileVersion__c createAnalysisCandidate(String fileName) {
		return createAnalysisCandidates(fileName, 1, false)[0];
	}

	private static List<GoogleFileVersion__c> createAnalysisCandidates(String namePrefix, Integer count, Boolean withoutWorkspaceCopy) {
		List<GoogleFile__c> parentFiles = new List<GoogleFile__c>();
		for (Integer index = 0; index < count; index++) {
			parentFiles.add(GoogleCloudTestFactory.file().withName(namePrefix + index).build());
		}
		insert parentFiles;

		List<GoogleFileVersion__c> versions = new List<GoogleFileVersion__c>();
		for (Integer index = 0; index < count; index++) {
			versions.add(GoogleCloudTestFactory.version()
				.forFile(parentFiles[index].Id)
				.withName(namePrefix + index + '.docx')
				.withType(DOCX_MIME_TYPE)
				.withSize(2048)
				.withDriveId('GD_' + namePrefix + index)
				.withDocsId(withoutWorkspaceCopy ? null : 'DOCS_' + namePrefix + index)
				.build());
		}
		insert versions;
		return versions;
	}

	private static Set<Id> idsOf(List<GoogleFileVersion__c> versions) {
		return new Map<Id, GoogleFileVersion__c>(versions).keySet();
	}

	private static String loadSummary(Id versionId) {
		return [SELECT Summary__c FROM GoogleFileVersion__c WHERE Id = :versionId LIMIT 1].Summary__c;
	}

	private static Set<Id> summarizedVersionIds(Set<Id> versionIds) {
		return new Map<Id, GoogleFileVersion__c>([SELECT Id FROM GoogleFileVersion__c WHERE Id IN :versionIds AND Summary__c != null]).keySet();
	}

	private static List<GoogleFileVersionSummaryJob> chainedSummaryJobs(GQueueableChain chain) {
		List<GoogleFileVersionSummaryJob> summaryJobs = new List<GoogleFileVersionSummaryJob>();
		for (GQueueableJob chainedJob : chain.getJobs()) {
			if (chainedJob instanceof GoogleFileVersionSummaryJob) summaryJobs.add((GoogleFileVersionSummaryJob) chainedJob);
		}

		return summaryJobs;
	}

	private static List<String> loggedEntries(String level) {
		List<String> entries = new List<String>();
		if (GoogleFileVersionSummaryJob.loggedFailures == null) return entries;

		for (String entry : GoogleFileVersionSummaryJob.loggedFailures) {
			if (entry != null && entry.startsWith(level + ' ')) entries.add(entry);
		}

		return entries;
	}

	private static Boolean hasLoggedFailures() {
		return GoogleFileVersionSummaryJob.loggedFailures != null && !GoogleFileVersionSummaryJob.loggedFailures.isEmpty();
	}

	@IsTest
	private static void testExecutePositiveStoresSummary() {
		GoogleMetadataConfigService.configRecordOverride = buildFinalizeDisabledConfig();
		GoogleFileVersionSummaryJob.skipExecution = true;
		GoogleFileVersionSummaryJob.clearTestResults();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('SUMJOB1')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('SUMJOB1.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(2048)
			.withDocsId('DOCS_SUMJOB_1')
			.insertRecord();

		GoogleFileVersionSummaryJob.skipExecution = false;
		GoogleFileVersionSummaryJob.setTestResult(
			version.Id,
			buildTestResult(
				true,
				null,
				'Budget review covers Q4 revenue targets, staffing updates, and milestone approvals.',
				'STOP',
				null
			)
		);

		Test.startTest();
			new GoogleFileVersionSummaryJob(new Set<Id>{ version.Id }).work();
		Test.stopTest();
		GoogleFileVersionSummaryJob.clearTestResults();

		GoogleFileVersion__c refreshedVersion = [
			SELECT Summary__c
			FROM GoogleFileVersion__c
			WHERE Id = :version.Id
			LIMIT 1
		];

		Assert.areEqual('Budget review covers Q4 revenue targets, staffing updates, and milestone approvals.', refreshedVersion.Summary__c);
	}

	@IsTest
	private static void testExecutePositiveSkipsMaxTokensResponse() {
		GoogleMetadataConfigService.configRecordOverride = buildFinalizeDisabledConfig();
		GoogleFileVersionSummaryJob.skipExecution = true;
		GoogleFileVersionSummaryJob.clearTestResults();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('SUMJOB2')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('SUMJOB2.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(2048)
			.withDocsId('DOCS_SUMJOB_2')
			.insertRecord();

		GoogleFileVersionSummaryJob.skipExecution = false;
		GoogleFileVersionSummaryJob.setTestResult(
			version.Id,
			buildTestResult(
				null,
				null,
				null,
				'MAX_TOKENS',
				'Summary generation reached the maximum output token limit'
			)
		);

		Test.startTest();
			new GoogleFileVersionSummaryJob(new Set<Id>{ version.Id }).work();
		Test.stopTest();
		GoogleFileVersionSummaryJob.clearTestResults();

		GoogleFileVersion__c refreshedVersion = [
			SELECT Summary__c
			FROM GoogleFileVersion__c
			WHERE Id = :version.Id
			LIMIT 1
		];

		Assert.areEqual(null, refreshedVersion.Summary__c);
	}

	@IsTest
	private static void testExecutePositiveSkipsWhenAiIsNotConfigured() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt();
		GoogleFileVersionSummaryJob.skipExecution = true;
		GoogleFileVersionSummaryJob.clearTestResults();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('SUMJOB3')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('SUMJOB3.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(2048)
			.withDocsId('DOCS_SUMJOB_3')
			.insertRecord();

		GoogleFileVersionSummaryJob.skipExecution = false;

		Test.startTest();
			new GoogleFileVersionSummaryJob(new Set<Id>{ version.Id }).work();
		Test.stopTest();

		GoogleFileVersion__c refreshedVersion = [
			SELECT Summary__c
			FROM GoogleFileVersion__c
			WHERE Id = :version.Id
			LIMIT 1
		];

		Assert.areEqual(null, refreshedVersion.Summary__c);
	}

	@IsTest
	private static void testExecutePositiveSkipsBlockedResult() {
		GoogleMetadataConfigService.configRecordOverride = buildFinalizeDisabledConfig();
		GoogleFileVersionSummaryJob.skipExecution = true;
		GoogleFileVersionSummaryJob.clearTestResults();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('SUMJOB4')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('SUMJOB4.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(2048)
			.withDocsId('DOCS_SUMJOB_4')
			.insertRecord();

		GoogleFileVersionSummaryJob.skipExecution = false;
		GoogleFileVersionSummaryJob.setTestResult(
			version.Id,
			buildTestResult(false, true, null, null, 'Blocked for test')
		);

		Test.startTest();
			new GoogleFileVersionSummaryJob(new Set<Id>{ version.Id }).work();
		Test.stopTest();
		GoogleFileVersionSummaryJob.clearTestResults();

		GoogleFileVersion__c refreshedVersion = [
			SELECT Summary__c
			FROM GoogleFileVersion__c
			WHERE Id = :version.Id
			LIMIT 1
		];

		Assert.areEqual(null, refreshedVersion.Summary__c);
	}

	@IsTest
	private static void testExecutePositiveReturnsEarlyWhenSkippedOrEmpty() {
		GoogleMetadataConfigService.configRecordOverride = buildFinalizeDisabledConfig();
		GoogleFileVersionSummaryJob.skipExecution = true;
		GoogleFileVersionSummaryJob.clearTestResults();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('SUMJOB5')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('SUMJOB5.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(2048)
			.withDocsId('DOCS_SUMJOB_5')
			.insertRecord();

		GoogleFileVersionSummaryJob.setTestResult(
			version.Id,
			buildTestResult(true, null, 'A summary that a skipped job must never store.', 'STOP', null)
		);

		Test.startTest();
			new GoogleFileVersionSummaryJob(new Set<Id>{ version.Id }).work();
			GoogleFileVersionSummaryJob.skipExecution = false;
			new GoogleFileVersionSummaryJob(new Set<Id>()).work();
			new GoogleFileVersionSummaryJob(null).work();
		Test.stopTest();
		GoogleFileVersionSummaryJob.clearTestResults();

		GoogleFileVersion__c refreshedVersion = [
			SELECT Summary__c
			FROM GoogleFileVersion__c
			WHERE Id = :version.Id
			LIMIT 1
		];

		Assert.areEqual(null, refreshedVersion.Summary__c);
	}

	@IsTest
	private static void testExecutePositiveRetriesOnlyTheFailedVersions() {
		prepareRetryContext();
		GoogleFileVersion__c summarizedVersion = createAnalysisCandidate('SUMRTY1');
		GoogleFileVersion__c timedOutVersion = createAnalysisCandidate('SUMRTY2');
		GoogleFileVersion__c refusedVersion = createAnalysisCandidate('SUMRTY3');
		GoogleFileVersionSummaryJob.setTestResult(summarizedVersion.Id, buildTestResult(true, null, GENERATED_SUMMARY, 'STOP', null));
		GoogleFileVersionSummaryJob.setTestResult(timedOutVersion.Id, buildRetryableResult(TIMEOUT_REASON));
		GoogleFileVersionSummaryJob.setTestResult(refusedVersion.Id, buildTestResult(false, null, null, null, INVALID_ARGUMENT_BODY));
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Test.startTest();
			new GoogleFileVersionSummaryJob(new Set<Id>{ summarizedVersion.Id, timedOutVersion.Id, refusedVersion.Id }).work();
		Test.stopTest();
		GoogleFileVersionSummaryJob.clearTestResults();

		Assert.areEqual(GENERATED_SUMMARY, loadSummary(summarizedVersion.Id), 'The summaries that worked are saved as usual');
		Assert.isNull(loadSummary(timedOutVersion.Id));
		Assert.isNull(loadSummary(refusedVersion.Id));

		List<GoogleFileVersionSummaryJob> retryJobs = chainedSummaryJobs(runningChain);
		Assert.areEqual(1, retryJobs.size(), 'One queued job holds the versions to try again');
		Assert.areEqual(new Set<Id>{ timedOutVersion.Id }, retryJobs[0].versionIds, 'Only the version that failed for a passing reason is tried again');
		Assert.areEqual(2, retryJobs[0].attempt);
		Assert.areEqual(1, retryJobs[0].delay, 'The first retry waits about a minute');

		List<String> warnings = loggedEntries(WARN_LEVEL);
		Assert.areEqual(1, warnings.size());
		Assert.isTrue(warnings[0].contains(timedOutVersion.Id), 'The warning names the version that will be tried again');
		Assert.isTrue(warnings[0].contains(TIMEOUT_REASON), 'The warning carries the raw reason');
		List<String> errors = loggedEntries(ERROR_LEVEL);
		Assert.areEqual(1, errors.size(), 'A failure that is never retried is given up at once and logged as an error');
		Assert.isTrue(errors[0].contains(refusedVersion.Id));
		Assert.isFalse(String.join(GoogleFileVersionSummaryJob.loggedFailures, '\n').contains(summarizedVersion.Id), 'Nothing new is logged for a success');
	}

	@IsTest
	private static void testExecutePositiveSecondRetryWaitsThreeMinutes() {
		prepareRetryContext();
		GoogleFileVersion__c version = createAnalysisCandidate('SUMRTY4');
		GoogleFileVersionSummaryJob.setTestResult(version.Id, buildRetryableResult(TIMEOUT_REASON));
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Test.startTest();
			new GoogleFileVersionSummaryJob(new Set<Id>{ version.Id }, 2).work();
		Test.stopTest();
		GoogleFileVersionSummaryJob.clearTestResults();

		List<GoogleFileVersionSummaryJob> retryJobs = chainedSummaryJobs(runningChain);
		Assert.areEqual(1, retryJobs.size());
		Assert.areEqual(3, retryJobs[0].attempt);
		Assert.areEqual(3, retryJobs[0].delay, 'The second retry waits about three minutes');
	}

	@IsTest
	private static void testExecutePositiveRetryDelayCarriesTheSpread() {
		prepareRetryContext();
		GoogleTransientFailureResolver.retrySpreadOverride = 1;
		GoogleFileVersion__c version = createAnalysisCandidate('SUMRTY5');
		GoogleFileVersionSummaryJob.setTestResult(version.Id, buildRetryableResult(TIMEOUT_REASON));
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Test.startTest();
			new GoogleFileVersionSummaryJob(new Set<Id>{ version.Id }).work();
		Test.stopTest();
		GoogleFileVersionSummaryJob.clearTestResults();

		List<GoogleFileVersionSummaryJob> retryJobs = chainedSummaryJobs(runningChain);
		Assert.areEqual(1, retryJobs.size());
		Assert.areEqual(2, retryJobs[0].delay, 'The random spread is added to the delay so a burst of failures does not come back as a burst');
	}

	@IsTest
	private static void testExecutePositiveGivesUpAfterTheThirdAttempt() {
		prepareRetryContext();
		GoogleFileVersion__c version = createAnalysisCandidate('SUMRTY6');
		GoogleFileVersionSummaryJob.setTestResult(version.Id, buildRetryableResult(TIMEOUT_REASON));
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Test.startTest();
			new GoogleFileVersionSummaryJob(new Set<Id>{ version.Id }, 3).work();
		Test.stopTest();
		GoogleFileVersionSummaryJob.clearTestResults();

		Assert.areEqual(0, runningChain.getJobs().size(), 'Three attempts in all, then the file stays unsummarized');
		Assert.isNull(loadSummary(version.Id));
		Assert.areEqual(0, loggedEntries(WARN_LEVEL).size());
		List<String> errors = loggedEntries(ERROR_LEVEL);
		Assert.areEqual(1, errors.size(), 'A file given up on gets exactly one error line');
		Assert.isTrue(errors[0].contains(version.Id));
		Assert.isTrue(errors[0].contains(TIMEOUT_REASON));
	}

	@IsTest
	private static void testExecutePositiveTimeoutIsRetriedEndToEnd() {
		GoogleIntelligenceHttpMock intelligenceMock = prepareLiveAnalysis(new GoogleIntelligenceHttpMock().withCalloutException(TIMEOUT_REASON));
		GoogleFileVersion__c version = createAnalysisCandidate('SUMRTY7');
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Test.startTest();
			new GoogleFileVersionSummaryJob(new Set<Id>{ version.Id }).work();
		Test.stopTest();

		Assert.areEqual(1, intelligenceMock.getRequestCount(), 'The failed call is not repeated in place');
		Assert.isNull(loadSummary(version.Id));
		List<GoogleFileVersionSummaryJob> retryJobs = chainedSummaryJobs(runningChain);
		Assert.areEqual(1, retryJobs.size(), 'A summary that timed out is queued to be tried again later');
		Assert.areEqual(new Set<Id>{ version.Id }, retryJobs[0].versionIds);
		Assert.areEqual(2, retryJobs[0].attempt);
		Assert.areEqual(1, loggedEntries(WARN_LEVEL).size());
		Assert.areEqual(0, loggedEntries(ERROR_LEVEL).size(), 'An attempt that will be retried is a warning, not an error');
	}

	@IsTest
	private static void testExecutePositiveDefersVersionsWhenCalloutTimeRunsShort() {
		prepareRetryContext();
		List<GoogleFileVersion__c> versions = createAnalysisCandidates('SUMDEF', 10, false);
		for (GoogleFileVersion__c version : versions) {
			GoogleFileVersionSummaryJob.setTestResult(version.Id, buildTestResult(true, null, GENERATED_SUMMARY, 'STOP', null));
		}
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();
		GoogleCalloutTimeResolver.elapsedMillisOverride = 90001L;

		Test.startTest();
			new GoogleFileVersionSummaryJob(idsOf(versions)).work();
		Test.stopTest();
		GoogleFileVersionSummaryJob.clearTestResults();

		Set<Id> summarizedIds = summarizedVersionIds(idsOf(versions));
		Assert.areEqual(1, summarizedIds.size(), 'The first version always runs; with under thirty seconds left the next one does not start');

		List<GoogleFileVersionSummaryJob> followUpJobs = chainedSummaryJobs(runningChain);
		Assert.areEqual(1, followUpJobs.size());
		Assert.areEqual(9, followUpJobs[0].versionIds.size(), 'Every version not reached continues in one follow-up job');
		Assert.isFalse(followUpJobs[0].versionIds.containsAll(summarizedIds), 'A version already summarized is not handed on');
		Set<Id> everyVersion = new Set<Id>(followUpJobs[0].versionIds);
		everyVersion.addAll(summarizedIds);
		Assert.areEqual(idsOf(versions), everyVersion, 'No version is lost between the job and its follow-up');
		Assert.areEqual(1, followUpJobs[0].attempt, 'A deferred version has not been attempted, so it keeps its attempt');
		Assert.isNull(followUpJobs[0].delay, 'The follow-up starts straight away');
		Assert.isFalse(hasLoggedFailures(), 'Running out of time is not a failure');
	}

	@IsTest
	private static void testExecutePositiveKeepsEveryVersionWhenTimeIsAmple() {
		prepareRetryContext();
		List<GoogleFileVersion__c> versions = createAnalysisCandidates('SUMAMP', 10, false);
		for (GoogleFileVersion__c version : versions) {
			GoogleFileVersionSummaryJob.setTestResult(version.Id, buildTestResult(true, null, GENERATED_SUMMARY, 'STOP', null));
		}
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();
		GoogleCalloutTimeResolver.elapsedMillisOverride = 90000L;

		Test.startTest();
			new GoogleFileVersionSummaryJob(idsOf(versions)).work();
		Test.stopTest();
		GoogleFileVersionSummaryJob.clearTestResults();

		Assert.areEqual(10, summarizedVersionIds(idsOf(versions)).size(), 'Exactly thirty seconds left is still enough, so a batch of ten finishes in one job');
		Assert.areEqual(0, runningChain.getJobs().size());
	}

	@IsTest
	private static void testExecutePositiveFirstVersionRunsEvenWithoutTime() {
		prepareRetryContext();
		GoogleFileVersion__c version = createAnalysisCandidate('SUMFST');
		GoogleFileVersionSummaryJob.setTestResult(version.Id, buildTestResult(true, null, GENERATED_SUMMARY, 'STOP', null));
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();
		GoogleCalloutTimeResolver.elapsedMillisOverride = 130000L;

		Test.startTest();
			new GoogleFileVersionSummaryJob(new Set<Id>{ version.Id }).work();
		Test.stopTest();
		GoogleFileVersionSummaryJob.clearTestResults();

		Assert.areEqual(GENERATED_SUMMARY, loadSummary(version.Id), 'A job always moves forward, or a follow-up could defer the same version for ever');
		Assert.areEqual(0, runningChain.getJobs().size());
	}

	@IsTest
	private static void testExecutePositiveDeferredVersionsKeepTheirAttempt() {
		prepareRetryContext();
		List<GoogleFileVersion__c> versions = createAnalysisCandidates('SUMDAT', 3, false);
		for (GoogleFileVersion__c version : versions) {
			GoogleFileVersionSummaryJob.setTestResult(version.Id, buildTestResult(true, null, GENERATED_SUMMARY, 'STOP', null));
		}
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();
		GoogleCalloutTimeResolver.elapsedMillisOverride = 95000L;

		Test.startTest();
			new GoogleFileVersionSummaryJob(idsOf(versions), 2).work();
		Test.stopTest();
		GoogleFileVersionSummaryJob.clearTestResults();

		List<GoogleFileVersionSummaryJob> followUpJobs = chainedSummaryJobs(runningChain);
		Assert.areEqual(1, followUpJobs.size());
		Assert.areEqual(2, followUpJobs[0].versionIds.size());
		Assert.areEqual(2, followUpJobs[0].attempt, 'A follow-up of a retry is still that retry, not a new attempt');
		Assert.isNull(followUpJobs[0].delay);
	}

	@IsTest
	private static void testExecutePositiveStopsWhenAiWasTurnedOff() {
		GoogleIntelligenceHttpMock intelligenceMock = new GoogleIntelligenceHttpMock();
		GoogleCloudTestFactory.config().apply();
		GoogleCloudTestFactory.initMocks(new GoogleCompositeHttpMock(new GoogleDriveHttpMock().withDefaultHappyPath(), intelligenceMock));
		GoogleCloudTestFactory.bypassTriggers();
		GoogleFileVersionSummaryJob.clearTestResults();
		GoogleCalloutTimeResolver.elapsedMillisOverride = 0L;
		GoogleFileVersion__c version = createAnalysisCandidate('SUMOFF');
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Test.startTest();
			new GoogleFileVersionSummaryJob(new Set<Id>{ version.Id }, 2).work();
		Test.stopTest();

		Assert.areEqual(0, intelligenceMock.getRequestCount(), 'A retry finds AI Analytics turned off and sends nothing');
		Assert.areEqual(0, runningChain.getJobs().size(), 'Nothing is queued once AI is off');
		Assert.areEqual(0, loggedEntries(WARN_LEVEL).size());
		Assert.areEqual(0, loggedEntries(ERROR_LEVEL).size(), 'AI being turned off is not a failure');
	}

	@IsTest
	private static void testExecutePositiveStopsWhenTheVersionWasDeleted() {
		GoogleIntelligenceHttpMock intelligenceMock = prepareLiveAnalysis(new GoogleIntelligenceHttpMock());
		GoogleFileVersion__c version = createAnalysisCandidate('SUMDEL');
		delete version;
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Test.startTest();
			new GoogleFileVersionSummaryJob(new Set<Id>{ version.Id }, 2).work();
		Test.stopTest();

		Assert.areEqual(0, intelligenceMock.getRequestCount());
		Assert.areEqual(0, runningChain.getJobs().size());
		Assert.isFalse(hasLoggedFailures(), 'A deleted file is not a failure to report');
	}

	@IsTest
	private static void testExecutePositiveStopsWhenAlreadySummarized() {
		GoogleIntelligenceHttpMock intelligenceMock = prepareLiveAnalysis(new GoogleIntelligenceHttpMock());
		GoogleFileVersion__c version = createAnalysisCandidate('SUMDONE');
		update new GoogleFileVersion__c(Id = version.Id, Summary__c = GENERATED_SUMMARY);
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Test.startTest();
			new GoogleFileVersionSummaryJob(new Set<Id>{ version.Id }, 2).work();
		Test.stopTest();

		Assert.areEqual(0, intelligenceMock.getRequestCount(), 'A version that already has its summary is never sent again');
		Assert.areEqual(GENERATED_SUMMARY, loadSummary(version.Id));
		Assert.areEqual(0, runningChain.getJobs().size());
		Assert.isFalse(hasLoggedFailures(), 'An already summarized version is a normal skip');
	}

	@IsTest
	private static void testExecutePositiveCommitFailureStillQueuesTheRetry() {
		prepareRetryContext();
		GoogleFileVersion__c oversizedVersion = createAnalysisCandidate('SUMCMT1');
		GoogleFileVersion__c timedOutVersion = createAnalysisCandidate('SUMCMT2');
		GoogleFileVersionSummaryJob.setTestResult(oversizedVersion.Id, buildTestResult(true, null, OVERSIZED_SUMMARY, 'STOP', null));
		GoogleFileVersionSummaryJob.setTestResult(timedOutVersion.Id, buildRetryableResult(TIMEOUT_REASON));
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Exception jobFailure;
		Test.startTest();
			try {
				new GoogleFileVersionSummaryJob(new Set<Id>{ oversizedVersion.Id, timedOutVersion.Id }).work();
			} catch (Exception ex) {
				jobFailure = ex;
			}
		Test.stopTest();
		GoogleFileVersionSummaryJob.clearTestResults();

		Assert.isNull(jobFailure, 'A failed save is logged rather than thrown, so the job still hands over what it owes');
		List<GoogleFileVersionSummaryJob> retryJobs = chainedSummaryJobs(runningChain);
		Assert.areEqual(1, retryJobs.size(), 'The retry is queued whatever the save does');
		Assert.areEqual(new Set<Id>{ timedOutVersion.Id }, retryJobs[0].versionIds);
		Assert.areEqual(2, retryJobs[0].attempt);
	}

	@IsTest
	private static void testExecutePositiveCommitFailureStillQueuesTheFollowUp() {
		prepareRetryContext();
		List<GoogleFileVersion__c> versions = createAnalysisCandidates('SUMCMF', 2, false);
		for (GoogleFileVersion__c version : versions) {
			GoogleFileVersionSummaryJob.setTestResult(version.Id, buildTestResult(true, null, OVERSIZED_SUMMARY, 'STOP', null));
		}
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();
		GoogleCalloutTimeResolver.elapsedMillisOverride = 95000L;

		Exception jobFailure;
		Test.startTest();
			try {
				new GoogleFileVersionSummaryJob(idsOf(versions)).work();
			} catch (Exception ex) {
				jobFailure = ex;
			}
		Test.stopTest();
		GoogleFileVersionSummaryJob.clearTestResults();

		Assert.isNull(jobFailure);
		List<GoogleFileVersionSummaryJob> followUpJobs = chainedSummaryJobs(runningChain);
		Assert.areEqual(1, followUpJobs.size(), 'A version never tried must not be lost because the save of another failed');
		Assert.areEqual(1, followUpJobs[0].versionIds.size());
	}

	@IsTest
	private static void testExecutePositiveDeletedVersionDoesNotCostTheOthersTheirSummaries() {
		prepareRetryContext();
		GoogleFileVersion__c keptVersion = createAnalysisCandidate('SUMDLK');
		GoogleFileVersion__c deletedVersion = createAnalysisCandidate('SUMDLD');
		GoogleFileVersionSummaryJob.setTestResult(keptVersion.Id, buildTestResult(true, null, GENERATED_SUMMARY, 'STOP', null));
		GoogleFileVersionSummaryJob.setTestResult(deletedVersion.Id, buildTestResult(true, null, GENERATED_SUMMARY, 'STOP', null));
		delete deletedVersion;
		GoogleCloudTestFactory.runningChain();

		Exception jobFailure;
		Test.startTest();
			try {
				new GoogleFileVersionSummaryJob(new Set<Id>{ keptVersion.Id, deletedVersion.Id }).work();
			} catch (Exception ex) {
				jobFailure = ex;
			}
		Test.stopTest();
		GoogleFileVersionSummaryJob.clearTestResults();

		Assert.isNull(jobFailure);
		Assert.areEqual(GENERATED_SUMMARY, loadSummary(keptVersion.Id), 'One file deleted from a batch must not cost the rest their summaries');
		Assert.isFalse(hasLoggedFailures());
	}

	@IsTest
	private static void testExecutePositiveNullAttemptCountsAsTheFirst() {
		prepareRetryContext();
		GoogleFileVersion__c version = createAnalysisCandidate('SUMNUL');
		GoogleFileVersionSummaryJob.setTestResult(version.Id, buildRetryableResult(TIMEOUT_REASON));
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Test.startTest();
			new GoogleFileVersionSummaryJob(new Set<Id>{ version.Id }, null).work();
		Test.stopTest();
		GoogleFileVersionSummaryJob.clearTestResults();

		List<GoogleFileVersionSummaryJob> retryJobs = chainedSummaryJobs(runningChain);
		Assert.areEqual(1, retryJobs.size());
		Assert.areEqual(2, retryJobs[0].attempt);
		Assert.areEqual(1, retryJobs[0].delay);
	}

	@IsTest
	private static void testExecutePositiveJobQueuedBeforeTheUpgradeCountsAsTheFirstAttempt() {
		prepareRetryContext();
		GoogleFileVersion__c version = createAnalysisCandidate('SUMUPG');
		GoogleFileVersionSummaryJob.setTestResult(version.Id, buildRetryableResult(TIMEOUT_REASON));
		Map<String, Object> serializedJob = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(new GoogleFileVersionSummaryJob(new Set<Id>{ version.Id })));
		serializedJob.remove('attempt');
		GoogleFileVersionSummaryJob queuedBeforeUpgrade = (GoogleFileVersionSummaryJob) JSON.deserialize(JSON.serialize(serializedJob), GoogleFileVersionSummaryJob.class);
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Test.startTest();
			queuedBeforeUpgrade.work();
		Test.stopTest();
		GoogleFileVersionSummaryJob.clearTestResults();

		List<GoogleFileVersionSummaryJob> retryJobs = chainedSummaryJobs(runningChain);
		Assert.areEqual(1, retryJobs.size(), 'A job queued before the upgrade gets the retries too');
		Assert.areEqual(2, retryJobs[0].attempt, 'A job serialized without an attempt counts as the first one');
	}

	@IsTest
	private static void testExecutePositiveSecondPassJobIsRetried() {
		prepareRetryContext();
		GoogleFileVersion__c largeUpload = createAnalysisCandidate('SUMSEC');
		update new GoogleFileVersion__c(Id = largeUpload.Id, Size__c = GoogleCloudConstants.MAX_SUMMARY_FILE_SIZE_BYTES + 1, GoogleDocsFileSize__c = 112000);
		GoogleFileVersionSummaryJob.setTestResult(largeUpload.Id, buildRetryableResult(TIMEOUT_REASON));
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Test.startTest();
			new GoogleFileVersionSummaryJob(new Set<Id>{ largeUpload.Id }).work();
		Test.stopTest();
		GoogleFileVersionSummaryJob.clearTestResults();

		List<GoogleFileVersionSummaryJob> retryJobs = chainedSummaryJobs(runningChain);
		Assert.areEqual(1, retryJobs.size(), 'A large upload summarized through its measured copy gets the same retries');
		Assert.areEqual(2, retryJobs[0].attempt);
	}

	@IsTest
	private static void testExecutePositiveLogsNothingNewForASuccess() {
		prepareRetryContext();
		GoogleFileVersion__c version = createAnalysisCandidate('SUMQUIET');
		GoogleFileVersionSummaryJob.setTestResult(version.Id, buildTestResult(true, null, GENERATED_SUMMARY, 'STOP', null));
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Test.startTest();
			new GoogleFileVersionSummaryJob(new Set<Id>{ version.Id }).work();
		Test.stopTest();
		GoogleFileVersionSummaryJob.clearTestResults();

		Assert.areEqual(GENERATED_SUMMARY, loadSummary(version.Id));
		Assert.isFalse(hasLoggedFailures());
		Assert.areEqual(0, runningChain.getJobs().size());
	}

	@IsTest
	private static void testExecutePositiveLogsAVersionWithoutWorkspaceCopy() {
		prepareRetryContext();
		GoogleFileVersion__c version = createAnalysisCandidates('SUMNOCPY', 1, true)[0];
		GoogleFileVersionSummaryJob.setTestResult(version.Id, buildTestResult(true, null, GENERATED_SUMMARY, 'STOP', null));
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Test.startTest();
			new GoogleFileVersionSummaryJob(new Set<Id>{ version.Id }).work();
		Test.stopTest();
		GoogleFileVersionSummaryJob.clearTestResults();

		Assert.isNull(loadSummary(version.Id), 'A version whose expected Workspace copy is missing is not analyzed');
		List<String> warnings = loggedEntries(WARN_LEVEL);
		Assert.areEqual(1, warnings.size(), 'A copy that should exist and does not is abnormal and answers why the file has no summary');
		Assert.isTrue(warnings[0].contains(version.Id));
		Assert.areEqual(0, loggedEntries(ERROR_LEVEL).size());
		Assert.areEqual(0, runningChain.getJobs().size(), 'A missing copy is not a passing failure');
	}

	@IsTest
	private static void testExecutePositiveStaysSilentWhenPreviewsAreOff() {
		GoogleIntelligenceHttpMock intelligenceMock = new GoogleIntelligenceHttpMock();
		GoogleCloudTestFactory.config()
			.withPreviewDisabled(true)
			.withFolderStructure('{User}')
			.withFileIntelligence(true)
			.withGeminiApiKey('api-key-1')
			.withAiModel('gemini-2.0-flash')
			.apply();
		GoogleCloudTestFactory.initMocks(new GoogleCompositeHttpMock(new GoogleDriveHttpMock().withDefaultHappyPath(), intelligenceMock));
		GoogleCloudTestFactory.bypassTriggers();
		GoogleFileVersionSummaryJob.clearTestResults();
		GoogleCalloutTimeResolver.elapsedMillisOverride = 0L;
		GoogleFileVersion__c version = createAnalysisCandidates('SUMPVOFF', 1, true)[0];
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Test.startTest();
			new GoogleFileVersionSummaryJob(new Set<Id>{ version.Id }).work();
		Test.stopTest();

		Assert.areEqual(0, intelligenceMock.getRequestCount());
		Assert.isFalse(hasLoggedFailures(), 'With previews off no copy is ever made, so its absence is normal and stays silent');
		Assert.areEqual(0, runningChain.getJobs().size());
	}

	@IsTest
	private static void testExecutePositiveFollowUpRunsStraightAfterTheJobThatDeferredIt() {
		prepareRetryContext();
		List<GoogleFileVersion__c> versions = createAnalysisCandidates('SUMPRI', 3, false);
		for (GoogleFileVersion__c version : versions) {
			GoogleFileVersionSummaryJob.setTestResult(version.Id, buildTestResult(true, null, GENERATED_SUMMARY, 'STOP', null));
		}
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();
		GoogleFileVersionSummaryJob summaryJob = new GoogleFileVersionSummaryJob(idsOf(versions));
		GoogleFileVersionLabelJob queuedLabelJob = new GoogleFileVersionLabelJob(idsOf(versions));
		GoogleFileVersionPreviewSizeJob queuedSizeJob = buildQueuedSizeJob(idsOf(versions));
		queueUploadChain(runningChain, summaryJob, new List<GQueueableJob>{ queuedLabelJob, queuedSizeJob });
		GoogleCalloutTimeResolver.elapsedMillisOverride = 90001L;

		Test.startTest();
			summaryJob.work();
		Test.stopTest();
		GoogleFileVersionSummaryJob.clearTestResults();
		summaryJob.isProcessed = true;

		List<GQueueableJob> waitingJobs = pendingJobs(runningChain);
		Assert.areEqual(3, waitingJobs.size());
		Assert.isTrue(waitingJobs[0] instanceof GoogleFileVersionSummaryJob, 'The follow-up runs straight after the job that deferred it, ahead of the label job and the size check');
		GoogleFileVersionSummaryJob followUpJob = (GoogleFileVersionSummaryJob) waitingJobs[0];
		Assert.areEqual(2, followUpJob.versionIds.size());
		Assert.areEqual(1, followUpJob.attempt);
		Assert.isNull(followUpJob.delay, 'A follow-up never waits');
		Assert.areEqual(1, followUpJob.priority);
		Assert.isTrue(waitingJobs[1] === queuedLabelJob, 'The label job keeps its place behind the follow-up');
		Assert.isTrue(waitingJobs[2] === queuedSizeJob, 'The size check keeps its place behind the label job');
	}

	@IsTest
	private static void testExecutePositiveRetryStillWaitsAtTheEndOfTheChain() {
		prepareRetryContext();
		GoogleFileVersion__c version = createAnalysisCandidate('SUMPRR');
		GoogleFileVersionSummaryJob.setTestResult(version.Id, buildRetryableResult(TIMEOUT_REASON));
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();
		GoogleFileVersionSummaryJob summaryJob = new GoogleFileVersionSummaryJob(new Set<Id>{ version.Id });
		GoogleFileVersionLabelJob queuedLabelJob = new GoogleFileVersionLabelJob(new Set<Id>{ version.Id });
		GoogleFileVersionPreviewSizeJob queuedSizeJob = buildQueuedSizeJob(new Set<Id>{ version.Id });
		queueUploadChain(runningChain, summaryJob, new List<GQueueableJob>{ queuedLabelJob, queuedSizeJob });

		Test.startTest();
			summaryJob.work();
		Test.stopTest();
		GoogleFileVersionSummaryJob.clearTestResults();
		summaryJob.isProcessed = true;

		List<GQueueableJob> waitingJobs = pendingJobs(runningChain);
		Assert.areEqual(3, waitingJobs.size());
		Assert.isTrue(waitingJobs[0] === queuedLabelJob, 'A retry does not jump the queue');
		Assert.isTrue(waitingJobs[1] === queuedSizeJob);
		Assert.isTrue(waitingJobs[2] instanceof GoogleFileVersionSummaryJob, 'The retry is appended at the end of the chain');
		GoogleFileVersionSummaryJob retryJob = (GoogleFileVersionSummaryJob) waitingJobs[2];
		Assert.areEqual(2, retryJob.attempt);
		Assert.areEqual(1, retryJob.delay, 'The retry keeps its delay');
		Assert.isNull(retryJob.priority, 'A retry has no priority, so its delay holds up nothing queued before it');
	}

	@IsTest
	private static void testExecutePositiveFollowUpGoesFirstAndRetryLastFromOneJob() {
		prepareRetryContext();
		List<GoogleFileVersion__c> versions = createAnalysisCandidates('SUMPRB', 3, false);
		for (GoogleFileVersion__c version : versions) {
			GoogleFileVersionSummaryJob.setTestResult(version.Id, buildRetryableResult(TIMEOUT_REASON));
		}
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();
		GoogleFileVersionSummaryJob summaryJob = new GoogleFileVersionSummaryJob(idsOf(versions));
		GoogleFileVersionLabelJob queuedLabelJob = new GoogleFileVersionLabelJob(idsOf(versions));
		GoogleFileVersionPreviewSizeJob queuedSizeJob = buildQueuedSizeJob(idsOf(versions));
		queueUploadChain(runningChain, summaryJob, new List<GQueueableJob>{ queuedLabelJob, queuedSizeJob });
		GoogleCalloutTimeResolver.elapsedMillisOverride = 90001L;

		Test.startTest();
			summaryJob.work();
		Test.stopTest();
		GoogleFileVersionSummaryJob.clearTestResults();
		summaryJob.isProcessed = true;

		List<GQueueableJob> waitingJobs = pendingJobs(runningChain);
		Assert.areEqual(4, waitingJobs.size(), 'A stall followed by too little time leaves one follow-up and one retry');
		GoogleFileVersionSummaryJob followUpJob = (GoogleFileVersionSummaryJob) waitingJobs[0];
		Assert.areEqual(1, followUpJob.priority);
		Assert.areEqual(2, followUpJob.versionIds.size());
		Assert.isNull(followUpJob.delay);
		Assert.isTrue(waitingJobs[1] === queuedLabelJob);
		Assert.isTrue(waitingJobs[2] === queuedSizeJob);
		GoogleFileVersionSummaryJob retryJob = (GoogleFileVersionSummaryJob) waitingJobs[3];
		Assert.isNull(retryJob.priority);
		Assert.areEqual(1, retryJob.versionIds.size());
		Assert.areEqual(1, retryJob.delay);
		Set<Id> everyVersion = new Set<Id>(followUpJob.versionIds);
		everyVersion.addAll(retryJob.versionIds);
		Assert.areEqual(idsOf(versions), everyVersion, 'No version is lost between the follow-up and the retry');
	}

	@IsTest
	private static void testExecutePositiveFollowUpOfAFollowUpKeepsTheOrder() {
		prepareRetryContext();
		List<GoogleFileVersion__c> versions = createAnalysisCandidates('SUMPRF', 3, false);
		for (GoogleFileVersion__c version : versions) {
			GoogleFileVersionSummaryJob.setTestResult(version.Id, buildTestResult(true, null, GENERATED_SUMMARY, 'STOP', null));
		}
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();
		GoogleFileVersionSummaryJob firstSummaryJob = new GoogleFileVersionSummaryJob(new Set<Id>());
		firstSummaryJob.isProcessed = true;
		GoogleFileVersionSummaryJob firstFollowUpJob = new GoogleFileVersionSummaryJob(idsOf(versions));
		firstFollowUpJob.priority = 1;
		GoogleFileVersionLabelJob queuedLabelJob = new GoogleFileVersionLabelJob(idsOf(versions));
		GoogleFileVersionPreviewSizeJob queuedSizeJob = buildQueuedSizeJob(idsOf(versions));
		queueUploadChain(runningChain, firstSummaryJob, new List<GQueueableJob>{ queuedLabelJob, queuedSizeJob, firstFollowUpJob });
		GoogleCalloutTimeResolver.elapsedMillisOverride = 90001L;

		Test.startTest();
			firstFollowUpJob.work();
		Test.stopTest();
		GoogleFileVersionSummaryJob.clearTestResults();
		firstFollowUpJob.isProcessed = true;

		List<GQueueableJob> chainedJobs = runningChain.getJobs();
		Assert.isTrue(chainedJobs[0] === firstFollowUpJob, 'Two follow-ups keep the order they were queued in');
		Assert.isTrue(chainedJobs[1] instanceof GoogleFileVersionSummaryJob);
		Assert.areEqual(1, chainedJobs[1].priority);
		List<GQueueableJob> waitingJobs = pendingJobs(runningChain);
		Assert.areEqual(3, waitingJobs.size());
		Assert.isTrue(waitingJobs[0] === chainedJobs[1], 'The second follow-up runs next');
		Assert.areEqual(2, ((GoogleFileVersionSummaryJob) waitingJobs[0]).versionIds.size());
		Assert.isTrue(waitingJobs[1] === queuedLabelJob);
		Assert.isTrue(waitingJobs[2] === queuedSizeJob);
	}

	private static GoogleFileVersionPreviewSizeJob buildQueuedSizeJob(Set<Id> versionIds) {
		GoogleFileVersionPreviewSizeJob sizeJob = new GoogleFileVersionPreviewSizeJob(versionIds);
		sizeJob.delay = 1;
		return sizeJob;
	}

	private static void queueUploadChain(GQueueableChain chain, GQueueableJob runningJob, List<GQueueableJob> queuedJobs) {
		GQueueableJob previewJob = new GoogleFileVersionPreviewJob(new Set<Id>());
		previewJob.isProcessed = true;
		GQueueableJob folderJob = new GoogleFileCloudFolderJob(new List<GoogleFileRelocationRequestDTO>());
		folderJob.isProcessed = true;
		chain.addJob(previewJob);
		chain.addJob(folderJob);
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
}