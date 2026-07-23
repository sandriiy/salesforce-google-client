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

	private static GoogleClientConfig__mdt buildConfig(Boolean isPreviewDisabled) {
		return new GoogleClientConfig__mdt(
			DeveloperName = 'GoogleClient',
			MasterLabel = 'Google Client',
			IsFilePreviewDisabled__c = isPreviewDisabled
		);
	}

	@IsTest
	private static void testConstructorPositiveConfigExists() {
		GoogleMetadataConfigService.configRecordOverride = buildConfig(false);
		GoogleMetadataConfigService svc = new GoogleMetadataConfigService();
		System.assertNotEquals(null, svc.getConfig());
	}

	@IsTest
	private static void testSaveConfigPositiveNoOps() {
		GoogleMetadataConfigService.configRecordOverride = buildConfig(false);
		GoogleMetadataConfigService svc = new GoogleMetadataConfigService(new ThrowingDeployer());

		Test.startTest();
		svc.saveConfig(null);
		svc.saveConfig(new Map<String, Object>());
		Test.stopTest();

		System.assert(true);
	}

	@IsTest
	private static void testSaveConfigPositiveEnqueue() {
		GoogleMetadataConfigService.configRecordOverride = buildConfig(false);
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
	private static void testSaveConfigNegativeEnqueueThrows() {
		GoogleMetadataConfigService.configRecordOverride = buildConfig(false);
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
	private static void testSaveConfigPositiveCreatesRecordWhenNotExists() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt();

		GoogleMetadataConfigService svc = new GoogleMetadataConfigService(new SuccessDeployer());

		Map<String, Object> changes = new Map<String, Object>{
			'CustomGoogleCertificate__c' => 'MyCert',
			'CustomGoogleServiceAccount__c' => 'sa@project.iam.gserviceaccount.com'
		};

		Test.startTest();
		Id result = svc.saveConfig(changes);
		Test.stopTest();

		System.assertNotEquals(null, result, 'Should return a deployment Id when creating a new record');
	}

	@IsTest
	private static void testGettersPositiveValues() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(
			IsFilePreviewDisabled__c = false,
			DefaultBigFileSize__c = 2097152,
			MaxDeleteChainSize__c = 3
		);
		GoogleMetadataConfigService svc = new GoogleMetadataConfigService();
		System.assertNotEquals(null, svc.isPreviewDisabled());
		System.assertNotEquals(null, svc.getBigFileSizeInBytes());
		System.assertNotEquals(null, svc.getDeleteChainSize());
	}

	@IsTest
	private static void testGetAdditionalUploadFolderIdsPositiveEmpty() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(
			AdditionalGoogleUploadFolderIds__c = null
		);
		GoogleMetadataConfigService svc = new GoogleMetadataConfigService();

		Assert.areEqual(0, svc.getAdditionalUploadFolderIds().size());
	}

	@IsTest
	private static void testGetAdditionalUploadFolderIdsPositiveBlank() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(
			AdditionalGoogleUploadFolderIds__c = '   '
		);
		GoogleMetadataConfigService svc = new GoogleMetadataConfigService();

		Assert.areEqual(0, svc.getAdditionalUploadFolderIds().size());
	}

	@IsTest
	private static void testGetAdditionalUploadFolderIdsPositiveTrimsAndDropsBlanks() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(
			AdditionalGoogleUploadFolderIds__c = ' folder_a ;;folder_b; ;folder_c '
		);
		GoogleMetadataConfigService svc = new GoogleMetadataConfigService();

		List<String> ids = svc.getAdditionalUploadFolderIds();
		Assert.areEqual(3, ids.size());
		Assert.areEqual('folder_a', ids[0]);
		Assert.areEqual('folder_b', ids[1]);
		Assert.areEqual('folder_c', ids[2]);
	}

	@IsTest
	private static void testGetAllUploadFolderIdsPositiveOrderedAndDeduped() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(
			DefaultGoogleUploadFolderId__c = 'primary_folder',
			AdditionalGoogleUploadFolderIds__c = 'secondary_folder;primary_folder;third_folder'
		);
		GoogleMetadataConfigService svc = new GoogleMetadataConfigService();

		List<String> ordered = svc.getAllUploadFolderIds();
		Assert.areEqual(3, ordered.size());
		Assert.areEqual('primary_folder', ordered[0]);
		Assert.areEqual('secondary_folder', ordered[1]);
		Assert.areEqual('third_folder', ordered[2]);
	}

	@IsTest
	private static void testGetAllUploadFolderIdsPositivePrimaryOnly() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(
			DefaultGoogleUploadFolderId__c = 'primary_folder',
			AdditionalGoogleUploadFolderIds__c = null
		);
		GoogleMetadataConfigService svc = new GoogleMetadataConfigService();

		List<String> ordered = svc.getAllUploadFolderIds();
		Assert.areEqual(1, ordered.size());
		Assert.areEqual('primary_folder', ordered[0]);
	}

	@IsTest
	private static void testGetAllUploadFolderIdsPositiveNoPrimary() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(
			DefaultGoogleUploadFolderId__c = null,
			AdditionalGoogleUploadFolderIds__c = 'secondary_folder;third_folder'
		);
		GoogleMetadataConfigService svc = new GoogleMetadataConfigService();

		List<String> ordered = svc.getAllUploadFolderIds();
		Assert.areEqual(2, ordered.size());
		Assert.areEqual('secondary_folder', ordered[0]);
		Assert.areEqual('third_folder', ordered[1]);
	}

	@IsTest
	private static void testGetAllUploadFolderIdsPositiveAllBlank() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(
			DefaultGoogleUploadFolderId__c = null,
			AdditionalGoogleUploadFolderIds__c = null
		);
		GoogleMetadataConfigService svc = new GoogleMetadataConfigService();

		Assert.areEqual(0, svc.getAllUploadFolderIds().size());
	}

	@IsTest
	private static void testGetFileExplorerColumnsPositiveBlankUsesDefault() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(
			FileExplorerColumns__c = null
		);
		GoogleMetadataConfigService svc = new GoogleMetadataConfigService();

		List<String> columns = svc.getFileExplorerColumns();
		Assert.areEqual(5, columns.size());
		Assert.areEqual('title', columns[0]);
		Assert.areEqual('isLinked', columns[1]);
		Assert.areEqual('access', columns[2]);
		Assert.areEqual('owner', columns[3]);
		Assert.areEqual('lastModified', columns[4]);
	}

	@IsTest
	private static void testGetFileExplorerColumnsPositiveParsesConfigured() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(
			FileExplorerColumns__c = ' title ;summary;; type ; '
		);
		GoogleMetadataConfigService svc = new GoogleMetadataConfigService();

		List<String> columns = svc.getFileExplorerColumns();
		Assert.areEqual(3, columns.size());
		Assert.areEqual('title', columns[0]);
		Assert.areEqual('summary', columns[1]);
		Assert.areEqual('type', columns[2]);
	}
}