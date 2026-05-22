@IsTest
private class GoogleCloudFileIntelligenceCtrlTest {
	@IsTest
	static void testRetrieveFileIntelligenceStatePositive() {
		GoogleCloudTestFactory.initMocks();

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
}