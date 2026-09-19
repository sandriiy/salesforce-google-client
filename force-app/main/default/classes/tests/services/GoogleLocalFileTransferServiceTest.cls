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
private class GoogleLocalFileTransferServiceTest {
	private static final Long DEFAULT_BIG_FILE_SIZE = 2097152L;
	private static final Long TINY_BIG_FILE_SIZE = 5L;

	private static GoogleClientConfig__mdt buildConfig(Long bigFileSize) {
		GoogleClientConfig__mdt config = new GoogleClientConfig__mdt();
		config.DefaultGoogleUploadFolderId__c = 'ROOT_FOLDER';
		config.IsFilePreviewDisabled__c = true;
		config.DefaultBigFileSize__c = bigFileSize;
		return config;
	}

	@IsTest
	private static void testUploadSalesforceFilePositiveCreatesFileVersionAndLink() {
		GoogleMetadataConfigService.configRecordOverride = buildConfig(DEFAULT_BIG_FILE_SIZE);
		GoogleCloudTestFactory.initMocks();
		GoogleFileCloudFolderJob.skipExecution = true;

		ContentVersion sourceFile = GoogleCloudTestFactory.salesforceFile().withTitle('Contract').withExtension('pdf').withContent('hello contract').mock();
		Id linkedRecordId = GoogleCloudTestFactory.linkedRecord('Opportunity Alpha');

		GoogleFileUploadRequestDTO request = new GoogleFileUploadRequestDTO();
		request.salesforceFileId = sourceFile.Id;
		request.relatedRecordId = linkedRecordId;

		Test.startTest();
		GoogleFileUploadResultDTO result = new GoogleLocalFileTransferService().uploadSalesforceFile(request);
		Test.stopTest();

		Assert.isFalse(result.isQueued, 'A small file must be uploaded within the same run');
		Assert.areEqual('Contract.pdf', result.fileName);
		Assert.areEqual(14L, result.fileSize);
		Assert.areEqual('gfile_big_001', result.googleDriveFileId);
		Assert.areEqual('ROOT_FOLDER', result.googleDriveFolderId, 'Without parents in the Drive answer the configured upload folder is recorded');

		GoogleFileVersion__c createdVersion = [SELECT Name, Type__c, Size__c, GoogleDriveFileId__c, GoogleFileId__c FROM GoogleFileVersion__c WHERE Id = :result.googleFileVersionId];
		Assert.areEqual('Contract.pdf', createdVersion.Name);
		Assert.areEqual('application/pdf', createdVersion.Type__c);
		Assert.areEqual(14, createdVersion.Size__c.intValue());
		Assert.areEqual('gfile_big_001', createdVersion.GoogleDriveFileId__c);
		Assert.areEqual(result.googleFileId, createdVersion.GoogleFileId__c);

		GoogleFileLink__c createdLink = [SELECT LinkedObjectId__c, Source__c FROM GoogleFileLink__c WHERE GoogleFileId__c = :result.googleFileId];
		Assert.areEqual(String.valueOf(linkedRecordId), createdLink.LinkedObjectId__c);
		Assert.areEqual('Notes & Attachments', createdLink.Source__c, 'Files land where the Attachments component looks unless another source is asked for');
	}

	@IsTest
	private static void testUploadSalesforceFilePositiveRenamesAndKeepsExtension() {
		GoogleMetadataConfigService.configRecordOverride = buildConfig(DEFAULT_BIG_FILE_SIZE);
		GoogleCloudTestFactory.initMocks();
		GoogleFileCloudFolderJob.skipExecution = true;

		ContentVersion sourceFile = GoogleCloudTestFactory.salesforceFile().withTitle('Scan').withExtension('png').mock();

		GoogleFileUploadRequestDTO request = new GoogleFileUploadRequestDTO();
		request.salesforceFileId = sourceFile.ContentDocumentId;
		request.fileName = 'Signed agreement';
		request.source = 'uploader';

		Test.startTest();
		GoogleFileUploadResultDTO result = new GoogleLocalFileTransferService().uploadSalesforceFile(request);
		Test.stopTest();

		Assert.areEqual('Signed agreement.png', result.fileName);
		GoogleFile__c createdFile = [SELECT Name, Source__c FROM GoogleFile__c WHERE Id = :result.googleFileId];
		Assert.areEqual('Signed agreement', createdFile.Name);
		Assert.areEqual('Uploader', createdFile.Source__c, 'The source is matched to the picklist value regardless of case');
		Assert.areEqual(0, [SELECT COUNT() FROM GoogleFileLink__c WHERE GoogleFileId__c = :result.googleFileId], 'No record means no link');
	}

