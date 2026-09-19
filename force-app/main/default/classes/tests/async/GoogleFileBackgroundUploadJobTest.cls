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
private class GoogleFileBackgroundUploadJobTest {
	private static GoogleClientConfig__mdt buildConfig() {
		GoogleClientConfig__mdt config = new GoogleClientConfig__mdt();
		config.DefaultGoogleUploadFolderId__c = 'ROOT_FOLDER';
		config.IsFilePreviewDisabled__c = true;
		config.DefaultBigFileSize__c = 5;
		return config;
	}

	@IsTest
	private static void testWorkPositiveUploadsTheFileRegardlessOfSize() {
		GoogleMetadataConfigService.configRecordOverride = buildConfig();
		GoogleCloudTestFactory.initMocks();
		GoogleFileCloudFolderJob.skipExecution = true;

		ContentVersion sourceFile = GoogleCloudTestFactory.salesforceFile().withTitle('Large').withExtension('txt').withContent('this content is above the tiny threshold').mock();

		GoogleFileUploadRequestDTO request = new GoogleFileUploadRequestDTO();
		request.salesforceFileId = sourceFile.Id;

		Test.startTest();
		new GoogleFileBackgroundUploadJob(request).work();
		Test.stopTest();

		GoogleFileVersion__c createdVersion = [SELECT Name, Type__c, GoogleDriveFileId__c FROM GoogleFileVersion__c WHERE GoogleDriveFileId__c = 'gfile_big_001' LIMIT 1];
		Assert.areEqual('Large.txt', createdVersion.Name);
		Assert.areEqual('text/plain', createdVersion.Type__c);
	}

	@IsTest
	private static void testWorkNegativeFailureIsLoggedAndRethrown() {
		GoogleMetadataConfigService.configRecordOverride = buildConfig();
		GoogleCloudTestFactory.initMocks();
		GSOQL.mock(GoogleContentVersionSelector.MOCK_ID).thenReturn(new List<SObject>());

		GoogleFileUploadRequestDTO request = new GoogleFileUploadRequestDTO();
		request.salesforceFileId = GoogleCloudTestFactory.fakeId(ContentVersion.SObjectType);

		Test.startTest();
		try {
			new GoogleFileBackgroundUploadJob(request).work();
			Assert.fail('A file that disappeared before the job ran must fail the job');
		} catch (GoogleFileBackgroundUploadJob.GoogleFileBackgroundUploadJobException ex) {
			Assert.isTrue(ex.getMessage().contains('Unable to upload the file'), ex.getMessage());
		}
		Test.stopTest();
	}

	@IsTest
	private static void testWorkPositiveSkipsWhenAsked() {
		GoogleMetadataConfigService.configRecordOverride = buildConfig();
		GoogleCloudTestFactory.initMocks();
		GoogleFileBackgroundUploadJob.skipExecution = true;

		GoogleFileUploadRequestDTO request = new GoogleFileUploadRequestDTO();
		request.salesforceFileId = GoogleCloudTestFactory.fakeId(ContentVersion.SObjectType);

		Test.startTest();
		new GoogleFileBackgroundUploadJob(request).work();
		new GoogleFileBackgroundUploadJob(null).work();
		Test.stopTest();

		Assert.areEqual(0, [SELECT COUNT() FROM GoogleFile__c]);
	}
}
