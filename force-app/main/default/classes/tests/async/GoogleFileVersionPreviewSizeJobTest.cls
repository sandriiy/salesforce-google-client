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
private class GoogleFileVersionPreviewSizeJobTest {
	private static final String DOCX_MIME_TYPE = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
	private static final Long UPLOAD_WITHIN_ANALYSIS_LIMIT_BYTES = 5000000L;
	private static final Long UPLOAD_OVER_ANALYSIS_LIMIT_BYTES = GoogleCloudConstants.MAX_SUMMARY_FILE_SIZE_BYTES + 1;
	private static final String FITTING_COPY_SIZE = '112000';
	private static final String SECOND_PASS_SUMMARY = 'This file describes a product brochure for the spring catalogue.';
	private static final String LABEL_DEFINITIONS = '[{"name":"Brochure","labelId":"LABEL_BROCHURE","description":"Marketing material describing products"}]';

	private static GoogleFileVersion__c createVersion(String fileName, String driveId, String docsId, Long docsSize) {
		return createVersion(fileName, driveId, docsId, docsSize, UPLOAD_WITHIN_ANALYSIS_LIMIT_BYTES);
	}

	private static GoogleFileVersion__c createVersion(String fileName, String driveId, String docsId, Long docsSize, Long uploadSize) {
		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName(fileName + '_Parent')
			.withDescription('D')
			.insertRecord();

		return GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName(fileName)
			.withType(DOCX_MIME_TYPE)
			.withSize(uploadSize)
			.withDriveId(driveId)
			.withDocsId(docsId)
			.withDocsSize(docsSize)
			.insertRecord();
	}

	private static GoogleCloudTestFactory.ConfigBuilder analysisConfig() {
		return GoogleCloudTestFactory.config()
			.withFileIntelligence(true)
			.withGeminiApiKey('api-key-1')
			.withAiModel('gemini-2.0-flash');
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

	private static GoogleFileLabelResultDTO buildLabelResult(String labelName) {
		GoogleFileLabelResultDTO result = new GoogleFileLabelResultDTO();
		result.success = true;
		result.applied = true;
		result.provider = 'Gemini';
		result.labelName = labelName;
		result.labelId = 'LABEL_' + labelName.toUpperCase();
		result.confidence = 90;
		return result;
	}

	private static GoogleDriveHttpMock mockPreviewSize(String docsId, String size) {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.endpointContains('/files/' + docsId)
		).thenReturn(new GoogleDriveHttpMock.JsonResponses().fileSizeSuccess(docsId, size));

		return driveMock;
	}

	private static GoogleFileVersion__c loadVersion(Id versionId) {
		return [
			SELECT GoogleDocsFileSize__c, Summary__c, AiLabels__c
			FROM GoogleFileVersion__c
			WHERE Id = :versionId
			LIMIT 1
		];
	}

	private static Integer countRequestsFor(GoogleDriveHttpMock driveMock, String docsId) {
		Integer requests = 0;
		for (GoogleDriveHttpMock.CapturedRequest capturedRequest : driveMock.getCapturedRequests()) {
			if (capturedRequest.endpoint != null && capturedRequest.endpoint.contains('/files/' + docsId)) {
				requests++;
			}
		}

		return requests;
	}

	@IsTest
	private static void testExecutePositiveStoresMeasuredPreviewSize() {
		GoogleDriveHttpMock driveMock = mockPreviewSize('DOCS_PS_1', '4335');
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleFileVersion__c version = createVersion('PS1.docx', 'GD_PS_1', 'DOCS_PS_1', null);

		Test.startTest();
		new GoogleFileVersionPreviewSizeJob(new Set<Id>{ version.Id }).work();
		Integer rescheduledJobs = Limits.getQueueableJobs();
		Test.stopTest();

		Assert.areEqual(4335, loadVersion(version.Id).GoogleDocsFileSize__c);
		Assert.areEqual(1, countRequestsFor(driveMock, 'DOCS_PS_1'));
		Assert.areEqual(0, rescheduledJobs);
	}

	@IsTest
	private static void testExecutePositiveReschedulesWhileConversionPending() {
		GoogleDriveHttpMock driveMock = mockPreviewSize('DOCS_PS_2', '1');
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleFileVersion__c version = createVersion('PS2.docx', 'GD_PS_2', 'DOCS_PS_2', null);

		Test.startTest();
		new GoogleFileVersionPreviewSizeJob(new Set<Id>{ version.Id }).work();
		Integer rescheduledJobs = Limits.getQueueableJobs();
		GoogleFileVersionPreviewSizeJob.skipExecution = true;
		Test.stopTest();

		Assert.isNull(loadVersion(version.Id).GoogleDocsFileSize__c);
		Assert.areEqual(1, rescheduledJobs);
	}

