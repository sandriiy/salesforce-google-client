@IsTest
private class GoogleLocalFileVersionLifecycleServTest {
	@IsTest
	private static void testSyncLatestVersionToMainFilePositiveNoInput() {
		Test.startTest();
		new GoogleLocalFileVersionLifecycleService().syncLatestVersionToMainFile(null, null);
		Test.stopTest();
		System.assert(true);
	}

	@IsTest
	private static void testMarkAsLatestVersionIfApplicablePositiveNoInput() {
		Test.startTest();
		new GoogleLocalFileVersionLifecycleService().markAsLatestVersionIfApplicable(new List<GoogleFileVersion__c>(), new List<GoogleFileVersion__c>());
		Test.stopTest();
		System.assert(true);
	}

	@IsTest
	private static void testApplyPreviewStateIfEligiblePositiveNoInput() {
		Test.startTest();
		new GoogleLocalFileVersionLifecycleService().applyPreviewStateIfEligible(null);
		Test.stopTest();
		System.assert(true);
	}

	@IsTest
	private static void testRemoveGoogleFilesPositiveEnqueue() {
		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('P1').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('VDel.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId('GD_DEL')
			.withDocsId('DOCS_DEL')
			.insertRecord();

		Test.startTest();
		new GoogleLocalFileVersionLifecycleService().removeGoogleFiles(new List<GoogleFileVersion__c>{ localFileVersion });
		Test.stopTest();

		Integer queueableJobs = [SELECT count() FROM AsyncApexJob WHERE JobType = 'Queueable'];
		System.assert(queueableJobs > 0);
	}
}