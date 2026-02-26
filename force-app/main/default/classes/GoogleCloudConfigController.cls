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
    public static String validateMetadataConfig() {
        GoogleDriveApiProvider remoteProvider = new GoogleDriveApiProvider();
		return remoteProvider.validateCustomGoogleAuthorizerCreds();
    }

	@AuraEnabled
	public static void removeConfig(String configId) {
		GoogleCacheConfigService cache = new GoogleCacheConfigService();
		cache.removeConfig(configId);
	}
}
