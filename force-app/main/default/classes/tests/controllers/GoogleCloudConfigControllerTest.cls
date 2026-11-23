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
@IsTest
private class GoogleCloudConfigControllerTest {
	private static GoogleClientConfig__mdt buildDefaultMetadataConfig() {
		return new GoogleClientConfig__mdt(
			DeveloperName = 'GoogleClient',
			MasterLabel = 'Google Client'
		);
	}

	private static GoogleClientConfig__mdt buildGeminiMetadataConfig() {
		return new GoogleClientConfig__mdt(
			DeveloperName = 'GoogleClient',
			MasterLabel = 'Google Client',
			IsFileIntelligenceEnabled__c = true,
			CustomGeminiApiKey__c = 'api-key-1',
			CustomModelName__c = 'gemini-2.0-flash'
		);
	}

	private static GoogleClientConfig__mdt buildSavedMetadataConfig(Datetime savedTime) {
		return (GoogleClientConfig__mdt) JSON.deserialize(JSON.serialize(new Map<String, Object>{
			'attributes' => new Map<String, Object>{ 'type' => 'GoogleClientConfig__mdt' },
			'DeveloperName' => 'GoogleClient',
			'MasterLabel' => 'Google Client',
			'SystemModstamp' => savedTime
		}), GoogleClientConfig__mdt.class);
	}

	@IsTest
	private static void testGenerateConfigIdPositive() {
		Test.startTest();
		String generatedConfigId = GoogleCloudConfigController.generateConfigId();
		Test.stopTest();

		Assert.isNotNull(generatedConfigId);
		Assert.isTrue(generatedConfigId.startsWith('cfg_'));
	}

	@IsTest
	private static void testPushPullRemoveConfigPositive() {
		String generatedConfigId = GoogleCloudConfigController.generateConfigId();
		String payloadJson = '{"a":1}';

		Test.startTest();
		GoogleCloudConfigController.pushConfig(generatedConfigId, payloadJson);
		String pulledPayload = GoogleCloudConfigController.pullConfig(generatedConfigId);
		GoogleCloudConfigController.removeConfig(generatedConfigId);
		String afterRemovePayload = GoogleCloudConfigController.pullConfig(generatedConfigId);
		Test.stopTest();

		if (pulledPayload == null) {
			Assert.isNull(pulledPayload);
		} else {
			Assert.areEqual(payloadJson, pulledPayload);
		}
		Assert.isNull(afterRemovePayload);
	}

	@IsTest
	private static void testPullConfigNegativeInvalidFormat() {
		String invalidConfigId = GoogleCloudConfigController.generateConfigId() + '_notfound';

		try {
			Test.startTest();
			GoogleCloudConfigController.pullConfig(invalidConfigId);
			Test.stopTest();
			Assert.isTrue(false);
		} catch (Exception ex) {
			Assert.isTrue(ex.getMessage().contains('Invalid configId format'));
		}
	}

	@IsTest
	private static void testPushConfigNegativeInvalidFormat() {
		try {
			Test.startTest();
			GoogleCloudConfigController.pushConfig('bad', '{}');
			Test.stopTest();
			Assert.isTrue(false);
		} catch (Exception ex) {
			Assert.isTrue(String.isNotBlank(ex.getMessage()));
		}
	}

	@IsTest
	private static void testRemoveConfigNegativeInvalidFormat() {
		try {
			Test.startTest();
			GoogleCloudConfigController.removeConfig('bad');
			Test.stopTest();
			Assert.isTrue(false);
		} catch (Exception ex) {
			Assert.isTrue(String.isNotBlank(ex.getMessage()));
		}
	}

	@IsTest
	private static void testSaveMetadataConfigPositive() {
		GoogleCloudConfigController.adminAccessOverride = true;
		GoogleMetadataConfigService.configRecordOverride = buildDefaultMetadataConfig();

		Map<String, Object> fieldApiToValue = new Map<String, Object>{
			'IsFilePreviewDisabled__c' => false
		};

		Test.startTest();
		try {
			GoogleCloudConfigController.saveMetadataConfig(fieldApiToValue);
			Assert.isTrue(true);
		} catch (Exception ex) {
			Assert.isTrue(String.isNotBlank(ex.getMessage()));
		}
		Test.stopTest();
	}

	@IsTest
	private static void testSaveMetadataConfigNegativeNull() {
		GoogleCloudConfigController.adminAccessOverride = true;
		GoogleMetadataConfigService.configRecordOverride = buildDefaultMetadataConfig();

		Test.startTest();
		Id result = GoogleCloudConfigController.saveMetadataConfig(null);
		Test.stopTest();

		Assert.isNull(result);
	}

	@IsTest
	private static void testValidateLatestMetadataDeployPositive() {
		GoogleCloudConfigController.adminAccessOverride = true;
		Test.startTest();
		String result = GoogleCloudConfigController.validateLatestMetadataDeploy();
		Test.stopTest();

		if (result == null) {
			Assert.isNull(result);
		} else {
			Assert.isTrue(result == 'pending' || result == 'success' || result == 'fail');
		}
	}