	@IsTest
	private static void testExecutePositiveStopsReschedulingAfterLastAttempt() {
		GoogleDriveHttpMock driveMock = mockPreviewSize('DOCS_PS_3', '1');
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleFileVersion__c version = createVersion('PS3.docx', 'GD_PS_3', 'DOCS_PS_3', null);

		Test.startTest();
		new GoogleFileVersionPreviewSizeJob(new Set<Id>{ version.Id }, 3).work();
		Integer rescheduledJobs = Limits.getQueueableJobs();
		Test.stopTest();

		Assert.isNull(loadVersion(version.Id).GoogleDocsFileSize__c);
		Assert.areEqual(0, rescheduledJobs);
	}

	@IsTest
	private static void testExecutePositiveSkipsAlreadyMeasuredVersion() {
		GoogleDriveHttpMock driveMock = mockPreviewSize('DOCS_PS_4', '9999');
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleFileVersion__c version = createVersion('PS4.docx', 'GD_PS_4', 'DOCS_PS_4', 700);

		Test.startTest();
		new GoogleFileVersionPreviewSizeJob(new Set<Id>{ version.Id }).work();
		Integer rescheduledJobs = Limits.getQueueableJobs();
		Test.stopTest();

		Assert.areEqual(700, loadVersion(version.Id).GoogleDocsFileSize__c);
		Assert.areEqual(0, countRequestsFor(driveMock, 'DOCS_PS_4'));
		Assert.areEqual(0, rescheduledJobs);
	}

	@IsTest
	private static void testExecutePositiveSkipsVersionWithoutWorkspaceCopy() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleFileVersion__c version = createVersion('PS5.docx', 'GD_PS_5', null, null);

		Test.startTest();
		new GoogleFileVersionPreviewSizeJob(new Set<Id>{ version.Id }).work();
		Integer rescheduledJobs = Limits.getQueueableJobs();
		Integer driveRequests = driveMock.getCapturedRequests().size();
		Test.stopTest();

