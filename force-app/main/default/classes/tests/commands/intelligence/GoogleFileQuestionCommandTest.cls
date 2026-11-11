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
private class GoogleFileQuestionCommandTest {
	private static final String DOCX_MIME_TYPE = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
	private static final String QUESTION = 'What does this file cover?';
	private static final String GEMINI_UNAVAILABLE_BODY = '{"error":{"code":503,"message":"The model is overloaded. Please try again later.","status":"UNAVAILABLE"}}';
	private static final String VERTEX_PERMISSION_DENIED_BODY = '{"error":{"code":403,"message":"Permission \'aiplatform.endpoints.predict\' denied on resource \'//aiplatform.googleapis.com/projects/project-1/locations/global/publishers/google/models/gemini-3.8-flash\' (or it may not exist).","status":"PERMISSION_DENIED"}}';
	private static final String DRIVE_NOT_FOUND_BODY = '{"error":{"code":404,"message":"File not found: DOCS_QLIM8.","errors":[{"message":"File not found: DOCS_QLIM8.","domain":"global","reason":"notFound","location":"fileId","locationType":"parameter"}]}}';

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

	private class RecordingSafetyGuard implements IGoogleAiPromptSafetyGuard {
		private GoogleAiPromptContext capturedRequestContext;
		private GoogleAiPromptContext capturedResponseContext;
		private GoogleAiResponseSnapshot capturedResponseSnapshot;
		private String capturedWrappedPrompt;
		private final GoogleAiPromptSafetyDecision requestDecision;
		private final GoogleAiResponseSafetyDecision responseDecision;

		private RecordingSafetyGuard(GoogleAiPromptSafetyDecision requestDecision, GoogleAiResponseSafetyDecision responseDecision) {
			this.requestDecision = requestDecision;
			this.responseDecision = responseDecision;
		}

		public String wrapSystemPrompt(GoogleAiPromptContext context) {
			this.capturedWrappedPrompt = '[wrapped] ' + (context == null || context.rawSystemPrompt == null ? '' : context.rawSystemPrompt);
			return this.capturedWrappedPrompt;
		}

		public GoogleAiPromptSafetyDecision inspectRequest(GoogleAiPromptContext context) {
			this.capturedRequestContext = context;
			return this.requestDecision;
		}

