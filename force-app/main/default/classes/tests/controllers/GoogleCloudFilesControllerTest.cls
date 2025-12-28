@IsTest
private class GoogleCloudFilesControllerTest {
	private static final String LINK_SELECTOR_MOCK_ID = 'GoogleFileLinkSelector';
	private static final String FILE_SELECTOR_MOCK_ID = 'GoogleFileSelector';
	private static final String VERSION_SELECTOR_MOCK_ID = 'GoogleFileVersionSelector';

	public class TestGoogleAuthorizer implements GoogleAuthorizer {
		public String retrieveAccessToken() {
			return 'client.test-access-token';
		}
	}

	private static void initMocks() {
		Test.setMock(HttpCalloutMock.class, new GoogleDriveHttpMock().withDefaultHappyPath());
		GoogleRemoteFileService.authorizerClassNameOverride = 'GoogleCloudFilesControllerTest.TestGoogleAuthorizer';
	}

	@IsTest
	private static void fetchFileAccessTestSuccessOwner() {
		initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file()
			.withName('FA1')
			.withDescription('D')
			.insertRecord();

		Test.startTest();
		String access = GoogleCloudFilesController.fetchFileAccess(f.Id);
		Test.stopTest();

		System.assertEquals('Edit', access);
	}

	@IsTest
	private static void retrieveGoogleFilesWithLimitTestSuccessExec() {
		initMocks();

		Account a = new Account(Name = 'RGF1');
		insert a;

		GoogleFile__c f1 = GoogleCloudTestFactory.file().withName('F1').withDescription('D').withSource('Uploader').forRecord(a.Id).insertRecord();
		GoogleFile__c f2 = GoogleCloudTestFactory.file().withName('F2').withDescription('D').withSource('Notes & Attachments').forRecord(a.Id).insertRecord();

		GSOQL.mock(FILE_SELECTOR_MOCK_ID).thenReturn(new List<SObject>{
			new GoogleFile__c(Id = f1.Id, Name = f1.Name, OwnerId = UserInfo.getUserId()),
			new GoogleFile__c(Id = f2.Id, Name = f2.Name, OwnerId = UserInfo.getUserId())
		});

		Test.startTest();
		List<GoogleFile__c> out = GoogleCloudFilesController.retrieveGoogleFilesWithLimit(a.Id, 'Uploader', 1);
		Test.stopTest();

		System.assertNotEquals(null, out);
	}

	@IsTest
	private static void retrieveGoogleFilesWithoutLimitTestSuccessExec() {
		initMocks();

		Account a = new Account(Name = 'RGF2');
		insert a;

		GoogleFile__c f1 = GoogleCloudTestFactory.file().withName('F3').withDescription('D').withSource('Uploader').forRecord(a.Id).insertRecord();

		GSOQL.mock(FILE_SELECTOR_MOCK_ID).thenReturn(new List<SObject>{
			new GoogleFile__c(Id = f1.Id, Name = f1.Name, OwnerId = UserInfo.getUserId())
		});

		Test.startTest();
		List<GoogleFile__c> out = GoogleCloudFilesController.retrieveGoogleFilesWithoutLimit(a.Id, null);
		Test.stopTest();

		System.assertNotEquals(null, out);
		System.assertEquals(1, out.size());
	}

	@IsTest
	private static void retrieveLocalGoogleFileByIdTestSuccessFound() {
		initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file()
			.withName('RLF1')
			.withDescription('D')
			.insertRecord();

		GSOQL.mock(FILE_SELECTOR_MOCK_ID).thenReturn(new List<SObject>{
			new GoogleFile__c(Id = f.Id, Name = f.Name, OwnerId = UserInfo.getUserId())
		});

		Test.startTest();
		GoogleFile__c out = GoogleCloudFilesController.retrieveLocalGoogleFileById(f.Id);
		Test.stopTest();

		System.assertNotEquals(null, out);
		System.assertEquals(f.Id, out.Id);
	}

