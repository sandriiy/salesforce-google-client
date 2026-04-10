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

	@IsTest
	private static void testConstructorPositiveConfigExists() {
		GoogleMetadataConfigService svc = new GoogleMetadataConfigService();
		System.assertNotEquals(null, svc.getConfig());
	}

	@IsTest
	private static void testSaveConfigPositiveNoOps() {
		GoogleMetadataConfigService svc = new GoogleMetadataConfigService(new ThrowingDeployer());

		Test.startTest();
		svc.saveConfig(null);
		svc.saveConfig(new Map<String, Object>());
		Test.stopTest();

		System.assert(true);
	}

	@IsTest
	private static void testSaveConfigPositiveEnqueue() {
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
	private static void testGettersPositiveValues() {
		GoogleMetadataConfigService svc = new GoogleMetadataConfigService();
		System.assertNotEquals(null, svc.isPreviewDisabled());
		System.assertNotEquals(null, svc.getBigFileSizeInBytes());
		System.assertNotEquals(null, svc.getDeleteChainSize());
	}
}