@IsTest
private class GoogleLocalFileServiceTest {
	public class TestGoogleAuthorizer implements GoogleAuthorizer {
		public String retrieveAccessToken() {
			return 'client.test-access-token';
		}
	}

	private static void initMocks() {
		Test.setMock(HttpCalloutMock.class, new GoogleDriveHttpMock().withDefaultHappyPath());
		GoogleDriveApiProvider.authorizerClassNameOverride = 'GoogleLocalFileServiceTest.TestGoogleAuthorizer';
	}

	private static void coverFactories() {
		GoogleLocalFileService localFileService = new GoogleLocalFileService();
		System.assertNotEquals(null, localFileService.deleteGoogleFileRecord());
		System.assertNotEquals(null, localFileService.retrieveGoogleFileHeaderDetails());
		System.assertNotEquals(null, localFileService.stripInaccessibleRecords());
	}

	@IsTest
	private static void testStripPositiveOwner() {
		initMocks();
		coverFactories();

		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('F1').withDescription('D').insertRecord();
		List<GoogleFile__c> visibleFiles = new GoogleFileAccessCheckCommand().forFile(localFile.Id).forUser(UserInfo.getUserId()).strip();

		System.assertEquals(1, visibleFiles.size());
		System.assertEquals('Edit', visibleFiles[0].UserAccessLevel__c);
	}

	@IsTest
	private static void testStripPositiveShareView() {
		initMocks();
		coverFactories();

		User targetUser = GoogleCloudTestFactory.newUser();
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('F2').withDescription('D').insertRecord();

		GoogleFile__Share shareRecord = new GoogleFile__Share(
			ParentId = localFile.Id,
			UserOrGroupId = targetUser.Id,
			AccessLevel = 'Read',
			RowCause = Schema.GoogleFile__Share.RowCause.Manual
		);
		insert shareRecord;

		List<GoogleFile__c> visibleFiles = new GoogleFileAccessCheckCommand()
			.forFile(new GoogleFile__c(Id = localFile.Id))
			.forUser(targetUser.Id)
			.strip();

		System.assertEquals(1, visibleFiles.size());
		System.assertEquals('View', visibleFiles[0].UserAccessLevel__c);
	}

	@IsTest
	private static void testStripPositiveShareEdit() {
		initMocks();
		coverFactories();

		User targetUser = GoogleCloudTestFactory.newUser();
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('F3').withDescription('D').insertRecord();

		GoogleFile__Share shareRecord = new GoogleFile__Share(
			ParentId = localFile.Id,
			UserOrGroupId = targetUser.Id,
			AccessLevel = 'Edit',
			RowCause = Schema.GoogleFile__Share.RowCause.Manual
		);
		insert shareRecord;

		List<GoogleFile__c> visibleFiles = new GoogleFileAccessCheckCommand().forFile(localFile).forUser(targetUser.Id).strip();

		System.assertEquals(1, visibleFiles.size());
		System.assertEquals('Edit', visibleFiles[0].UserAccessLevel__c);
	}

	@IsTest
	private static void testStripPositiveLinkView() {
		initMocks();
		coverFactories();

		User targetUser = GoogleCloudTestFactory.newUser();
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('F4').withDescription('D').insertRecord();

		GoogleCloudTestFactory.link().forFile(localFile.Id).withShareType('Viewer').withVisibility('AllUsers').insertRecord();

		List<GoogleFileLink__c> fileLinks = [
			SELECT Id, Name, GoogleFileId__c, LinkedObjectName__c, LinkedObjectId__c, LinkedObjectType__c, ShareType__c, Visibility__c
			FROM GoogleFileLink__c
			WHERE GoogleFileId__c = :localFile.Id
		];
		GSOQL.mock(GoogleFileLinkSelector.MOCK_ID).thenReturn(fileLinks);

		List<GoogleFile__c> visibleFiles = new GoogleFileAccessCheckCommand().forFile(localFile.Id).forUser(targetUser.Id).strip();

		System.assertEquals(1, visibleFiles.size());
		System.assertEquals('View', visibleFiles[0].UserAccessLevel__c);
	}

	@IsTest
	private static void testStripPositiveLinkEdit() {
		initMocks();
		coverFactories();

		User targetUser = GoogleCloudTestFactory.newUser();
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('F5').withDescription('D').insertRecord();

		GoogleCloudTestFactory.link().forFile(localFile.Id).withShareType('Collaborator').withVisibility('InternalUsers').insertRecord();

		List<GoogleFileLink__c> fileLinks = [
			SELECT Id, Name, GoogleFileId__c, LinkedObjectName__c, LinkedObjectId__c, LinkedObjectType__c, ShareType__c, Visibility__c
			FROM GoogleFileLink__c
			WHERE GoogleFileId__c = :localFile.Id
		];
		GSOQL.mock(GoogleFileLinkSelector.MOCK_ID).thenReturn(fileLinks);

		List<GoogleFile__c> visibleFiles = new GoogleFileAccessCheckCommand()
			.forFile(new GoogleFile__c(Id = localFile.Id))
			.forUser(targetUser.Id)
			.strip();

		System.assertEquals(1, visibleFiles.size());
		System.assertEquals('Edit', visibleFiles[0].UserAccessLevel__c);
	}