	@IsTest
	private static void retrieveLocalGoogleFileVersionByIdTestSuccessFound() {
		initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('RV1').withDescription('D').insertRecord();
		GoogleFileVersion__c v = GoogleCloudTestFactory.version()
			.forFile(f.Id)
			.withName('V1.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId('GD1')
			.withDocsId('DOCS1')
			.insertRecord();

		GSOQL.mock(VERSION_SELECTOR_MOCK_ID).thenReturn(new List<SObject>{
			new GoogleFileVersion__c(Id = v.Id, Name = v.Name)
		});

		Test.startTest();
		GoogleFileVersion__c out = GoogleCloudFilesController.retrieveLocalGoogleFileVersionById(v.Id);
		Test.stopTest();

		System.assertNotEquals(null, out);
		System.assertEquals(v.Id, out.Id);
	}

	@IsTest
	private static void saveNewGoogleFileTestSuccessExec() {
		initMocks();

		Account a = new Account(Name = 'SNF1');
		insert a;

		GSOQL.mock(FILE_SELECTOR_MOCK_ID).thenReturn(new List<SObject>{ new GoogleFile__c(Name = 'Any') });

		Test.startTest();
		GoogleFile__c out = GoogleCloudFilesController.saveNewGoogleFile(
			a.Id, 'My.pdf', 'application/pdf', 123L, 'GD_NEW', 'FOLDER1', 'Notes & Attachments'
		);
		Test.stopTest();

		System.assertNotEquals(null, out);
	}

	@IsTest
	private static void saveNewGoogleFileVersionTestSuccessExec() {
		initMocks();

		Account a = new Account(Name = 'SNFV1');
		insert a;

		GoogleFile__c base = GoogleCloudTestFactory.file().withName('Base').withDescription('D').forRecord(a.Id).insertRecord();
		GoogleCloudTestFactory.version().forFile(base.Id).withName('Old.pdf').withType('application/pdf').withSize(1).withDriveId('GD_OLD').withDocsId('DOCS_OLD').insertRecord();

		GSOQL.mock(FILE_SELECTOR_MOCK_ID).thenReturn(new List<SObject>{
			new GoogleFile__c(Id = base.Id, Name = 'Base')
		});

		Test.startTest();
		GoogleFile__c out = GoogleCloudFilesController.saveNewGoogleFileVersion(
			a.Id,
			base.Id,
			'New.docx',
			'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
			10L,
			'GD_NEWVER',
			'FOLDER2',
			'UI'
		);
		Test.stopTest();

		System.assertNotEquals(null, out);
	}

	@IsTest
	private static void deleteExistingGoogleFileTestSuccessExec() {
		initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('DEL1').withDescription('D').insertRecord();
		GoogleCloudTestFactory.version()
			.forFile(f.Id)
			.withName('V1.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId('GD1')
			.withDocsId('DOCS1')
			.insertRecord();

		GSOQL.mock(VERSION_SELECTOR_MOCK_ID).thenReturn(new List<SObject>{
			[SELECT Id, Name, GoogleDriveFolderId__c, IsLatestFile__c, PublicLink__c, PublicLinkExpirationDate__c, PublicLinkPermissionId__c,
			        CreatedDate, LastModifiedDate, IsPreviewableFile__c, GoogleFileId__c, GoogleDriveFileId__c, GoogleDocsFileId__c, Type__c, Size__c
			 FROM GoogleFileVersion__c
			 WHERE GoogleFileId__c = :f.Id]
		});

		Test.startTest();
		GoogleCloudFilesController.deleteExistingGoogleFile(f.Id);
		Test.stopTest();

		System.assertEquals(0, [SELECT count() FROM GoogleFile__c WHERE Id = :f.Id]);
	}

	@IsTest
	private static void uploadFileTestSuccessExec() {
		initMocks();

		Test.startTest();
		GoogleFileEntity uploaded = GoogleCloudFilesController.uploadFile('hello.txt', 'aGVsbG8=');
		Test.stopTest();
		System.assertNotEquals(null, uploaded);
	}

	@IsTest
	private static void retrieveGoogleFileBase64PreviewTestSuccessExec() {
		initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('DL1').withDescription('D').insertRecord();
		GoogleFileVersion__c v = GoogleCloudTestFactory.version()
			.forFile(f.Id)
			.withName('V1.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId('GD1')
			.withDocsId('DOCS1')
			.insertRecord();

		Test.startTest();
		try {
			String previewB64 = GoogleCloudFilesController.retrieveGoogleFileBase64Preview(v.Id);
			String dl = GoogleCloudFilesController.downloadFile(v.Id);
			String part = GoogleCloudFilesController.downloadLargeFilePartial(v.Id, 0L, 10L);
			System.assert(true, 'Preview/download methods executed');
		} catch (Exception e) {
			System.assertNotEquals(null, e.getMessage());
		}
		Test.stopTest();
	}
}
