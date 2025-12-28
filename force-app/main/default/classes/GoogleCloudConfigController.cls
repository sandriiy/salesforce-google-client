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
    public static void saveMetadataConfig(Map<String, Object> fieldApiToValue) {
		GoogleMetadataConfigService metadataService = new GoogleMetadataConfigService();
		metadataService.saveConfig(fieldApiToValue);
    }

	@AuraEnabled(cacheable=true)
	public static String pullConfig(String configId) {
		GoogleCacheConfigService cache = new GoogleCacheConfigService();
		return cache.getConfig(configId);
	}

	@AuraEnabled
    public static String validateMetadataConfig(String className) {
        GoogleRemoteFileService remoteService = new GoogleRemoteFileService();
		return remoteService.validateCustomGoogleAuthorizerClass(className);
    }

	@AuraEnabled
	public static void removeConfig(String configId) {
		GoogleCacheConfigService cache = new GoogleCacheConfigService();
		cache.removeConfig(configId);
	}
}
