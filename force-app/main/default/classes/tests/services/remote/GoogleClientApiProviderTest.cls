@IsTest
private class GoogleClientApiProviderTest {
	public class TestGoogleAuthorizer implements GoogleAuthorizer {
		public String retrieveAccessToken() {
			return 'client.test-access-token';
		}
	}

	private static GoogleClientApiProvider newSut() {
		return new GoogleClientApiProvider();
	}

	private static void initMocks() {
		Test.setMock(HttpCalloutMock.class, new GoogleDriveHttpMock().withDefaultHappyPath());
		GoogleClientApiProvider.authorizerClassNameOverride = 'GoogleClientApiProviderTest.TestGoogleAuthorizer';
	}

	@IsTest
	private static void testValidateGoogleServiceAccountPositive() {
		initMocks();

		Test.startTest();
		String message = newSut().validateGoogleServiceAccount();
		Test.stopTest();

		System.assert(String.isNotBlank(message));
		System.assert(message.contains('valid access token'));
	}

	@IsTest
	private static void testRetrieveGoogleDriveClientPositive() {
		initMocks();

		Test.startTest();
		GoogleDrive googleDriveClient = newSut().retrieveGoogleDriveClient();
		Test.stopTest();

		System.assertNotEquals(null, googleDriveClient);
	}
}