	@IsTest
	private static void testStripPositiveInferred() {
		initMocks();
		coverFactories();

		User targetUser = GoogleCloudTestFactory.newUser();
		Account linkedAccount = new Account(Name = 'A1', OwnerId = targetUser.Id);
		insert linkedAccount;

		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('F6').withDescription('D').insertRecord();

		GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withShareType('InferredFromRecord')
			.withVisibility('AllUsers')
			.withLinkedRecord(linkedAccount.Id)
			.withLinkedType('Account')
			.insertRecord();

		List<GoogleFileLink__c> fileLinks = [
			SELECT Id, Name, GoogleFileId__c, LinkedObjectName__c, LinkedObjectId__c, LinkedObjectType__c, ShareType__c, Visibility__c
			FROM GoogleFileLink__c
			WHERE GoogleFileId__c = :localFile.Id
		];
		GSOQL.mock(GoogleFileLinkSelector.MOCK_ID).thenReturn(fileLinks);

		List<GoogleFile__c> visibleFiles = new GoogleFileAccessCheckCommand().forFile(localFile.Id).forUser(targetUser.Id).strip();

		System.assertEquals(1, visibleFiles.size());
		System.assertEquals('Edit', visibleFiles[0].UserAccessLevel__c);
	}

	@IsTest
	private static void testStripPositiveEmpty() {
		initMocks();
		coverFactories();

		List<GoogleFile__c> visibleFiles = new GoogleFileAccessCheckCommand().forFiles(new List<GoogleFile__c>()).strip();
		System.assertEquals(0, visibleFiles.size());
	}

	@IsTest
	private static void testStripNegativeUserMissing() {
		initMocks();
		coverFactories();

		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('F8').withDescription('D').insertRecord();
		Id missingUserId = (Id)('005000000000000AAA');

		try {
			new GoogleFileAccessCheckCommand().forFile(localFile.Id).forUser(missingUserId).strip();
			System.assert(false);
		} catch (GoogleFileAccessCheckCommand.GoogleFileAccessCheckException ex) {
			System.assert(ex.getMessage().contains('Target user was not found'));
		}
	}

	@IsTest
	private static void testDeletePositiveLocalOnly() {
		initMocks();
		coverFactories();

		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('Del1').withDescription('D').insertRecord();
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
		Boolean deleteResult = new GoogleLocalFileService().deleteGoogleFileRecord().setRecordId(localFile.Id).setCloudDeletion(false).save();
		Test.stopTest();

		System.assertEquals(true, deleteResult);
		System.assertEquals(0, [SELECT count() FROM GoogleFile__c WHERE Id = :localFile.Id]);
		System.assertEquals(0, [SELECT count() FROM GoogleFileVersion__c WHERE GoogleFileId__c = :localFile.Id]);
	}

	@IsTest
	private static void testDeletePositiveWithCloud() {
		initMocks();
		coverFactories();

		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('Del2').withDescription('D').insertRecord();
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
		Boolean deleteResult = new GoogleLocalFileService().deleteGoogleFileRecord().setRecordId(localFile.Id).setCloudDeletion(true).save();
		Test.stopTest();

		System.assertEquals(true, deleteResult);
		System.assertEquals(0, [SELECT count() FROM GoogleFile__c WHERE Id = :localFile.Id]);
		System.assertEquals(0, [SELECT count() FROM GoogleFileVersion__c WHERE GoogleFileId__c = :localFile.Id]);
	}

	@IsTest
	private static void testCreatePositiveNew() {
		initMocks();
		coverFactories();

		Account parentRecord = new Account(Name = 'R1');
		insert parentRecord;

		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(new List<SObject>{ new GoogleFile__c(Name = 'Any') });

		GoogleFileCreateRequestDTO request = new GoogleFileCreateRequestDTO();
		request.recordId = parentRecord.Id;
		request.googleDriveId = 'GD_NEW';
		request.fileName = 'MyVeryLongName_' + String.valueOf(Crypto.getRandomLong()) + '.pdf';
		request.fileType = 'application/pdf';
		request.fileSize = 123L;
		request.parentFolderId = 'FOLDER1';
		request.source = 'Notes & Attachments';
		request.localGoogleFileId = null;

		Test.startTest();
		new GoogleLocalFileService().createGoogleFileRecord(request);
		Test.stopTest();

		System.assert(true);
	}

	@IsTest
	private static void testCreatePositiveVersion() {
		initMocks();
		coverFactories();

		GoogleFile__c existingFile = GoogleCloudTestFactory.file().withName('Base').withDescription('D').insertRecord();
		GoogleCloudTestFactory.version()
			.forFile(existingFile.Id)
			.withName('Old.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId('GD_OLD')
			.withDocsId('DOCS_OLD')
			.insertRecord();

		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(new List<SObject>{ new GoogleFile__c(Id = existingFile.Id, Name = 'Base') });

		GoogleFileCreateRequestDTO request = new GoogleFileCreateRequestDTO();
		request.localGoogleFileId = existingFile.Id;
		request.googleDriveId = 'GD_NEWVER';
		request.fileName = 'New.docx';
		request.fileType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
		request.fileSize = 10L;
		request.parentFolderId = 'FOLDER2';

		Test.startTest();
		GoogleFile__c createdFile = new GoogleLocalFileService().createGoogleFileRecord(request);
		Test.stopTest();

		System.assertNotEquals(null, createdFile);
	}
}