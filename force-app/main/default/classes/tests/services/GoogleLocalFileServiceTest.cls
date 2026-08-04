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
	private static GoogleClientConfig__mdt buildFolderConfig(String uploadFolderId, String folderStructure) {
		GoogleClientConfig__mdt config = new GoogleClientConfig__mdt();
		config.DefaultGoogleUploadFolderId__c = uploadFolderId;
		config.CustomGoogleUploadFolderStructure__c = folderStructure;
		config.IsFilePreviewDisabled__c = true;
		return config;
	}

	private static List<GoogleFile__c> stripForRecord(Id localFileId, Id relatedRecordId, Id targetUserId) {
		List<GoogleFileLink__c> scopedLinks = new GoogleFileLinkPlacementResolver().resolveLinks(relatedRecordId, null);
		if (scopedLinks.isEmpty()) return new List<GoogleFile__c>();

		return new GoogleFileAccessCheckCommand()
			.forFile(localFileId)
			.forRecordLinks(scopedLinks)
			.forUser(targetUserId)
			.strip();
	}

	private static void coverFactories() {
		GoogleLocalFileService localFileService = new GoogleLocalFileService();
		Assert.areNotEqual(null, localFileService.deleteGoogleFileRecord());
		Assert.areNotEqual(null, localFileService.retrieveGoogleFileHeaderDetails());
		Assert.areNotEqual(null, localFileService.stripInaccessibleRecords());
	}

	@IsTest
	private static void testStripPositiveOwner() {
		GoogleCloudTestFactory.initMocks();
		coverFactories();

		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('F1').withDescription('D').insertRecord();
		List<GoogleFile__c> visibleFiles = new GoogleFileAccessCheckCommand().forFile(localFile.Id).forUser(UserInfo.getUserId()).strip();

		Assert.areEqual(1, visibleFiles.size());
		Assert.areEqual('Edit', visibleFiles[0].UserAccessLevel__c);
	}

	@IsTest
	private static void testStripPositiveShareView() {
		GoogleCloudTestFactory.initMocks();
		coverFactories();

		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('F2').withDescription('D').insertRecord();

		GoogleCloudTestFactory.mockShares(new List<GoogleFile__Share>{
			GoogleCloudTestFactory.share().forFile(localFile.Id).sharedWith(targetUserId).withAccessLevel('Read').build()
		});

		List<GoogleFile__c> visibleFiles = new GoogleFileAccessCheckCommand()
			.forFile(new GoogleFile__c(Id = localFile.Id))
			.forUser(targetUserId)
			.strip();

		Assert.areEqual(1, visibleFiles.size());
		Assert.areEqual('View', visibleFiles[0].UserAccessLevel__c);
	}

	@IsTest
	private static void testStripPositiveShareEdit() {
		GoogleCloudTestFactory.initMocks();
		coverFactories();

		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('F3').withDescription('D').insertRecord();

		GoogleCloudTestFactory.mockShares(new List<GoogleFile__Share>{
			GoogleCloudTestFactory.share().forFile(localFile.Id).sharedWith(targetUserId).withAccessLevel('Edit').build()
		});

		List<GoogleFile__c> visibleFiles = new GoogleFileAccessCheckCommand().forFile(localFile).forUser(targetUserId).strip();

		Assert.areEqual(1, visibleFiles.size());
		Assert.areEqual('Edit', visibleFiles[0].UserAccessLevel__c);
	}

	@IsTest
	private static void testStripPositiveLinkView() {
		GoogleCloudTestFactory.initMocks();
		coverFactories();

		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		Id linkedRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleCloudTestFactory.grantRecordAccess(linkedRecordId, true, true);
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('F4').withDescription('D').insertRecord();

		GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withLinkedRecord(linkedRecordId)
			.withLinkedType('GoogleFile__c')
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.insertRecord();

		List<GoogleFileLink__c> fileLinks = [
			SELECT Id, Name, GoogleFileId__c, LinkedObjectName__c, LinkedObjectId__c, LinkedObjectType__c, ShareType__c, Visibility__c
			FROM GoogleFileLink__c
			WHERE GoogleFileId__c = :localFile.Id
		];
		GSOQL.mock(GoogleFileLinkSelector.MOCK_ID).thenReturn(fileLinks);

		List<GoogleFile__c> visibleFiles = new GoogleFileAccessCheckCommand().forFile(localFile.Id).forUser(targetUserId).strip();

		Assert.areEqual(1, visibleFiles.size());
		Assert.areEqual('View', visibleFiles[0].UserAccessLevel__c);
	}

	@IsTest
	private static void testStripPositiveLinkEdit() {
		GoogleCloudTestFactory.initMocks();
		coverFactories();

		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		Id linkedRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleCloudTestFactory.grantRecordAccess(linkedRecordId, true, true);
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('F5').withDescription('D').insertRecord();

		GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withLinkedRecord(linkedRecordId)
			.withLinkedType('GoogleFile__c')
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
			.forUser(targetUserId)
			.strip();

		Assert.areEqual(1, visibleFiles.size());
		Assert.areEqual('Edit', visibleFiles[0].UserAccessLevel__c);
	}

	@IsTest
	private static void testStripNegativeLinkWithoutRecordAccess() {
		GoogleCloudTestFactory.initMocks();
		coverFactories();

		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('F5_NoRecordAccess').withDescription('D').insertRecord();

		GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withLinkedRecord(GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType))
			.withLinkedType('GoogleFile__c')
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
			.forUser(targetUserId)
			.strip();

		Assert.areEqual(0, visibleFiles.size());
	}

	@IsTest
	private static void testStripPositiveInferred() {
		GoogleCloudTestFactory.initMocks();
		coverFactories();

		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		Id linkedRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleCloudTestFactory.grantRecordAccess(linkedRecordId, true, true);

		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('F6').withDescription('D').insertRecord();

		GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withShareType('InferredFromRecord')
			.withVisibility('AllUsers')
			.withLinkedRecord(linkedRecordId)
			.withLinkedType('GoogleFile__c')
			.insertRecord();

		List<GoogleFileLink__c> fileLinks = [
			SELECT Id, Name, GoogleFileId__c, LinkedObjectName__c, LinkedObjectId__c, LinkedObjectType__c, ShareType__c, Visibility__c
			FROM GoogleFileLink__c
			WHERE GoogleFileId__c = :localFile.Id
		];
		GSOQL.mock(GoogleFileLinkSelector.MOCK_ID).thenReturn(fileLinks);

		List<GoogleFile__c> visibleFiles = new GoogleFileAccessCheckCommand().forFile(localFile.Id).forUser(targetUserId).strip();

		Assert.areEqual(1, visibleFiles.size());
		Assert.areEqual('Edit', visibleFiles[0].UserAccessLevel__c);
	}

	@IsTest
	private static void testStripPositiveEmpty() {
		GoogleCloudTestFactory.initMocks();
		coverFactories();

		List<GoogleFile__c> visibleFiles = new GoogleFileAccessCheckCommand().forFiles(new List<GoogleFile__c>()).strip();
		Assert.areEqual(0, visibleFiles.size());
	}

	@IsTest
	private static void testStripNegativeUserMissing() {
		GoogleCloudTestFactory.initMocks();
		coverFactories();

		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('F8').withDescription('D').insertRecord();
		Id missingUserId = (Id)('005000000000000AAA');

		try {
			new GoogleFileAccessCheckCommand().forFile(localFile.Id).forUser(missingUserId).strip();
			Assert.isTrue(false);
		} catch (GoogleFileAccessResolver.GoogleFileAccessCheckException ex) {
			Assert.isTrue(ex.getMessage().contains('Target user was not found'));
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
					CreatedDate, LastModifiedDate, IsPreviewableFile__c, GoogleFileId__c, GoogleDriveFileId__c, GoogleDocsFileId__c, Type__c, Size__c, Summary__c
				FROM GoogleFileVersion__c
				WHERE GoogleFileId__c = :localFile.Id
			]
		});

		Test.startTest();
		Boolean deleteResult = new GoogleLocalFileService().deleteGoogleFileRecord().setRecordId(localFile.Id).setCloudDeletion(false).save();
		Test.stopTest();

		Assert.areEqual(true, deleteResult);
		Assert.areEqual(0, [SELECT count() FROM GoogleFile__c WHERE Id = :localFile.Id]);
		Assert.areEqual(0, [SELECT count() FROM GoogleFileVersion__c WHERE GoogleFileId__c = :localFile.Id]);
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
					CreatedDate, LastModifiedDate, IsPreviewableFile__c, GoogleFileId__c, GoogleDriveFileId__c, GoogleDocsFileId__c, Type__c, Size__c, Summary__c
				FROM GoogleFileVersion__c
				WHERE GoogleFileId__c = :localFile.Id
			]
		});

		Test.startTest();
		Boolean deleteResult = new GoogleLocalFileService().deleteGoogleFileRecord().setRecordId(localFile.Id).setCloudDeletion(true).save();
		Test.stopTest();

		Assert.areEqual(true, deleteResult);
		Assert.areEqual(0, [SELECT count() FROM GoogleFile__c WHERE Id = :localFile.Id]);
		Assert.areEqual(0, [SELECT count() FROM GoogleFileVersion__c WHERE GoogleFileId__c = :localFile.Id]);
	}

	@IsTest
	private static void testCreatePositiveNew() {
		GoogleCloudTestFactory.initMocks();
		GoogleFileCloudFolderJob.skipExecution = true;
		coverFactories();

		Id parentRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);

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
	private static void testCreatePositiveNewPlacesFileInRecordFolder() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.queryContains('appProperties')
		).thenReturnStatus(200, '{"files":[{"id":"DEST_FOLDER_UPLOAD","name":"Existing Record Folder"}]}');
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('PATCH')
		).thenReturnStatus(200, '{"id":"MOVED_UPLOAD_FILE"}');
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig('ROOT_FOLDER_01', '{Record}');
		GoogleFileCloudFolderJob.skipExecution = false;

		Id parentRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(new List<SObject>{ new GoogleFile__c(Name = 'Any') });

		GoogleFileCreateRequestDTO request = new GoogleFileCreateRequestDTO();
		request.recordId = parentRecordId;
		request.googleDriveId = 'GD_UPLOAD_NEW';
		request.fileName = 'Upload.pdf';
		request.fileType = 'application/pdf';
		request.fileSize = 123L;
		request.parentFolderId = 'ROOT_FOLDER_01';
		request.source = 'Notes & Attachments';

		Test.startTest();
		new GoogleLocalFileService().createGoogleFileRecord(request);
		Test.stopTest();

		GoogleFileVersion__c createdVersion = [
			SELECT GoogleDriveFolderId__c, GoogleDriveFileId__c
			FROM GoogleFileVersion__c
			WHERE Name = :request.fileName
			LIMIT 1
		];

		Assert.areEqual('DEST_FOLDER_UPLOAD', createdVersion.GoogleDriveFolderId__c);
		Assert.areEqual('MOVED_UPLOAD_FILE', createdVersion.GoogleDriveFileId__c);
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

		Assert.areNotEqual(null, createdFile);
	}

	@IsTest
	private static void testRetrieveAllPositiveInferredCandidate() {
		GoogleCloudTestFactory.initMocks();
		coverFactories();

		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		Id accessibleRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleCloudTestFactory.grantRecordAccess(accessibleRecordId, true, true);

		GoogleFile__c localFile = GoogleCloudTestFactory.file()
			.withName('Record Shared File')
			.withDescription('D')
			.insertRecord();

		GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withLinkedRecord(accessibleRecordId)
			.withLinkedType('GoogleFile__c')
			.withShareType('InferredFromRecord')
			.withVisibility('AllUsers')
			.insertRecord();

		GoogleFileExplorerPageRequestDTO request = GoogleFileExplorerPageRequestDTO.firstPage();
		request.bucket = GoogleCloudConstants.FILE_EXPLORER_BUCKET_SHARED;

		Test.startTest();
		GoogleFileExplorerResultDTO result = new GoogleLocalFileService().retrieveGoogleFilesPage(request, targetUserId);
		GoogleFileExplorerResultDTO ownedView = new GoogleLocalFileService().retrieveFileExplorerFiles(targetUserId);
		Test.stopTest();

		List<GoogleFile__c> accessibleFiles = result.files;
		Assert.areEqual(1, accessibleFiles.size());
		Assert.areEqual(localFile.Id, accessibleFiles[0].Id);
		Assert.areEqual('Edit', accessibleFiles[0].UserAccessLevel__c);
		Assert.areEqual(0, ownedView.files.size(), 'A file owned by somebody else must not appear in the Owned bucket');
	}

	@IsTest
	private static void testViewAllFloorGrantsViaStrip() {
		GoogleCloudTestFactory.initMocks();
		coverFactories();

		Id privilegedUserId = GoogleCloudTestFactory.mockInternalUser();
		GoogleFile__c localFile = GoogleCloudTestFactory.file()
			.withName('Unlinked File')
			.withDescription('D')
			.insertRecord();

		setPrivilegedFloor(GoogleFileAccessResolver.AccessLevel.View);

		List<GoogleFile__c> visibleFiles = new GoogleFileAccessCheckCommand()
			.forFile(localFile.Id)
			.forUser(privilegedUserId)
			.strip();

		Assert.areEqual(1, visibleFiles.size());
		Assert.areEqual('View', visibleFiles[0].UserAccessLevel__c);
	}

	@IsTest
	private static void testEditAllFloorGrantsEditViaStrip() {
		GoogleCloudTestFactory.initMocks();
		coverFactories();

		Id privilegedUserId = GoogleCloudTestFactory.mockInternalUser();
		GoogleFile__c localFile = GoogleCloudTestFactory.file()
			.withName('Unlinked File')
			.insertRecord();

		setPrivilegedFloor(GoogleFileAccessResolver.AccessLevel.Edit);

		List<GoogleFile__c> visibleFiles = new GoogleFileAccessCheckCommand()
			.forFile(localFile.Id)
			.forUser(privilegedUserId)
			.strip();

		Assert.areEqual(1, visibleFiles.size());
		Assert.areEqual('Edit', visibleFiles[0].UserAccessLevel__c);
	}

	@IsTest
	private static void testFloorDoesNotDowngradeOwner() {
		GoogleCloudTestFactory.initMocks();
		coverFactories();

		Id privilegedUserId = UserInfo.getUserId();
		GoogleFile__c ownedFile = GoogleCloudTestFactory.file()
			.withName('Owned File')
			.insertRecord();

		setPrivilegedFloor(GoogleFileAccessResolver.AccessLevel.View);

		List<GoogleFile__c> visibleFiles = new GoogleFileAccessCheckCommand()
			.forFile(ownedFile.Id)
			.forUser(privilegedUserId)
			.strip();

		Assert.areEqual(1, visibleFiles.size());
		Assert.areEqual('Edit', visibleFiles[0].UserAccessLevel__c);
	}

	@IsTest
	private static void testNoFloorRemainsRestricted() {
		GoogleCloudTestFactory.initMocks();
		coverFactories();

		Id otherUserId = GoogleCloudTestFactory.mockInternalUser();
		GoogleFile__c localFile = GoogleCloudTestFactory.file()
			.withName('Unlinked File')
			.insertRecord();

		setPrivilegedFloor(null);

		List<GoogleFile__c> visibleFiles = new GoogleFileAccessCheckCommand()
			.forFile(localFile.Id)
			.forUser(otherUserId)
			.strip();

		Assert.areEqual(0, visibleFiles.size());
	}

	@IsTest
	private static void testExplorerPrivilegedFirstPage() {
		GoogleCloudTestFactory.initMocks();
		coverFactories();

		Id otherOwnerId = GoogleCloudTestFactory.fakeId(User.SObjectType);
		GoogleFile__c ownedFile = new GoogleFile__c(Id = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType), Name = 'Owned File', OwnerId = UserInfo.getUserId());
		GoogleFile__c otherFile = new GoogleFile__c(Id = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType), Name = 'Other File', OwnerId = otherOwnerId);
		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(new List<SObject>{ ownedFile, otherFile });

		setPrivilegedFloor(GoogleFileAccessResolver.AccessLevel.View);

		Test.startTest();
		GoogleFileExplorerResultDTO result = new GoogleLocalFileService().retrieveFileExplorerFiles(UserInfo.getUserId());
		Test.stopTest();

		Assert.areEqual(true, result.isPrivileged);

		Assert.areEqual(2, result.files.size());
		Assert.areEqual(ownedFile.Id, result.files[0].Id, 'The queried order must be preserved on the way back to the client');
		Assert.areEqual('Edit', result.files[0].UserAccessLevel__c);
		Assert.areEqual(otherFile.Id, result.files[1].Id);
		Assert.areEqual('View', result.files[1].UserAccessLevel__c);
	}

	@IsTest
	private static void testPrivilegedPageStampsEditFloor() {
		GoogleCloudTestFactory.initMocks();
		coverFactories();

		Id otherOwnerId = GoogleCloudTestFactory.fakeId(User.SObjectType);
		GoogleFile__c ownedFile = new GoogleFile__c(Id = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType), Name = 'Owned Page File', OwnerId = UserInfo.getUserId());
		GoogleFile__c otherFile = new GoogleFile__c(Id = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType), Name = 'Other Page File', OwnerId = otherOwnerId);
		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(new List<SObject>{ ownedFile, otherFile });

		setPrivilegedFloor(GoogleFileAccessResolver.AccessLevel.Edit);

		Test.startTest();
		GoogleFileExplorerResultDTO result = new GoogleLocalFileService().retrieveGoogleFilesPage(GoogleFileExplorerPageRequestDTO.firstPage());
		Test.stopTest();

		Assert.areEqual(true, result.isPrivileged);

		Map<Id, GoogleFile__c> filesById = new Map<Id, GoogleFile__c>(result.files);
		Assert.areEqual('Edit', filesById.get(ownedFile.Id).UserAccessLevel__c);
		Assert.areEqual('Edit', filesById.get(otherFile.Id).UserAccessLevel__c);
	}

	@IsTest
	private static void testPageSizeIsClampedToTheSupportedMaximum() {
		GoogleFileExplorerPageRequestDTO request = GoogleFileExplorerPageRequestDTO.firstPage();
		request.pageSize = 45000;

		Assert.areEqual(
			GoogleCloudConstants.FILE_EXPLORER_MAX_PAGE_SIZE,
			request.effectivePageSize(),
			'A client must not be able to request an unbounded page'
		);

		request.pageSize = null;
		Assert.areEqual(GoogleCloudConstants.FILE_EXPLORER_PAGE_SIZE, request.effectivePageSize());
	}

	@IsTest
	private static void testExplorerPagesThroughEveryAccessibleFileWithoutRepeats() {
		GoogleCloudTestFactory.initMocks();
		coverFactories();

		List<GoogleFile__c> seededFiles = new List<GoogleFile__c>();
		for (Integer i = 0; i < 5; i++) {
			seededFiles.add(GoogleCloudTestFactory.file().withName('Paged File ' + i).insertRecord());
		}

		Set<Id> seenFileIds = new Set<Id>();
		GoogleFileExplorerPageRequestDTO request = GoogleFileExplorerPageRequestDTO.firstPage();
		request.pageSize = 2;

		GoogleLocalFileService recordService = new GoogleLocalFileService();
		for (Integer page = 0; page < 5; page++) {
			GoogleFileExplorerResultDTO result = recordService.retrieveGoogleFilesPage(request);

			for (GoogleFile__c pagedFile : result.files) {
				Assert.isTrue(seenFileIds.add(pagedFile.Id), 'Keyset paging must never return the same file twice');
			}

			if (!result.hasMore) break;

			Assert.areNotEqual(null, result.nextCursor, 'hasMore must always be accompanied by a usable cursor');
			request.cursor = result.nextCursor;
		}

		Assert.areEqual(seededFiles.size(), seenFileIds.size(), 'Paging must reach every accessible file');
	}

	@IsTest
	private static void testCursorEncodeDecodeRoundTrip() {
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('Cursor File').insertRecord();
		GoogleFile__c row = [SELECT Id, Name FROM GoogleFile__c WHERE Id = :localFile.Id];

		GoogleFileExplorerPageRequestDTO request = new GoogleFileExplorerPageRequestDTO();
		request.sortField = 'fileName';
		request.sortDirection = 'DESC';
		String cursor = request.encodeCursorFrom(row);
		Assert.areNotEqual(null, cursor);

		GoogleFileExplorerPageRequestDTO next = new GoogleFileExplorerPageRequestDTO();
		next.sortField = 'fileName';
		next.sortDirection = 'DESC';
		next.cursor = cursor;

		Assert.areEqual(true, next.hasCursor());
		Assert.areEqual(row.Id, next.cursorId());
		Assert.areEqual(row.Name, (String) next.decodedCursorValue());
	}

	private static void setPrivilegedFloor(GoogleFileAccessResolver.AccessLevel floor) {
		GoogleFileAccessResolver.privilegedFloorOverrideSet = true;
		GoogleFileAccessResolver.privilegedFloorOverride = floor;
	}

	@IsTest
	private static void testStripPositiveMultipleLinksHighestAccess() {
		GoogleCloudTestFactory.initMocks();
		coverFactories();

		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		Id editableRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleCloudTestFactory.grantRecordAccess(editableRecordId, true, true);

		GoogleFile__c localFile = GoogleCloudTestFactory.file()
			.withName('Multi Link File')
			.withDescription('D')
			.insertRecord();

		GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withLinkedRecord(GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType))
			.withLinkedType('GoogleFile__c')
			.withShareType('Viewer')
			.withVisibility('InternalUsers')
			.insertRecord();

		GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withLinkedRecord(editableRecordId)
			.withLinkedType('GoogleFile__c')
			.withShareType('InferredFromRecord')
			.withVisibility('AllUsers')
			.insertRecord();

		Test.startTest();
		List<GoogleFile__c> accessibleFiles = new GoogleFileAccessCheckCommand()
			.forFile(localFile.Id)
			.forUser(targetUserId)
			.strip();
		Test.stopTest();

		Assert.areEqual(1, accessibleFiles.size());
		Assert.areEqual('Edit', accessibleFiles[0].UserAccessLevel__c);
	}

	@IsTest
	private static void testRetrieveGoogleFilesForRelatedRecordShowsNoneFilesForOwnerAndExplicitShare() {
		GoogleCloudTestFactory.initMocks();
		coverFactories();

		Id sharedUserId = GoogleCloudTestFactory.mockInternalUser();
		Id relatedRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleCloudTestFactory.grantRecordAccess(relatedRecordId, true, true);

		GoogleFile__c localFile = GoogleCloudTestFactory.file()
			.withName('None Visible File')
			.withDescription('D')
			.insertRecord();

		GoogleCloudTestFactory.version()
			.forFile(localFile.Id)
			.withName('NoneVisible.pdf')
			.withDriveId('GD_NONE_VISIBLE')
			.insertRecord();

		GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withLinkedRecord(relatedRecordId)
			.withLinkedType('GoogleFile__c')
			.withShareType('None')
			.withVisibility('AllUsers')
			.insertRecord();

		GoogleCloudTestFactory.mockShares(new List<GoogleFile__Share>{
			GoogleCloudTestFactory.share().forFile(localFile.Id).sharedWith(sharedUserId).withAccessLevel('Read').build()
		});

		List<GoogleFile__c> ownerFiles = new GoogleLocalFileService().retrieveGoogleFilesForRelatedRecord(relatedRecordId, null, 10);

		Assert.areEqual(1, ownerFiles.size());
		Assert.areEqual(localFile.Id, ownerFiles[0].Id);
		Assert.areEqual('Edit', ownerFiles[0].UserAccessLevel__c);

		List<GoogleFileLink__c> scopedLinks = new GoogleFileLinkPlacementResolver().resolveLinks(relatedRecordId, null);
		List<GoogleFile__c> sharedFiles = new GoogleFileAccessCheckCommand()
			.forFile(localFile.Id)
			.forRecordLinks(scopedLinks)
			.forUser(sharedUserId)
			.strip();

		Assert.areEqual(1, sharedFiles.size());
		Assert.areEqual(localFile.Id, sharedFiles[0].Id);
		Assert.areEqual('View', sharedFiles[0].UserAccessLevel__c);
	}

	@IsTest
	private static void testRetrieveGoogleFilesForRelatedRecordDoesNotLeakNoneAccessFromAnotherRecord() {
		GoogleCloudTestFactory.initMocks();
		coverFactories();

		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		Id hiddenRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		Id accessibleRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleCloudTestFactory.grantRecordAccess(hiddenRecordId, true, true);
		GoogleCloudTestFactory.grantRecordAccess(accessibleRecordId, true, true);

		GoogleFile__c localFile = GoogleCloudTestFactory.file()
			.withName('None Scoped File')
			.withDescription('D')
			.insertRecord();

		GoogleCloudTestFactory.version()
			.forFile(localFile.Id)
			.withName('NoneScoped.pdf')
			.withDriveId('GD_NONE_SCOPED')
			.insertRecord();

		GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withLinkedRecord(hiddenRecordId)
			.withLinkedType('GoogleFile__c')
			.withShareType('None')
			.withVisibility('AllUsers')
			.insertRecord();

		GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withLinkedRecord(accessibleRecordId)
			.withLinkedType('GoogleFile__c')
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.insertRecord();

		Test.startTest();
		List<GoogleFile__c> hiddenFiles = stripForRecord(localFile.Id, hiddenRecordId, targetUserId);
		List<GoogleFile__c> visibleFiles = stripForRecord(localFile.Id, accessibleRecordId, targetUserId);
		Test.stopTest();

		Assert.areEqual(0, hiddenFiles.size());
		Assert.areEqual(1, visibleFiles.size());
		Assert.areEqual(localFile.Id, visibleFiles[0].Id);
		Assert.areEqual('View', visibleFiles[0].UserAccessLevel__c);
	}

	@IsTest
	private static void testRetrieveGoogleFilesForRelatedRecordFiltersOtherRecordLinks() {
		GoogleCloudTestFactory.initMocks();
		coverFactories();

		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		Id accessibleRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleCloudTestFactory.grantRecordAccess(accessibleRecordId, true, true);
		Id hiddenRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);

		GoogleFile__c localFile = GoogleCloudTestFactory.file()
			.withName('Scoped Visibility File')
			.withDescription('D')
			.insertRecord();

		GoogleCloudTestFactory.version()
			.forFile(localFile.Id)
			.withName('ScopedVisibility.pdf')
			.withDriveId('GD_SCOPED_VISIBILITY')
			.insertRecord();

		GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withLinkedRecord(accessibleRecordId)
			.withLinkedType('GoogleFile__c')
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.insertRecord();

		GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withLinkedRecord(hiddenRecordId)
			.withLinkedType('GoogleFile__c')
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.insertRecord();

		Test.startTest();
		List<GoogleFile__c> visibleFiles = stripForRecord(localFile.Id, accessibleRecordId, targetUserId);
		List<GoogleFile__c> hiddenFiles = stripForRecord(localFile.Id, hiddenRecordId, targetUserId);
		Test.stopTest();

		Assert.areEqual(1, visibleFiles.size());
		Assert.areEqual(localFile.Id, visibleFiles[0].Id);
		Assert.areEqual(0, hiddenFiles.size());
	}
}