	@IsTest
	private static void testUploadSalesforceFilePositiveLargeFileIsQueued() {
		GoogleMetadataConfigService.configRecordOverride = buildConfig(TINY_BIG_FILE_SIZE);
		GoogleCloudTestFactory.initMocks();
		GoogleFileBackgroundUploadJob.skipExecution = true;

		ContentVersion sourceFile = GoogleCloudTestFactory.salesforceFile().withContent('larger than five bytes').mock();

		GoogleFileUploadRequestDTO request = new GoogleFileUploadRequestDTO();
		request.salesforceFileId = sourceFile.ContentDocumentId;

		Test.startTest();
		GoogleFileUploadResultDTO result = new GoogleLocalFileTransferService().uploadSalesforceFile(request);
		Test.stopTest();

		Assert.isTrue(result.isQueued, 'A file above the configured size must continue in the background');
		Assert.isNull(result.googleFileId);
		Assert.isNull(result.googleDriveFileId);
		Assert.areEqual('Test File.pdf', result.fileName);
		Assert.areEqual(0, [SELECT COUNT() FROM GoogleFile__c], 'Nothing is recorded until the background upload finishes');
	}

	@IsTest
	private static void testUploadSalesforceFileNowPositiveIgnoresTheSizeThreshold() {
		GoogleMetadataConfigService.configRecordOverride = buildConfig(TINY_BIG_FILE_SIZE);
		GoogleCloudTestFactory.initMocks();
		GoogleFileCloudFolderJob.skipExecution = true;

		ContentVersion sourceFile = GoogleCloudTestFactory.salesforceFile().withContent('larger than five bytes').mock();

		GoogleFileUploadRequestDTO request = new GoogleFileUploadRequestDTO();
		request.salesforceFileId = sourceFile.Id;

		Test.startTest();
		GoogleFileUploadResultDTO result = new GoogleLocalFileTransferService().uploadSalesforceFileNow(request);
		Test.stopTest();

		Assert.isFalse(result.isQueued);
		Assert.isNotNull(result.googleFileId, 'The background job relies on this path uploading whatever size it is given');
	}

	@IsTest
	private static void testUploadSalesforceFilePositiveRemovesSalesforceCopyWhenAsked() {
		GoogleMetadataConfigService.configRecordOverride = buildConfig(DEFAULT_BIG_FILE_SIZE);
		GoogleCloudTestFactory.initMocks();
		GoogleCapturingUnitOfWork uow = new GoogleCapturingUnitOfWork();

		ContentVersion sourceFile = GoogleCloudTestFactory.salesforceFile().mock();

		GoogleFileUploadRequestDTO request = new GoogleFileUploadRequestDTO();
		request.salesforceFileId = sourceFile.Id;
		request.removeSalesforceFile = true;

		Test.startTest();
		new GoogleLocalFileTransferService(uow).uploadSalesforceFile(request);
		Test.stopTest();

		Assert.areEqual(1, uow.registeredDeleted.size(), 'The Salesforce copy is removed only after the file record is committed');
		Assert.areEqual(sourceFile.ContentDocumentId, uow.registeredDeleted[0].Id);
		Assert.areEqual(2, uow.commitCount);
	}

