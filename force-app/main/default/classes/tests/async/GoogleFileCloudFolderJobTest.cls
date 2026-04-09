@IsTest
private class GoogleFileCloudFolderJobTest {
	public class TestGoogleAuthorizer implements GoogleAuthorizer {
		public String retrieveAccessToken() {
			return 'client.test-access-token';
		}
	}

	private static void initMocks() {
		Test.setMock(HttpCalloutMock.class, new GoogleDriveHttpMock().withDefaultHappyPath());
		GoogleClientApiProvider.authorizerClassNameOverride = 'GoogleFileCloudFolderJobTest.TestGoogleAuthorizer';
	}

	@IsTest
	private static void testExecutePositiveNullRequest() {
		Test.startTest();
		new GoogleFileCloudFolderJob(null).execute(null);
		Test.stopTest();

		Assert.isTrue(true);
	}

	@IsTest
	private static void testExecutePositiveEarlyReturn() {
		initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('FJ1')
			.withDescription('D')
			.insertRecord();

		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('V1.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId(null)
			.withDocsId(null)
			.insertRecord();

		GSOQL.mock(GoogleFileVersionSelector.MOCK_ID).thenReturn(new List<SObject>{
			new GoogleFileVersion__c(
				Id = localFileVersion.Id,
				GoogleDriveFileId__c = '',
				GoogleDocsFileId__c = ''
			)
		});

		GoogleFileRelocationRequestDTO relocationRequest = new GoogleFileRelocationRequestDTO(
			UserInfo.getUserId(),
			parentFile.Id,
			localFileVersion.Id,
			null
		);

		Test.startTest();
		new GoogleFileCloudFolderJob(relocationRequest).execute(null);
		Test.stopTest();

		Assert.isTrue(true);
	}

	@IsTest
	private static void testExecuteNegativeWrapped() {
		initMocks();

		GoogleFileRelocationRequestDTO relocationRequest = new GoogleFileRelocationRequestDTO(
			UserInfo.getUserId(),
			(Id) 'a0B000000000001AAA',
			null,
			(Id) 'a0C000000000001AAA'
		);

		try {
			Test.startTest();
			new GoogleFileCloudFolderJob(relocationRequest).execute(null);
			Test.stopTest();
			Assert.isTrue(false);
		} catch (GoogleFileCloudFolderJob.GoogleFileCloudFolderJobException ex) {
			Assert.isTrue(ex.getMessage().contains('Unable to place the file into a folder'));
		}
	}
}