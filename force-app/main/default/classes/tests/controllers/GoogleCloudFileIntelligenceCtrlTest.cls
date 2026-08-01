@IsTest
private class GoogleCloudFileIntelligenceCtrlTest {
	private static GoogleClientConfig__mdt buildGeminiConfig() {
		return new GoogleClientConfig__mdt(
			IsFileIntelligenceEnabled__c = true,
			CustomGeminiApiKey__c = 'api-key-1',
			CustomModelName__c = 'gemini-2.0-flash'
		);
	}

	@IsTest
	private static void testRetrieveFileIntelligenceStatePositive() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildGeminiConfig();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('RINT1')
			.withDescription('D')
			.insertRecord();

		GoogleFileVersion__c fileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('RINT1.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(1024)
			.withDriveId('GD_RINT_1')
			.withDocsId('DOCS_RINT_1')
			.insertRecord();

		GoogleFileIntelligenceStateDTO intelligenceState;

		Test.startTest();
		intelligenceState = GoogleCloudFileIntelligenceController.retrieveFileIntelligenceState(fileVersion.Id);
		Test.stopTest();

		Assert.areNotEqual(null, intelligenceState);
		Assert.areEqual(fileVersion.Id, intelligenceState.versionId);
		Assert.areEqual(false, intelligenceState.hasSummary);
		Assert.areEqual(true, intelligenceState.isIntelligenceEligible);
	}

	@IsTest
	private static void testAnswerFileQuestionPositive() {
		GoogleCloudTestFactory.initMocks(new GoogleCompositeHttpMock());
		GoogleMetadataConfigService.configRecordOverride = buildGeminiConfig();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('RINT2')
			.withDescription('D')
			.insertRecord();

		GoogleFileVersion__c fileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('RINT2.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(1024)
			.withDriveId('GD_RINT_2')
			.withDocsId('DOCS_RINT_2')
			.insertRecord();

		GoogleFileAnalysisResultDTO result;

		Test.startTest();
			result = GoogleCloudFileIntelligenceController.answerFileQuestion(fileVersion.Id, 'What does this file cover?');
		Test.stopTest();

		Assert.areNotEqual(null, result);
		Assert.areEqual(true, result.success);
		Assert.areEqual('QUESTION', result.operationType);
		Assert.areEqual('Gemini', result.provider);
		Assert.areEqual('OK', result.text);
	}
}