	@IsTest
	private static void testUploadSalesforceFileNegativeMissingFileId() {
		GoogleMetadataConfigService.configRecordOverride = buildConfig(DEFAULT_BIG_FILE_SIZE);
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		try {
			new GoogleLocalFileTransferService().uploadSalesforceFile(new GoogleFileUploadRequestDTO());
			Assert.fail('A request without a Salesforce file must be refused');
		} catch (GoogleLocalFileTransferService.GoogleLocalFileTransferException ex) {
			Assert.isTrue(ex.getMessage().contains('Content Document Id or a Content Version Id'), ex.getMessage());
		}
		Test.stopTest();
	}

	@IsTest
	private static void testUploadSalesforceFileNegativeWrongIdType() {
		GoogleMetadataConfigService.configRecordOverride = buildConfig(DEFAULT_BIG_FILE_SIZE);
		GoogleCloudTestFactory.initMocks();

		GoogleFileUploadRequestDTO request = new GoogleFileUploadRequestDTO();
		request.salesforceFileId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);

		Test.startTest();
		try {
			new GoogleLocalFileTransferService().uploadSalesforceFile(request);
			Assert.fail('Only Salesforce Files can be uploaded');
		} catch (GoogleLocalFileTransferService.GoogleLocalFileTransferException ex) {
			Assert.isTrue(ex.getMessage().contains('must be a Content Document Id'), ex.getMessage());
		}
		Test.stopTest();
	}

	@IsTest
	private static void testUploadSalesforceFileNegativeFileNotFound() {
		GoogleMetadataConfigService.configRecordOverride = buildConfig(DEFAULT_BIG_FILE_SIZE);
		GoogleCloudTestFactory.initMocks();
		GSOQL.mock(GoogleContentVersionSelector.MOCK_ID).thenReturn(new List<SObject>());

		GoogleFileUploadRequestDTO request = new GoogleFileUploadRequestDTO();
		request.salesforceFileId = GoogleCloudTestFactory.fakeId(ContentVersion.SObjectType);

		Test.startTest();
		try {
			new GoogleLocalFileTransferService().uploadSalesforceFile(request);
			Assert.fail('A missing file must be reported');
		} catch (GoogleLocalFileTransferService.GoogleLocalFileTransferException ex) {
			Assert.isTrue(ex.getMessage().contains('could not be found'), ex.getMessage());
		}
		Test.stopTest();
	}

	@IsTest
	private static void testUploadSalesforceFileNegativeUnknownSource() {
		GoogleMetadataConfigService.configRecordOverride = buildConfig(DEFAULT_BIG_FILE_SIZE);
		GoogleCloudTestFactory.initMocks();

		ContentVersion sourceFile = GoogleCloudTestFactory.salesforceFile().mock();

		GoogleFileUploadRequestDTO request = new GoogleFileUploadRequestDTO();
		request.salesforceFileId = sourceFile.Id;
		request.source = 'Somewhere else';

		Test.startTest();
		try {
			new GoogleLocalFileTransferService().uploadSalesforceFile(request);
			Assert.fail('An unknown source must be refused before anything reaches Google Drive');
		} catch (GoogleLocalFileTransferService.GoogleLocalFileTransferException ex) {
			Assert.isTrue(ex.getMessage().contains('must be one of'), ex.getMessage());
		}
		Test.stopTest();
	}

	@IsTest
	private static void testDownloadToSalesforceFilePositiveSavesLatestVersionOfFile() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();
		GoogleCapturingUnitOfWork uow = new GoogleCapturingUnitOfWork();

		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('Report').insertRecord();
		GoogleCloudTestFactory.version().forFile(localFile.Id).withName('Report.pdf').withDriveId('GD_REPORT').isLatest(true).insertRecord();
		Id relatedRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);

		GoogleFileDownloadRequestDTO request = new GoogleFileDownloadRequestDTO();
		request.googleFileId = localFile.Id;
		request.relatedRecordId = relatedRecordId;

		Test.startTest();
		GoogleFileDownloadResultDTO result = new GoogleLocalFileTransferService(uow).downloadToSalesforceFile(request);
		Test.stopTest();

		ContentVersion savedFile = (ContentVersion) uow.firstNew();
		Assert.areEqual('Report.pdf', savedFile.PathOnClient);
		Assert.areEqual('Report', savedFile.Title);
		Assert.areEqual(relatedRecordId, savedFile.FirstPublishLocationId, 'The record link is created by Salesforce from the first publish location');
		Assert.areEqual('mock file content', savedFile.VersionData.toString());
		Assert.areEqual('Report.pdf', result.fileName);
		Assert.areEqual(17L, result.fileSize);
		Assert.areEqual(1, uow.commitCount);
	}

	@IsTest
	private static void testDownloadToSalesforceFilePositiveConvertsThroughThePreviewCopy() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();
		GoogleCapturingUnitOfWork uow = new GoogleCapturingUnitOfWork();

		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('Proposal').insertRecord();
		GoogleFileVersion__c localVersion = GoogleCloudTestFactory.version()
			.forFile(localFile.Id)
			.withName('Proposal.pdf')
			.withType('application/pdf')
			.withSize(10)
			.withDriveId('GD_PROPOSAL')
			.withDocsId('DOCS_PROPOSAL')
			.insertRecord();

		GoogleFileDownloadRequestDTO request = new GoogleFileDownloadRequestDTO();
		request.googleFileVersionId = localVersion.Id;
		request.convertTo = '.DOCX';
		request.fileName = 'Proposal for review';

		Test.startTest();
		GoogleFileDownloadResultDTO result = new GoogleLocalFileTransferService(uow).downloadToSalesforceFile(request);
		Test.stopTest();

		ContentVersion savedFile = (ContentVersion) uow.firstNew();
		Assert.areEqual('Proposal for review.docx', savedFile.PathOnClient, 'The requested format decides the extension');
		Assert.areEqual('Proposal for review.docx', result.fileName);
		Assert.isNull(savedFile.FirstPublishLocationId);
	}

	@IsTest
	private static void testDownloadToSalesforceFileNegativeUnsupportedFormat() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();

		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('Proposal').insertRecord();
		GoogleFileVersion__c localVersion = GoogleCloudTestFactory.version().forFile(localFile.Id).withDocsId('DOCS_PROPOSAL').insertRecord();

		GoogleFileDownloadRequestDTO request = new GoogleFileDownloadRequestDTO();
		request.googleFileVersionId = localVersion.Id;
		request.convertTo = 'exe';

		Test.startTest();
		try {
			new GoogleLocalFileTransferService(new GoogleCapturingUnitOfWork()).downloadToSalesforceFile(request);
			Assert.fail('A format outside the Download As catalog must be refused');
		} catch (GoogleLocalFileTransferService.GoogleLocalFileTransferException ex) {
			Assert.isTrue(ex.getMessage().contains('download format is unavailable'), ex.getMessage());
		}
		Test.stopTest();
	}

	@IsTest
	private static void testDownloadToSalesforceFileNegativeMissingIds() {
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		try {
			new GoogleLocalFileTransferService(new GoogleCapturingUnitOfWork()).downloadToSalesforceFile(new GoogleFileDownloadRequestDTO());
			Assert.fail('A request without a file must be refused');
		} catch (GoogleLocalFileTransferService.GoogleLocalFileTransferException ex) {
			Assert.isTrue(ex.getMessage().contains('Provide a Google File Id'), ex.getMessage());
		}
		Test.stopTest();
	}

	@IsTest
	private static void testDownloadToSalesforceFileNegativeUnknownFile() {
		GoogleCloudTestFactory.initMocks();

		GoogleFileDownloadRequestDTO request = new GoogleFileDownloadRequestDTO();
		request.googleFileId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);

		Test.startTest();
		try {
			new GoogleLocalFileTransferService(new GoogleCapturingUnitOfWork()).downloadToSalesforceFile(request);
			Assert.fail('An unknown file must be reported');
		} catch (GoogleLocalFileTransferService.GoogleLocalFileTransferException ex) {
			Assert.isTrue(ex.getMessage().contains('could not be found'), ex.getMessage());
		}
		Test.stopTest();
	}
}
