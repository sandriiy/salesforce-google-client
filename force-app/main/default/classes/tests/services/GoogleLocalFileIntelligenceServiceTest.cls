@IsTest
private class GoogleLocalFileIntelligenceServiceTest {
	@IsTest
	private static void testRetrieveIntelligenceStatesPositiveEligibleWithSummary() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('INT1').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('INT1.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(1024)
			.withDriveId('GD_INT_1')
			.withDocsId('DOCS_INT_1')
			.build();
		localFileVersion.Summary__c = 'This file describes a signed project agreement.';
		insert localFileVersion;

		List<GoogleFileIntelligenceStateDTO> states;
		Test.startTest();
			states = new GoogleLocalFileIntelligenceService().retrieveIntelligenceStates(new List<Id>{ localFileVersion.Id });
		Test.stopTest();

		Assert.areEqual(1, states.size());
		Assert.areEqual(localFileVersion.Id, states[0].versionId);
		Assert.areEqual('This file describes a signed project agreement.', states[0].summary);
		Assert.isTrue(states[0].hasSummary);
		Assert.isTrue(states[0].isIntelligenceEligible);
	}

	@IsTest
	private static void testRetrieveIntelligenceStatesNegativeTooLarge() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('INT2').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('INT2.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(GoogleCloudConstants.MAX_SUMMARY_FILE_SIZE_BYTES + 1)
			.withDriveId('GD_INT_2')
			.withDocsId('DOCS_INT_2')
			.insertRecord();

		List<GoogleFileIntelligenceStateDTO> states;
		Test.startTest();
			states = new GoogleLocalFileIntelligenceService().retrieveIntelligenceStates(new List<Id>{ localFileVersion.Id });
		Test.stopTest();

		Assert.areEqual(1, states.size());
		Assert.areEqual(localFileVersion.Id, states[0].versionId);
		Assert.areEqual(null, states[0].summary);
		Assert.isFalse(states[0].hasSummary);
		Assert.isFalse(states[0].isIntelligenceEligible);
	}
}