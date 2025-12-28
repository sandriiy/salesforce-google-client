@IsTest
private class GoogleMetadataConfigServiceTest {
	private class SuccessDeployer implements IGoogleMetadataDeployer {
		public Id enqueue(Metadata.DeployContainer container) {
			return '0Af000000000001AAA';
		}
	}

	private class NullIdDeployer implements IGoogleMetadataDeployer {
		public Id enqueue(Metadata.DeployContainer container) {
			return null;
		}
	}

	private class ThrowingDeployer implements IGoogleMetadataDeployer {
		public Id enqueue(Metadata.DeployContainer container) {
			throw new CalloutException('boom');
		}
	}

	@IsTest
	private static void constructorTestSuccessConfigExists() {
		GoogleMetadataConfigService svc = new GoogleMetadataConfigService();
		System.assertNotEquals(null, svc.getConfig());
	}

	@IsTest
	private static void saveConfigTestSuccessNoOps() {
		GoogleMetadataConfigService svc = new GoogleMetadataConfigService(new ThrowingDeployer());

		Test.startTest();
		svc.saveConfig(null);
		svc.saveConfig(new Map<String, Object>());
		Test.stopTest();

		System.assert(true);
	}

	@IsTest
	private static void saveConfigTestSuccessEnqueue() {
		GoogleMetadataConfigService svc = new GoogleMetadataConfigService(new SuccessDeployer());

		Map<String, Object> changes = new Map<String, Object>{
			'DefaultGoogleUploadFolderId__c' => 'folder_123',
			'IsFilePreviewDisabled__c' => true
		};

		Test.startTest();
		svc.saveConfig(changes);
		Test.stopTest();

		System.assert(true);
	}

	@IsTest
	private static void saveConfigTestFailNullJobId() {
		GoogleMetadataConfigService svc = new GoogleMetadataConfigService(new NullIdDeployer());

		Map<String, Object> changes = new Map<String, Object>{
			'DefaultGoogleUploadFolderId__c' => 'folder_123'
		};

		Test.startTest();
		try {
			svc.saveConfig(changes);
			System.assert(false);
		} catch (GoogleMetadataConfigService.GoogleMetadataConfigException ex) {
			System.assert(ex.getMessage().contains('Failed to save Google Client configuration'));
		}
		Test.stopTest();
	}

	@IsTest
	private static void saveConfigTestFailEnqueueThrows() {
		GoogleMetadataConfigService svc = new GoogleMetadataConfigService(new ThrowingDeployer());

		Map<String, Object> changes = new Map<String, Object>{
			'DefaultGoogleUploadFolderId__c' => 'folder_123'
		};

		Test.startTest();
		try {
			svc.saveConfig(changes);
			System.assert(false);
		} catch (GoogleMetadataConfigService.GoogleMetadataConfigException ex) {
			System.assert(ex.getMessage().contains('Failed to save Google Client configuration'));
		}
		Test.stopTest();
	}

	@IsTest
	private static void gettersTestSuccessValues() {
		GoogleMetadataConfigService svc = new GoogleMetadataConfigService();
		System.assertNotEquals(null, svc.isPreviewDisabled());
		System.assertNotEquals(null, svc.getBigFileSizeInBytes());
		System.assertNotEquals(null, svc.getDeleteChainSize());
	}
}