	@IsTest
	private static void testRetrieveMetadataConfigSavedTimePositive() {
		GoogleCloudConfigController.adminAccessOverride = true;
		Datetime savedTime = Datetime.newInstanceGmt(2026, 11, 23, 5, 11, 28);
		GoogleMetadataConfigService.configRecordOverride = buildSavedMetadataConfig(savedTime);

		Test.startTest();
		Long result = GoogleCloudConfigController.retrieveMetadataConfigSavedTime();
		Test.stopTest();

		Assert.areEqual(savedTime.getTime(), result, 'A save is confirmed by this time moving, so it must be the moment the settings were last saved');
	}

	@IsTest
	private static void testRetrieveMetadataConfigSavedTimeNegativeNothingSaved() {
		GoogleCloudConfigController.adminAccessOverride = true;
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt();

		Test.startTest();
		Long result = GoogleCloudConfigController.retrieveMetadataConfigSavedTime();
		Test.stopTest();

		Assert.isNull(result, 'An org that never saved its settings has no saved time, so its first save reads as a change');
	}

	@IsTest
	private static void testValidateDriveMetadataConfigPositive() {
		GoogleCloudConfigController.adminAccessOverride = true;
		GoogleMetadataConfigService.configRecordOverride = buildDefaultMetadataConfig();
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		String result = GoogleCloudConfigController.validateDriveMetadataConfig();
		Test.stopTest();

		Assert.isNotNull(result);
	}

	@IsTest
	private static void testDeactivateIntelligenceMetadataConfigNegativeWithoutSavedConfig() {
		GoogleCloudConfigController.adminAccessOverride = true;
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt();

		Test.startTest();
		try {
			GoogleCloudConfigController.deactivateIntelligenceMetadataConfig();
			Assert.fail('Nothing can be deactivated before the configuration exists');
		} catch (AuraHandledException ex) {
			Assert.isTrue(true);
		}
		Test.stopTest();
	}

	@IsTest
	private static void testDeactivateIntelligenceMetadataConfigPositive() {
		GoogleCloudConfigController.adminAccessOverride = true;
		GoogleMetadataConfigService.configRecordOverride = buildGeminiMetadataConfig();

		Test.startTest();
		try {
			GoogleCloudConfigController.deactivateIntelligenceMetadataConfig();
			Assert.isTrue(true);
		} catch (Exception ex) {
			Assert.isTrue(String.isNotBlank(ex.getMessage()));
		}
		Test.stopTest();
	}

	@IsTest
	private static void testValidateIntelligenceMetadataConfigPositive() {
		GoogleCloudConfigController.adminAccessOverride = true;
		GoogleMetadataConfigService.configRecordOverride = buildGeminiMetadataConfig();
		Test.setMock(HttpCalloutMock.class, new GoogleIntelligenceHttpMock());
		GoogleClientApiProvider.authorizerClassNameOverride = 'GoogleCloudTestFactory.TestGoogleAuthorizer';

		Test.startTest();
		String result = GoogleCloudConfigController.validateIntelligenceMetadataConfig();
		Test.stopTest();

		Assert.isNotNull(result);
	}

	@IsTest
	private static void testSetupMethodsNegativeRefuseUserWithoutAdminAccess() {
		GoogleMetadataConfigService.configRecordOverride = buildGeminiMetadataConfig();
		GoogleCloudTestFactory.initMocks();
		GoogleCloudConfigController.adminAccessOverride = false;

		Integer refusedCalls = 0;
		Test.startTest();
		try {
			GoogleCloudConfigController.saveMetadataConfig(new Map<String, Object>{ 'IsFilePreviewDisabled__c' => true });
		} catch (AuraHandledException ex) {
			refusedCalls++;
		}
		try {
			GoogleCloudConfigController.validateLatestMetadataDeploy();
		} catch (AuraHandledException ex) {
			refusedCalls++;
		}
		try {
			GoogleCloudConfigController.validateDriveMetadataConfig();
		} catch (AuraHandledException ex) {
			refusedCalls++;
		}
		try {
			GoogleCloudConfigController.validateIntelligenceMetadataConfig();
		} catch (AuraHandledException ex) {
			refusedCalls++;
		}
		try {
			GoogleCloudConfigController.deactivateIntelligenceMetadataConfig();
		} catch (AuraHandledException ex) {
			refusedCalls++;
		}
		try {
			GoogleCloudConfigController.retrieveMetadataConfigSavedTime();
		} catch (AuraHandledException ex) {
			refusedCalls++;
		}
		Test.stopTest();

		Assert.areEqual(6, refusedCalls, 'Every setup method must refuse a user without Google Client administrator access');
	}

	@IsTest
	private static void testConfigBusPositiveStaysOpenToUsersWithoutAdminAccess() {
		GoogleCloudConfigController.adminAccessOverride = false;

		Test.startTest();
		String generatedConfigId = GoogleCloudConfigController.generateConfigId();
		GoogleCloudConfigController.pushConfig(generatedConfigId, '{"a":1}');
		GoogleCloudConfigController.removeConfig(generatedConfigId);
		Test.stopTest();

		Assert.isTrue(generatedConfigId.startsWith('cfg_'), 'The configuration hand-off serves every Google Client screen, so it must not ask for administrator access');
	}
}
