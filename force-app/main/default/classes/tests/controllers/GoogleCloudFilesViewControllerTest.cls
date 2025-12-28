@IsTest
private class GoogleCloudFilesViewControllerTest {
	private static final String FILE_SELECTOR_MOCK_ID = 'GoogleFileSelector';
	private static final String VERSION_SELECTOR_MOCK_ID = 'GoogleFileVersionSelector';

	public class TestGoogleAuthorizer implements GoogleAuthorizer {
		public String retrieveAccessToken() {
			return 'client.test-access-token';
		}
	}

	private static void initMocks() {
		Test.setMock(HttpCalloutMock.class, new GoogleDriveHttpMock().withDefaultHappyPath());
		GoogleRemoteFileService.authorizerClassNameOverride = 'GoogleCloudFilesViewControllerTest.TestGoogleAuthorizer';
	}

	@IsTest
	private static void fetchFileHeaderDetailsTestSuccessNullId() {
		initMocks();

		Test.startTest();
		GoogleFileHeaderInfoDTO out = GoogleCloudFilesViewController.fetchFileHeaderDetails(null);
		Test.stopTest();

		System.assertNotEquals(null, out);
		System.assertEquals(null, out.name);
		System.assertNotEquals(null, out.compactFields);
		System.assertEquals(0, out.compactFields.size());
	}

	@IsTest
	private static void fetchFileHeaderDetailsTestSuccessMissing() {
		initMocks();

		GSOQL.mock(FILE_SELECTOR_MOCK_ID).thenReturn(new List<SObject>());

		Test.startTest();
		GoogleFileHeaderInfoDTO out = GoogleCloudFilesViewController.fetchFileHeaderDetails('a0B000000000001AAA');
		Test.stopTest();

		System.assertNotEquals(null, out);
		System.assertEquals(null, out.name);
		System.assertNotEquals(null, out.compactFields);
		System.assertEquals(0, out.compactFields.size());
	}

	@IsTest
	private static void fetchFileHeaderDetailsTestSuccessExec() {
		initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file()
			.withName('HDR1')
			.withDescription('D')
			.insertRecord();

		GSOQL.mock(FILE_SELECTOR_MOCK_ID).thenReturn(new List<SObject>{
			new GoogleFile__c(Id = f.Id, Name = f.Name, OwnerId = UserInfo.getUserId())
		});

		Test.startTest();
		GoogleFileHeaderInfoDTO out = GoogleCloudFilesViewController.fetchFileHeaderDetails(f.Id);
		Test.stopTest();

		System.assertNotEquals(null, out);
	}

	@IsTest
	private static void retrieveLocalGoogleFileVersionsTestSuccessList() {
		initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file()
			.withName('VER_PARENT')
			.withDescription('D')
			.insertRecord();

		GoogleFileVersion__c v = GoogleCloudTestFactory.version()
			.forFile(f.Id)
			.withName('V1.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId('GD1')
			.withDocsId('DOCS1')
			.insertRecord();

		GSOQL.mock(VERSION_SELECTOR_MOCK_ID).thenReturn(new List<SObject>{
			new GoogleFileVersion__c(Id = v.Id, Name = v.Name, GoogleFileId__c = f.Id)
		});

		Test.startTest();
		List<GoogleFileVersion__c> out = GoogleCloudFilesViewController.retrieveLocalGoogleFileVersions(f.Id);
		Test.stopTest();

		System.assertNotEquals(null, out);
		System.assertEquals(1, out.size());
		System.assertEquals(v.Id, out[0].Id);
	}
}