		Assert.isNull(loadVersion(version.Id).GoogleDocsFileSize__c);
		Assert.areEqual(0, driveRequests);
		Assert.areEqual(0, rescheduledJobs);
	}

	@IsTest
	private static void testExecuteNegativeDriveErrorLeavesSizeBlankAndReschedules() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.endpointContains('/files/DOCS_PS_6')
		).thenReturnStatus(500, '{ "error": { "message": "Backend Error" } }');
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleFileVersion__c version = createVersion('PS6.docx', 'GD_PS_6', 'DOCS_PS_6', null);

		Test.startTest();
		new GoogleFileVersionPreviewSizeJob(new Set<Id>{ version.Id }).work();
		Integer rescheduledJobs = Limits.getQueueableJobs();
		GoogleFileVersionPreviewSizeJob.skipExecution = true;
		Test.stopTest();

		Assert.isNull(loadVersion(version.Id).GoogleDocsFileSize__c);
		Assert.areEqual(1, rescheduledJobs);
	}

	@IsTest
	private static void testExecutePositiveEmptyVersionIds() {
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		new GoogleFileVersionPreviewSizeJob(new Set<Id>()).work();
		Integer rescheduledJobs = Limits.getQueueableJobs();
		Test.stopTest();

		Assert.areEqual(0, rescheduledJobs);
	}

	@IsTest
	private static void testExecutePositiveNullVersionIds() {
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		new GoogleFileVersionPreviewSizeJob(null).work();
		Integer rescheduledJobs = Limits.getQueueableJobs();
		Test.stopTest();

		Assert.areEqual(0, rescheduledJobs);
	}

	@IsTest
	private static void testExecutePositiveChainsSummaryForLargeUploadWithFittingCopy() {
		analysisConfig().apply();
		GoogleCloudTestFactory.initMocks(mockPreviewSize('DOCS_PS_7', FITTING_COPY_SIZE));
		GoogleCloudTestFactory.bypassTriggers();
		GoogleFileVersion__c version = createVersion('PS7.docx', 'GD_PS_7', 'DOCS_PS_7', null, UPLOAD_OVER_ANALYSIS_LIMIT_BYTES);
		GoogleFileVersionSummaryJob.setTestResult(version.Id, buildSummaryResult(SECOND_PASS_SUMMARY));

		Test.startTest();
		new GoogleFileVersionPreviewSizeJob(new Set<Id>{ version.Id }).work();
		Integer chainedJobs = Limits.getQueueableJobs();
		Test.stopTest();

		GoogleFileVersion__c measuredVersion = loadVersion(version.Id);
		Assert.areEqual(Decimal.valueOf(FITTING_COPY_SIZE), measuredVersion.GoogleDocsFileSize__c);
		Assert.areEqual(SECOND_PASS_SUMMARY, measuredVersion.Summary__c);
		Assert.areEqual(1, chainedJobs);
	}

	@IsTest
	private static void testExecutePositiveChainsSummaryAndLabelWhenLabelingConfigured() {
		analysisConfig().withAiLabeling(true).withAiLabelDefinitions(LABEL_DEFINITIONS).apply();
		GoogleCloudTestFactory.initMocks(mockPreviewSize('DOCS_PS_8', FITTING_COPY_SIZE));
		GoogleCloudTestFactory.bypassTriggers();
		GoogleFileVersion__c version = createVersion('PS8.docx', 'GD_PS_8', 'DOCS_PS_8', null, UPLOAD_OVER_ANALYSIS_LIMIT_BYTES);
		GoogleFileVersionSummaryJob.setTestResult(version.Id, buildSummaryResult(SECOND_PASS_SUMMARY));
		GoogleFileVersionLabelJob.setTestResult(version.Id, buildLabelResult('Brochure'));

		Test.startTest();
		new GoogleFileVersionPreviewSizeJob(new Set<Id>{ version.Id }).work();
		Integer chainedJobs = Limits.getQueueableJobs();
		Test.stopTest();

		List<GoogleFileVersionLabel__c> labels = [
			SELECT Name, GoogleDriveLabelId__c
			FROM GoogleFileVersionLabel__c
			WHERE GoogleFileVersionId__c = :version.Id
		];
		GoogleFileVersion__c measuredVersion = loadVersion(version.Id);
		Assert.areEqual(SECOND_PASS_SUMMARY, measuredVersion.Summary__c);
		Assert.areEqual('Brochure', measuredVersion.AiLabels__c);
		Assert.areEqual(1, labels.size());
		Assert.areEqual('LABEL_BROCHURE', labels[0].GoogleDriveLabelId__c);
		Assert.areEqual(1, chainedJobs);
	}

	@IsTest
	private static void testExecutePositiveSmallUploadChainsNothingExtra() {
		analysisConfig().apply();
		GoogleCloudTestFactory.initMocks(mockPreviewSize('DOCS_PS_9', FITTING_COPY_SIZE));
		GoogleCloudTestFactory.bypassTriggers();
		GoogleFileVersion__c version = createVersion('PS9.docx', 'GD_PS_9', 'DOCS_PS_9', null);
		GoogleFileVersionSummaryJob.setTestResult(version.Id, buildSummaryResult(SECOND_PASS_SUMMARY));

		Test.startTest();
		new GoogleFileVersionPreviewSizeJob(new Set<Id>{ version.Id }).work();
		Integer chainedJobs = Limits.getQueueableJobs();
		Test.stopTest();

		GoogleFileVersion__c measuredVersion = loadVersion(version.Id);
		Assert.areEqual(Decimal.valueOf(FITTING_COPY_SIZE), measuredVersion.GoogleDocsFileSize__c);
		Assert.isNull(measuredVersion.Summary__c);
		Assert.areEqual(0, chainedJobs);
	}

	@IsTest
	private static void testExecutePositiveOversizedCopyChainsNothingExtra() {
		analysisConfig().apply();
		GoogleCloudTestFactory.initMocks(mockPreviewSize('DOCS_PS_10', String.valueOf(UPLOAD_OVER_ANALYSIS_LIMIT_BYTES)));
		GoogleCloudTestFactory.bypassTriggers();
		GoogleFileVersion__c version = createVersion('PS10.docx', 'GD_PS_10', 'DOCS_PS_10', null, UPLOAD_OVER_ANALYSIS_LIMIT_BYTES);

		Test.startTest();
		new GoogleFileVersionPreviewSizeJob(new Set<Id>{ version.Id }).work();
		Integer chainedJobs = Limits.getQueueableJobs();
		Test.stopTest();

		Assert.areEqual(UPLOAD_OVER_ANALYSIS_LIMIT_BYTES, loadVersion(version.Id).GoogleDocsFileSize__c);
		Assert.areEqual(0, chainedJobs);
	}

	@IsTest
	private static void testExecutePositiveAnalysisOffChainsNothingExtra() {
		GoogleCloudTestFactory.initMocks(mockPreviewSize('DOCS_PS_11', FITTING_COPY_SIZE));
		GoogleCloudTestFactory.bypassTriggers();
		GoogleFileVersion__c version = createVersion('PS11.docx', 'GD_PS_11', 'DOCS_PS_11', null, UPLOAD_OVER_ANALYSIS_LIMIT_BYTES);

		Test.startTest();
		new GoogleFileVersionPreviewSizeJob(new Set<Id>{ version.Id }).work();
		Integer chainedJobs = Limits.getQueueableJobs();
		Test.stopTest();

		Assert.areEqual(Decimal.valueOf(FITTING_COPY_SIZE), loadVersion(version.Id).GoogleDocsFileSize__c);
		Assert.areEqual(0, chainedJobs);
	}

	@IsTest
	private static void testExecutePositiveReschedulesUnmeasuredAlongsideSecondPass() {
		analysisConfig().apply();
		GoogleDriveHttpMock driveMock = mockPreviewSize('DOCS_PS_12', FITTING_COPY_SIZE);
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.endpointContains('/files/DOCS_PS_13')
		).thenReturn(new GoogleDriveHttpMock.JsonResponses().fileSizeSuccess('DOCS_PS_13', '1'));
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleCloudTestFactory.bypassTriggers();
		GoogleFileVersion__c measuredVersion = createVersion('PS12.docx', 'GD_PS_12', 'DOCS_PS_12', null, UPLOAD_OVER_ANALYSIS_LIMIT_BYTES);
		GoogleFileVersion__c convertingVersion = createVersion('PS13.docx', 'GD_PS_13', 'DOCS_PS_13', null, UPLOAD_OVER_ANALYSIS_LIMIT_BYTES);
		GoogleFileVersionSummaryJob.setTestResult(measuredVersion.Id, buildSummaryResult(SECOND_PASS_SUMMARY));

		Test.startTest();
		new GoogleFileVersionPreviewSizeJob(new Set<Id>{ measuredVersion.Id, convertingVersion.Id }).work();
		Integer chainedJobs = Limits.getQueueableJobs();
		GoogleFileVersionPreviewSizeJob.skipExecution = true;
		Test.stopTest();

		GoogleFileVersion__c stillConvertingVersion = loadVersion(convertingVersion.Id);
		Assert.areEqual(SECOND_PASS_SUMMARY, loadVersion(measuredVersion.Id).Summary__c);
		Assert.isNull(stillConvertingVersion.GoogleDocsFileSize__c);
		Assert.isNull(stillConvertingVersion.Summary__c);
		Assert.areEqual(2, chainedJobs);
	}

	@IsTest
	private static void testSchedulePositiveSecondPassRunsInsideTheMeasurementChain() {
		analysisConfig().apply();
		GoogleCloudTestFactory.initMocks(mockPreviewSize('DOCS_PS_14', FITTING_COPY_SIZE));
		GoogleCloudTestFactory.bypassTriggers();
		GoogleFileVersion__c version = createVersion('PS14.docx', 'GD_PS_14', 'DOCS_PS_14', null, UPLOAD_OVER_ANALYSIS_LIMIT_BYTES);
		GoogleFileVersionSummaryJob.setTestResult(version.Id, buildSummaryResult(SECOND_PASS_SUMMARY));

		Test.startTest();
		GoogleFileVersionPreviewSizeJob.schedule(new Set<Id>{ version.Id });
		Test.stopTest();

		GoogleFileVersion__c measuredVersion = loadVersion(version.Id);
		Assert.areEqual(Decimal.valueOf(FITTING_COPY_SIZE), measuredVersion.GoogleDocsFileSize__c);
		Assert.areEqual(SECOND_PASS_SUMMARY, measuredVersion.Summary__c);
	}

	@IsTest
	private static void testSchedulePositiveWithoutAnalysisStoresSizeOnly() {
		analysisConfig().apply();
		GoogleCloudTestFactory.initMocks(mockPreviewSize('DOCS_PS_15', FITTING_COPY_SIZE));
		GoogleCloudTestFactory.bypassTriggers();
		GoogleFileVersion__c version = createVersion('PS15.docx', 'GD_PS_15', 'DOCS_PS_15', null, UPLOAD_OVER_ANALYSIS_LIMIT_BYTES);
		GoogleFileVersionSummaryJob.setTestResult(version.Id, buildSummaryResult(SECOND_PASS_SUMMARY));

		Test.startTest();
		GoogleFileVersionPreviewSizeJob.schedule(new Set<Id>{ version.Id }, false);
		Test.stopTest();

		GoogleFileVersion__c measuredVersion = loadVersion(version.Id);
		Assert.areEqual(Decimal.valueOf(FITTING_COPY_SIZE), measuredVersion.GoogleDocsFileSize__c);
		Assert.isNull(measuredVersion.Summary__c);
	}
}
