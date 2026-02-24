public with sharing class GoogleDriveApiProvider {
	private final String DETAULT_ERROR_HANDLER = 'GoogleFileWebErrorHandler';
	private final String DEFAULT_TOKEN_CACHE_NAME = 'accessToken';
	private final String DEFAULT_AGENT_NAME = 'Apex Client 1/1';

	@TestVisible
	private static String authorizerClassNameOverride;

	private GoogleCacheConfigService cacheService = new GoogleCacheConfigService();
	private GoogleMetadataConfigService metadataService = new GoogleMetadataConfigService();

	public String validateCustomGoogleAuthorizerCreds() {
		GoogleCredential testCredential = new GoogleAuthorizationCodeFlow.Builder()
			.setLocalGoogleAuthorizer(metadataService.getGoogleDriveAuthorizerClassName())
			.build();

		if (String.isBlank(testCredential.accessToken)) {
			return 'Your organization was successfully authenticated, but no access token was returned!';
		} else {
			return 'Your organization was successfully authenticated and a valid access token was returned!';
		}
	}

	public GoogleDrive retrieveGoogleDriveClient() {
		GoogleCredential googleDriveCredentials = retrieveGoogleCredential();
		return new GoogleDrive(googleDriveCredentials, DEFAULT_AGENT_NAME)
			.withFailureStrategy(DETAULT_ERROR_HANDLER);
	}

	private GoogleCredential retrieveGoogleCredential() {
		String authorizerClassName = authorizerClassNameOverride != null
			? authorizerClassNameOverride
			: metadataService.getGoogleDriveAuthorizerClassName();

		GoogleAuthorizationCodeFlow.Builder builder = new GoogleAuthorizationCodeFlow.Builder()
			.setLocalGoogleAuthorizer(authorizerClassName);

		if (cacheService.getSessionPartition() != null) {
			builder.setLocalPlatformCache(
				cacheService.getSessionPartition(),
				DEFAULT_TOKEN_CACHE_NAME
			);
		} else {
			builder.setLocalPlatformCache(
				cacheService.getOrgPartition(),
				DEFAULT_TOKEN_CACHE_NAME
			);
		}

		return builder.build();
	}
}