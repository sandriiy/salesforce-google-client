@IsTest
private class GoogleDriveApiProviderTest {
	public class TestGoogleAuthorizer implements GoogleAuthorizer {
		public String retrieveAccessToken() {
			return 'client.test-access-token';
		}
	}

	private static GoogleDriveApiProvider newSut() {
		return new GoogleDriveApiProvider();
	}

	private static void initMocks() {
		Test.setMock(HttpCalloutMock.class, new GoogleDriveHttpMock().withDefaultHappyPath());
		GoogleDriveApiProvider.authorizerClassNameOverride = 'GoogleDriveApiProviderTest.TestGoogleAuthorizer';
	}

	@IsTest
	private static void testValidateCustomGoogleAuthorizerCredsPositive() {
		initMocks();

		Test.startTest();
		String message = newSut().validateCustomGoogleAuthorizerCreds();
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