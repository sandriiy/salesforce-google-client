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
private class GoogleFileSummarizeCommandTest {
	private static final String DOCX_MIME_TYPE = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
	private static final String TIMEOUT_REASON = 'Read timed out';
	private static final String VERTEX_RESOURCE_EXHAUSTED_BODY = '{"error":{"code":429,"message":"Resource exhausted. Please try again later. Please refer to https://cloud.google.com/vertex-ai/generative-ai/docs/error-code-429 for more details.","status":"RESOURCE_EXHAUSTED"}}';
	private static final String GEMINI_INVALID_KEY_BODY = '{"error":{"code":400,"message":"API key not valid. Please pass a valid API key.","status":"INVALID_ARGUMENT"}}';
	private static final String DRIVE_USER_RATE_LIMIT_BODY = '{"error":{"code":403,"message":"User rate limit exceeded.","errors":[{"message":"User rate limit exceeded.","domain":"usageLimits","reason":"userRateLimitExceeded"}]}}';
	private static final String DRIVE_CONVERSION_REFUSED_BODY = '{"error":{"code":400,"message":"The requested conversion is not supported.","errors":[{"message":"The requested conversion is not supported.","domain":"global","reason":"badRequest","location":"convertTo","locationType":"parameter"}]}}';
	private static final String GENERATED_SUMMARY = 'This file describes a product brochure for the spring catalogue.';

	private class GenAiClientStub implements IGenAiClient {
		private final GenAiResponse response;
		private GenAiRequest capturedRequest;

		private GenAiClientStub(String text, String finishReason) {
			GenAiResponse generatedResponse = new GenAiResponse();
			GenAiCandidate candidate = new GenAiCandidate();
			candidate.finishReason = finishReason;
			candidate.content = new GenAiMessage('model').addText(text);
			generatedResponse.addCandidate(candidate);
			this.response = generatedResponse;
		}

		public GenAiResponse generate(GenAiRequest request) {
			this.capturedRequest = request;
			return this.response;
		}
	}

	private class FailingGenAiClient implements IGenAiClient {
		private final Exception failure;

		private FailingGenAiClient(Exception failure) {
			this.failure = failure;
		}

		public GenAiResponse generate(GenAiRequest request) {
			throw this.failure;
		}
	}

	private static GoogleFileVersion__c createSummaryCandidate(String fileName) {
		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName(fileName)
			.insertRecord();

		return GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName(fileName + '.docx')
			.withType(DOCX_MIME_TYPE)
			.withSize(2048)
			.withDocsId('DOCS_' + fileName)
			.insertRecord();
	}

	private static GoogleClientConfig__mdt buildUpgradedConfig() {
		return new GoogleClientConfig__mdt(
			IsFilePreviewDisabled__c = true,
			IsFileIntelligenceEnabled__c = true,
			QuestionMaxOutputTokens__c = 1024
		);
	}