		public GoogleAiResponseSafetyDecision inspectResponse(GoogleAiPromptContext context, GoogleAiResponseSnapshot response) {
			this.capturedResponseContext = context;
			this.capturedResponseSnapshot = response;
			return this.responseDecision;
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

	private static GoogleFileVersion__c createQuestionCandidate(String fileName) {
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

	private static void applyQuestionLimit(Integer questionMaxOutputTokens) {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(
			IsFilePreviewDisabled__c = true,
			IsFileIntelligenceEnabled__c = true,
			QuestionMaxOutputTokens__c = questionMaxOutputTokens
		);
	}

	private static String buildQuestion(Integer length) {
		String value = '';
		for (Integer index = 0; index < length; index++) {
			value += 'Q';
		}
		return value;
	}

	@IsTest
	private static void testAnswerQuestionNegativeUnavailableConfiguration() {
		GoogleFileAnalysisResultDTO result = new GoogleFileQuestionCommand().answerQuestion(
			GoogleCloudTestFactory.fakeId(GoogleFileVersion__c.SObjectType),
			'What is this file about?',
			'Gemini',
			null,
			null
		);

		Assert.isTrue(result.blocked);
		Assert.areEqual('Google AI question configuration is unavailable', result.errorMessage);
	}

	@IsTest
	private static void testAnswerQuestionNegativeTooLong() {
		GoogleFileAnalysisResultDTO result = new GoogleFileQuestionCommand().answerQuestion(
			GoogleCloudTestFactory.fakeId(GoogleFileVersion__c.SObjectType),
			buildQuestion(256),
			'Gemini',
			'gemini-2.0-flash',
			new GenAiClientStub('OK', 'STOP')
		);

		Assert.areEqual('Questions must be 255 characters or fewer', result.errorMessage);
	}

	@IsTest
	private static void testAnswerQuestionNegativeIneligibleWithoutGoogleDocsId() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('QCMD1')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('QCMD1.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(2048)
			.withDocsId(null)
			.insertRecord();

		GoogleFileAnalysisResultDTO result;
		Test.startTest();
			result = new GoogleFileQuestionCommand().answerQuestion(
				version.Id,
				'What does this file cover?',
				'Gemini',
				'gemini-2.0-flash',
				new GenAiClientStub('OK', 'STOP')
			);
		Test.stopTest();

		Assert.isTrue(result.blocked);
		Assert.areEqual('This file is not available for AI questions', result.errorMessage);
	}

	@IsTest
	private static void testAnswerQuestionPositiveLargeUploadWithFittingWorkspaceCopy() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('QCMD9')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('QCMD9.pdf')
			.withType('application/pdf')
			.withSize(GoogleCloudConstants.MAX_SUMMARY_FILE_SIZE_BYTES + 1)
			.withDocsId('DOCS_QCMD_9')
			.withDocsSize(112000)
			.insertRecord();

		GoogleFileAnalysisResultDTO result;
		Test.startTest();
			result = new GoogleFileQuestionCommand().answerQuestion(
				version.Id,
				'What does this file cover?',
				'Gemini',
				'gemini-2.0-flash',
				new GenAiClientStub('The brochure covers the spring catalogue.', 'STOP')
			);
		Test.stopTest();

		Assert.isTrue(result.success);
		Assert.areEqual('The brochure covers the spring catalogue.', result.text);
	}

	@IsTest
	private static void testAnswerQuestionNegativeSmallUploadWithOversizedWorkspaceCopy() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('QCMD10')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('QCMD10.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(2048)
			.withDocsId('DOCS_QCMD_10')
			.withDocsSize(GoogleCloudConstants.MAX_SUMMARY_FILE_SIZE_BYTES + 1)
			.insertRecord();

		GenAiClientStub clientStub = new GenAiClientStub('OK', 'STOP');
		GoogleFileAnalysisResultDTO result;
		Test.startTest();
			result = new GoogleFileQuestionCommand().answerQuestion(
				version.Id,
				'What does this file cover?',
				'Gemini',
				'gemini-2.0-flash',
				clientStub
			);
		Test.stopTest();

		Assert.isTrue(result.blocked);
		Assert.areEqual('This file is not available for AI questions', result.errorMessage);
		Assert.isNull(clientStub.capturedRequest);
	}

	@IsTest
	private static void testAnswerQuestionPositive() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('QCMD2')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('QCMD2.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(2048)
			.withDocsId('DOCS_QCMD_2')
			.insertRecord();

		GenAiClientStub clientStub = new GenAiClientStub('The file covers revenue planning and staffing updates.', 'STOP');
		GoogleFileAnalysisResultDTO result;
		Test.startTest();
			result = new GoogleFileQuestionCommand().answerQuestion(
				version.Id,
				'What does this file cover?',
				'Gemini',
				'gemini-2.0-flash',
				clientStub
			);
		Test.stopTest();

		Assert.isTrue(result.success);
		Assert.areEqual('QUESTION', result.operationType);
		Assert.areEqual('Gemini', result.provider);
		Assert.areEqual('The file covers revenue planning and staffing updates.', result.text);
	}

	@IsTest
	private static void testAnswerQuestionPositiveAddsEllipsisForPartialResponse() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('QCMD3')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('QCMD3.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(2048)
			.withDocsId('DOCS_QCMD_3')
			.insertRecord();

		GoogleFileAnalysisResultDTO result;
		Test.startTest();
			result = new GoogleFileQuestionCommand().answerQuestion(
				version.Id,
				'What does this file cover?',
				'Gemini',
				'gemini-2.0-flash',
				new GenAiClientStub('The file covers revenue planning and staffing updates', 'MAX_TOKENS')
			);
		Test.stopTest();

		Assert.isTrue(result.success);
		Assert.areEqual('The file covers revenue planning and staffing updates...', result.text);
		Assert.areEqual('MAX_TOKENS', result.finishReason);
	}

	@IsTest
	private static void testAnswerQuestionGuardBlocksRequestNoCalloutMade() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('QCMD4')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('QCMD4.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(2048)
			.withDocsId('DOCS_QCMD_4')
			.insertRecord();

		RecordingSafetyGuard stubGuard = new RecordingSafetyGuard(
			GoogleAiPromptSafetyDecision.block(GoogleAiPromptSafetyDecision.REASON_INJECTION, 'Blocked by stub guard'),
			GoogleAiResponseSafetyDecision.allow()
		);
		GoogleAiPromptSafetyGuardFactory.resetForTest();
		GoogleAiPromptSafetyGuardFactory.cachedGuard = stubGuard;

		GenAiClientStub clientStub = new GenAiClientStub('Should not be called', 'STOP');
		Integer calloutsBefore;
		Integer calloutsAfter;
		GoogleFileAnalysisResultDTO result;

		Test.startTest();
			calloutsBefore = Limits.getCallouts();
			result = new GoogleFileQuestionCommand().answerQuestion(
				version.Id,
				'What does this file cover?',
				'Gemini',
				'gemini-2.0-flash',
				clientStub
			);
			calloutsAfter = Limits.getCallouts();
		Test.stopTest();

		Assert.isTrue(result.blocked);
		Assert.areEqual('Blocked by stub guard', result.errorMessage);
		Assert.areEqual(calloutsBefore, calloutsAfter);
		Assert.isNull(clientStub.capturedRequest);
	}

	@IsTest
	private static void testAnswerQuestionGuardBlocksResponseAfterCallout() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('QCMD5')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('QCMD5.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(2048)
			.withDocsId('DOCS_QCMD_5')
			.insertRecord();

		RecordingSafetyGuard stubGuard = new RecordingSafetyGuard(
			GoogleAiPromptSafetyDecision.allow(),
			GoogleAiResponseSafetyDecision.block(GoogleAiResponseSafetyDecision.REASON_SECRET_LEAK, 'Response blocked by stub')
		);
		GoogleAiPromptSafetyGuardFactory.resetForTest();
		GoogleAiPromptSafetyGuardFactory.cachedGuard = stubGuard;

		GoogleFileAnalysisResultDTO result;
		Test.startTest();
			result = new GoogleFileQuestionCommand().answerQuestion(
				version.Id,
				'What does this file cover?',
				'Gemini',
				'gemini-2.0-flash',
				new GenAiClientStub('The file contains AIzaSyABCDEFGHIJKLMNOPQRSTUVWXYZ0123456ab', 'STOP')
			);
		Test.stopTest();

		Assert.isTrue(result.blocked);
		Assert.areNotEqual(true, result.success);
		Assert.isNull(result.text);
		Assert.areEqual('Response blocked by stub', result.errorMessage);
	}

	@IsTest
	private static void testAnswerQuestionGuardSanitizedTextReplacesResponse() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('QCMD6')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('QCMD6.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(2048)
			.withDocsId('DOCS_QCMD_6')
			.insertRecord();

		GoogleAiResponseSafetyDecision sanitizedDecision = GoogleAiResponseSafetyDecision.allow();
		sanitizedDecision.sanitizedText = 'Sanitized answer from stub';
		RecordingSafetyGuard stubGuard = new RecordingSafetyGuard(
			GoogleAiPromptSafetyDecision.allow(),
			sanitizedDecision
		);
		GoogleAiPromptSafetyGuardFactory.resetForTest();
		GoogleAiPromptSafetyGuardFactory.cachedGuard = stubGuard;

		GoogleFileAnalysisResultDTO result;
		Test.startTest();
			result = new GoogleFileQuestionCommand().answerQuestion(
				version.Id,
				'What does this file cover?',
				'Gemini',
				'gemini-2.0-flash',
				new GenAiClientStub('Original AI text', 'STOP')
			);
		Test.stopTest();

		Assert.isTrue(result.success);
		Assert.areEqual('Sanitized answer from stub', result.text);
	}

	@IsTest
	private static void testAnswerQuestionWrappedSystemPromptReachesGenAiClient() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('QCMD7')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('QCMD7.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(2048)
			.withDocsId('DOCS_QCMD_7')
			.insertRecord();

		RecordingSafetyGuard stubGuard = new RecordingSafetyGuard(
			GoogleAiPromptSafetyDecision.allow(),
			GoogleAiResponseSafetyDecision.allow()
		);
		GoogleAiPromptSafetyGuardFactory.resetForTest();
		GoogleAiPromptSafetyGuardFactory.cachedGuard = stubGuard;

		GenAiClientStub clientStub = new GenAiClientStub('Benign answer', 'STOP');
		Test.startTest();
			new GoogleFileQuestionCommand().answerQuestion(
				version.Id,
				'What does this file cover?',
				'Gemini',
				'gemini-2.0-flash',
				clientStub
			);
		Test.stopTest();

		Assert.isNotNull(stubGuard.capturedWrappedPrompt);
		Assert.isTrue(stubGuard.capturedWrappedPrompt.startsWith('[wrapped]'));
		Assert.isNotNull(clientStub.capturedRequest);
	}

	@IsTest
	private static void testAnswerQuestionPositiveZeroLimitSendsNoCap() {
		GoogleCloudTestFactory.initMocks();
		applyQuestionLimit(0);
		GoogleFileVersion__c version = createQuestionCandidate('QLIM1');

		GenAiClientStub clientStub = new GenAiClientStub('The file covers the spring catalogue.', 'STOP');
		GoogleFileAnalysisResultDTO result;
		Test.startTest();
			result = new GoogleFileQuestionCommand().answerQuestion(version.Id, QUESTION, 'Agent Platform', 'gemini-3.8-flash', clientStub);
		Test.stopTest();

		Assert.isTrue(result.success, 'A saved 0 used to send a cap of 0 and get no answer; it now means No limit');
		Assert.isNull(clientStub.capturedRequest.generation.maxTokens);
		Assert.isFalse(new GenAiGoogleRequestSerializer().serialize(clientStub.capturedRequest).contains('maxOutputTokens'));
	}

	@IsTest
	private static void testAnswerQuestionPositiveDefaultLimitUnchanged() {
		GoogleCloudTestFactory.initMocks();
		applyQuestionLimit(null);
		GoogleFileVersion__c version = createQuestionCandidate('QLIM2');

		GenAiClientStub clientStub = new GenAiClientStub('The file covers the spring catalogue.', 'STOP');
		Test.startTest();
			new GoogleFileQuestionCommand().answerQuestion(version.Id, QUESTION, 'Agent Platform', 'gemini-3.8-flash', clientStub);
		Test.stopTest();

		Assert.areEqual(GoogleMetadataConfigService.DEFAULT_QUESTION_MAX_OUTPUT_TOKENS, clientStub.capturedRequest.generation.maxTokens);
	}

	@IsTest
	private static void testAnswerQuestionPositiveNegativeLimitMeansTheDefault() {
		GoogleCloudTestFactory.initMocks();
		applyQuestionLimit(-5);
		GoogleFileVersion__c version = createQuestionCandidate('QLIM3');

		GenAiClientStub clientStub = new GenAiClientStub('The file covers the spring catalogue.', 'STOP');
		Test.startTest();
			new GoogleFileQuestionCommand().answerQuestion(version.Id, QUESTION, 'Agent Platform', 'gemini-3.8-flash', clientStub);
		Test.stopTest();

		Assert.areEqual(GoogleMetadataConfigService.DEFAULT_QUESTION_MAX_OUTPUT_TOKENS, clientStub.capturedRequest.generation.maxTokens, 'Only 0 means No limit; a negative value must not turn into one');
	}

	@IsTest
	private static void testAnswerQuestionNegativeTimeoutSaysTheServiceTookTooLong() {
		GoogleCloudTestFactory.initMocks();
		applyQuestionLimit(1024);
		GoogleFileVersion__c version = createQuestionCandidate('QLIM4');

		GoogleFileAnalysisResultDTO result;
		Test.startTest();
			result = new GoogleFileQuestionCommand().answerQuestion(version.Id, QUESTION, 'Agent Platform', 'gemini-3.8-flash', new FailingGenAiClient(new CalloutException('Read timed out')));
		Test.stopTest();

		Assert.areNotEqual(true, result.success);
		Assert.areEqual(GoogleFileIntelligenceCommandBase.AI_SERVICE_TIMEOUT_MESSAGE, result.errorMessage);
		Assert.areEqual('The AI service took too long to answer. Please try again.', GoogleFileIntelligenceCommandBase.AI_SERVICE_TIMEOUT_MESSAGE);
	}

	@IsTest
	private static void testAnswerQuestionNegativeCalloutTimeExhaustedSaysTheServiceTookTooLong() {
		GoogleCloudTestFactory.initMocks();
		applyQuestionLimit(1024);
		GoogleFileVersion__c version = createQuestionCandidate('QLIM5');

		GoogleFileAnalysisResultDTO result;
		Test.startTest();
			result = new GoogleFileQuestionCommand().answerQuestion(version.Id, QUESTION, 'Agent Platform', 'gemini-3.8-flash', new FailingGenAiClient(new CalloutException('Exceeded maximum time allotted for callout (120000 ms)')));
		Test.stopTest();

		Assert.areEqual(GoogleFileIntelligenceCommandBase.AI_SERVICE_TIMEOUT_MESSAGE, result.errorMessage, 'A question that used up the two minutes reads as slow, never as the platform message');
	}

	@IsTest
	private static void testAnswerQuestionNegativeBusySaysTheServiceIsBusy() {
		GoogleCloudTestFactory.initMocks();
		applyQuestionLimit(1024);
		GoogleFileVersion__c version = createQuestionCandidate('QLIM6');

		GoogleFileAnalysisResultDTO result;
		Test.startTest();
			result = new GoogleFileQuestionCommand().answerQuestion(version.Id, QUESTION, 'Gemini', 'gemini-2.0-flash', new FailingGenAiClient(new GenAiProviderException(GEMINI_UNAVAILABLE_BODY)));
		Test.stopTest();

		Assert.areNotEqual(true, result.success);
		Assert.areEqual(GoogleFileIntelligenceCommandBase.AI_SERVICE_BUSY_MESSAGE, result.errorMessage);
		Assert.areEqual('The AI service is busy right now. Please try again in a moment.', GoogleFileIntelligenceCommandBase.AI_SERVICE_BUSY_MESSAGE);
	}

	@IsTest
	private static void testAnswerQuestionNegativeOtherFailureShowsNoProviderBody() {
		GoogleCloudTestFactory.initMocks();
		applyQuestionLimit(1024);
		GoogleFileVersion__c version = createQuestionCandidate('QLIM7');

		GoogleFileAnalysisResultDTO result;
		Test.startTest();
			result = new GoogleFileQuestionCommand().answerQuestion(version.Id, QUESTION, 'Agent Platform', 'gemini-3.8-flash', new FailingGenAiClient(new GenAiProviderException(VERTEX_PERMISSION_DENIED_BODY)));
		Test.stopTest();

		Assert.areNotEqual(true, result.success);
		Assert.areEqual(GoogleFileIntelligenceCommandBase.AI_SERVICE_FAILURE_MESSAGE, result.errorMessage, 'A user asking a question never sees Google\'s raw error');
		Assert.areEqual('The AI service could not answer this question. Please try again or contact your administrator.', GoogleFileIntelligenceCommandBase.AI_SERVICE_FAILURE_MESSAGE);
	}

	@IsTest
	private static void testAnswerQuestionNegativeDriveFailureShowsNoDriveBody() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher().withMethod('GET').endpointContains('DOCS_QLIM8')
		).thenReturnStatus(404, DRIVE_NOT_FOUND_BODY);
		GoogleCloudTestFactory.initMocks(driveMock);
		applyQuestionLimit(1024);
		GoogleFileVersion__c version = createQuestionCandidate('QLIM8');

