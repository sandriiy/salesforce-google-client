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
private class GoogleFileVersionLifecycleServiceTest {
	private static GoogleClientConfig__mdt buildLifecycleConfig() {
		return new GoogleClientConfig__mdt(
			IsFilePreviewDisabled__c = false,
			CustomGoogleUploadFolderStructure__c = '{User}',
			MaxDeleteChainSize__c = 10,
			CustomGeminiApiKey__c = 'api-key-1',
			CustomModelName__c = 'gemini-2.0-flash'
		);
	}

	@IsTest
	private static void testMarkAsLatestVersionIfApplicablePositiveNoInput() {
		Test.startTest();
		new GoogleLocalFileVersionLifecycleService().markAsLatestVersionIfApplicable(
			new List<GoogleFileVersion__c>(),
			new List<GoogleFileVersion__c>()
		);
		Test.stopTest();
		Assert.isTrue(true);
	}

	@IsTest
	private static void testProcessFileInsertFinalizerPositiveNoInput() {
		Test.startTest();
		new GoogleLocalFileVersionLifecycleService().processFileInsertFinalizer(null);
		Test.stopTest();
		Assert.isTrue(true);
	}

	@IsTest
	private static void testProcessFileInsertFinalizerChainsPdfPreviewBeforeFolderPlacement() {
		GoogleCloudTestFactory.initMocks(new GoogleCompositeHttpMock());
		GoogleMetadataConfigService.configRecordOverride = buildLifecycleConfig();
		GoogleFileVersionPreviewJob.skipExecution = false;
		GoogleFileVersionSummaryJob.skipExecution = false;
		GoogleFileCloudFolderJob.skipExecution = true;

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('CHAIN1')
			.withDescription('D')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('CHAIN1.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId('GD_CHAIN_1')
			.insertRecord();

		Test.startTest();
		new GoogleLocalFileVersionLifecycleService().processFileInsertFinalizer(new List<GoogleFileVersion__c>{ version });
		Test.stopTest();

		GoogleFileVersion__c refreshedVersion = [
			SELECT GoogleDocsFileId__c
			FROM GoogleFileVersion__c
			WHERE Id = :version.Id
			LIMIT 1
		];

		Assert.isTrue(String.isNotBlank(refreshedVersion.GoogleDocsFileId__c));
	}
}