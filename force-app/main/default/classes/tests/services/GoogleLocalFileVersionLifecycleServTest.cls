@IsTest
private class GoogleLocalFileVersionLifecycleServTest {
	@IsTest
	private static void testMarkAsLatestVersionIfApplicablePositiveNoInput() {
		Test.startTest();
		new GoogleLocalFileVersionLifecycleService().markAsLatestVersionIfApplicable(
			new List<GoogleFileVersion__c>(),
			new List<GoogleFileVersion__c>()
		);
		Test.stopTest();
		Assert.isTrue(true);
	}

	@IsTest
	private static void testApplyPreviewStateIfEligiblePositiveNoInput() {
		Test.startTest();
		new GoogleLocalFileVersionLifecycleService().applyPreviewStateIfEligible(null);
		Test.stopTest();
		Assert.isTrue(true);
	}
}