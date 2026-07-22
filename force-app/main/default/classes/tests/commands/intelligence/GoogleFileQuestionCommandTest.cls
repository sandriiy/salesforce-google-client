@IsTest
private class GoogleFileQuestionCommandTest {
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
}