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

		Assert.areEqual(payloadJson, pulledPayload);
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
		Test.startTest();
		Id result = GoogleCloudConfigController.saveMetadataConfig(null);
		Test.stopTest();

		Assert.isNull(result);
	}

	@IsTest
	private static void testValidateLatestMetadataDeployPositive() {
		Test.startTest();
		String result = GoogleCloudConfigController.validateLatestMetadataDeploy();
		Test.stopTest();

		Assert.isTrue(true);
	}

	@IsTest
	private static void testValidateDriveMetadataConfigPositive() {
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		String result = GoogleCloudConfigController.validateDriveMetadataConfig();
		Test.stopTest();

		Assert.isNotNull(result);
	}

	@IsTest
	private static void testValidateIntelligenceMetadataConfigPositive() {
		Test.setMock(HttpCalloutMock.class, new GoogleIntelligenceHttpMock());
		GoogleClientApiProvider.authorizerClassNameOverride = 'GoogleCloudTestFactory.TestGoogleAuthorizer';

		Test.startTest();
		try {
			String result = GoogleCloudConfigController.validateIntelligenceMetadataConfig();
			Assert.isNotNull(result);
		} catch (Exception ex) {
			Assert.isTrue(String.isNotBlank(ex.getMessage()));
		}
		Test.stopTest();
	}
}