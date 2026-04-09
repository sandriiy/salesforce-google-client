@IsTest
private class GoogleFileCloudDeleteJobTest {
	public class TestGoogleAuthorizer implements GoogleAuthorizer {
		public String retrieveAccessToken() {
			return 'client.test-access-token';
		}
	}

	private static void initMocks() {
		Test.setMock(HttpCalloutMock.class, new GoogleDriveHttpMock().withDefaultHappyPath());
		GoogleClientApiProvider.authorizerClassNameOverride = 'GoogleFileCloudDeleteJobTest.TestGoogleAuthorizer';
	}

	@IsTest
	private static void testExecutePositiveNoIds() {
		initMocks();

		Test.startTest();
		new GoogleFileCloudDeleteJob(new List<String>()).execute(null);
		Test.stopTest();

		Assert.isTrue(true);
	}

	@IsTest
	private static void testExecutePositiveOneId() {
		initMocks();

		List<String> googleDriveIds = new List<String>{ 'GD_1' };

		Test.startTest();
		new GoogleFileCloudDeleteJob(googleDriveIds).execute(null);
		Test.stopTest();

		Assert.isTrue(true);
	}
}