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
private class GoogleFileVersionPreviewJobTest {
	private static final String DOCX_MIME_TYPE = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
	private static final String CLONED_WORKSPACE_COPY_ID = 'gdoc_preview_001';
	private static final String FITTING_COPY_SIZE = '112000';
	private static final Long UPLOAD_OVER_ANALYSIS_LIMIT_BYTES = GoogleCloudConstants.MAX_SUMMARY_FILE_SIZE_BYTES + 1;
	private static final String SECOND_PASS_SUMMARY = 'This file describes a product brochure for the spring catalogue.';
	private static final String WARN_LEVEL = 'WARN';
	private static final String ERROR_LEVEL = 'ERROR';
	private static final String LABEL_DEFINITIONS = '[{"name":"Invoice","labelId":"LABEL_INVOICE","description":"A bill requesting payment for goods or services"}]';
	private static final String DRIVE_UNAVAILABLE_BODY = '{"error":{"code":503,"message":"Service Unavailable","errors":[{"message":"Service Unavailable","domain":"global","reason":"backendError"}]}}';
	private static final String DRIVE_USER_RATE_LIMIT_BODY = '{"error":{"code":403,"message":"User rate limit exceeded.","errors":[{"message":"User rate limit exceeded.","domain":"usageLimits","reason":"userRateLimitExceeded"}]}}';
	private static final String DRIVE_CONVERSION_REFUSED_BODY = '{"error":{"code":400,"message":"The requested conversion is not supported.","errors":[{"message":"The requested conversion is not supported.","domain":"global","reason":"badRequest","location":"convertTo","locationType":"parameter"}]}}';

	private static void mockPreviewQuery(Id versionId) {
		GSOQL.mock(GoogleFileVersionSelector.MOCK_ID).thenReturn(new List<SObject>{
			[
				SELECT Id, Name, Summary__c, GoogleDriveFolderId__c, IsLatestFile__c, PublicLink__c, PublicLinkExpirationDate__c, PublicLinkPermissionId__c,
					CreatedDate, LastModifiedDate, IsPreviewableFile__c, GoogleFileId__c, GoogleDriveFileId__c, GoogleDocsFileId__c, Type__c, Size__c, GoogleDocsFileSize__c, AiLabels__c
				FROM GoogleFileVersion__c
				WHERE Id = :versionId
			]
		});
	}

	private static GoogleFileVersion__c createPreviewVersion(String fileName, String mimeType, String driveId, String docsId) {
		return createPreviewVersion(fileName, mimeType, driveId, docsId, 1L);
	}

	private static GoogleFileVersion__c createPreviewVersion(String fileName, String mimeType, String driveId, String docsId, Long uploadSize) {
		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName(fileName + '_Parent')
			.withDescription('D')
			.insertRecord();

		return GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName(fileName)
			.withType(mimeType)
			.withSize(uploadSize)
			.withDriveId(driveId)
			.withDocsId(docsId)
			.insertRecord();
	}

	private static GoogleDriveHttpMock mockMeasuredWorkspaceCopy(String size) {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.endpointContains('/files/' + CLONED_WORKSPACE_COPY_ID)
		).thenReturn(new GoogleDriveHttpMock.JsonResponses().fileSizeSuccess(CLONED_WORKSPACE_COPY_ID, size));

