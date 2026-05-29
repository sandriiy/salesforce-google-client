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
private class GoogleLocalFileServiceTest {
	private static void coverFactories() {
		GoogleLocalFileService localFileService = new GoogleLocalFileService();
		System.assertNotEquals(null, localFileService.deleteGoogleFileRecord());
		System.assertNotEquals(null, localFileService.retrieveGoogleFileHeaderDetails());
		System.assertNotEquals(null, localFileService.stripInaccessibleRecords());
	}

	@IsTest
	private static void testStripPositiveOwner() {
		GoogleCloudTestFactory.initMocks();
		coverFactories();

		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('F1').withDescription('D').insertRecord();
		List<GoogleFile__c> visibleFiles = new GoogleFileAccessCheckCommand().forFile(localFile.Id).forUser(UserInfo.getUserId()).strip();

		System.assertEquals(1, visibleFiles.size());
		System.assertEquals('Edit', visibleFiles[0].UserAccessLevel__c);
	}

	@IsTest
	private static void testStripPositiveShareView() {
		GoogleCloudTestFactory.initMocks();
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
		GoogleCloudTestFactory.initMocks();
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
		GoogleCloudTestFactory.initMocks();
		coverFactories();

		User targetUser = GoogleCloudTestFactory.newUser();
		Account linkedAccount = new Account(Name = 'Linked View Account', OwnerId = targetUser.Id);
		insert linkedAccount;
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('F4').withDescription('D').insertRecord();

		GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withLinkedRecord(linkedAccount.Id)
			.withLinkedType('Account')
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.insertRecord();

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
		GoogleCloudTestFactory.initMocks();
		coverFactories();

		User targetUser = GoogleCloudTestFactory.newUser();
		Account linkedAccount = new Account(Name = 'Linked Edit Account', OwnerId = targetUser.Id);
		insert linkedAccount;
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('F5').withDescription('D').insertRecord();

		GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withLinkedRecord(linkedAccount.Id)
			.withLinkedType('Account')
			.withShareType('Collaborator')
			.withVisibility('InternalUsers')
			.insertRecord();

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
	private static void testStripNegativeLinkWithoutRecordAccess() {
		GoogleCloudTestFactory.initMocks();
		coverFactories();

		User targetUser = GoogleCloudTestFactory.newUser();
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('F5_NoRecordAccess').withDescription('D').insertRecord();

		GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withLinkedRecord(GoogleCloudTestFactory.fakeId(Account.SObjectType))
			.withLinkedType('Account')
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.insertRecord();

		List<GoogleFileLink__c> fileLinks = [
			SELECT Id, Name, GoogleFileId__c, LinkedObjectName__c, LinkedObjectId__c, LinkedObjectType__c, ShareType__c, Visibility__c
			FROM GoogleFileLink__c
			WHERE GoogleFileId__c = :localFile.Id
		];
		GSOQL.mock(GoogleFileLinkSelector.MOCK_ID).thenReturn(fileLinks);

		List<GoogleFile__c> visibleFiles = new GoogleFileAccessCheckCommand()
			.forFile(localFile.Id)
			.forUser(targetUser.Id)
			.strip();

		System.assertEquals(0, visibleFiles.size());
	}

	@IsTest
	private static void testStripPositiveInferred() {
		GoogleCloudTestFactory.initMocks();
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
		GoogleCloudTestFactory.initMocks();
		coverFactories();

		List<GoogleFile__c> visibleFiles = new GoogleFileAccessCheckCommand().forFiles(new List<GoogleFile__c>()).strip();
		System.assertEquals(0, visibleFiles.size());
	}

	@IsTest
	private static void testStripNegativeUserMissing() {
		GoogleCloudTestFactory.initMocks();
		coverFactories();

		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('F8').withDescription('D').insertRecord();
		Id missingUserId = (Id)('005000000000000AAA');

		try {
			new GoogleFileAccessCheckCommand().forFile(localFile.Id).forUser(missingUserId).strip();
			System.assert(false);
		} catch (GoogleFileAccessResolver.GoogleFileAccessCheckException ex) {
			System.assert(ex.getMessage().contains('Target user was not found'));
		}
	}

	@IsTest
	private static void testDeletePositiveLocalOnly() {
		GoogleCloudTestFactory.initMocks();
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
		GoogleCloudTestFactory.initMocks();
		GoogleFileCloudDeleteJob.skipExecution = true;
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
		GoogleCloudTestFactory.initMocks();
		GoogleFileCloudFolderJob.skipExecution = true;
		coverFactories();

		Id parentRecordId = GoogleCloudTestFactory.fakeId(Account.SObjectType);

		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(new List<SObject>{ new GoogleFile__c(Name = 'Any') });

		GoogleFileCreateRequestDTO request = new GoogleFileCreateRequestDTO();
		request.recordId = parentRecordId;
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

		GoogleFileVersion__c createdVersion = [
			SELECT GoogleFileId__c
			FROM GoogleFileVersion__c
			WHERE GoogleDriveFileId__c = :request.googleDriveId
			LIMIT 1
		];

		GoogleFile__c createdFile = [
			SELECT Source__c
			FROM GoogleFile__c
			WHERE Id = :createdVersion.GoogleFileId__c
			LIMIT 1
		];

		GoogleFileLink__c createdLink = [
			SELECT Source__c, LinkedObjectId__c
			FROM GoogleFileLink__c
			WHERE GoogleFileId__c = :createdVersion.GoogleFileId__c
			LIMIT 1
		];

		Assert.areEqual(request.source, createdFile.Source__c);
		Assert.areEqual(request.source, createdLink.Source__c);
		Assert.areEqual(String.valueOf(parentRecordId), createdLink.LinkedObjectId__c);
	}

	@IsTest
	private static void testCreatePositiveVersion() {
		GoogleCloudTestFactory.initMocks();
		GoogleFileCloudFolderJob.skipExecution = true;
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

	@IsTest
	private static void testRetrieveAllPositiveInferredCandidate() {
		GoogleCloudTestFactory.initMocks();
		coverFactories();

		User fileOwner = GoogleCloudTestFactory.newUser();
		User targetUser = GoogleCloudTestFactory.newUser();
		Account accessibleAccount = new Account(Name = 'Accessible Account', OwnerId = targetUser.Id);
		insert accessibleAccount;

		GoogleFile__c localFile = GoogleCloudTestFactory.file()
			.withName('Record Shared File')
			.withDescription('D')
			.withOwner(fileOwner.Id)
			.insertRecord();

		GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withLinkedRecord(accessibleAccount.Id)
			.withLinkedType('Account')
			.withShareType('InferredFromRecord')
			.withVisibility('AllUsers')
			.insertRecord();

		System.runAs(targetUser) {
			Test.startTest();
			List<GoogleFile__c> accessibleFiles = new GoogleLocalFileService().retrieveGoogleFiles(UserInfo.getUserId());
			Test.stopTest();

			Assert.areEqual(1, accessibleFiles.size());
			Assert.areEqual(localFile.Id, accessibleFiles[0].Id);
			Assert.areEqual('Edit', accessibleFiles[0].UserAccessLevel__c);
		}
	}

	@IsTest
	private static void testStripPositiveMultipleLinksHighestAccess() {
		GoogleCloudTestFactory.initMocks();
		coverFactories();

		User fileOwner = GoogleCloudTestFactory.newUser();
		User targetUser = GoogleCloudTestFactory.newUser();
		Account editableAccount = new Account(Name = 'Editable Account', OwnerId = targetUser.Id);
		insert editableAccount;

		GoogleFile__c localFile = GoogleCloudTestFactory.file()
			.withName('Multi Link File')
			.withDescription('D')
			.withOwner(fileOwner.Id)
			.insertRecord();

		GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withLinkedRecord(GoogleCloudTestFactory.fakeId(Account.SObjectType))
			.withLinkedType('Account')
			.withShareType('Viewer')
			.withVisibility('InternalUsers')
			.insertRecord();

		GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withLinkedRecord(editableAccount.Id)
			.withLinkedType('Account')
			.withShareType('InferredFromRecord')
			.withVisibility('AllUsers')
			.insertRecord();

		Test.startTest();
		List<GoogleFile__c> accessibleFiles = new GoogleFileAccessCheckCommand()
			.forFile(localFile.Id)
			.forUser(targetUser.Id)
			.strip();
		Test.stopTest();

		Assert.areEqual(1, accessibleFiles.size());
		Assert.areEqual('Edit', accessibleFiles[0].UserAccessLevel__c);
	}

	@IsTest
	private static void testRetrieveGoogleFilesForRelatedRecordFiltersOtherRecordLinks() {
		GoogleCloudTestFactory.initMocks();
		coverFactories();

		User fileOwner = GoogleCloudTestFactory.newUser();
		User targetUser = GoogleCloudTestFactory.newUser();
		Account accessibleAccount = new Account(Name = 'Visible Related Account', OwnerId = targetUser.Id);
		insert accessibleAccount;
		Id hiddenAccountId = GoogleCloudTestFactory.fakeId(Account.SObjectType);

		GoogleFile__c localFile = GoogleCloudTestFactory.file()
			.withName('Scoped Visibility File')
			.withDescription('D')
			.withOwner(fileOwner.Id)
			.insertRecord();

		GoogleCloudTestFactory.version()
			.forFile(localFile.Id)
			.withName('ScopedVisibility.pdf')
			.withDriveId('GD_SCOPED_VISIBILITY')
			.insertRecord();

		GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withLinkedRecord(accessibleAccount.Id)
			.withLinkedType('Account')
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.insertRecord();

		GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withLinkedRecord(hiddenAccountId)
			.withLinkedType('Account')
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.insertRecord();

		System.runAs(targetUser) {
			Test.startTest();
			List<GoogleFile__c> visibleFiles = new GoogleLocalFileService().retrieveGoogleFilesForRelatedRecord(accessibleAccount.Id, null, 10);
			List<GoogleFile__c> hiddenFiles = new GoogleLocalFileService().retrieveGoogleFilesForRelatedRecord(hiddenAccountId, null, 10);
			Test.stopTest();

			Assert.areEqual(1, visibleFiles.size());
			Assert.areEqual(localFile.Id, visibleFiles[0].Id);
			Assert.areEqual(0, hiddenFiles.size());
		}
	}
}