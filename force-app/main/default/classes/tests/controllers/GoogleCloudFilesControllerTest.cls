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
private class GoogleCloudFilesControllerTest {
	@IsTest
	private static void testFetchFileAccessPositiveOwner() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c localFile = GoogleCloudTestFactory.file()
			.withName('FA1')
			.withDescription('D')
			.insertRecord();

		Test.startTest();
		String accessLevel = GoogleCloudFilesController.fetchFileAccess(localFile.Id);
		Test.stopTest();

		Assert.areEqual('Edit', accessLevel);
	}

	@IsTest
	private static void testRetrieveFileExplorerFilesPositive() {
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		GoogleFileExplorerResultDTO result = GoogleCloudFilesController.retrieveFileExplorerFiles();
		Test.stopTest();

		Assert.areNotEqual(null, result.files);
	}

	@IsTest
	private static void testRetrieveAllGoogleFilesPositive() {
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		List<GoogleFile__c> accessibleFiles = GoogleCloudFilesController.retrieveAllGoogleFiles();
		Test.stopTest();

		Assert.areNotEqual(null, accessibleFiles);
	}

	@IsTest
	private static void testRetrieveFileExplorerColumnsPositiveDefault() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(
			FileExplorerColumns__c = null
		);

		Test.startTest();
		List<GoogleFileColumnDTO> columns = GoogleCloudFilesController.retrieveFileExplorerColumns();
		Test.stopTest();

		Assert.areEqual(5, columns.size());
		Assert.areEqual('title', columns[0].key);
	}

	@IsTest
	private static void testRetrieveFileExplorerColumnsPositiveConfigured() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(
			FileExplorerColumns__c = 'title;summary'
		);

		Test.startTest();
		List<GoogleFileColumnDTO> columns = GoogleCloudFilesController.retrieveFileExplorerColumns();
		Test.stopTest();

		Assert.areEqual(2, columns.size());
		Assert.areEqual('summary', columns[1].key);
	}

	@IsTest
	private static void testRetrieveGoogleFilesWithLimitPositive() {
		GoogleCloudTestFactory.initMocks();

		Id relatedRecordId = GoogleCloudTestFactory.linkedRecord('Related Record');

		GoogleFile__c firstFile = GoogleCloudTestFactory.file()
			.withName('F1')
			.withDescription('D')
			.withSource('Uploader')
			.insertRecord();
		GoogleCloudTestFactory.version().forFile(firstFile.Id).withName('F1.pdf').withDriveId('GD_F1').insertRecord();

		GoogleFile__c secondFile = GoogleCloudTestFactory.file()
			.withName('F2')
			.withDescription('D')
			.withSource('Uploader')
			.insertRecord();
		GoogleCloudTestFactory.version().forFile(secondFile.Id).withName('F2.pdf').withDriveId('GD_F2').insertRecord();

		GoogleCloudTestFactory.link()
			.forFile(firstFile.Id)
			.withLinkedRecord(relatedRecordId)
			.withLinkedType('GoogleFile__c')
			.withSource('Notes & Attachments')
			.withShareType('Viewer')
			.withVisibility('InternalUsers')
			.insertRecord();

		GoogleCloudTestFactory.link()
			.forFile(secondFile.Id)
			.withLinkedRecord(relatedRecordId)
			.withLinkedType('GoogleFile__c')
			.withSource('Uploader')
			.withShareType('Viewer')
			.withVisibility('InternalUsers')
			.insertRecord();

		Test.startTest();
		List<GoogleFile__c> files = GoogleCloudFilesController.retrieveGoogleFilesWithLimit(relatedRecordId, 'Notes & Attachments', 1);
		Test.stopTest();

		Assert.areEqual(1, files.size());
		Assert.areEqual(firstFile.Id, files[0].Id);
	}

	@IsTest
	private static void testRetrieveGoogleFilesWithLimitFallsBackToPrimarySource() {
		GoogleCloudTestFactory.initMocks();

		Id relatedRecordId = GoogleCloudTestFactory.linkedRecord('Fallback Record');

		GoogleFile__c firstFile = GoogleCloudTestFactory.file()
			.withName('FB1')
			.withDescription('D')
			.withSource('Uploader')
			.insertRecord();
		GoogleCloudTestFactory.version().forFile(firstFile.Id).withName('FB1.pdf').withDriveId('GD_FB1').insertRecord();

		GoogleFile__c secondFile = GoogleCloudTestFactory.file()
			.withName('FB2')
			.withDescription('D')
			.withSource('Notes & Attachments')
			.insertRecord();
		GoogleCloudTestFactory.version().forFile(secondFile.Id).withName('FB2.pdf').withDriveId('GD_FB2').insertRecord();

		GoogleCloudTestFactory.link()
			.forFile(firstFile.Id)
			.withLinkedRecord(relatedRecordId)
			.withLinkedType('GoogleFile__c')
			.withShareType('Viewer')
			.withVisibility('InternalUsers')
			.insertRecord();

		GoogleCloudTestFactory.link()
			.forFile(secondFile.Id)
			.withLinkedRecord(relatedRecordId)
			.withLinkedType('GoogleFile__c')
			.withShareType('Viewer')
			.withVisibility('InternalUsers')
			.insertRecord();

		Test.startTest();
		List<GoogleFile__c> files = GoogleCloudFilesController.retrieveGoogleFilesWithLimit(relatedRecordId, 'Uploader', 5);
		Test.stopTest();

		Assert.areEqual(1, files.size());
		Assert.areEqual(firstFile.Id, files[0].Id);
	}

	@IsTest
	private static void testRetrieveGoogleFilesWithoutLimitPositive() {
		GoogleCloudTestFactory.initMocks();

		Id relatedRecordId = GoogleCloudTestFactory.linkedRecord('All Linked Record');

		GoogleFile__c firstFile = GoogleCloudTestFactory.file()
			.withName('F3')
			.withDescription('D')
			.withSource('Uploader')
			.insertRecord();
		GoogleCloudTestFactory.version().forFile(firstFile.Id).withName('F3.pdf').withDriveId('GD_F3').insertRecord();

		GoogleFile__c secondFile = GoogleCloudTestFactory.file()
			.withName('F4')
			.withDescription('D')
			.withSource('Notes & Attachments')
			.insertRecord();
		GoogleCloudTestFactory.version().forFile(secondFile.Id).withName('F4.pdf').withDriveId('GD_F4').insertRecord();

		GoogleCloudTestFactory.link()
			.forFile(firstFile.Id)
			.withLinkedRecord(relatedRecordId)
			.withLinkedType('GoogleFile__c')
			.withSource('Uploader')
			.withShareType('Viewer')
			.withVisibility('InternalUsers')
			.insertRecord();

		GoogleCloudTestFactory.link()
			.forFile(secondFile.Id)
			.withLinkedRecord(relatedRecordId)
			.withLinkedType('GoogleFile__c')
			.withShareType('Viewer')
			.withVisibility('InternalUsers')
			.insertRecord();

		Test.startTest();
		List<GoogleFile__c> files = GoogleCloudFilesController.retrieveGoogleFilesWithoutLimit(relatedRecordId, null);
		Test.stopTest();

		Assert.areEqual(2, files.size());
		Assert.areEqual(new Set<Id>{ firstFile.Id, secondFile.Id }, new Map<Id, GoogleFile__c>(files).keySet());
	}

	@IsTest
	private static void testRetrieveLocalGoogleFileByIdPositive() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c localFile = GoogleCloudTestFactory.file()
			.withName('RLF1')
			.withDescription('D')
			.insertRecord();

		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(new List<SObject>{
			new GoogleFile__c(Id = localFile.Id, Name = localFile.Name, OwnerId = UserInfo.getUserId())
		});

		Test.startTest();
		GoogleFile__c fileRecord = GoogleCloudFilesController.retrieveLocalGoogleFileById(localFile.Id);
		Test.stopTest();

		Assert.areNotEqual(null, fileRecord);
		Assert.areEqual(localFile.Id, fileRecord.Id);
	}

	@IsTest
	private static void testRetrieveLocalGoogleFileByIdNegativeNoAccess() {
		GoogleCloudTestFactory.initMocks();

		Id missingFileId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);

		try {
			Test.startTest();
			GoogleCloudFilesController.retrieveLocalGoogleFileById(missingFileId);
			Test.stopTest();
			Assert.fail('A file that does not exist must be refused');
		} catch (AuraHandledException ex) {
			Assert.isNotNull(ex);
		}
	}

	@IsTest
	private static void testRetrieveLocalGoogleFileVersionByIdPositive() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('RV1').withDescription('D').insertRecord();
		GoogleFileVersion__c fileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('V1.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId('GD1')
			.withDocsId('DOCS1')
			.insertRecord();

		GSOQL.mock(GoogleFileVersionSelector.MOCK_ID).thenReturn(new List<SObject>{
			new GoogleFileVersion__c(Id = fileVersion.Id, Name = fileVersion.Name, GoogleFileId__c = parentFile.Id)
		});

		Test.startTest();
		GoogleFileVersion__c outVersion = GoogleCloudFilesController.retrieveLocalGoogleFileVersionById(fileVersion.Id);
		Test.stopTest();

		Assert.areNotEqual(null, outVersion);
		Assert.areEqual(fileVersion.Id, outVersion.Id);
	}

	@IsTest
	private static void testSaveNewGoogleFilePositive() {
		GoogleCloudTestFactory.initMocks();
		GoogleFileCloudFolderJob.skipExecution = true;

		Id relatedRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);

		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(new List<SObject>{ new GoogleFile__c(Name = 'Any') });

		Test.startTest();
		GoogleCloudFilesController.saveNewGoogleFile(
			relatedRecordId, 'My.pdf', 'application/pdf', 123L, 'GD_NEW', 'FOLDER1', 'Notes & Attachments'
		);
		Test.stopTest();

		GoogleFileVersion__c savedVersion = [SELECT Name, Type__c, Size__c, GoogleDriveFileId__c, GoogleDriveFolderId__c, GoogleFileId__c, GoogleFileId__r.Name FROM GoogleFileVersion__c];
		GoogleFileLink__c savedLink = [SELECT GoogleFileId__c, LinkedObjectId__c, Source__c FROM GoogleFileLink__c];

		Assert.areEqual('My', savedVersion.GoogleFileId__r.Name);
		Assert.areEqual('My.pdf', savedVersion.Name);
		Assert.areEqual('application/pdf', savedVersion.Type__c);
		Assert.areEqual(123L, savedVersion.Size__c.longValue());
		Assert.areEqual('GD_NEW', savedVersion.GoogleDriveFileId__c);
		Assert.areEqual('FOLDER1', savedVersion.GoogleDriveFolderId__c);
		Assert.areEqual(savedVersion.GoogleFileId__c, savedLink.GoogleFileId__c);
		Assert.areEqual(String.valueOf(relatedRecordId), savedLink.LinkedObjectId__c);
		Assert.areEqual('Notes & Attachments', savedLink.Source__c);
	}

	@IsTest
	private static void testEnsureGoogleDriveFolderStructurePositive() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.queryContains('appProperties')
		).thenReturnStatus(200, '{"files":[]}');

		GoogleCloudTestFactory.initMocks(driveMock);

		GoogleClientConfig__mdt config = new GoogleClientConfig__mdt();
		config.DefaultGoogleUploadFolderId__c = 'ROOT_FOLDER_01';
		config.CustomGoogleUploadFolderStructure__c = '{Record}';
		GoogleMetadataConfigService.configRecordOverride = config;

		Id linkedRecordId = GoogleCloudTestFactory.linkedRecord('Controller Folder Record');

		Test.startTest();
		GoogleCloudFilesController.ensureGoogleDriveFolderStructure(linkedRecordId);
		Test.stopTest();

		Boolean recordFolderCreated = false;
		for (GoogleDriveHttpMock.CapturedRequest captured : driveMock.getCapturedRequests()) {
			if (captured.method == 'POST' && captured.body != null && captured.body.contains('ROOT_FOLDER_01') && captured.body.contains(String.valueOf(linkedRecordId))) {
				recordFolderCreated = true;
			}
		}
		Assert.isTrue(recordFolderCreated, 'The record folder must be created under the upload folder and carry the record it belongs to');
	}

	@IsTest
	private static void testSaveNewGoogleFileVersionPositive() {
		GoogleCloudTestFactory.initMocks();
		GoogleFileCloudFolderJob.skipExecution = true;

		GoogleFile__c baseFile = GoogleCloudTestFactory.file().withName('Base').withDescription('D').insertRecord();
		GoogleCloudTestFactory.version()
			.forFile(baseFile.Id)
			.withName('Old.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId('GD_OLD')
			.withDocsId('DOCS_OLD')
			.insertRecord();

		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(new List<SObject>{
			new GoogleFile__c(Id = baseFile.Id, Name = 'Base', OwnerId = UserInfo.getUserId())
		});

		Id relatedRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);

		Test.startTest();
		GoogleFile__c createdFile = GoogleCloudFilesController.saveNewGoogleFileVersion(
			relatedRecordId,
			baseFile.Id,
			'New.docx',
			'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
			10L,
			'GD_NEWVER',
			'FOLDER2',
			'UI'
		);
		Test.stopTest();

		Assert.areNotEqual(null, createdFile);
	}

	@IsTest
	private static void testDeleteExistingGoogleFilePositive() {
		GoogleCloudTestFactory.initMocks();
		GoogleFileCloudDeleteJob.skipExecution = true;

		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('DEL1').withDescription('D').insertRecord();
		GoogleCloudTestFactory.version()
			.forFile(localFile.Id)
			.withName('V1.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId('GD1')
			.withDocsId('DOCS1')
			.insertRecord();

		GSOQL.mock(GoogleFileVersionSelector.MOCK_ID).thenReturn(new List<SObject>{
			[
				SELECT Id, Name, GoogleDriveFolderId__c, IsLatestFile__c, PublicLink__c, PublicLinkExpirationDate__c, PublicLinkPermissionId__c,
					CreatedDate, LastModifiedDate, IsPreviewableFile__c, GoogleFileId__c, GoogleDriveFileId__c, GoogleDocsFileId__c, Type__c, Size__c, GoogleDocsFileSize__c, AiLabels__c, Summary__c
				FROM GoogleFileVersion__c
				WHERE GoogleFileId__c = :localFile.Id
			]
		});

		Test.startTest();
		GoogleCloudFilesController.deleteExistingGoogleFile(localFile.Id);
		Test.stopTest();

		Assert.areEqual(0, [SELECT count() FROM GoogleFile__c WHERE Id = :localFile.Id]);
	}

	@IsTest
	private static void testUploadFilePositive() {
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		GoogleFileEntity uploadedFile = GoogleCloudFilesController.uploadFile('hello.txt', 'aGVsbG8=');
		Test.stopTest();

		Assert.areNotEqual(null, uploadedFile);
	}

	@IsTest
	private static void testUploadLargeFilePartialPositive() {
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		GoogleBigFileEntity bigFileResult = GoogleCloudFilesController.uploadLargeFilePartial(
			'large.bin',
			'aGVsbG8=',
			'session1',
			0L,
			10L
		);
		Test.stopTest();

		Assert.areNotEqual(null, bigFileResult);
	}

	@IsTest
	private static void testRetrieveTransferLimitsPositiveSizedForTheRunningOrg() {
		GoogleCloudTestFactory.config().apply();

		Test.startTest();
		GoogleTransferLimitDTO limits = GoogleCloudFilesController.retrieveTransferLimits();
		Test.stopTest();

		GoogleTransferLimitResolver resolver = new GoogleTransferLimitResolver();
		Assert.areEqual(resolver.downloadChunkBytes(), limits.downloadChunkBytes);
		Assert.areEqual(resolver.uploadChunkBytes(), limits.uploadChunkBytes);
		Assert.areEqual(resolver.largeFileThresholdBytes(), limits.largeFileThresholdBytes);
		Assert.areEqual(resolver.largeFileThresholdBytes(), limits.maxPreviewFileSizeBytes, 'A blank Maximum Preview File Size follows the org');
		Assert.isTrue(limits.uploadChunkBytes <= limits.downloadChunkBytes, 'An upload request never carries more than a download request may');
	}

	@IsTest
	private static void testRetrieveTransferLimitsPositiveCarriesConfiguredPreviewSize() {
		GoogleCloudTestFactory.config().withBigFileSize(1048576L).apply();

		Test.startTest();
		GoogleTransferLimitDTO limits = GoogleCloudFilesController.retrieveTransferLimits();
		Test.stopTest();

		Assert.areEqual(1048576L, limits.maxPreviewFileSizeBytes, 'Download As must stop at the size the server stops at');
		Assert.areEqual(new GoogleTransferLimitResolver().largeFileThresholdBytes(), limits.largeFileThresholdBytes, 'A configured preview size never changes what one request can carry');
	}

	@IsTest
	private static void testRetrieveDownloadAsOptionsPositive() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(
			IsFilePreviewDisabled__c = false,
			DefaultBigFileSize__c = 1000L
		);

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('CTR_DA_1').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('Plan.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(50)
			.withDriveId('GD_CTR_DA_1')
			.withDocsId('DOCS_CTR_DA_1')
			.insertRecord();

		Test.startTest();
		List<GoogleFileDownloadAsOptionDTO> options = GoogleCloudFilesController.retrieveDownloadAsOptions(localFileVersion.Id);
		Test.stopTest();

		Assert.areEqual(8, options.size());
		Assert.areEqual('Plan.docx', options[0].fileName);
	}


	@IsTest
	private static void testDownloadFileAsPositive() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.endpointContains('/export')
		).thenReturn(
			new GoogleDriveHttpMock.MockResponse()
				.withStatus(200)
				.withHeader('Content-Type', 'text/plain')
				.withBodyAsBlob(Blob.valueOf('DOWNLOADED-AS-TEXT'))
		);

		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(
			IsFilePreviewDisabled__c = false,
			DefaultBigFileSize__c = 1000L
		);

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('CTR_DA_2').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('Plan.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(50)
			.withDriveId('GD_CTR_DA_2')
			.withDocsId('DOCS_CTR_DA_2')
			.insertRecord();

		Test.startTest();
		String base64Body = GoogleCloudFilesController.downloadFileAs(localFileVersion.Id, 'text/plain');
		Test.stopTest();

		Assert.areEqual(EncodingUtil.base64Encode(Blob.valueOf('DOWNLOADED-AS-TEXT')), base64Body);
	}

	@IsTest
	private static void testRetrieveAttachableOwnedGoogleFilesFiltersExistingLinks() {
		GoogleCloudTestFactory.initMocks();

		Id relatedRecordId = GoogleCloudTestFactory.linkedRecord('Attach Target');

		GoogleFile__c attachableFile = createOwnedFileRecord('Attachable File', UserInfo.getUserId(), 'GD_ATTACHABLE_1');
		GoogleFile__c linkedFile = createOwnedFileRecord('Linked File', UserInfo.getUserId(), 'GD_LINKED_1');

		GoogleCloudTestFactory.link()
			.forFile(linkedFile.Id)
			.withLinkedRecord(relatedRecordId)
			.withLinkedType('GoogleFile__c')
			.withShareType('Viewer')
			.withVisibility('InternalUsers')
			.insertRecord();

		Test.startTest();
		List<GoogleFile__c> attachableFiles = GoogleCloudFilesController.retrieveAttachableOwnedGoogleFiles(relatedRecordId);
		Test.stopTest();

		Assert.areEqual(1, attachableFiles.size());
		Assert.areEqual(attachableFile.Id, attachableFiles[0].Id);
		Assert.areEqual('Edit', attachableFiles[0].UserAccessLevel__c);
		Assert.areNotEqual(linkedFile.Id, attachableFiles[0].Id);
	}

	private static GoogleFile__c createOwnedFileRecord(String fileName, Id ownerId, String driveId) {
		return createOwnedFileRecord(fileName, ownerId, driveId, 'Notes & Attachments');
	}

	private static GoogleFile__c createOwnedFileRecord(String fileName, Id ownerId, String driveId, String source) {
		GoogleFile__c localFile = GoogleCloudTestFactory.file()
			.withName(fileName)
			.withDescription('D')
			.withSource(source)
			.withOwner(ownerId)
			.insertRecord();

		GoogleCloudTestFactory.version()
			.forFile(localFile.Id)
			.withName(fileName + '.pdf')
			.withType('application/pdf')
			.withSize(10L)
			.withDriveId(driveId)
			.insertRecord();

		return localFile;
	}

	@IsTest
	private static void testReadEndpointsNegativeRefuseAVersionTheUserCannotOpen() {
		GoogleCloudTestFactory.initMocks();
		Id unknownVersionId = GoogleCloudTestFactory.fakeId(GoogleFileVersion__c.SObjectType);

		Test.startTest();
		try {
			GoogleCloudFilesController.validateFilePreview(unknownVersionId);
			Assert.fail('Checking a preview must be refused');
		} catch (AuraHandledException ex) {
			Assert.isNotNull(ex);
		}

		try {
			GoogleCloudFilesController.retrieveLocalGoogleFileVersionById(unknownVersionId);
			Assert.fail('Reading a version must be refused');
		} catch (AuraHandledException ex) {
			Assert.isNotNull(ex);
		}

		try {
			GoogleCloudFilesController.downloadFile(unknownVersionId);
			Assert.fail('Downloading must be refused');
		} catch (AuraHandledException ex) {
			Assert.isNotNull(ex);
		}

		try {
			GoogleCloudFilesController.downloadFileAsPdf(unknownVersionId);
			Assert.fail('Downloading as PDF must be refused');
		} catch (AuraHandledException ex) {
			Assert.isNotNull(ex);
		}

		try {
			GoogleCloudFilesController.retrieveDownloadAsOptions(unknownVersionId);
			Assert.fail('Listing download formats must be refused');
		} catch (AuraHandledException ex) {
			Assert.isNotNull(ex);
		}

		try {
			GoogleCloudFilesController.downloadFileAs(unknownVersionId, 'text/plain');
			Assert.fail('Downloading in another format must be refused');
		} catch (AuraHandledException ex) {
			Assert.isNotNull(ex);
		}

		try {
			GoogleCloudFilesController.downloadLargeFilePartial(unknownVersionId, 0L, 10L);
			Assert.fail('Downloading part of a large file must be refused');
		} catch (AuraHandledException ex) {
			Assert.isNotNull(ex);
		}
		Test.stopTest();
	}

	@IsTest
	private static void testChangeEndpointsNegativeRefuseAFileTheUserCannotOpen() {
		GoogleCloudTestFactory.initMocks();
		Id unreachableFileId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);

		Test.startTest();
		try {
			GoogleCloudFilesController.saveNewGoogleFileVersion(GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType), unreachableFileId, 'New.pdf', 'application/pdf', 10L, 'GD_NEW', 'FOLDER', 'UI');
			Assert.fail('Adding a version to a file the user cannot open must be refused');
		} catch (AuraHandledException ex) {
			Assert.isNotNull(ex);
		}

		try {
			GoogleCloudFilesController.deleteExistingGoogleFile(unreachableFileId);
			Assert.fail('Deleting a file the user cannot open must be refused');
		} catch (AuraHandledException ex) {
			Assert.isNotNull(ex);
		}
		Test.stopTest();

		Assert.areEqual(0, [SELECT COUNT() FROM GoogleFileVersion__c], 'No version was added');
	}

	private static GoogleFile__c insertSearchCandidate(String fileName, String versionName, String mimeType, Long sizeBytes, Integer versionCount, Boolean isLinked) {
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName(fileName).insertRecord();
		List<GoogleFileVersion__c> versions = new List<GoogleFileVersion__c>();
		for (Integer i = 1; i <= versionCount; i++) {
			versions.add(GoogleCloudTestFactory.version()
				.forFile(localFile.Id)
				.withName(i == versionCount ? versionName : 'Old draft.pdf')
				.withType(mimeType)
				.withSize(sizeBytes)
				.isLatest(i == versionCount)
				.build());
		}
		
		insert versions;

		if (isLinked) {
			GoogleCloudTestFactory.link().forFile(localFile.Id).withShareType('Viewer').insertRecord();
		}

		return localFile;
	}

	private static String dayString(Date day) {
		return Datetime.newInstance(day, Time.newInstance(0, 0, 0, 0)).format('yyyy-MM-dd');
	}

	private static Set<Id> idsOf(List<GoogleFile__c> files) {
		return new Map<Id, GoogleFile__c>(files).keySet();
	}

	private static void mockExternalVisibilityPage(GoogleFile__c internalOnlyFile, GoogleFile__c everyoneFile) {
		GoogleCloudTestFactory.denyAllRecordAccess();
		GoogleCloudTestFactory.mockExternalUser();
		GoogleCloudTestFactory.mockNoGroupMemberships();
		Id readableRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleCloudTestFactory.grantRecordAccess(readableRecordId, true, false);

		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(new List<SObject>{ internalOnlyFile, everyoneFile });
		GoogleCloudTestFactory.mockLinks(new List<GoogleFileLink__c>{
			GoogleCloudTestFactory.link().forFile(internalOnlyFile.Id).withLinkedRecord(readableRecordId).withShareType('Viewer').withVisibility('InternalUsers').build(),
			GoogleCloudTestFactory.link().forFile(everyoneFile.Id).withLinkedRecord(readableRecordId).withShareType('Viewer').withVisibility('AllUsers').build()
		});
	}

	@IsTest
	private static void testSearchFileExplorerFilesPositiveRebuildsTheRequestFromPrimitives() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();
		String pdfType = GoogleCloudConstants.MIME_TYPE_PDF;

		GoogleFile__c match = insertSearchCandidate('Match', 'Renewal brief.pdf', pdfType, 2097152L, 2, true);
		GoogleFile__c createdEarlier = insertSearchCandidate('Created Earlier', 'Renewal brief.pdf', pdfType, 2097152L, 2, true);
		GoogleFile__c createdLater = insertSearchCandidate('Created Later', 'Renewal brief.pdf', pdfType, 2097152L, 2, true);
		List<GoogleFile__c> inRange = new List<GoogleFile__c>{
			match,
			insertSearchCandidate('No Phrase', 'Brief.pdf', pdfType, 2097152L, 2, true),
			insertSearchCandidate('Wrong Type', 'Renewal brief.txt', GoogleCloudConstants.MIME_TYPE_TEXT, 2097152L, 2, true),
			insertSearchCandidate('Too Small', 'Renewal brief.pdf', pdfType, 1000L, 2, true),
			insertSearchCandidate('Too Large', 'Renewal brief.pdf', pdfType, 20971520L, 2, true),
			insertSearchCandidate('Single Version', 'Renewal brief.pdf', pdfType, 2097152L, 1, true),
			insertSearchCandidate('Many Versions', 'Renewal brief.pdf', pdfType, 2097152L, 4, true),
			insertSearchCandidate('Unlinked', 'Renewal brief.pdf', pdfType, 2097152L, 2, false)
		};
		for (GoogleFile__c candidate : inRange) {
			Test.setCreatedDate(candidate.Id, Datetime.newInstance(2025, 3, 3, 12, 0, 0));
		}
		Test.setCreatedDate(createdEarlier.Id, Datetime.newInstance(2025, 2, 1, 12, 0, 0));
		Test.setCreatedDate(createdLater.Id, Datetime.newInstance(2025, 3, 10, 12, 0, 0));
		String currentDay = dayString(Date.today());
		String previousDay = dayString(Date.today().addDays(-1));

		Test.startTest();
		GoogleFileExplorerResultDTO mine = GoogleCloudFilesController.searchFileExplorerFiles('renewal', 'pdf;docx', 1048576L, 10485760L, '2025-03-01', '2025-03-05', currentDay, currentDay, 2, 3, 'mine', 'linked', 'fileName', 'ASC', null, 50);
		GoogleFileExplorerResultDTO others = GoogleCloudFilesController.searchFileExplorerFiles('renewal', 'pdf;docx', 1048576L, 10485760L, '2025-03-01', '2025-03-05', currentDay, currentDay, 2, 3, 'others', 'linked', 'fileName', 'ASC', null, 50);
		GoogleFileExplorerResultDTO changedBefore = GoogleCloudFilesController.searchFileExplorerFiles('renewal', 'pdf;docx', 1048576L, 10485760L, '2025-03-01', '2025-03-05', null, previousDay, 2, 3, 'mine', 'linked', 'fileName', 'ASC', null, 50);
		Test.stopTest();

		Assert.areEqual(1, mine.files.size(), 'Each value sent from the screen must reach the search');
		Assert.areEqual(match.Id, mine.files[0].Id);
		Assert.isTrue(others.files.isEmpty(), 'The ownership value must reach the search');
		Assert.isTrue(changedBefore.files.isEmpty(), 'The last modified range must reach the search');
	}

	@IsTest
	private static void testSearchFileExplorerFilesPositiveSortCursorAndPageSizeReachThePage() {
		GoogleCloudTestFactory.initMocks();

		GoogleCloudTestFactory.file().withName('Alpha').insertRecord();
		GoogleFile__c bravo = GoogleCloudTestFactory.file().withName('Bravo').insertRecord();
		GoogleFile__c charlie = GoogleCloudTestFactory.file().withName('Charlie').insertRecord();

		Test.startTest();
		GoogleFileExplorerResultDTO firstPage = GoogleCloudFilesController.searchFileExplorerFiles(null, null, null, null, null, null, null, null, null, null, null, null, 'fileName', 'DESC', null, 1);
		GoogleFileExplorerResultDTO secondPage = GoogleCloudFilesController.searchFileExplorerFiles(null, null, null, null, null, null, null, null, null, null, null, null, 'fileName', 'DESC', firstPage.nextCursor, 1);
		Test.stopTest();

		Assert.areEqual(1, firstPage.files.size());
		Assert.areEqual(charlie.Id, firstPage.files[0].Id);
		Assert.isTrue(firstPage.hasMore);
		Assert.isNotNull(firstPage.nextCursor, 'More files must come with a cursor');
		Assert.areEqual(1, secondPage.files.size());
		Assert.areEqual(bravo.Id, secondPage.files[0].Id);
	}

	@IsTest
	private static void testSearchFileExplorerFilesPositiveAllNullsListsEverything() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();

		GoogleFile__c withVersion = insertSearchCandidate('With Version', 'With version.pdf', GoogleCloudConstants.MIME_TYPE_PDF, 2097152L, 1, false);
		GoogleFile__c withoutVersion = GoogleCloudTestFactory.file().withName('Without Version').insertRecord();

		Test.startTest();
		GoogleFileExplorerResultDTO result = GoogleCloudFilesController.searchFileExplorerFiles(null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null);
		Test.stopTest();

		Assert.areEqual(new Set<Id>{ withVersion.Id, withoutVersion.Id }, idsOf(result.files), 'With nothing entered, Search lists every file the user can open');
		Assert.isFalse(result.hasMore);
	}

	@IsTest
	private static void testSearchFileExplorerFilesNegativeExternalUserSeesOnlyFilesForAllUsers() {
		GoogleCloudTestFactory.initMocks();
		GoogleFile__c internalOnlyFile = new GoogleFile__c(Id = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType), Name = 'Internal Only', OwnerId = GoogleCloudTestFactory.otherUserId());
		GoogleFile__c everyoneFile = new GoogleFile__c(Id = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType), Name = 'Everyone', OwnerId = GoogleCloudTestFactory.otherUserId());
		mockExternalVisibilityPage(internalOnlyFile, everyoneFile);

		Test.startTest();
		GoogleFileExplorerResultDTO result = GoogleCloudFilesController.searchFileExplorerFiles(null, null, null, null, null, null, null, null, null, null, null, null, 'fileName', 'ASC', null, 50);
		Test.stopTest();

		Assert.areEqual(1, result.files.size(), 'An external user only gets files shown to all users');
		Assert.areEqual(everyoneFile.Id, result.files[0].Id);
		Assert.areEqual('View', result.files[0].UserAccessLevel__c);
	}

	@IsTest
	private static void testSearchFileExplorerFilesNegativeViewAllFloorDoesNotReachExternalUsers() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.setPrivilegedFloor(GoogleFileAccessResolver.AccessLevel.Edit);
		GoogleFile__c internalOnlyFile = new GoogleFile__c(Id = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType), Name = 'Internal Only', OwnerId = GoogleCloudTestFactory.otherUserId());
		GoogleFile__c everyoneFile = new GoogleFile__c(Id = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType), Name = 'Everyone', OwnerId = GoogleCloudTestFactory.otherUserId());
		mockExternalVisibilityPage(internalOnlyFile, everyoneFile);

		Test.startTest();
		GoogleFileExplorerResultDTO result = GoogleCloudFilesController.searchFileExplorerFiles(null, null, null, null, null, null, null, null, null, null, null, null, 'fileName', 'ASC', null, 50);
		Test.stopTest();

		Assert.areEqual(1, result.files.size(), 'The Edit All floor must not open internal-only files to an external user');
		Assert.areEqual(everyoneFile.Id, result.files[0].Id);
		Assert.areEqual('View', result.files[0].UserAccessLevel__c, 'The floor is for internal users only');
	}

	@IsTest
	private static void testSearchFileExplorerFilesNegativeUnreadableValuesAreIgnored() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();

		GoogleFile__c withVersion = insertSearchCandidate('With Version', 'With version.pdf', GoogleCloudConstants.MIME_TYPE_PDF, 2097152L, 1, false);
		GoogleFile__c withoutVersion = GoogleCloudTestFactory.file().withName('Without Version').insertRecord();

		Test.startTest();
		GoogleFileExplorerResultDTO result = GoogleCloudFilesController.searchFileExplorerFiles('', '%;dw g', -1L, -5L, 'garbage', 'later', 'soon', 'never', -2, -1, 'everyone', 'maybe', 'notAColumn', 'sideways', 'not a cursor', -10);
		Test.stopTest();

		Assert.areEqual(new Set<Id>{ withVersion.Id, withoutVersion.Id }, idsOf(result.files), 'Values the search cannot read are ignored, not refused');
	}

	@IsTest
	private static void testRetrieveFileExplorerOwnersPositiveReturnsTheServicesOwners() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();

		insert new List<GoogleFile__c>{
			GoogleCloudTestFactory.file().withName('Owner Probe One').build(),
			GoogleCloudTestFactory.file().withName('Owner Probe Two').build()
		};
		String runningUserName = [SELECT Name FROM User WHERE Id = :UserInfo.getUserId()].Name;

		Test.startTest();
		List<GoogleFileOwnerDTO> owners = GoogleCloudFilesController.retrieveFileExplorerOwners();
		GoogleCloudTestFactory.setPrivilegedFloor(GoogleFileAccessResolver.AccessLevel.View);
		List<GoogleFileOwnerDTO> everyOwner = GoogleCloudFilesController.retrieveFileExplorerOwners();
		List<GoogleFileOwnerDTO> serviceOwners = new GoogleLocalFileService().retrieveFileExplorerOwners();
		Test.stopTest();

		Assert.areEqual(1, owners.size(), 'The running user owns both files, so they are the one owner');
		Assert.areEqual(UserInfo.getUserId(), owners[0].ownerId);
		Assert.areEqual(1, everyOwner.size(), 'One owner for a View All user too, however many files they own');
		Assert.areEqual(UserInfo.getUserId(), everyOwner[0].ownerId);
		Assert.areEqual(runningUserName, everyOwner[0].name);
		Assert.areEqual(serviceOwners.size(), everyOwner.size());
		Assert.areEqual(serviceOwners[0].ownerId, everyOwner[0].ownerId, 'The endpoint hands back what the service resolves');
		Assert.areEqual(serviceOwners[0].name, everyOwner[0].name);
	}
}