		GenAiClientStub clientStub = new GenAiClientStub('Never sent.', 'STOP');
		GoogleFileAnalysisResultDTO result;
		Test.startTest();
			result = new GoogleFileQuestionCommand().answerQuestion(version.Id, QUESTION, 'Agent Platform', 'gemini-3.8-flash', clientStub);
		Test.stopTest();

		Assert.areNotEqual(true, result.success);
		Assert.areEqual(GoogleFileIntelligenceCommandBase.AI_SERVICE_FAILURE_MESSAGE, result.errorMessage);
		Assert.isNull(clientStub.capturedRequest);
	}

	@IsTest
	private static void testIsRetriedAfterFailureNegativeQuestionsAreNeverRetried() {
		Assert.isFalse(new GoogleFileQuestionCommand().isRetriedAfterFailure(), 'Nothing asks a question again, so its failures are logged as errors');
	}

	@IsTest
	private static void testAnswerQuestionNegativeTimeoutStaysRetryableThoughNeverRetried() {
		GoogleCloudTestFactory.initMocks();
		applyQuestionLimit(1024);
		GoogleFileVersion__c version = createQuestionCandidate('QLIM9');

		GoogleFileQuestionCommand questionCommand = new GoogleFileQuestionCommand();
		GoogleFileAnalysisResultDTO result;
		Test.startTest();
			result = questionCommand.answerQuestion(version.Id, QUESTION, 'Agent Platform', 'gemini-3.8-flash', new FailingGenAiClient(new CalloutException('Read timed out')));
		Test.stopTest();

		Assert.isTrue(result.retryable, 'The result still says the failure was a passing one');
		Assert.isFalse(questionCommand.isRetriedAfterFailure());
		Assert.areEqual(GoogleFileIntelligenceCommandBase.AI_SERVICE_TIMEOUT_MESSAGE, result.errorMessage);
	}
}