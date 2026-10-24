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
	private static final Long BIG_FILE_SIZE_ABOVE_ANY_REQUEST = 30000000L;
	private static final Integer HEAP_LIMIT_ABOVE_ANY_REQUEST = 30000000;
	private static final Long ONE_BYTE_OVER_A_SYNCHRONOUS_REQUEST = 6000001L;

	private static GoogleClientConfig__mdt buildConfig(Long bigFileSize) {
		GoogleClientConfig__mdt config = new GoogleClientConfig__mdt();
		config.DefaultGoogleUploadFolderId__c = 'ROOT_FOLDER';
		config.IsFilePreviewDisabled__c = true;
		config.DefaultBigFileSize__c = bigFileSize;
		return config;
	}

	private static List<ContentVersion> mockSourceFiles(List<String> titles) {
		List<ContentVersion> sourceFiles = new List<ContentVersion>();
		GoogleLocalFileTransferService.sourceContentOverride = new Map<Id, Blob>();
		for (String title : titles) {
			ContentVersion sourceFile = GoogleCloudTestFactory.salesforceFile().withTitle(title).withContent(title).build();
			sourceFiles.add(sourceFile);
			GoogleLocalFileTransferService.sourceContentOverride.put(sourceFile.Id, Blob.valueOf(title));
		}

		GSOQL.mock(GoogleContentVersionSelector.MOCK_ID).thenReturn(sourceFiles);
		return sourceFiles;
	}

	private static List<GoogleFileUploadRequestDTO> requestsFor(List<ContentVersion> sourceFiles) {
		List<GoogleFileUploadRequestDTO> requests = new List<GoogleFileUploadRequestDTO>();
		for (ContentVersion sourceFile : sourceFiles) {
			GoogleFileUploadRequestDTO request = new GoogleFileUploadRequestDTO();
			request.salesforceFileId = sourceFile.Id;
			requests.add(request);
		}

		return requests;
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
	private static void testUploadSalesforceFileNowNegativeLargerThanOneRequestMayCarry() {
		GoogleMetadataConfigService.configRecordOverride = buildConfig(DEFAULT_BIG_FILE_SIZE);
		GoogleCloudTestFactory.initMocks();
		GoogleTransferLimitResolver.heapLimitOverride = HEAP_LIMIT_ABOVE_ANY_REQUEST;

		ContentVersion sourceFile = GoogleCloudTestFactory.salesforceFile().withSize(ONE_BYTE_OVER_A_SYNCHRONOUS_REQUEST).mock();

		GoogleFileUploadRequestDTO request = new GoogleFileUploadRequestDTO();
		request.salesforceFileId = sourceFile.Id;

		Test.startTest();
		try {
			new GoogleLocalFileTransferService().uploadSalesforceFileNow(request);
			Assert.fail('A file no single request can carry must be refused before anything reaches Google Drive');
		} catch (GoogleLocalFileTransferService.GoogleLocalFileTransferException ex) {
			Assert.isTrue(ex.getMessage().contains('too large to be transferred'), ex.getMessage());
		}
		Test.stopTest();
	}

	@IsTest
	private static void testUploadSalesforceFilePositiveLargerThanOneRequestIsQueued() {
		GoogleMetadataConfigService.configRecordOverride = buildConfig(BIG_FILE_SIZE_ABOVE_ANY_REQUEST);
		GoogleCloudTestFactory.initMocks();
		GoogleFileBackgroundUploadJob.skipExecution = true;
		GoogleTransferLimitResolver.heapLimitOverride = HEAP_LIMIT_ABOVE_ANY_REQUEST;

		ContentVersion sourceFile = GoogleCloudTestFactory.salesforceFile().withSize(ONE_BYTE_OVER_A_SYNCHRONOUS_REQUEST).mock();

		GoogleFileUploadRequestDTO request = new GoogleFileUploadRequestDTO();
		request.salesforceFileId = sourceFile.Id;

		Test.startTest();
		GoogleFileUploadResultDTO result = new GoogleLocalFileTransferService().uploadSalesforceFile(request);
		Test.stopTest();

		Assert.isTrue(result.isQueued, 'A file that fits the heap but not one request continues in the background, where a request may carry more');
		Assert.areEqual(0, [SELECT COUNT() FROM GoogleFile__c], 'Nothing is recorded until the background upload finishes');
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

	private static final Long DEFERRAL_PROBE_FILE_SIZE = 500000L;
	private static final Integer DEFERRAL_HEAP_MARGIN_BYTES = 300000;
	private static final Integer TRANSFER_HEAP_RESERVE_BYTES = 1048576;

	@IsTest
	private static void testUploadSalesforceFilePositiveRemembersTheSalesforceFile() {
		GoogleMetadataConfigService.configRecordOverride = buildConfig(DEFAULT_BIG_FILE_SIZE);
		GoogleCloudTestFactory.initMocks();
		GoogleFileCloudFolderJob.skipExecution = true;

		ContentVersion sourceFile = GoogleCloudTestFactory.salesforceFile().withTitle('Policy').mock();
		GoogleFileUploadRequestDTO request = new GoogleFileUploadRequestDTO();
		request.salesforceFileId = sourceFile.Id;

		Test.startTest();
		GoogleFileUploadResultDTO result = new GoogleLocalFileTransferService().uploadSalesforceFile(request);
		Test.stopTest();

		GoogleFile__c createdFile = [SELECT SalesforceFileId__c FROM GoogleFile__c WHERE Id = :result.googleFileId];
		Assert.areEqual(String.valueOf(sourceFile.ContentDocumentId), createdFile.SalesforceFileId__c, 'Every upload of a Salesforce file records where it came from, so a migration can tell it is already in Drive');
	}

	@IsTest
	private static void testUploadSalesforceFilesNowPositiveKeepsOwnerSharingAndLinksEveryRecord() {
		GoogleMetadataConfigService.configRecordOverride = buildConfig(DEFAULT_BIG_FILE_SIZE);
		GoogleCloudTestFactory.initMocks();
		GoogleFileCloudFolderJob.skipExecution = true;

		ContentVersion sourceFile = GoogleCloudTestFactory.salesforceFile().withTitle('Agreement').mock();
		Id primaryRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		Id secondRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);

		GoogleFileUploadRequestDTO request = new GoogleFileUploadRequestDTO();
		request.salesforceFileId = sourceFile.Id;
		request.relatedRecordId = primaryRecordId;
		request.additionalRecordIds = new List<Id>{ secondRecordId, secondRecordId };
		request.source = GoogleCloudConstants.FILE_SOURCE_MIGRATION;
		request.linkSource = GoogleCloudConstants.FILE_SOURCE_NOTES_AND_ATTACHMENTS;
		request.shareType = 'Collaborator';
		request.visibility = 'AllUsers';
		request.ownerId = UserInfo.getUserId();

		Test.startTest();
		List<GoogleFileUploadResultDTO> results = new GoogleLocalFileTransferService().uploadSalesforceFilesNow(new List<GoogleFileUploadRequestDTO>{ request });
		Test.stopTest();

		Assert.areEqual(1, results.size());
		Assert.isNull(results[0].errorMessage);
		Assert.isFalse(results[0].isDeferred);

		GoogleFile__c createdFile = [SELECT Source__c, OwnerId, SalesforceFileId__c FROM GoogleFile__c WHERE Id = :results[0].googleFileId];
		Assert.areEqual(GoogleCloudConstants.FILE_SOURCE_MIGRATION, createdFile.Source__c, 'The file keeps the source it was asked for');
		Assert.areEqual(UserInfo.getUserId(), createdFile.OwnerId);
		Assert.areEqual(String.valueOf(sourceFile.ContentDocumentId), createdFile.SalesforceFileId__c);

		List<GoogleFileLink__c> links = [SELECT LinkedObjectId__c, Source__c, ShareType__c, Visibility__c, IsAdditionalLink__c FROM GoogleFileLink__c WHERE GoogleFileId__c = :results[0].googleFileId ORDER BY IsAdditionalLink__c];
		Assert.areEqual(2, links.size(), 'The second record is linked once even though it was given twice');
		Assert.areEqual(String.valueOf(primaryRecordId), links[0].LinkedObjectId__c);
		Assert.isFalse(links[0].IsAdditionalLink__c);
		Assert.areEqual(GoogleCloudConstants.FILE_SOURCE_NOTES_AND_ATTACHMENTS, links[0].Source__c, 'The link carries the link source, so the file shows under Notes and Attachments');
		Assert.areEqual('Collaborator', links[0].ShareType__c);
		Assert.areEqual('AllUsers', links[0].Visibility__c);
		Assert.areEqual(String.valueOf(secondRecordId), links[1].LinkedObjectId__c);
		Assert.isTrue(links[1].IsAdditionalLink__c);
		Assert.areEqual(GoogleCloudConstants.FILE_SOURCE_NOTES_AND_ATTACHMENTS, links[1].Source__c);
		Assert.areEqual('Collaborator', links[1].ShareType__c);
	}

	@IsTest
	private static void testUploadSalesforceFilesNowPositiveAcceptsMigrationSourceTheUpgradedFieldLacks() {
		GoogleMetadataConfigService.configRecordOverride = buildConfig(DEFAULT_BIG_FILE_SIZE);
		GoogleCloudTestFactory.initMocks();
		GoogleFileCloudFolderJob.skipExecution = true;
		GoogleLocalFileTransferService.activeFieldSourcesOverride = new List<String>{ GoogleCloudConstants.FILE_SOURCE_NOTES_AND_ATTACHMENTS, 'Uploader', 'File Details', 'File Explorer' };

		ContentVersion sourceFile = GoogleCloudTestFactory.salesforceFile().withTitle('Agreement').mock();

		GoogleFileUploadRequestDTO request = new GoogleFileUploadRequestDTO();
		request.salesforceFileId = sourceFile.Id;
		request.relatedRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		request.source = GoogleCloudConstants.FILE_SOURCE_MIGRATION;
		request.linkSource = GoogleCloudConstants.FILE_SOURCE_NOTES_AND_ATTACHMENTS;

		Test.startTest();
		List<GoogleFileUploadResultDTO> results = new GoogleLocalFileTransferService().uploadSalesforceFilesNow(new List<GoogleFileUploadRequestDTO>{ request });
		Test.stopTest();

		Assert.isNull(results[0].errorMessage);
		GoogleFile__c createdFile = [SELECT Source__c FROM GoogleFile__c WHERE Id = :results[0].googleFileId];
		Assert.areEqual(GoogleCloudConstants.FILE_SOURCE_MIGRATION, createdFile.Source__c, 'An org upgraded from 2.2.0 has no Migration value on the field, and the migration must still copy its files');
	}

	@IsTest
	private static void testUploadSalesforceFileNegativeUnknownSourceListsMigrationTheUpgradedFieldLacks() {
		GoogleMetadataConfigService.configRecordOverride = buildConfig(DEFAULT_BIG_FILE_SIZE);
		GoogleCloudTestFactory.initMocks();
		GoogleLocalFileTransferService.activeFieldSourcesOverride = new List<String>{ GoogleCloudConstants.FILE_SOURCE_NOTES_AND_ATTACHMENTS, 'Uploader' };

		ContentVersion sourceFile = GoogleCloudTestFactory.salesforceFile().mock();

		GoogleFileUploadRequestDTO request = new GoogleFileUploadRequestDTO();
		request.salesforceFileId = sourceFile.Id;
		request.source = 'Somewhere else';

		Test.startTest();
		try {
			new GoogleLocalFileTransferService().uploadSalesforceFile(request);
			Assert.fail('An unknown source must still be refused');
		} catch (GoogleLocalFileTransferService.GoogleLocalFileTransferException ex) {
			Assert.areEqual('The file source must be one of "Notes & Attachments", "Uploader", "Migration"', ex.getMessage());
		}
		Test.stopTest();
	}

	@IsTest
	private static void testUploadSalesforceFilesNowPositiveCarriesOnPastAFileThatFails() {
		GoogleMetadataConfigService.configRecordOverride = buildConfig(DEFAULT_BIG_FILE_SIZE);
		GoogleCloudTestFactory.initMocks();
		GoogleFileCloudFolderJob.skipExecution = true;

		ContentVersion sourceFile = GoogleCloudTestFactory.salesforceFile().withTitle('Good').mock();
		GoogleFileUploadRequestDTO missingRequest = new GoogleFileUploadRequestDTO();
		missingRequest.salesforceFileId = GoogleCloudTestFactory.fakeId(ContentVersion.SObjectType);
		GoogleFileUploadRequestDTO goodRequest = new GoogleFileUploadRequestDTO();
		goodRequest.salesforceFileId = sourceFile.Id;

		Test.startTest();
		List<GoogleFileUploadResultDTO> results = new GoogleLocalFileTransferService().uploadSalesforceFilesNow(new List<GoogleFileUploadRequestDTO>{ missingRequest, goodRequest });
		Test.stopTest();

		Assert.areEqual(2, results.size());
		Assert.isNotNull(results[0].errorMessage, 'A file that cannot be found is reported on its own result');
		Assert.isNull(results[0].googleFileId);
		Assert.isNull(results[1].errorMessage);
		Assert.isNotNull(results[1].googleFileId, 'The files after a failure are still uploaded');
	}

	@IsTest
	private static void testUploadSalesforceFilesNowPositiveDefersWhatNoLongerFits() {
		GoogleMetadataConfigService.configRecordOverride = buildConfig(DEFAULT_BIG_FILE_SIZE);
		GoogleCloudTestFactory.initMocks();
		GoogleFileCloudFolderJob.skipExecution = true;

		ContentVersion firstFile = GoogleCloudTestFactory.salesforceFile().withTitle('First').withSize(DEFERRAL_PROBE_FILE_SIZE).build();
		ContentVersion secondFile = GoogleCloudTestFactory.salesforceFile().withTitle('Second').withSize(DEFERRAL_PROBE_FILE_SIZE).build();
		GSOQL.mock(GoogleContentVersionSelector.MOCK_ID).thenReturn(new List<SObject>{ firstFile, secondFile });
		GoogleLocalFileTransferService.sourceContentOverride = new Map<Id, Blob>{ firstFile.Id => Blob.valueOf('first'), secondFile.Id => Blob.valueOf('second') };

		GoogleFileUploadRequestDTO firstRequest = new GoogleFileUploadRequestDTO();
		firstRequest.salesforceFileId = firstFile.Id;
		GoogleFileUploadRequestDTO secondRequest = new GoogleFileUploadRequestDTO();
		secondRequest.salesforceFileId = secondFile.Id;

		Test.startTest();
		GoogleTransferLimitResolver.heapLimitOverride = Limits.getHeapSize() + TRANSFER_HEAP_RESERVE_BYTES + (DEFERRAL_PROBE_FILE_SIZE.intValue() * 2) + DEFERRAL_HEAP_MARGIN_BYTES;
		List<GoogleFileUploadResultDTO> results = new GoogleLocalFileTransferService().uploadSalesforceFilesNow(new List<GoogleFileUploadRequestDTO>{ firstRequest, secondRequest });
		Test.stopTest();

		Assert.areEqual(2, results.size());
		Assert.isNotNull(results[0].googleFileId, 'The first file fits on its own');
		Assert.isTrue(results[1].isDeferred, 'The second file would not fit beside the first and waits for the next transaction');
		Assert.isNull(results[1].errorMessage, 'Deferred is not failed');
		Assert.isNull(results[1].googleFileId);
	}

	@IsTest
	private static void testUploadSalesforceFilesNowPositiveDefersWhatTheUploadTimeCannotCover() {
		GoogleMetadataConfigService.configRecordOverride = buildConfig(DEFAULT_BIG_FILE_SIZE);
		GoogleCloudTestFactory.initMocks();
		GoogleFileCloudFolderJob.skipExecution = true;
		List<ContentVersion> sourceFiles = mockSourceFiles(new List<String>{ 'First', 'Second', 'Third' });
		GoogleLocalFileTransferService.uploadTimeBudgetMillisOverride = 0L;

		Test.startTest();
		List<GoogleFileUploadResultDTO> results = new GoogleLocalFileTransferService().uploadSalesforceFilesNow(requestsFor(sourceFiles));
		Test.stopTest();

		Assert.areEqual(sourceFiles.size(), results.size());
		Assert.isNotNull(results[0].googleFileId, 'The first file is always sent, so every transaction moves forward');
		Assert.isFalse(results[0].isDeferred);

		for (Integer index = 1; index < results.size(); index++) {
			Assert.isTrue(results[index].isDeferred, 'A file that would start after the upload time is spent waits for the next transaction');
			Assert.isNull(results[index].errorMessage, 'Deferred is not failed');
			Assert.isNull(results[index].googleDriveFileId, 'A deferred file never reaches Google Drive');
			Assert.isNull(results[index].googleFileId);
		}

		Assert.areEqual(1, [SELECT COUNT() FROM GoogleFile__c]);
	}

	@IsTest
	private static void testUploadSalesforceFilesNowPositiveSendsEveryFileWithinTheUploadTime() {
		GoogleMetadataConfigService.configRecordOverride = buildConfig(DEFAULT_BIG_FILE_SIZE);
		GoogleCloudTestFactory.initMocks();
		GoogleFileCloudFolderJob.skipExecution = true;
		List<ContentVersion> sourceFiles = mockSourceFiles(new List<String>{ 'First', 'Second', 'Third' });

		Test.startTest();
		List<GoogleFileUploadResultDTO> results = new GoogleLocalFileTransferService().uploadSalesforceFilesNow(requestsFor(sourceFiles));
		Test.stopTest();

		for (GoogleFileUploadResultDTO result : results) {
			Assert.isFalse(result.isDeferred, 'Uploads well inside the upload time leave nothing for the next transaction');
			Assert.isNull(result.errorMessage);
			Assert.isNotNull(result.googleFileId);
		}

		Assert.areEqual(sourceFiles.size(), [SELECT COUNT() FROM GoogleFile__c]);
	}

	@IsTest
	private static void testUploadSalesforceFilesPositiveTheUploadTimeOnlyPacesBatchesThatCarryOn() {
		GoogleMetadataConfigService.configRecordOverride = buildConfig(DEFAULT_BIG_FILE_SIZE);
		GoogleCloudTestFactory.initMocks();
		GoogleFileCloudFolderJob.skipExecution = true;
		List<ContentVersion> sourceFiles = mockSourceFiles(new List<String>{ 'First', 'Second' });
		GoogleLocalFileTransferService.uploadTimeBudgetMillisOverride = 0L;

		Test.startTest();
		List<GoogleFileUploadResultDTO> results = new GoogleLocalFileTransferService().uploadSalesforceFiles(requestsFor(sourceFiles));
		Test.stopTest();

		for (GoogleFileUploadResultDTO result : results) {
			Assert.isFalse(result.isDeferred, 'An ordinary upload has no next transaction to leave a file to');
			Assert.isNotNull(result.googleFileId);
		}

		Assert.areEqual(sourceFiles.size(), [SELECT COUNT() FROM GoogleFile__c]);
	}

	@IsTest
	private static void testUploadSalesforceFilesNowPositiveSkipsIntelligenceWhenAsked() {
		GoogleMetadataConfigService.configRecordOverride = buildConfig(DEFAULT_BIG_FILE_SIZE);
		GoogleCloudTestFactory.initMocks();
		GoogleFileCloudFolderJob.skipExecution = true;

		ContentVersion sourceFile = GoogleCloudTestFactory.salesforceFile().withTitle('Quiet').mock();
		GoogleFileUploadRequestDTO request = new GoogleFileUploadRequestDTO();
		request.salesforceFileId = sourceFile.Id;
		request.skipIntelligence = true;

		Test.startTest();
		List<GoogleFileUploadResultDTO> results = new GoogleLocalFileTransferService().uploadSalesforceFilesNow(new List<GoogleFileUploadRequestDTO>{ request });
		Test.stopTest();

		Assert.isNotNull(results[0].googleFileId);
		Assert.isTrue(GoogleFileInsertFinalizeCommand.intelligenceSkipped, 'Asking to skip AI analysis reaches the finalizer before the commit');
	}
}
