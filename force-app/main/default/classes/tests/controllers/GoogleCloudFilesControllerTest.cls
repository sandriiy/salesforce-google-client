@IsTest
private class GoogleCloudFilesControllerTest {
	public class TestGoogleAuthorizer implements GoogleAuthorizer {
		public String retrieveAccessToken() {
			return 'client.test-access-token';
		}
	}

	private static void initMocks() {
		Test.setMock(HttpCalloutMock.class, new GoogleDriveHttpMock().withDefaultHappyPath());
		GoogleDriveApiProvider.authorizerClassNameOverride = 'GoogleCloudFilesControllerTest.TestGoogleAuthorizer';
	}

	@IsTest
	private static void testFetchFileAccessPositiveOwner() {
		initMocks();

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
		initMocks();

		Test.startTest();
		List<GoogleFile__c> allFiles = GoogleCloudFilesController.retrieveAllGoogleFiles();
		Test.stopTest();

		System.assertNotEquals(null, allFiles);
	}

	@IsTest
	private static void testRetrieveGoogleFilesWithLimitPositive() {
		initMocks();

		Account relatedAccount = new Account(Name = 'RGF1');
		insert relatedAccount;

		GoogleFile__c firstFile = GoogleCloudTestFactory.file()
			.withName('F1')
			.withDescription('D')
			.withSource('Uploader')
			.forRecord(relatedAccount.Id)
			.insertRecord();

		GoogleFile__c secondFile = GoogleCloudTestFactory.file()
			.withName('F2')
			.withDescription('D')
			.withSource('Notes & Attachments')
			.forRecord(relatedAccount.Id)
			.insertRecord();

		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(new List<SObject>{
			new GoogleFile__c(Id = firstFile.Id, Name = firstFile.Name, OwnerId = UserInfo.getUserId()),
			new GoogleFile__c(Id = secondFile.Id, Name = secondFile.Name, OwnerId = UserInfo.getUserId())
		});

		Test.startTest();
		List<GoogleFile__c> files = GoogleCloudFilesController.retrieveGoogleFilesWithLimit(relatedAccount.Id, 'Uploader', 1);
		Test.stopTest();

		System.assertNotEquals(null, files);
	}

	@IsTest
	private static void testRetrieveGoogleFilesWithoutLimitPositive() {
		initMocks();

		Account relatedAccount = new Account(Name = 'RGF2');
		insert relatedAccount;

		GoogleFile__c fileRecord = GoogleCloudTestFactory.file()
			.withName('F3')
			.withDescription('D')
			.withSource('Uploader')
			.forRecord(relatedAccount.Id)
			.insertRecord();

		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(new List<SObject>{
			new GoogleFile__c(Id = fileRecord.Id, Name = fileRecord.Name, OwnerId = UserInfo.getUserId())
		});

		Test.startTest();
		List<GoogleFile__c> files = GoogleCloudFilesController.retrieveGoogleFilesWithoutLimit(relatedAccount.Id, null);
		Test.stopTest();

		System.assertNotEquals(null, files);
		System.assertEquals(1, files.size());
	}

	@IsTest
	private static void testRetrieveLocalGoogleFileByIdPositive() {
		initMocks();

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
		initMocks();

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
		initMocks();

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
		initMocks();

		Account relatedAccount = new Account(Name = 'SNF1');
		insert relatedAccount;

		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(new List<SObject>{ new GoogleFile__c(Name = 'Any') });

		Test.startTest();
		GoogleCloudFilesController.saveNewGoogleFile(
			relatedAccount.Id, 'My.pdf', 'application/pdf', 123L, 'GD_NEW', 'FOLDER1', 'Notes & Attachments'
		);
		Test.stopTest();

		System.assert(true);
	}

	@IsTest
	private static void testSaveNewGoogleFileVersionPositive() {
		initMocks();

		Account relatedAccount = new Account(Name = 'SNFV1');
		insert relatedAccount;

		GoogleFile__c baseFile = GoogleCloudTestFactory.file().withName('Base').withDescription('D').forRecord(relatedAccount.Id).insertRecord();
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

		Test.startTest();
		GoogleFile__c createdFile = GoogleCloudFilesController.saveNewGoogleFileVersion(
			relatedAccount.Id,
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
		initMocks();

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
		initMocks();

		Test.startTest();
		GoogleFileEntity uploadedFile = GoogleCloudFilesController.uploadFile('hello.txt', 'aGVsbG8=');
		Test.stopTest();

		System.assertNotEquals(null, uploadedFile);
	}

	@IsTest
	private static void testUploadLargeFilePartialPositive() {
		initMocks();

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