@IsTest
private class GoogleLocalFileVersionPublicLinkServTest {
	public class TestGoogleAuthorizer implements GoogleAuthorizer {
		public String retrieveAccessToken() {
			return 'client.test-access-token';
		}
	}

	private static void initMocks() {
		Test.setMock(HttpCalloutMock.class, new GoogleDriveHttpMock().withDefaultHappyPath());
		GoogleClientApiProvider.authorizerClassNameOverride = 'GoogleLocalFileVersionPublicLinkServTest.TestGoogleAuthorizer';
	}

	@IsTest
	private static void testApplyPublicLinkSharingPositive() {
		initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('PL1')
			.withDescription('D')
			.insertRecord();

		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('V1.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId('GD_PL_1')
			.withDocsId('DOCS_PL_1')
			.insertRecord();

		Datetime expirationDate = System.now().addDays(1);

		Test.startTest();
		List<GoogleFileVersion__c> updatedVersions = new GoogleLocalFileVersionPublicLinkService()
			.applyPublicLinkSharing(localFileVersion.Id, expirationDate, false);
		Test.stopTest();

		Assert.areEqual(1, updatedVersions.size());
		Assert.isTrue(String.isNotBlank(updatedVersions[0].PublicLink__c));
		Assert.areEqual(expirationDate, updatedVersions[0].PublicLinkExpirationDate__c);
		Assert.isTrue(String.isNotBlank(updatedVersions[0].PublicLinkPermissionId__c));
		Assert.areEqual('Active', updatedVersions[0].PublicLinkStatus__c);
	}

	@IsTest
	private static void testApplyPublicLinkSharingPositiveSkipDomain() {
		initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('PL2')
			.withDescription('D')
			.insertRecord();

		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('V2.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId('GD_PL_2')
			.withDocsId('DOCS_PL_2')
			.insertRecord();

		Test.startTest();
		List<GoogleFileVersion__c> updatedVersions = new GoogleLocalFileVersionPublicLinkService()
			.applyPublicLinkSharing(localFileVersion.Id, null, true);
		Test.stopTest();

		Assert.areEqual(1, updatedVersions.size());
		Assert.areEqual('Active', updatedVersions[0].PublicLinkStatus__c);
	}

	@IsTest
	private static void testRemovePublicLinkSharingPositive() {
		initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('PL3')
			.withDescription('D')
			.insertRecord();

		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('V3.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId('GD_PL_3')
			.withDocsId('DOCS_PL_3')
			.insertRecord();

		Datetime expirationDate = System.now().addDays(1);

		localFileVersion.PublicLink__c = 'https://example.com/view';
		localFileVersion.PublicLinkExpirationDate__c = expirationDate;
		localFileVersion.PublicLinkPermissionId__c = 'PERM_123';
		localFileVersion.PublicLinkStatus__c = 'Active';
		update localFileVersion;

		Test.startTest();
		List<GoogleFileVersion__c> updatedVersions =
			new GoogleLocalFileVersionPublicLinkService().removePublicLinkSharing(localFileVersion.Id);
		Test.stopTest();

		Assert.areEqual(1, updatedVersions.size());
		Assert.areEqual(null, updatedVersions[0].PublicLink__c);
		Assert.areEqual(null, updatedVersions[0].PublicLinkExpirationDate__c);
		Assert.areEqual(null, updatedVersions[0].PublicLinkPermissionId__c);
		Assert.areEqual('None', updatedVersions[0].PublicLinkStatus__c);
	}
}