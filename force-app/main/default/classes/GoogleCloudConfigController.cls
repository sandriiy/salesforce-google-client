/**
 * MIT License
 *
 * Copyright (c) 2026 Andrii Sukhetskyi
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
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
			return 'The Intelligence request was submitted successfully, but a successful response was not returned!';
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
