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
		List<GoogleFile__c> allFiles = GoogleCloudFilesController.retrieveAllGoogleFiles();
		Test.stopTest();

		System.assertNotEquals(null, allFiles);
	}

	@IsTest
	private static void testRetrieveGoogleFilesWithLimitPositive() {
		GoogleCloudTestFactory.initMocks();

		Id relatedAccountId = GoogleCloudTestFactory.fakeId(Account.SObjectType);

		GoogleFile__c firstFile = GoogleCloudTestFactory.file()
			.withName('F1')
			.withDescription('D')
			.withSource('Uploader')
			.insertRecord();

		GoogleFile__c secondFile = GoogleCloudTestFactory.file()
			.withName('F2')
			.withDescription('D')
			.withSource('Notes & Attachments')
			.insertRecord();

		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(new List<SObject>{
			new GoogleFile__c(Id = firstFile.Id, Name = firstFile.Name, OwnerId = UserInfo.getUserId()),
			new GoogleFile__c(Id = secondFile.Id, Name = secondFile.Name, OwnerId = UserInfo.getUserId())
		});

		Test.startTest();
		List<GoogleFile__c> files = GoogleCloudFilesController.retrieveGoogleFilesWithLimit(relatedAccountId, 'Uploader', 1);
		Test.stopTest();

		System.assertNotEquals(null, files);
	}

	@IsTest
	private static void testRetrieveGoogleFilesWithoutLimitPositive() {
		GoogleCloudTestFactory.initMocks();

		Id relatedAccountId = GoogleCloudTestFactory.fakeId(Account.SObjectType);

		GoogleFile__c fileRecord = GoogleCloudTestFactory.file()
			.withName('F3')
			.withDescription('D')
			.withSource('Uploader')
			.insertRecord();

		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(new List<SObject>{
			new GoogleFile__c(Id = fileRecord.Id, Name = fileRecord.Name, OwnerId = UserInfo.getUserId())
		});

		Test.startTest();
		List<GoogleFile__c> files = GoogleCloudFilesController.retrieveGoogleFilesWithoutLimit(relatedAccountId, null);
		Test.stopTest();

		System.assertNotEquals(null, files);
		System.assertEquals(1, files.size());
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
					CreatedDate, LastModifiedDate, IsPreviewableFile__c, GoogleFileId__c, GoogleDriveFileId__c, GoogleDocsFileId__c, Type__c, Size__c
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
}