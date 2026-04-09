public with sharing class GoogleClientApiProvider {
	private final String DETAULT_ERROR_HANDLER = 'GoogleFileWebErrorHandler';
	private final String DEFAULT_TOKEN_CACHE_NAME = 'accessToken';
	private final String DEFAULT_AGENT_NAME = 'Apex Client 1/1';

	@TestVisible
	private static String authorizerClassNameOverride;

	private GoogleCacheConfigService cacheService = new GoogleCacheConfigService();
	private GoogleMetadataConfigService metadataService = new GoogleMetadataConfigService();

	public Boolean validateGoogleServiceAccount() {
		String authorizerClassName = authorizerClassNameOverride != null
			? authorizerClassNameOverride
			: metadataService.getGoogleDriveAuthorizerClassName();

		GoogleCredential testCredential = new GoogleAuthorizationCodeFlow.Builder()
			.setLocalGoogleAuthorizer(authorizerClassName)
			.build();

		return String.isNotBlank(testCredential.accessToken);
	}

	public GoogleDrive retrieveGoogleDriveClient() {
		GoogleCredential googleDriveCredentials = retrieveGoogleCredential();
		return new GoogleDrive(googleDriveCredentials, DEFAULT_AGENT_NAME)
			.withFailureStrategy(DETAULT_ERROR_HANDLER);
	}

	public GoogleCredential retrieveGoogleClientCreds() {
		return retrieveGoogleCredential();
	}

	private GoogleCredential retrieveGoogleCredential() {
		String authorizerClassName = authorizerClassNameOverride != null
			? authorizerClassNameOverride
			: metadataService.getGoogleDriveAuthorizerClassName();

		GoogleAuthorizationCodeFlow.Builder builder = new GoogleAuthorizationCodeFlow.Builder()
			.setLocalGoogleAuthorizer(authorizerClassName);

		Cache.SessionPartition sessionPartition = cacheService.getSessionPartition();
		Cache.OrgPartition orgPartition = cacheService.getOrgPartition();

		if (sessionPartition != null) {
			builder.setLocalPlatformCache(sessionPartition, DEFAULT_TOKEN_CACHE_NAME);
		} else if (orgPartition != null) {
			builder.setLocalPlatformCache(orgPartition, DEFAULT_TOKEN_CACHE_NAME);
		}

		return builder.build();
	}
}