		return driveMock;
	}

	private static GoogleFileAnalysisResultDTO buildSummaryResult(String text) {
		GoogleFileAnalysisResultDTO result = new GoogleFileAnalysisResultDTO();
		result.success = true;
		result.provider = 'Gemini';
		result.operationType = 'SUMMARY';
		result.text = text;
		result.finishReason = 'STOP';
		return result;
	}

	private static GoogleDriveHttpMock prepareCopyRetry(Boolean isAnalysisConfigured) {
		GoogleCloudTestFactory.ConfigBuilder config = GoogleCloudTestFactory.config();
		if (isAnalysisConfigured) {
			config.withFileIntelligence(true)
				.withGeminiApiKey('api-key-1')
				.withAiModel('gemini-2.0-flash')
				.withAiLabeling(true)
				.withAiLabelDefinitions(LABEL_DEFINITIONS);
		}
		config.apply();

		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleCloudTestFactory.bypassTriggers();
		GoogleCalloutTimeResolver.elapsedMillisOverride = 0L;
		GoogleTransientFailureResolver.retrySpreadOverride = 0;
		return driveMock;
	}

	private static void refuseCopy(GoogleDriveHttpMock driveMock, String driveFileId, Integer statusCode, String body) {
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher().withMethod('POST').endpointContains(driveFileId)
		).thenReturnStatus(statusCode, body);
	}

	private static Integer countCopyRequests(GoogleDriveHttpMock driveMock) {
		Integer copyRequests = 0;
		for (GoogleDriveHttpMock.CapturedRequest capturedRequest : driveMock.getCapturedRequests()) {
			String endpoint = capturedRequest.endpoint == null ? '' : capturedRequest.endpoint.toLowerCase();
			if (capturedRequest.method == 'POST' && (endpoint.contains('/copy') || endpoint.contains('/clone'))) copyRequests++;
		}

		return copyRequests;
	}

	private static List<GoogleFileVersionPreviewJob> chainedPreviewJobs(GQueueableChain chain) {
		List<GoogleFileVersionPreviewJob> previewJobs = new List<GoogleFileVersionPreviewJob>();
		for (GQueueableJob chainedJob : chain.getJobs()) {
			if (chainedJob instanceof GoogleFileVersionPreviewJob) previewJobs.add((GoogleFileVersionPreviewJob) chainedJob);
		}

		return previewJobs;
	}

	private static Integer indexOfJob(GQueueableChain chain, Type jobType) {
		List<GQueueableJob> chainedJobs = chain.getJobs();
		for (Integer index = 0; index < chainedJobs.size(); index++) {
			if (chainedJobs[index].className == jobType.getName()) return index;
		}

		return -1;
	}

	private static Set<Id> versionIdsOf(GQueueableJob chainedJob) {
		Map<String, Object> serializedJob = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(chainedJob));
		Set<Id> versionIds = new Set<Id>();
		for (Object versionId : (List<Object>) serializedJob.get('versionIds')) {
			versionIds.add(Id.valueOf(String.valueOf(versionId)));
		}

		return versionIds;
	}

	private static List<String> loggedEntries(String level) {
		List<String> entries = new List<String>();
		if (GoogleFileVersionPreviewJob.loggedFailures == null) return entries;

		for (String entry : GoogleFileVersionPreviewJob.loggedFailures) {
			if (entry != null && entry.startsWith(level + ' ')) entries.add(entry);
		}

		return entries;
	}

	private static GoogleFileVersion__c loadVersion(Id versionId) {
		return [
			SELECT GoogleDocsFileId__c, GoogleDocsFileSize__c, Summary__c
			FROM GoogleFileVersion__c
			WHERE Id = :versionId
			LIMIT 1
		];
	}

	@IsTest
	private static void testExecutePositiveWithPreviewableVersion() {
		GoogleCloudTestFactory.initMocks();
		GoogleFileVersionPreviewSizeJob.skipExecution = true;

		GoogleFileVersion__c version = createPreviewVersion('V1.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'GD_PJ_1', null);
		mockPreviewQuery(version.Id);

		Test.startTest();
		new GoogleFileVersionPreviewJob(new Set<Id>{ version.Id }).work();
		Test.stopTest();

		Assert.isTrue(String.isNotBlank(loadVersion(version.Id).GoogleDocsFileId__c));
	}

	@IsTest
	private static void testExecutePositiveWithPreviewablePdfVersion() {
		GoogleCloudTestFactory.initMocks();
		GoogleFileVersionPreviewSizeJob.skipExecution = true;

		GoogleFileVersion__c version = createPreviewVersion('VPDF.pdf', 'application/pdf', 'GD_PJ_PDF', null);
		mockPreviewQuery(version.Id);

		Test.startTest();
		new GoogleFileVersionPreviewJob(new Set<Id>{ version.Id }).work();
		Test.stopTest();

		Assert.isTrue(String.isNotBlank(loadVersion(version.Id).GoogleDocsFileId__c));
	}

	@IsTest
	private static void testExecutePositiveWithImagePreviewableVersion() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleFileVersionPreviewSizeJob.skipExecution = true;

		GTriggerHandler.setBypass('GoogleFileVersionTriggerHandler', true);
		GoogleFileVersion__c version = createPreviewVersion('Preview.png', 'image/png', 'GD_PJ_IMG_1', null);
		mockPreviewQuery(version.Id);
		GTriggerHandler.setBypass('GoogleFileVersionTriggerHandler', false);

		Test.startTest();
		new GoogleFileVersionPreviewJob(new Set<Id>{ version.Id }).work();
		Test.stopTest();

		Assert.isTrue(String.isNotBlank(loadVersion(version.Id).GoogleDocsFileId__c));
		for (GoogleDriveHttpMock.CapturedRequest capturedRequest : driveMock.getCapturedRequests()) {
			Assert.isFalse(capturedRequest.endpoint != null && capturedRequest.endpoint.contains('/v1/documents/'));
		}
	}

	@IsTest
	private static void testExecutePositiveEmptyVersionIds() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		GoogleCloudTestFactory.initMocks(driveMock);

		Test.startTest();
		new GoogleFileVersionPreviewJob(new Set<Id>()).work();
		Integer scheduledJobs = Limits.getQueueableJobs();
		Test.stopTest();

		Assert.isTrue(driveMock.getCapturedRequests().isEmpty());
		Assert.areEqual(0, scheduledJobs);
	}

	@IsTest
	private static void testExecutePositiveNullVersionIds() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		GoogleCloudTestFactory.initMocks(driveMock);

		Test.startTest();
		new GoogleFileVersionPreviewJob(null).work();
		Integer scheduledJobs = Limits.getQueueableJobs();
		Test.stopTest();

		Assert.isTrue(driveMock.getCapturedRequests().isEmpty());
		Assert.areEqual(0, scheduledJobs);
	}

	@IsTest
	private static void testExecutePositiveAlreadyHasDocs() {
		GoogleCloudTestFactory.initMocks();
		GoogleFileVersion__c version = createPreviewVersion('V2.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'GD_PJ_2', 'DOCS_PJ_2');
		mockPreviewQuery(version.Id);

		Test.startTest();
		new GoogleFileVersionPreviewJob(new Set<Id>{ version.Id }).work();
		Integer scheduledJobs = Limits.getQueueableJobs();
		Test.stopTest();

		Assert.areEqual('DOCS_PJ_2', loadVersion(version.Id).GoogleDocsFileId__c);
		Assert.areEqual(0, scheduledJobs);
	}

	@IsTest
	private static void testExecutePositiveSchedulesPreviewSizeMeasurement() {
		GoogleCloudTestFactory.initMocks();
		GoogleFileVersionPreviewSizeJob.skipExecution = true;

		GoogleFileVersion__c version = createPreviewVersion('V3.docx', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'GD_PJ_3', null);
		mockPreviewQuery(version.Id);

		Test.startTest();
		new GoogleFileVersionPreviewJob(new Set<Id>{ version.Id }).work();
		Integer scheduledJobs = Limits.getQueueableJobs();
		Test.stopTest();

		Assert.areEqual(1, scheduledJobs);
		Assert.isTrue(String.isNotBlank(loadVersion(version.Id).GoogleDocsFileId__c));
	}

	@IsTest
	private static void testExecutePositiveLargeUploadIsSummarizedOnceItsCopyIsMeasured() {
		GoogleCloudTestFactory.config().withFileIntelligence(true).withGeminiApiKey('api-key-1').withAiModel('gemini-2.0-flash').apply();
		GoogleCloudTestFactory.initMocks(mockMeasuredWorkspaceCopy(FITTING_COPY_SIZE));
		GoogleCloudTestFactory.bypassTriggers();
		GoogleFileVersion__c version = createPreviewVersion('V4.docx', DOCX_MIME_TYPE, 'GD_PJ_4', null, UPLOAD_OVER_ANALYSIS_LIMIT_BYTES);
		GoogleFileVersionSummaryJob.setTestResult(version.Id, buildSummaryResult(SECOND_PASS_SUMMARY));

		Test.startTest();
		new GoogleFileVersionPreviewJob(new Set<Id>{ version.Id }).work();
		Test.stopTest();

		GoogleFileVersion__c analyzedVersion = loadVersion(version.Id);
		Assert.areEqual(CLONED_WORKSPACE_COPY_ID, analyzedVersion.GoogleDocsFileId__c);
		Assert.areEqual(Decimal.valueOf(FITTING_COPY_SIZE), analyzedVersion.GoogleDocsFileSize__c);
		Assert.areEqual(SECOND_PASS_SUMMARY, analyzedVersion.Summary__c);
	}

	@IsTest
	private static void testExecutePositiveWithoutAnalysisMeasuresTheCopyOnly() {
		GoogleCloudTestFactory.config().withFileIntelligence(true).withGeminiApiKey('api-key-1').withAiModel('gemini-2.0-flash').apply();
		GoogleCloudTestFactory.initMocks(mockMeasuredWorkspaceCopy(FITTING_COPY_SIZE));
		GoogleCloudTestFactory.bypassTriggers();
		GoogleFileVersion__c version = createPreviewVersion('V5.docx', DOCX_MIME_TYPE, 'GD_PJ_5', null, UPLOAD_OVER_ANALYSIS_LIMIT_BYTES);
		GoogleFileVersionSummaryJob.setTestResult(version.Id, buildSummaryResult(SECOND_PASS_SUMMARY));

		Test.startTest();
		new GoogleFileVersionPreviewJob(new Set<Id>{ version.Id }, false).work();
		Integer scheduledJobs = Limits.getQueueableJobs();
		Test.stopTest();

		GoogleFileVersion__c measuredVersion = loadVersion(version.Id);
		Assert.areEqual(1, scheduledJobs);
		Assert.areEqual(CLONED_WORKSPACE_COPY_ID, measuredVersion.GoogleDocsFileId__c);
		Assert.areEqual(Decimal.valueOf(FITTING_COPY_SIZE), measuredVersion.GoogleDocsFileSize__c);
		Assert.isNull(measuredVersion.Summary__c);
	}

	@IsTest
	private static void testExecutePositiveOneFailedCopyDoesNotStopTheOthers() {
		GoogleDriveHttpMock driveMock = prepareCopyRetry(false);
		refuseCopy(driveMock, 'GD_PVRTY_A', 503, DRIVE_UNAVAILABLE_BODY);
		GoogleFileVersion__c refusedVersion = createPreviewVersion('PVRTYA.docx', DOCX_MIME_TYPE, 'GD_PVRTY_A', null);
		GoogleFileVersion__c copiedVersion = createPreviewVersion('PVRTYB.docx', DOCX_MIME_TYPE, 'GD_PVRTY_B', null);
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Test.startTest();
		new GoogleFileVersionPreviewJob(new Set<Id>{ refusedVersion.Id, copiedVersion.Id }).work();
		Test.stopTest();

		Assert.areEqual(CLONED_WORKSPACE_COPY_ID, loadVersion(copiedVersion.Id).GoogleDocsFileId__c, 'One copy Drive could not make must not cost the others theirs');
		Assert.isNull(loadVersion(refusedVersion.Id).GoogleDocsFileId__c);

		List<GoogleFileVersionPreviewJob> retryJobs = chainedPreviewJobs(runningChain);
		Assert.areEqual(1, retryJobs.size());
		Assert.areEqual(new Set<Id>{ refusedVersion.Id }, retryJobs[0].versionIds, 'Only the copy that failed for a passing reason is tried again');
		Assert.areEqual(2, retryJobs[0].attempt);
		Assert.areEqual(1, retryJobs[0].delay);

		Integer sizeJobIndex = indexOfJob(runningChain, GoogleFileVersionPreviewSizeJob.class);
		Assert.areNotEqual(-1, sizeJobIndex, 'The copies that worked are measured as before');
		Assert.areEqual(new Set<Id>{ copiedVersion.Id }, versionIdsOf(runningChain.getJobs()[sizeJobIndex]));
	}

	@IsTest
	private static void testExecutePositiveRetriesACopyDriveWasTooBusyFor() {
		GoogleDriveHttpMock driveMock = prepareCopyRetry(false);
		refuseCopy(driveMock, 'GD_PVRTY_C', 403, DRIVE_USER_RATE_LIMIT_BODY);
		GoogleFileVersion__c version = createPreviewVersion('PVRTYC.docx', DOCX_MIME_TYPE, 'GD_PVRTY_C', null);
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Test.startTest();
		new GoogleFileVersionPreviewJob(new Set<Id>{ version.Id }).work();
		Test.stopTest();

		List<GoogleFileVersionPreviewJob> retryJobs = chainedPreviewJobs(runningChain);
		Assert.areEqual(1, retryJobs.size(), 'Drive refusing a copy for its rate limit, as it did under the 2026-11-09 burst, is tried again');
		Assert.areEqual(new Set<Id>{ version.Id }, retryJobs[0].versionIds);
		Assert.areEqual(2, retryJobs[0].attempt);
		Assert.areEqual(true, retryJobs[0].chainIntelligence, 'The retry keeps the upload\'s decision to be analyzed');
		Assert.areEqual(-1, indexOfJob(runningChain, GoogleFileVersionPreviewSizeJob.class), 'A copy that does not exist is not measured');
		List<String> warnings = loggedEntries(WARN_LEVEL);
		Assert.areEqual(1, warnings.size());
		Assert.isTrue(warnings[0].contains(version.Id));
	}

	@IsTest
	private static void testExecutePositiveDoesNotRetryAConversionDriveRefuses() {
		GoogleDriveHttpMock driveMock = prepareCopyRetry(false);
		refuseCopy(driveMock, 'GD_PVRTY_D', 400, DRIVE_CONVERSION_REFUSED_BODY);
		GoogleFileVersion__c version = createPreviewVersion('PVRTYD.webp', 'image/webp', 'GD_PVRTY_D', null);
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Exception jobFailure;
		Test.startTest();
		try {
			new GoogleFileVersionPreviewJob(new Set<Id>{ version.Id }).work();
		} catch (Exception ex) {
			jobFailure = ex;
		}
		Test.stopTest();

		Assert.isNull(jobFailure, 'A refused copy is logged and dropped, not thrown');
		Assert.areEqual(0, runningChain.getJobs().size(), 'A conversion Drive does not support is refused on every attempt');
		List<String> errors = loggedEntries(ERROR_LEVEL);
		Assert.areEqual(1, errors.size(), 'A copy given up on is logged as an error');
		Assert.isTrue(errors[0].contains(version.Id));
	}

	@IsTest
	private static void testExecutePositiveGivesUpOnTheCopyAfterTheThirdAttempt() {
		GoogleDriveHttpMock driveMock = prepareCopyRetry(false);
		refuseCopy(driveMock, 'GD_PVRTY_E', 503, DRIVE_UNAVAILABLE_BODY);
		GoogleFileVersion__c version = createPreviewVersion('PVRTYE.docx', DOCX_MIME_TYPE, 'GD_PVRTY_E', null);
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Test.startTest();
		new GoogleFileVersionPreviewJob(new Set<Id>{ version.Id }, true, 3).work();
		Test.stopTest();

		Assert.areEqual(0, runningChain.getJobs().size(), 'A copy gets three attempts in all');
		Assert.areEqual(1, loggedEntries(ERROR_LEVEL).size());
		Assert.areEqual(0, loggedEntries(WARN_LEVEL).size());
	}

	@IsTest
	private static void testExecutePositiveLateCopyChainsItsSummaryAndLabel() {
		prepareCopyRetry(true);
		GoogleFileVersion__c version = createPreviewVersion('PVLATE1.docx', DOCX_MIME_TYPE, 'GD_PVLATE_1', null, 2048L);
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Test.startTest();
		new GoogleFileVersionPreviewJob(new Set<Id>{ version.Id }, true, 2).work();
		Test.stopTest();

		Assert.areEqual(CLONED_WORKSPACE_COPY_ID, loadVersion(version.Id).GoogleDocsFileId__c);
		Integer summaryJobIndex = indexOfJob(runningChain, GoogleFileVersionSummaryJob.class);
		Integer labelJobIndex = indexOfJob(runningChain, GoogleFileVersionLabelJob.class);
		Integer sizeJobIndex = indexOfJob(runningChain, GoogleFileVersionPreviewSizeJob.class);
		Assert.areNotEqual(-1, summaryJobIndex, 'The chain\'s own summary already ran without a copy, so a late copy chains its own');
		Assert.areNotEqual(-1, labelJobIndex, 'And its own label, with labeling on');
		Assert.areNotEqual(-1, sizeJobIndex);
		Assert.isTrue(summaryJobIndex < labelJobIndex, 'Summary before label, as in every chain');
		Assert.isTrue(labelJobIndex < sizeJobIndex, 'The analysis does not wait behind the size measurement\'s one-minute delay');

		GoogleFileVersionSummaryJob summaryJob = (GoogleFileVersionSummaryJob) runningChain.getJobs()[summaryJobIndex];
		Assert.areEqual(new Set<Id>{ version.Id }, summaryJob.versionIds);
		Assert.areEqual(1, summaryJob.attempt, 'The copy\'s attempts are not the analysis\'s; the summary starts at its first');
		GoogleFileVersionLabelJob labelJob = (GoogleFileVersionLabelJob) runningChain.getJobs()[labelJobIndex];
		Assert.areEqual(new Set<Id>{ version.Id }, labelJob.versionIds);
		Assert.areEqual(1, labelJob.attempt);
	}

	@IsTest
	private static void testExecutePositiveLateCopyWithoutAnalysisChainsNothing() {
		prepareCopyRetry(true);
		GoogleFileVersion__c version = createPreviewVersion('PVLATE2.docx', DOCX_MIME_TYPE, 'GD_PVLATE_2', null, 2048L);
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Test.startTest();
		new GoogleFileVersionPreviewJob(new Set<Id>{ version.Id }, false, 2).work();
		Test.stopTest();

		Assert.areEqual(-1, indexOfJob(runningChain, GoogleFileVersionSummaryJob.class), 'A migrated file is never analyzed through a retried copy');
		Assert.areEqual(-1, indexOfJob(runningChain, GoogleFileVersionLabelJob.class));
		Assert.areNotEqual(-1, indexOfJob(runningChain, GoogleFileVersionPreviewSizeJob.class));
	}

	@IsTest
	private static void testExecutePositiveLateCopyWithAiOffChainsNoAnalysis() {
		prepareCopyRetry(false);
		GoogleFileVersion__c version = createPreviewVersion('PVLATE3.docx', DOCX_MIME_TYPE, 'GD_PVLATE_3', null, 2048L);
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Test.startTest();
		new GoogleFileVersionPreviewJob(new Set<Id>{ version.Id }, true, 2).work();
		Test.stopTest();

		Assert.areEqual(-1, indexOfJob(runningChain, GoogleFileVersionSummaryJob.class), 'Nothing is analyzed while AI is off');
		Assert.areEqual(-1, indexOfJob(runningChain, GoogleFileVersionLabelJob.class));
		Assert.areNotEqual(-1, indexOfJob(runningChain, GoogleFileVersionPreviewSizeJob.class));
	}

	@IsTest
	private static void testExecutePositiveFirstAttemptCopyChainsNoExtraAnalysis() {
		prepareCopyRetry(true);
		GoogleFileVersion__c version = createPreviewVersion('PVLATE4.docx', DOCX_MIME_TYPE, 'GD_PVLATE_4', null, 2048L);
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Test.startTest();
		new GoogleFileVersionPreviewJob(new Set<Id>{ version.Id }).work();
		Test.stopTest();

		Assert.areEqual(-1, indexOfJob(runningChain, GoogleFileVersionSummaryJob.class), 'A copy made on the first attempt is analyzed by the summary already in its chain, never twice');
		Assert.areEqual(-1, indexOfJob(runningChain, GoogleFileVersionLabelJob.class));
		Assert.areEqual(1, runningChain.getJobs().size());
	}

	@IsTest
	private static void testExecutePositiveLateCopyOfALargeUploadLeavesAnalysisToTheSizeJob() {
		prepareCopyRetry(true);
		GoogleFileVersion__c version = createPreviewVersion('PVLATE5.docx', DOCX_MIME_TYPE, 'GD_PVLATE_5', null, UPLOAD_OVER_ANALYSIS_LIMIT_BYTES);
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Test.startTest();
		new GoogleFileVersionPreviewJob(new Set<Id>{ version.Id }, true, 2).work();
		Test.stopTest();

		Assert.areEqual(-1, indexOfJob(runningChain, GoogleFileVersionSummaryJob.class), 'A large upload is admitted only once its copy is measured, by the size job');
		Assert.areNotEqual(-1, indexOfJob(runningChain, GoogleFileVersionPreviewSizeJob.class));
	}

	@IsTest
	private static void testExecutePositiveRetryCarriesTheAnalysisDecision() {
		GoogleDriveHttpMock driveMock = prepareCopyRetry(true);
		refuseCopy(driveMock, 'GD_PVRTY_F', 503, DRIVE_UNAVAILABLE_BODY);
		GoogleFileVersion__c version = createPreviewVersion('PVRTYF.docx', DOCX_MIME_TYPE, 'GD_PVRTY_F', null);
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Test.startTest();
		new GoogleFileVersionPreviewJob(new Set<Id>{ version.Id }, false).work();
		Test.stopTest();

		List<GoogleFileVersionPreviewJob> retryJobs = chainedPreviewJobs(runningChain);
		Assert.areEqual(1, retryJobs.size());
		Assert.areEqual(false, retryJobs[0].chainIntelligence, 'A migration that skipped analysis keeps skipping it on the retried copy');
	}

	@IsTest
	private static void testExecutePositiveNullAttemptCountsAsTheFirst() {
		GoogleDriveHttpMock driveMock = prepareCopyRetry(false);
		refuseCopy(driveMock, 'GD_PVRTY_G', 503, DRIVE_UNAVAILABLE_BODY);
		GoogleFileVersion__c version = createPreviewVersion('PVRTYG.docx', DOCX_MIME_TYPE, 'GD_PVRTY_G', null);
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Test.startTest();
		new GoogleFileVersionPreviewJob(new Set<Id>{ version.Id }, true, null).work();
		Test.stopTest();

		List<GoogleFileVersionPreviewJob> retryJobs = chainedPreviewJobs(runningChain);
		Assert.areEqual(1, retryJobs.size());
		Assert.areEqual(2, retryJobs[0].attempt);
	}

	@IsTest
	private static void testExecutePositiveRetryStopsWhenPreviewsWereTurnedOff() {
		GoogleDriveHttpMock driveMock = prepareCopyRetry(false);
		GoogleCloudTestFactory.config().withPreviewDisabled(true).apply();
		GoogleFileVersion__c version = createPreviewVersion('PVOFF.docx', DOCX_MIME_TYPE, 'GD_PVOFF', null);
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Test.startTest();
		new GoogleFileVersionPreviewJob(new Set<Id>{ version.Id }, true, 2).work();
		Test.stopTest();

		Assert.areEqual(0, countCopyRequests(driveMock), 'A retry finds previews turned off and makes no copy');
		Assert.isNull(loadVersion(version.Id).GoogleDocsFileId__c);
		Assert.areEqual(0, runningChain.getJobs().size());
	}
}
