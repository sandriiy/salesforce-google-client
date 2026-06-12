public with sharing class GoogleCloudConfigController {
	@AuraEnabled
	public static String generateConfigId() {
		GoogleCacheConfigService cache = new GoogleCacheConfigService();
		return cache.generateConfigId();
	}

	@AuraEnabled
	public static void pushConfig(String configId, String payloadJson) {
		GoogleCacheConfigService cache = new GoogleCacheConfigService();
		cache.putConfig(configId, payloadJson);
	}

	@AuraEnabled
    public static Id saveMetadataConfig(Map<String, Object> fieldApiToValue) {
		GoogleMetadataConfigService metadataService = new GoogleMetadataConfigService();
		return metadataService.saveConfig(fieldApiToValue);
    }

	@AuraEnabled(cacheable=true)
	public static String pullConfig(String configId) {
		GoogleCacheConfigService cache = new GoogleCacheConfigService();
		return cache.getConfig(configId);
	}

	@AuraEnabled
	public static String validateLatestMetadataDeploy() {
		GoogleCacheConfigService cacheService = new GoogleCacheConfigService(new GoogleOrgCacheProvider(GoogleCacheConfigService.PARTITION));
		return cacheService.get(GoogleMetadataConfigService.DEFAULT_METADATA_DEPLOY_KEY);
	}

	@AuraEnabled
    public static String validateDriveMetadataConfig() {
		ensureMetadataConfigExists();

        GoogleClientApiProvider remoteProvider = new GoogleClientApiProvider();
		Boolean isValid = remoteProvider.validateGoogleServiceAccount();

		if (isValid) {
			return 'Your organization was successfully authenticated and a valid access token was returned!';
		} else {
			return 'Your organization was successfully authenticated, but no access token was returned!';
		}
    }

	@AuraEnabled
    public static String validateIntelligenceMetadataConfig() {
		ensureMetadataConfigExists();

        GoogleFileIntelligenceFactory aiFactory = new GoogleFileIntelligenceFactory();
		Boolean isValid = aiFactory.createForValidation().validate();

		if (isValid) {
			return 'The Intelligence configuration is valid and a successful response was returned!';
		} else {
			return 'The Intelligence request was successful submitted, but a successful response was not returned!';
		}
    }

	@AuraEnabled
	public static void removeConfig(String configId) {
		GoogleCacheConfigService cache = new GoogleCacheConfigService();
		cache.removeConfig(configId);
	}

	private static void ensureMetadataConfigExists() {
		if (!new GoogleMetadataConfigService().hasConfigRecord()) {
			throw new AuraHandledException('Save the Google Client configuration before validating it');
		}
	}
}
