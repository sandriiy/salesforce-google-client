@IsTest
private class GoogleFileSharingCommandTest {
	private static IGoogleUnitOfWork buildUow() {
		return new GoogleCloudUnitOfWork(new List<SObjectType>{
			GoogleFile__c.SObjectType,
			GoogleFileVersion__c.SObjectType,
			GoogleFileLink__c.SObjectType
		});
	}

	@IsTest
	private static void testApplyWithResultCreatesRecordLink() {
		GoogleCloudTestFactory.initMocks();

		Account relatedAccount = new Account(Name = 'Sharing Result Account');
		insert relatedAccount;

		GoogleFile__c localFile = GoogleCloudTestFactory.file()
			.withName('Sharing Result File')
			.insertRecord();

		Test.startTest();
		GoogleFileSharingApplyResultDTO result = new GoogleFileSharingCommand(buildUow())
			.createSharing()
			.forFile(localFile.Id)
			.shareTo('Account', relatedAccount.Id)
			.withSource('Notes & Attachments')
			.applyWithResult();
		Test.stopTest();

		Assert.isTrue(result.wasCreated);
		Assert.isNotNull(result.recordId);
	}

	@IsTest
	private static void testApplyWithResultReusesExistingRecordLink() {
		GoogleCloudTestFactory.initMocks();

		Account relatedAccount = new Account(Name = 'Existing Sharing Result Account');
		insert relatedAccount;

		GoogleFile__c localFile = GoogleCloudTestFactory.file()
			.withName('Existing Sharing Result File')
			.insertRecord();

		GoogleFileLink__c existingLink = GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withLinkedRecord(relatedAccount.Id)
			.withLinkedType('Account')
			.insertRecord();

		Test.startTest();
		GoogleFileSharingApplyResultDTO result = new GoogleFileSharingCommand(buildUow())
			.createSharing()
			.forFile(localFile.Id)
			.shareTo('Account', relatedAccount.Id)
			.withSource('Notes & Attachments')
			.applyWithResult();
		Test.stopTest();

		Assert.isFalse(result.wasCreated);
		Assert.areEqual(existingLink.Id, result.recordId);
	}

	@IsTest
	private static void testApplyKeepsReturningCreatedId() {
		GoogleCloudTestFactory.initMocks();

		Account relatedAccount = new Account(Name = 'Apply Compatibility Account');
		insert relatedAccount;

		GoogleFile__c localFile = GoogleCloudTestFactory.file()
			.withName('Apply Compatibility File')
			.insertRecord();

		Test.startTest();
		Id linkId = new GoogleFileSharingCommand(buildUow())
			.createSharing()
			.forFile(localFile.Id)
			.shareTo('Account', relatedAccount.Id)
			.withSource('Notes & Attachments')
			.apply();
		Test.stopTest();

		Assert.isNotNull(linkId);
	}
}