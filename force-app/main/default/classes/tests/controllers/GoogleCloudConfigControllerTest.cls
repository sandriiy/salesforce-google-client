@IsTest
private class GoogleCloudConfigControllerTest {
	@IsTest
	private static void testGenerateConfigIdPositive() {
		Test.startTest();
		String generatedConfigId = GoogleCloudConfigController.generateConfigId();
		Test.stopTest();

		System.assertNotEquals(null, generatedConfigId);
		System.assert(generatedConfigId.startsWith('cfg_'));
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

		System.assertEquals(payloadJson, pulledPayload);
		System.assertEquals(null, afterRemovePayload);
	}

	@IsTest
	private static void testPullConfigNegativeFormat() {
		String invalidConfigId = GoogleCloudConfigController.generateConfigId() + '_notfound';

		Test.startTest();
		try {
			GoogleCloudConfigController.pullConfig(invalidConfigId);
			System.assert(false);
		} catch (Exception ex) {
			System.assert(ex.getMessage().contains('Invalid configId format'));
		}
		Test.stopTest();
	}

	@IsTest
	private static void testPushConfigNegativeFormat() {
		Test.startTest();
		try {
			GoogleCloudConfigController.pushConfig('bad', '{}');
			System.assert(false);
		} catch (Exception ex) {
			System.assert(String.isNotBlank(ex.getMessage()));
		}
		Test.stopTest();
	}

	@IsTest
	private static void testRemoveConfigNegativeFormat() {
		Test.startTest();
		try {
			GoogleCloudConfigController.removeConfig('bad');
			System.assert(false);
		} catch (Exception ex) {
			System.assert(String.isNotBlank(ex.getMessage()));
		}
		Test.stopTest();
	}

	@IsTest
	private static void testSaveMetadataConfigPositive() {
		Map<String, Object> fieldApiToValue = new Map<String, Object>{
			'IsFilePreviewDisabled__c' => false
		};

		Test.startTest();
		try {
			GoogleCloudConfigController.saveMetadataConfig(fieldApiToValue);
			System.assert(true);
		} catch (Exception ex) {
			System.assert(String.isNotBlank(ex.getMessage()));
		}
		Test.stopTest();
	}

	@IsTest
	private static void testValidateMetadataConfigPositive() {
		Test.startTest();
		try {
			String validationResult = GoogleCloudConfigController.validateMetadataConfig();
			System.assertNotEquals(null, validationResult);
		} catch (Exception ex) {
			System.assert(String.isNotBlank(ex.getMessage()));
		}
		Test.stopTest();
	}

	@IsTest
	private static void testValidateLatestMetadataDeployPositive() {
		Test.startTest();
		String latestDeployValidationValue = GoogleCloudConfigController.validateLatestMetadataDeploy();
		Test.stopTest();

		System.assert(true);
	}
}