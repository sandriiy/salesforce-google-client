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
		Assert.areEqual(512, clientStub.capturedRequest.generation.maxTokens);
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
}