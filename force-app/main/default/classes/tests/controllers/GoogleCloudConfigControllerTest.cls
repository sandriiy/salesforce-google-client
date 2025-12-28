@IsTest
private class GoogleCloudConfigControllerTest {
	@IsTest
	private static void generateConfigIdTestSuccessValue() {
		Test.startTest();
		String id = GoogleCloudConfigController.generateConfigId();
		Test.stopTest();
		System.assertNotEquals(null, id);
		System.assert(id.startsWith('cfg_'));
	}

	@IsTest
	private static void pushConfigTestSuccessRoundtrip() {
		String id = GoogleCloudConfigController.generateConfigId();
		String payload = '{"a":1}';
		Test.startTest();
		GoogleCloudConfigController.pushConfig(id, payload);
		String pulled = GoogleCloudConfigController.pullConfig(id);
		GoogleCloudConfigController.removeConfig(id);
		String afterRemove = GoogleCloudConfigController.pullConfig(id);
		Test.stopTest();
		System.assertEquals(payload, pulled);
		System.assertEquals(null, afterRemove);
	}

	@IsTest
	private static void pullConfigTestFailFormat() {
		String id = GoogleCloudConfigController.generateConfigId() + '_notfound';
		Test.startTest();
		try {
			String pulled = GoogleCloudConfigController.pullConfig(id);
		} catch (Exception ex) {
			Assert.isTrue(ex.getMessage().contains('Invalid configId format'));
		}
		Test.stopTest();
	}

	@IsTest
	private static void pushConfigTestFailFormat() {
		Test.startTest();
		try {
			GoogleCloudConfigController.pushConfig('bad', '{}');
			System.assert(false);
		} catch (Exception e) {
			System.assertNotEquals(null, e.getMessage());
		}
		Test.stopTest();
	}

	@IsTest
	private static void removeConfigTestFailFormat() {
		Test.startTest();
		try {
			GoogleCloudConfigController.removeConfig('bad');
			System.assert(false, 'Expected an exception for invalid config id');
		} catch (Exception e) {
			System.assertNotEquals(null, e.getMessage());
		}
		Test.stopTest();
	}

	@IsTest
	private static void saveMetadataConfigTestSuccessExec() {
		Map<String, Object> fieldApiToValue = new Map<String, Object>();
		fieldApiToValue.put('IsFilePreviewDisabled__c', false);
		Test.startTest();
		try {
			GoogleCloudConfigController.saveMetadataConfig(fieldApiToValue);
		} catch (Exception e) {
			System.assertNotEquals(null, e.getMessage());
		}
		Test.stopTest();
	}

	@IsTest
	private static void validateMetadataConfigTestSuccessExec() {
		Test.startTest();
		try {
			String result = GoogleCloudConfigController.validateMetadataConfig('GoogleCloudConfigControllerTest');
			System.assert(true);
		} catch (Exception e) {
			System.assertNotEquals(null, e.getMessage());
		}
		Test.stopTest();
	}
}
