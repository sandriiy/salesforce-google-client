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
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		new GoogleFileVersionPreviewJob(new Set<Id>()).work();
		Test.stopTest();

		Assert.isTrue(true);
	}

	@IsTest
	private static void testExecutePositiveNullVersionIds() {
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		new GoogleFileVersionPreviewJob(null).work();
		Test.stopTest();

		Assert.isTrue(true);
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
}
