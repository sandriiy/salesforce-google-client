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

		System.assertEquals('Edit', accessLevel);
	}

	@IsTest
	private static void testRetrieveAllGoogleFilesPositive() {
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		GoogleFileExplorerResultDTO result = GoogleCloudFilesController.retrieveAllGoogleFiles();
		Test.stopTest();

		System.assertNotEquals(null, result.files);
	}

	@IsTest
	private static void testRetrieveFileExplorerColumnsPositiveDefault() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(
			FileExplorerColumns__c = null
		);

		Test.startTest();
		List<GoogleFileColumnDTO> columns = GoogleCloudFilesController.retrieveFileExplorerColumns();
		Test.stopTest();

		System.assertEquals(5, columns.size());
		System.assertEquals('title', columns[0].key);
	}

	@IsTest
	private static void testRetrieveFileExplorerColumnsPositiveConfigured() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(
			FileExplorerColumns__c = 'title;summary'
		);

		Test.startTest();
		List<GoogleFileColumnDTO> columns = GoogleCloudFilesController.retrieveFileExplorerColumns();
		Test.stopTest();

		System.assertEquals(2, columns.size());
		System.assertEquals('summary', columns[1].key);
	}

	@IsTest
	private static void testRetrieveGoogleFilesWithLimitPositive() {
		GoogleCloudTestFactory.initMocks();

		Account relatedAccount = new Account(Name = 'Related Account');
		insert relatedAccount;

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
			.withLinkedRecord(relatedAccount.Id)
			.withLinkedType('Account')
			.withSource('Notes & Attachments')
			.withShareType('Viewer')
			.withVisibility('InternalUsers')
			.insertRecord();

		GoogleCloudTestFactory.link()
			.forFile(secondFile.Id)
			.withLinkedRecord(relatedAccount.Id)
			.withLinkedType('Account')
			.withSource('Uploader')
			.withShareType('Viewer')
			.withVisibility('InternalUsers')
			.insertRecord();

		Test.startTest();
		List<GoogleFile__c> files = GoogleCloudFilesController.retrieveGoogleFilesWithLimit(relatedAccount.Id, 'Notes & Attachments', 1);
		Test.stopTest();

		Assert.areEqual(1, files.size());
		Assert.areEqual(firstFile.Id, files[0].Id);
	}

	@IsTest
	private static void testRetrieveGoogleFilesWithLimitFallsBackToPrimarySource() {
		GoogleCloudTestFactory.initMocks();

		Account relatedAccount = new Account(Name = 'Fallback Account');
		insert relatedAccount;

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
			.withLinkedRecord(relatedAccount.Id)
			.withLinkedType('Account')
			.withShareType('Viewer')
			.withVisibility('InternalUsers')
			.insertRecord();

		GoogleCloudTestFactory.link()
			.forFile(secondFile.Id)
			.withLinkedRecord(relatedAccount.Id)
			.withLinkedType('Account')
			.withShareType('Viewer')
			.withVisibility('InternalUsers')
			.insertRecord();

		Test.startTest();
		List<GoogleFile__c> files = GoogleCloudFilesController.retrieveGoogleFilesWithLimit(relatedAccount.Id, 'Uploader', 5);
		Test.stopTest();

		Assert.areEqual(1, files.size());
		Assert.areEqual(firstFile.Id, files[0].Id);
	}

	@IsTest
	private static void testRetrieveGoogleFilesWithoutLimitPositive() {
		GoogleCloudTestFactory.initMocks();

		Account relatedAccount = new Account(Name = 'All Linked Account');
		insert relatedAccount;

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
			.withLinkedRecord(relatedAccount.Id)
			.withLinkedType('Account')
			.withSource('Uploader')
			.withShareType('Viewer')
			.withVisibility('InternalUsers')
			.insertRecord();

		GoogleCloudTestFactory.link()
			.forFile(secondFile.Id)
			.withLinkedRecord(relatedAccount.Id)
			.withLinkedType('Account')
			.withShareType('Viewer')
			.withVisibility('InternalUsers')
			.insertRecord();

		Test.startTest();
		List<GoogleFile__c> files = GoogleCloudFilesController.retrieveGoogleFilesWithoutLimit(relatedAccount.Id, null);
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

		System.assertNotEquals(null, fileRecord);
		System.assertEquals(localFile.Id, fileRecord.Id);
	}

	@IsTest
	private static void testRetrieveLocalGoogleFileByIdNegativeNoAccess() {
		GoogleCloudTestFactory.initMocks();

		Id missingFileId = (Id) 'a0B000000000001AAA';

		try {
			Test.startTest();
			GoogleCloudFilesController.retrieveLocalGoogleFileById(missingFileId);
			Test.stopTest();
			System.assert(false);
		} catch (Exception ex) {
			System.assert(String.isNotBlank(ex.getMessage()));
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
			new GoogleFileVersion__c(Id = fileVersion.Id, Name = fileVersion.Name)
		});

		Test.startTest();
		GoogleFileVersion__c outVersion = GoogleCloudFilesController.retrieveLocalGoogleFileVersionById(fileVersion.Id);
		Test.stopTest();

		System.assertNotEquals(null, outVersion);
		System.assertEquals(fileVersion.Id, outVersion.Id);
	}

	@IsTest
	private static void testSaveNewGoogleFilePositive() {
		GoogleCloudTestFactory.initMocks();
		GoogleFileCloudFolderJob.skipExecution = true;

		Id relatedAccountId = GoogleCloudTestFactory.fakeId(Account.SObjectType);

		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(new List<SObject>{ new GoogleFile__c(Name = 'Any') });

		Test.startTest();
		GoogleCloudFilesController.saveNewGoogleFile(
			relatedAccountId, 'My.pdf', 'application/pdf', 123L, 'GD_NEW', 'FOLDER1', 'Notes & Attachments'
		);
		Test.stopTest();

		System.assert(true);
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

		Account linkedRecord = new Account(Name = 'Controller Folder Account');
		insert linkedRecord;

		Test.startTest();
		GoogleCloudFilesController.ensureGoogleDriveFolderStructure(linkedRecord.Id);
		Test.stopTest();

		System.assert(true);
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
			new GoogleFile__c(Id = baseFile.Id, Name = 'Base')
		});

		Id relatedAccountId = GoogleCloudTestFactory.fakeId(Account.SObjectType);

		Test.startTest();
		GoogleFile__c createdFile = GoogleCloudFilesController.saveNewGoogleFileVersion(
			relatedAccountId,
			baseFile.Id,
			'New.docx',
			'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
			10L,
			'GD_NEWVER',
			'FOLDER2',
			'UI'
		);
		Test.stopTest();

		System.assertNotEquals(null, createdFile);
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
					CreatedDate, LastModifiedDate, IsPreviewableFile__c, GoogleFileId__c, GoogleDriveFileId__c, GoogleDocsFileId__c, Type__c, Size__c, Summary__c
				FROM GoogleFileVersion__c
				WHERE GoogleFileId__c = :localFile.Id
			]
		});

		Test.startTest();
		GoogleCloudFilesController.deleteExistingGoogleFile(localFile.Id);
		Test.stopTest();

		System.assertEquals(0, [SELECT count() FROM GoogleFile__c WHERE Id = :localFile.Id]);
	}

	@IsTest
	private static void testUploadFilePositive() {
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		GoogleFileEntity uploadedFile = GoogleCloudFilesController.uploadFile('hello.txt', 'aGVsbG8=');
		Test.stopTest();

		System.assertNotEquals(null, uploadedFile);
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

		System.assertNotEquals(null, bigFileResult);
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
	private static void testRetrieveAttachableOwnedGoogleFilesFiltersExistingLinksAndNonOwnedFiles() {
		GoogleCloudTestFactory.initMocks();

		User otherOwner = GoogleCloudTestFactory.newUser();
		Account relatedAccount = new Account(Name = 'Attach Target');
		insert relatedAccount;

		GoogleFile__c attachableFile = createOwnedFileRecord('Attachable File', UserInfo.getUserId(), 'GD_ATTACHABLE_1');
		GoogleFile__c linkedFile = createOwnedFileRecord('Linked File', UserInfo.getUserId(), 'GD_LINKED_1');
		GoogleFile__c foreignFile = createOwnedFileRecord('Foreign File', otherOwner.Id, 'GD_FOREIGN_1');

		GoogleCloudTestFactory.link()
			.forFile(linkedFile.Id)
			.withLinkedRecord(relatedAccount.Id)
			.withLinkedType('Account')
			.withShareType('Viewer')
			.withVisibility('InternalUsers')
			.insertRecord();

		Test.startTest();
		List<GoogleFile__c> attachableFiles = GoogleCloudFilesController.retrieveAttachableOwnedGoogleFiles(relatedAccount.Id);
		Test.stopTest();

		Assert.areEqual(1, attachableFiles.size());
		Assert.areEqual(attachableFile.Id, attachableFiles[0].Id);
		Assert.areEqual('Edit', attachableFiles[0].UserAccessLevel__c);
		Assert.areNotEqual(foreignFile.Id, attachableFiles[0].Id);
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
}