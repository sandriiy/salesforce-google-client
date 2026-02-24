@IsTest
private class GoogleLocalFileVersionPublicLinkServTest {
	public class TestGoogleAuthorizer implements GoogleAuthorizer {
		public String retrieveAccessToken() {
			return 'client.test-access-token';
		}
	}

	private static void initMocks() {
		Test.setMock(HttpCalloutMock.class, new GoogleDriveHttpMock().withDefaultHappyPath());
		GoogleDriveApiProvider.authorizerClassNameOverride = 'GoogleLocalFileVersionPublicLinkServTest.TestGoogleAuthorizer';
	}

	@IsTest
	private static void testApplyPublicLinkSharingPositive() {
		initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('PL1').withDescription('D').insertRecord();
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

		System.assertEquals(1, updatedVersions.size());
		System.assertNotEquals(null, updatedVersions[0].PublicLink__c);
		System.assertEquals(expirationDate, updatedVersions[0].PublicLinkExpirationDate__c);
		System.assertNotEquals(null, updatedVersions[0].PublicLinkPermissionId__c);
		System.assertEquals('Active', updatedVersions[0].PublicLinkStatus__c);
	}

	@IsTest
	private static void testApplyPublicLinkSharingPositiveSkipDomain() {
		initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('PL2').withDescription('D').insertRecord();
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

		System.assertEquals(1, updatedVersions.size());
		System.assertEquals('Active', updatedVersions[0].PublicLinkStatus__c);
	}

	@IsTest
	private static void testRemovePublicLinkSharingPositive() {
		initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('PL3').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('V3.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId('GD_PL_3')
			.withDocsId('DOCS_PL_3')
			.insertRecord();

		Datetime expirationDate = System.now().addDays(1);

		Test.startTest();
		new GoogleLocalFileVersionPublicLinkService().applyPublicLinkSharing(localFileVersion.Id, expirationDate, false);
		List<GoogleFileVersion__c> updatedVersions = new GoogleLocalFileVersionPublicLinkService().removePublicLinkSharing(localFileVersion.Id);
		Test.stopTest();

		System.assertEquals(1, updatedVersions.size());
		System.assertEquals(null, updatedVersions[0].PublicLink__c);
		System.assertEquals(null, updatedVersions[0].PublicLinkExpirationDate__c);
		System.assertEquals(null, updatedVersions[0].PublicLinkPermissionId__c);
		System.assertEquals('None', updatedVersions[0].PublicLinkStatus__c);
	}
}