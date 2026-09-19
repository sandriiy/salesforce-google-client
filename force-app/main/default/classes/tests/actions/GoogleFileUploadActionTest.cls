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
private class GoogleFileUploadActionTest {
	private static GoogleClientConfig__mdt buildConfig() {
		GoogleClientConfig__mdt config = new GoogleClientConfig__mdt();
		config.DefaultGoogleUploadFolderId__c = 'ROOT_FOLDER';
		config.IsFilePreviewDisabled__c = true;
		config.DefaultBigFileSize__c = 2097152;
		return config;
	}

	@IsTest
	private static void testUploadFilesPositive() {
		GoogleMetadataConfigService.configRecordOverride = buildConfig();
		GoogleCloudTestFactory.initMocks();
		GoogleFileCloudFolderJob.skipExecution = true;

		ContentVersion sourceFile = GoogleCloudTestFactory.salesforceFile().withTitle('Agreement').withExtension('docx').mock();
		Id linkedRecordId = GoogleCloudTestFactory.linkedRecord('Case 00001');

		GoogleFileUploadAction.Input input = new GoogleFileUploadAction.Input();
		input.salesforceFileId = sourceFile.ContentDocumentId;
		input.relatedRecordId = linkedRecordId;

		Test.startTest();
		List<GoogleFileUploadAction.Output> outputs = GoogleFileUploadAction.uploadFiles(new List<GoogleFileUploadAction.Input>{ input });
		Test.stopTest();

		Assert.areEqual(1, outputs.size(), 'Flow expects one output per input');
		Assert.isFalse(outputs[0].isQueued);
		Assert.areEqual('Agreement.docx', outputs[0].fileName);
		Assert.isNotNull(outputs[0].googleFileId);
		Assert.isNotNull(outputs[0].googleFileVersionId);
		Assert.areEqual('gfile_big_001', outputs[0].googleDriveFileId);

		GoogleFileVersion__c createdVersion = [SELECT Type__c FROM GoogleFileVersion__c WHERE Id = :outputs[0].googleFileVersionId];
		Assert.areEqual('application/vnd.openxmlformats-officedocument.wordprocessingml.document', createdVersion.Type__c, 'The type is taken from the file extension so previews keep working');
	}

	@IsTest
	private static void testUploadFilesPositiveUsesInjectedService() {
		GoogleMetadataConfigService.configRecordOverride = buildConfig();
		GoogleCloudTestFactory.initMocks();
		GoogleCapturingUnitOfWork uow = new GoogleCapturingUnitOfWork();
		GoogleFileUploadAction.transferServiceOverride = new GoogleLocalFileTransferService(uow);

		ContentVersion sourceFile = GoogleCloudTestFactory.salesforceFile().mock();

		GoogleFileUploadAction.Input input = new GoogleFileUploadAction.Input();
		input.salesforceFileId = sourceFile.Id;
		input.removeSalesforceFile = true;

		Test.startTest();
		List<GoogleFileUploadAction.Output> outputs = GoogleFileUploadAction.uploadFiles(new List<GoogleFileUploadAction.Input>{ input });
		Test.stopTest();

		Assert.areEqual(1, outputs.size());
		Assert.areEqual(2, uow.registeredNew.size(), 'A file and its version are registered');
		Assert.areEqual(1, uow.registeredDeleted.size(), 'The Salesforce copy is removed when asked');
	}

	@IsTest
	private static void testUploadFilesPositiveNullInputs() {
		Test.startTest();
		List<GoogleFileUploadAction.Output> outputs = GoogleFileUploadAction.uploadFiles(null);
		Test.stopTest();

		Assert.areEqual(0, outputs.size());
	}

	@IsTest
	private static void testUploadFilesPositiveEmptyInputs() {
		Test.startTest();
		List<GoogleFileUploadAction.Output> outputs = GoogleFileUploadAction.uploadFiles(new List<GoogleFileUploadAction.Input>());
		Test.stopTest();

		Assert.areEqual(0, outputs.size());
	}
}
