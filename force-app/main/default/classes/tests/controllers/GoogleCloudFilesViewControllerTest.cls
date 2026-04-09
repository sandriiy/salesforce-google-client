@IsTest
private class GoogleCloudFilesViewControllerTest {
	public class TestGoogleAuthorizer implements GoogleAuthorizer {
		public String retrieveAccessToken() {
			return 'client.test-access-token';
		}
	}

	private static void initMocks() {
		Test.setMock(HttpCalloutMock.class, new GoogleDriveHttpMock().withDefaultHappyPath());
		GoogleClientApiProvider.authorizerClassNameOverride = 'GoogleCloudFilesViewControllerTest.TestGoogleAuthorizer';
	}

	@IsTest
	private static void testFetchFileHeaderDetailsPositiveNullId() {
		initMocks();

		Test.startTest();
		GoogleFileHeaderInfoDTO headerInfo = GoogleCloudFilesViewController.fetchFileHeaderDetails(null);
		Test.stopTest();

		System.assertNotEquals(null, headerInfo);
		System.assertEquals(null, headerInfo.name);
		System.assertNotEquals(null, headerInfo.compactFields);
		System.assertEquals(0, headerInfo.compactFields.size());
	}

	@IsTest
	private static void testFetchFileHeaderDetailsPositiveMissing() {
		initMocks();

		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(new List<SObject>());

		Test.startTest();
		GoogleFileHeaderInfoDTO headerInfo = GoogleCloudFilesViewController.fetchFileHeaderDetails('a0B000000000001AAA');
		Test.stopTest();

		System.assertNotEquals(null, headerInfo);
		System.assertEquals(null, headerInfo.name);
		System.assertNotEquals(null, headerInfo.compactFields);
		System.assertEquals(0, headerInfo.compactFields.size());
	}

	@IsTest
	private static void testFetchFileHeaderDetailsPositive() {
		initMocks();

		GoogleFile__c localFile = GoogleCloudTestFactory.file()
			.withName('HDR1')
			.withDescription('D')
			.insertRecord();

		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(new List<SObject>{
			new GoogleFile__c(Id = localFile.Id, Name = localFile.Name, OwnerId = UserInfo.getUserId())
		});

		Test.startTest();
		GoogleFileHeaderInfoDTO headerInfo = GoogleCloudFilesViewController.fetchFileHeaderDetails(localFile.Id);
		Test.stopTest();

		System.assertNotEquals(null, headerInfo);
	}

	@IsTest
	private static void testRetrieveLocalGoogleFileVersionsPositive() {
		initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('VER_PARENT')
			.withDescription('D')
			.insertRecord();

		GoogleFileVersion__c firstVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('V1.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId('GD1')
			.withDocsId('DOCS1')
			.insertRecord();

		GSOQL.mock(GoogleFileVersionSelector.MOCK_ID).thenReturn(new List<SObject>{
			new GoogleFileVersion__c(Id = firstVersion.Id, Name = firstVersion.Name, GoogleFileId__c = parentFile.Id)
		});

		Test.startTest();
		List<GoogleFileVersion__c> fileVersions = GoogleCloudFilesViewController.retrieveLocalGoogleFileVersions(parentFile.Id);
		Test.stopTest();

		System.assertNotEquals(null, fileVersions);
		System.assertEquals(1, fileVersions.size());
		System.assertEquals(firstVersion.Id, fileVersions[0].Id);
	}
}