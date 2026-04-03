@IsTest
private class GoogleLocalFileVersionServiceTest {
	public class TestGoogleAuthorizer implements GoogleAuthorizer {
		public String retrieveAccessToken() {
			return 'client.test-access-token';
		}
	}

	private static void initMocks() {
		Test.setMock(HttpCalloutMock.class, new GoogleDriveHttpMock().withDefaultHappyPath());
		GoogleDriveApiProvider.authorizerClassNameOverride = 'GoogleLocalFileVersionServiceTest.TestGoogleAuthorizer';
	}

	@IsTest
	private static void testDownloadPositive() {
		initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('VS2').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('V2.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId('GD_VS_2')
			.withDocsId('DOCS_VS_2')
			.insertRecord();

		Test.startTest();
		String base64Body = new GoogleLocalFileVersionService().downloadFileBase64Body(localFileVersion.Id);
		Test.stopTest();

		System.assert(String.isNotBlank(base64Body));
	}

	@IsTest
	private static void testDownloadPositiveRange() {
		initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('VS3').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('V3.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId('GD_VS_3')
			.withDocsId('DOCS_VS_3')
			.insertRecord();

		Test.startTest();
		String base64Body = new GoogleLocalFileVersionService().downloadFileBase64Body(localFileVersion.Id, 0L, 10L);
		Test.stopTest();

		System.assert(String.isNotBlank(base64Body));
	}
}