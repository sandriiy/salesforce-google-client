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

		System.assertNotEquals(null, intelligenceState);
		System.assertEquals(fileVersion.Id, intelligenceState.versionId);
		System.assertEquals(false, intelligenceState.hasSummary);
		System.assertEquals(true, intelligenceState.isIntelligenceEligible);
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

		System.assertNotEquals(null, result);
		System.assertEquals(true, result.success);
		System.assertEquals('QUESTION', result.operationType);
		System.assertEquals('Gemini', result.provider);
		System.assertEquals('OK', result.text);
	}
}