	private static GoogleDriveHttpMock installExportAnswer(String docsFileId, Integer statusCode, String body) {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher().withMethod('GET').endpointContains(docsFileId)
		).thenReturnStatus(statusCode, body);
		GoogleCloudTestFactory.initMocks(driveMock);
		return driveMock;
	}

	@IsTest
	private static void testSummarizeNegativeUnavailableConfiguration() {
		GoogleFileAnalysisResultDTO result = new GoogleFileSummarizeCommand().summarize(
			GoogleCloudTestFactory.fakeId(GoogleFileVersion__c.SObjectType),
			'Gemini',
			null,
			null
		);

		Assert.isTrue(result.blocked);
		Assert.areEqual('Google AI summary configuration is unavailable', result.errorMessage);
	}

	@IsTest
	private static void testSummarizePositiveFitsResponseToCharacterLimit() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(IsFilePreviewDisabled__c = true);

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('SUMCMD1')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('SUMCMD1.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(2048)
			.withDocsId('DOCS_SUMCMD_1')
			.insertRecord();

		GenAiClientStub clientStub = new GenAiClientStub('X'.repeat(256), 'STOP');
		GoogleFileAnalysisResultDTO result;
		Test.startTest();
			result = new GoogleFileSummarizeCommand().summarize(
				version.Id,
				'Gemini',
				'gemini-2.0-flash',
				clientStub
			);
		Test.stopTest();

		Assert.isNotNull(result);
		Assert.isTrue(result.success);
		Assert.areEqual(255, result.text.length());
		Assert.areEqual('X'.repeat(252) + '...', result.text);
		Assert.areEqual(0, clientStub.capturedRequest.generation.stopSequences.size());
	}

	@IsTest
	private static void testSummarizePositiveLeavesRoomForReasoningPastTheBudget() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(IsFilePreviewDisabled__c = true);

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('SUMCMD9')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('SUMCMD9.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(2048)
			.withDocsId('DOCS_SUMCMD_9')
			.insertRecord();

		GenAiClientStub clientStub = new GenAiClientStub('This file describes a product brochure.', 'STOP');
		Test.startTest();
			new GoogleFileSummarizeCommand().summarize(version.Id, 'Agent Platform', 'gemini-3.8-flash', clientStub);
		Test.stopTest();

		GenAiGoogleOptions sentOptions = (GenAiGoogleOptions) clientStub.capturedRequest.providerOptions;
		Assert.areEqual(0, sentOptions.thinkingBudget);
		Assert.areEqual(80 + 2048, clientStub.capturedRequest.generation.maxTokens);
	}

	@IsTest
	private static void testSummarizePositiveAcceptsCompleteMaxTokensResponse() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(IsFilePreviewDisabled__c = true);

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('SUMCMD3')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('SUMCMD3.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(2048)
			.withDocsId('DOCS_SUMCMD_3')
			.insertRecord();

		String generatedText = 'This file describes an Adobe invoice for a Premiere plan subscription billed in CAD.';
		GoogleFileAnalysisResultDTO result;
		Test.startTest();
			result = new GoogleFileSummarizeCommand().summarize(
				version.Id,
				'Gemini',
				'gemini-2.0-flash',
				new GenAiClientStub(generatedText, 'MAX_TOKENS')
			);
		Test.stopTest();

		Assert.isTrue(result.success);
		Assert.areEqual(generatedText, result.text);
	}

	@IsTest
	private static void testSummarizePositiveAddsEllipsisToIncompleteResponse() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(IsFilePreviewDisabled__c = true);

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('SUMCMD4')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('SUMCMD4.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(2048)
			.withDocsId('DOCS_SUMCMD_4')
			.insertRecord();

		String generatedText = 'This file describes an Adobe invoice for a Premiere plan subscription billed in CAD';
		GoogleFileAnalysisResultDTO result;
		Test.startTest();
			result = new GoogleFileSummarizeCommand().summarize(
				version.Id,
				'Gemini',
				'gemini-2.0-flash',
				new GenAiClientStub(generatedText, 'MAX_TOKENS')
			);
		Test.stopTest();

		Assert.isTrue(result.success);
		Assert.areEqual(generatedText + '...', result.text);
	}

	@IsTest
	private static void testSummarizeNegativeNoContent() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(IsFilePreviewDisabled__c = true);

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('SUMCMD2')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('SUMCMD2.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(2048)
			.withDocsId('DOCS_SUMCMD_2')
			.insertRecord();

		GoogleFileAnalysisResultDTO result;
		Test.startTest();
			result = new GoogleFileSummarizeCommand().summarize(
				version.Id,
				'Gemini',
				'gemini-2.0-flash',
				new GenAiClientStub('', 'STOP')
			);
		Test.stopTest();

		Assert.isNotNull(result);
		Assert.areEqual(null, result.success);
		Assert.areEqual('Summary response returned no content (NO_CONTENT_STOP)', result.errorMessage);
	}

	@IsTest
	private static void testSummarizeGuardBlocksResponseWithSecretLeak() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(IsFilePreviewDisabled__c = true);

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('SUMCMD5')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('SUMCMD5.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(2048)
			.withDocsId('DOCS_SUMCMD_5')
			.insertRecord();

		GoogleAiPromptSafetyGuardFactory.resetForTest();

		GoogleFileAnalysisResultDTO result;
		Test.startTest();
			result = new GoogleFileSummarizeCommand().summarize(
				version.Id,
				'Gemini',
				'gemini-2.0-flash',
				new GenAiClientStub('Summary revealing key AIzaSyABCDEFGHIJKLMNOPQRSTUVWXYZ0123456ab.', 'STOP')
			);
		Test.stopTest();

		Assert.isTrue(result.blocked);
		Assert.areNotEqual(true, result.success);
		Assert.isNull(result.text);
	}

	@IsTest
	private static void testSummarizeGuardBlocksResponseOnProviderSafetyFinishReason() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(IsFilePreviewDisabled__c = true);

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('SUMCMD6')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('SUMCMD6.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(2048)
			.withDocsId('DOCS_SUMCMD_6')
			.insertRecord();

		GoogleAiPromptSafetyGuardFactory.resetForTest();

		GoogleFileAnalysisResultDTO result;
		Test.startTest();
			result = new GoogleFileSummarizeCommand().summarize(
				version.Id,
				'Gemini',
				'gemini-2.0-flash',
				new GenAiClientStub('Some benign summary text.', 'SAFETY')
			);
		Test.stopTest();

		Assert.isTrue(result.blocked);
		Assert.areNotEqual(true, result.success);
		Assert.isNull(result.text);
	}

	@IsTest
	private static void testSummarizePositiveLargeUploadWithFittingWorkspaceCopy() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(IsFilePreviewDisabled__c = true);

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('SUMCMD7')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('SUMCMD7.pdf')
			.withType('application/pdf')
			.withSize(GoogleCloudConstants.MAX_SUMMARY_FILE_SIZE_BYTES + 1)
			.withDocsId('DOCS_SUMCMD_7')
			.withDocsSize(112000)
			.insertRecord();

		String generatedText = 'This file describes a product brochure for the spring catalogue.';
		GoogleFileAnalysisResultDTO result;
		Test.startTest();
			result = new GoogleFileSummarizeCommand().summarize(
				version.Id,
				'Gemini',
				'gemini-2.0-flash',
				new GenAiClientStub(generatedText, 'STOP')
			);
		Test.stopTest();

		Assert.isTrue(result.success);
		Assert.areEqual(generatedText, result.text);
	}

	@IsTest
	private static void testSummarizeNegativeLargeUploadWithUnmeasuredWorkspaceCopy() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(IsFilePreviewDisabled__c = true);

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('SUMCMD8')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('SUMCMD8.pdf')
			.withType('application/pdf')
			.withSize(GoogleCloudConstants.MAX_SUMMARY_FILE_SIZE_BYTES + 1)
			.withDocsId('DOCS_SUMCMD_8')
			.insertRecord();

		GenAiClientStub clientStub = new GenAiClientStub('This file describes a product brochure.', 'STOP');
		GoogleFileAnalysisResultDTO result;
		Test.startTest();
			result = new GoogleFileSummarizeCommand().summarize(
				version.Id,
				'Gemini',
				'gemini-2.0-flash',
				clientStub
			);
		Test.stopTest();

		Assert.isTrue(result.blocked);
		Assert.areNotEqual(true, result.success);
		Assert.isNull(clientStub.capturedRequest);
	}

	@IsTest
	private static void testSummarizePositiveBlankLimitSendsTodaysBudget() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildUpgradedConfig();
		GoogleFileVersion__c version = createSummaryCandidate('SUMLIM1');

		GenAiClientStub clientStub = new GenAiClientStub(GENERATED_SUMMARY, 'STOP');
		Test.startTest();
			new GoogleFileSummarizeCommand().summarize(version.Id, 'Agent Platform', 'gemini-3.8-flash', clientStub);
		Test.stopTest();

		Assert.areEqual(2128, clientStub.capturedRequest.generation.maxTokens, 'A blank Summary Max Output Tokens must send exactly what every summary sent before');
	}

	@IsTest
	private static void testSummarizePositiveConfiguredLimitKeepsReasoningRoom() {
		GoogleCloudTestFactory.initMocks();
		GoogleClientConfig__mdt config = buildUpgradedConfig();
		config.SummaryMaxOutputTokens__c = 200;
		GoogleMetadataConfigService.configRecordOverride = config;
		GoogleFileVersion__c version = createSummaryCandidate('SUMLIM2');

		GenAiClientStub clientStub = new GenAiClientStub(GENERATED_SUMMARY, 'STOP');
		Test.startTest();
			new GoogleFileSummarizeCommand().summarize(version.Id, 'Agent Platform', 'gemini-3.8-flash', clientStub);
		Test.stopTest();

		GenAiGoogleOptions sentOptions = (GenAiGoogleOptions) clientStub.capturedRequest.providerOptions;
		Assert.areEqual(200 + 2048, clientStub.capturedRequest.generation.maxTokens, 'The setting counts the answer only; the reasoning room is still added on top');
		Assert.areEqual(0, sentOptions.thinkingBudget);
	}

	@IsTest
	private static void testSummarizePositiveZeroLimitSendsNoCap() {
		GoogleCloudTestFactory.initMocks();
		GoogleClientConfig__mdt config = buildUpgradedConfig();
		config.SummaryMaxOutputTokens__c = 0;
		GoogleMetadataConfigService.configRecordOverride = config;
		GoogleFileVersion__c version = createSummaryCandidate('SUMLIM3');

		GenAiClientStub clientStub = new GenAiClientStub(GENERATED_SUMMARY, 'STOP');
		GoogleFileAnalysisResultDTO result;
		Test.startTest();
			result = new GoogleFileSummarizeCommand().summarize(version.Id, 'Agent Platform', 'gemini-3.8-flash', clientStub);
		Test.stopTest();

		Assert.isTrue(result.success);
		Assert.isNull(clientStub.capturedRequest.generation.maxTokens, 'No limit sends no output cap at all, not a cap of 0 or of the reasoning room alone');
		Assert.isFalse(new GenAiGoogleRequestSerializer().serialize(clientStub.capturedRequest).contains('maxOutputTokens'));
	}

	@IsTest
	private static void testSummarizePositiveNegativeLimitSendsTodaysBudget() {
		GoogleCloudTestFactory.initMocks();
		GoogleClientConfig__mdt config = buildUpgradedConfig();
		config.SummaryMaxOutputTokens__c = -5;
		GoogleMetadataConfigService.configRecordOverride = config;
		GoogleFileVersion__c version = createSummaryCandidate('SUMLIM4');

		GenAiClientStub clientStub = new GenAiClientStub(GENERATED_SUMMARY, 'STOP');
		Test.startTest();
			new GoogleFileSummarizeCommand().summarize(version.Id, 'Agent Platform', 'gemini-3.8-flash', clientStub);
		Test.stopTest();

		Assert.areEqual(2128, clientStub.capturedRequest.generation.maxTokens, 'Only 0 means No limit; a negative value means the default');
	}

	@IsTest
	private static void testSummarizeNegativeTimeoutIsRetryable() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildUpgradedConfig();
		GoogleFileVersion__c version = createSummaryCandidate('SUMRTY1');

		GoogleFileAnalysisResultDTO result;
		Test.startTest();
			result = new GoogleFileSummarizeCommand().summarize(version.Id, 'Agent Platform', 'gemini-3.8-flash', new FailingGenAiClient(new CalloutException(TIMEOUT_REASON)));
		Test.stopTest();

		Assert.areNotEqual(true, result.success);
		Assert.isTrue(result.retryable, 'A summary the AI service did not answer in time is tried again later');
		Assert.areEqual(TIMEOUT_REASON, result.errorMessage, 'A summary is never shown to a user, so it keeps the raw reason for the job\'s log line');
	}

	@IsTest
	private static void testSummarizeNegativeBusyAnswerIsRetryable() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildUpgradedConfig();
		GoogleFileVersion__c version = createSummaryCandidate('SUMRTY2');

		GoogleFileAnalysisResultDTO result;
		Test.startTest();
			result = new GoogleFileSummarizeCommand().summarize(version.Id, 'Agent Platform', 'gemini-3.8-flash', new FailingGenAiClient(new GenAiProviderException(VERTEX_RESOURCE_EXHAUSTED_BODY)));
		Test.stopTest();

		Assert.areNotEqual(true, result.success);
		Assert.isTrue(result.retryable);
	}

	@IsTest
	private static void testSummarizeNegativeConfigurationErrorIsNotRetryable() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildUpgradedConfig();
		GoogleFileVersion__c version = createSummaryCandidate('SUMRTY3');

		GoogleFileAnalysisResultDTO result;
		Test.startTest();
			result = new GoogleFileSummarizeCommand().summarize(version.Id, 'Gemini', 'gemini-2.0-flash', new FailingGenAiClient(new GenAiProviderException(GEMINI_INVALID_KEY_BODY)));
		Test.stopTest();

		Assert.areNotEqual(true, result.success);
		Assert.areNotEqual(true, result.retryable, 'A wrong API key fails the same way on every attempt');
	}

	@IsTest
	private static void testSummarizeNegativeEmptyMaxTokensAnswerIsRetryable() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildUpgradedConfig();
		GoogleFileVersion__c version = createSummaryCandidate('SUMRTY4');

		GoogleFileAnalysisResultDTO result;
		Test.startTest();
			result = new GoogleFileSummarizeCommand().summarize(version.Id, 'Agent Platform', 'gemini-3.8-flash', new GenAiClientStub('', 'MAX_TOKENS'));
		Test.stopTest();

		Assert.areNotEqual(true, result.success);
		Assert.isTrue(result.retryable, 'An answer that ran out of room before writing anything is tried again');
	}

	@IsTest
	private static void testSummarizePositiveCutMaxTokensAnswerIsStoredNotRetried() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildUpgradedConfig();
		GoogleFileVersion__c version = createSummaryCandidate('SUMRTY5');

		GoogleFileAnalysisResultDTO result;
		Test.startTest();
			result = new GoogleFileSummarizeCommand().summarize(version.Id, 'Agent Platform', 'gemini-3.8-flash', new GenAiClientStub('This file describes', 'MAX_TOKENS'));
		Test.stopTest();

		Assert.isTrue(result.success);
		Assert.areEqual('This file describes...', result.text);
		Assert.areNotEqual(true, result.retryable, 'An answer cut short keeps the text it has');
	}

	@IsTest
	private static void testSummarizeNegativeBlankExportIsRetryable() {
		installExportAnswer('DOCS_SUMRTY6', 200, '');
		GoogleMetadataConfigService.configRecordOverride = buildUpgradedConfig();
		GoogleFileVersion__c version = createSummaryCandidate('SUMRTY6');

		GenAiClientStub clientStub = new GenAiClientStub(GENERATED_SUMMARY, 'STOP');
		GoogleFileAnalysisResultDTO result;
		Test.startTest();
			result = new GoogleFileSummarizeCommand().summarize(version.Id, 'Agent Platform', 'gemini-3.8-flash', clientStub);
		Test.stopTest();

		Assert.areNotEqual(true, result.success);
		Assert.isTrue(result.retryable, 'A copy that exports nothing right after it was made may export its text a moment later');
		Assert.isNull(clientStub.capturedRequest, 'Nothing is sent to the model without document text');
	}

	@IsTest
	private static void testSummarizeNegativeDriveRateLimitDuringExportIsRetryable() {
		installExportAnswer('DOCS_SUMRTY7', 403, DRIVE_USER_RATE_LIMIT_BODY);
		GoogleMetadataConfigService.configRecordOverride = buildUpgradedConfig();
		GoogleFileVersion__c version = createSummaryCandidate('SUMRTY7');

		GenAiClientStub clientStub = new GenAiClientStub(GENERATED_SUMMARY, 'STOP');
		GoogleFileAnalysisResultDTO result;
		Test.startTest();
			result = new GoogleFileSummarizeCommand().summarize(version.Id, 'Agent Platform', 'gemini-3.8-flash', clientStub);
		Test.stopTest();

		Assert.areNotEqual(true, result.success);
		Assert.isTrue(result.retryable, 'Drive refusing a read for its rate limit is a passing reason');
		Assert.isNull(clientStub.capturedRequest);
	}

	@IsTest
	private static void testSummarizeNegativeRefusedExportIsNotRetryable() {
		installExportAnswer('DOCS_SUMRTY8', 400, DRIVE_CONVERSION_REFUSED_BODY);
		GoogleMetadataConfigService.configRecordOverride = buildUpgradedConfig();
		GoogleFileVersion__c version = createSummaryCandidate('SUMRTY8');

		GoogleFileAnalysisResultDTO result;
		Test.startTest();
			result = new GoogleFileSummarizeCommand().summarize(version.Id, 'Agent Platform', 'gemini-3.8-flash', new GenAiClientStub(GENERATED_SUMMARY, 'STOP'));
		Test.stopTest();

		Assert.areNotEqual(true, result.success);
		Assert.areNotEqual(true, result.retryable, 'An export Google refuses, as for a CSV copy, is refused on every attempt');
	}

	@IsTest
	private static void testSummarizeNegativeSafetyBlockIsNotRetryable() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildUpgradedConfig();
		GoogleFileVersion__c version = createSummaryCandidate('SUMRTY9');
		GoogleAiPromptSafetyGuardFactory.resetForTest();

		GoogleFileAnalysisResultDTO result;
		Test.startTest();
			result = new GoogleFileSummarizeCommand().summarize(version.Id, 'Agent Platform', 'gemini-3.8-flash', new GenAiClientStub('Some benign summary text.', 'SAFETY'));
		Test.stopTest();

		Assert.isTrue(result.blocked);
		Assert.areNotEqual(true, result.retryable, 'A safety block is final');
	}

	@IsTest
	private static void testSummarizeNegativeIneligibleVersionIsNotRetryable() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildUpgradedConfig();
		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('SUMRTY10')
			.insertRecord();
		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('SUMRTY10.docx')
			.withType(DOCX_MIME_TYPE)
			.withSize(2048)
			.withDocsId('DOCS_SUMRTY10')
			.withSummary(GENERATED_SUMMARY)
			.insertRecord();

		GenAiClientStub clientStub = new GenAiClientStub('A different summary.', 'STOP');
		GoogleFileAnalysisResultDTO result;
		Test.startTest();
			result = new GoogleFileSummarizeCommand().summarize(version.Id, 'Agent Platform', 'gemini-3.8-flash', clientStub);
		Test.stopTest();

		Assert.isTrue(result.blocked);
		Assert.areNotEqual(true, result.retryable, 'A version that already has its summary is never tried again');
		Assert.isNull(clientStub.capturedRequest);
	}

	@IsTest
	private static void testIsRetriedAfterFailurePositiveSummariesAreRetried() {
		Assert.isTrue(new GoogleFileSummarizeCommand().isRetriedAfterFailure(), 'A summary job retries a passing failure, so it is logged as a warning');
	}
}