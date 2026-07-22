@IsTest
private class GoogleLocalFileIntelligenceServiceTest {
	private static GoogleClientConfig__mdt buildGeminiConfig() {
		return new GoogleClientConfig__mdt(
			IsFileIntelligenceEnabled__c = true,
			CustomGeminiApiKey__c = 'api-key-1',
			CustomModelName__c = 'gemini-2.0-flash'
		);
	}

	@IsTest
	private static void testRetrieveIntelligenceStatesPositiveEligibleWithSummary() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildGeminiConfig();

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
		GoogleMetadataConfigService.configRecordOverride = buildGeminiConfig();

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

	@IsTest
	private static void testRetrieveIntelligenceStatesNegativeNoConfiguration() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('INT3').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('INT3.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(1024)
			.withDriveId('GD_INT_3')
			.withDocsId('DOCS_INT_3')
			.insertRecord();

		List<GoogleFileIntelligenceStateDTO> states;
		Test.startTest();
			states = new GoogleLocalFileIntelligenceService().retrieveIntelligenceStates(new List<Id>{ localFileVersion.Id });
		Test.stopTest();

		Assert.areEqual(1, states.size());
		Assert.isFalse(states[0].isIntelligenceEligible);
	}

	@IsTest
	private static void testRetrieveIntelligenceStatesHidesHistoricalSummaryContainingSecret() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildGeminiConfig();
		GoogleAiPromptSafetyGuardFactory.resetForTest();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('INT4').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('INT4.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(1024)
			.withDriveId('GD_INT_4')
			.withDocsId('DOCS_INT_4')
			.build();
		localFileVersion.Summary__c = 'Historical summary leaking AIzaSyABCDEFGHIJKLMNOPQRSTUVWXYZ0123456ab key.';
		insert localFileVersion;

		List<GoogleFileIntelligenceStateDTO> states;
		Test.startTest();
			states = new GoogleLocalFileIntelligenceService().retrieveIntelligenceStates(new List<Id>{ localFileVersion.Id });
		Test.stopTest();

		Assert.areEqual(1, states.size());
		Assert.isNull(states[0].summary);
		Assert.isFalse(states[0].hasSummary);
	}

	@IsTest
	private static void testRetrieveIntelligenceStatesKeepsBenignHistoricalSummary() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildGeminiConfig();
		GoogleAiPromptSafetyGuardFactory.resetForTest();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('INT5').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('INT5.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(1024)
			.withDriveId('GD_INT_5')
			.withDocsId('DOCS_INT_5')
			.build();
		localFileVersion.Summary__c = 'This file describes a signed project agreement.';
		insert localFileVersion;

		List<GoogleFileIntelligenceStateDTO> states;
		Test.startTest();
			states = new GoogleLocalFileIntelligenceService().retrieveIntelligenceStates(new List<Id>{ localFileVersion.Id });
		Test.stopTest();

		Assert.areEqual(1, states.size());
		Assert.areEqual('This file describes a signed project agreement.', states[0].summary);
		Assert.isTrue(states[0].hasSummary);
	}
}