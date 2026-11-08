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
					CreatedDate, LastModifiedDate, IsPreviewableFile__c, GoogleFileId__c, GoogleDriveFileId__c, GoogleDocsFileId__c, Type__c, Size__c, GoogleDocsFileSize__c, AiLabels__c, Summary__c
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
					CreatedDate, LastModifiedDate, IsPreviewableFile__c, GoogleFileId__c, GoogleDriveFileId__c, GoogleDocsFileId__c, Type__c, Size__c, GoogleDocsFileSize__c, AiLabels__c, Summary__c
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
		Assert.isNull(next.decodedCursorValue(), 'The cursor carries no sort value; the server reads it from the row');
		Assert.isFalse(EncodingUtil.base64Decode(cursor).toString().contains(row.Name), 'The cursor must not carry the file name');
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

	@IsTest
	private static void testRetrieveGoogleFilesPagePositiveMigratedBucketListsOnlyMigratedFiles() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c migratedFile = GoogleCloudTestFactory.file()
			.withName('Migrated')
			.withDescription('D')
			.withSource(GoogleCloudConstants.FILE_SOURCE_MIGRATION)
			.insertRecord();
		GoogleCloudTestFactory.file()
			.withName('Uploaded')
			.withDescription('D')
			.withSource('Uploader')
			.insertRecord();

		GoogleFileExplorerPageRequestDTO request = GoogleFileExplorerPageRequestDTO.firstPage();
		request.bucket = GoogleCloudConstants.FILE_EXPLORER_BUCKET_MIGRATED;

		Test.startTest();
		GoogleFileExplorerResultDTO result = new GoogleLocalFileService().retrieveGoogleFilesPage(request, UserInfo.getUserId());
		Test.stopTest();

		Assert.areEqual(1, result.files.size(), 'The migrated bucket lists files whose source is Migration and nothing else');
		Assert.areEqual(migratedFile.Id, result.files[0].Id);
		Assert.isFalse(result.hasMore);
	}

	@IsTest
	private static void testRequireFileAccessPositiveTheOwnerMayChangeTheFile() {
		GoogleCloudTestFactory.initMocks();
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('Owned').insertRecord();

		Test.startTest();
		GoogleFile__c accessibleFile = new GoogleLocalFileService().requireFileAccess(localFile.Id, true);
		Test.stopTest();

		Assert.areEqual(localFile.Id, accessibleFile.Id);
		Assert.areEqual('Edit', accessibleFile.UserAccessLevel__c);
	}

	@IsTest
	private static void testRequireFileAccessNegativeAFileWithNoAccessPathIsRefused() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.denyAllRecordAccess();
		Id unreachableFileId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(new List<SObject>{
			new GoogleFile__c(Id = unreachableFileId, OwnerId = GoogleCloudTestFactory.otherUserId())
		});

		Test.startTest();
		try {
			new GoogleLocalFileService().requireFileAccess(unreachableFileId, false);
			Assert.fail('A file the user cannot open must be refused');
		} catch (GoogleLocalFileService.GoogleLocalFileException ex) {
			Assert.isTrue(ex.getMessage().contains('have access to this file'), ex.getMessage());
		}
		Test.stopTest();
	}

	@IsTest
	private static void testRequireFileAccessNegativeViewAccessCannotChangeTheFile() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.denyAllRecordAccess();
		Id readableRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleCloudTestFactory.grantRecordAccess(readableRecordId, true, false);
		Id viewableFileId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(new List<SObject>{
			new GoogleFile__c(Id = viewableFileId, OwnerId = GoogleCloudTestFactory.otherUserId())
		});
		GoogleCloudTestFactory.mockLinks(new List<GoogleFileLink__c>{
			GoogleCloudTestFactory.link().forFile(viewableFileId).withLinkedRecord(readableRecordId).withShareType('Viewer').build()
		});
		GoogleLocalFileService localFileService = new GoogleLocalFileService();

		Test.startTest();
		GoogleFile__c viewableFile = localFileService.requireFileAccess(viewableFileId, false);
		try {
			localFileService.requireFileAccess(viewableFileId, true);
			Assert.fail('View access must not be enough to change the file');
		} catch (GoogleLocalFileService.GoogleLocalFileException ex) {
			Assert.isTrue(ex.getMessage().contains('not change it'), ex.getMessage());
		}
		Test.stopTest();

		Assert.areEqual('View', viewableFile.UserAccessLevel__c, 'A Viewer link to a readable record opens the file for reading');
	}

	@IsTest
	private static void testRequireVersionAccessPositiveJudgesTheVersionByItsFile() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('Versioned').insertRecord();
		GoogleFileVersion__c localVersion = GoogleCloudTestFactory.version().forFile(localFile.Id).insertRecord();

		Test.startTest();
		GoogleFile__c accessibleFile = new GoogleLocalFileService().requireVersionAccess(localVersion.Id, true);
		Test.stopTest();

		Assert.areEqual(localFile.Id, accessibleFile.Id, 'A version is judged by the file it belongs to');
		Assert.areEqual('Edit', accessibleFile.UserAccessLevel__c);
	}

	@IsTest
	private static void testRequireVersionAccessNegativeAnUnknownVersionIsRefused() {
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		try {
			new GoogleLocalFileService().requireVersionAccess(GoogleCloudTestFactory.fakeId(GoogleFileVersion__c.SObjectType), false);
			Assert.fail('A version that does not exist must be refused like one the user cannot open');
		} catch (GoogleLocalFileService.GoogleLocalFileException ex) {
			Assert.isTrue(ex.getMessage().contains('have access to this file'), ex.getMessage());
		}
		Test.stopTest();
	}

	private static GoogleFile__c insertSearchFile(String fileName, String versionName) {
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName(fileName).insertRecord();
		GoogleCloudTestFactory.version().forFile(localFile.Id).withName(versionName).isLatest(true).insertRecord();
		return localFile;
	}

	private static GoogleFile__c insertSizedFile(String fileName, Long sizeBytes) {
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName(fileName).insertRecord();
		GoogleCloudTestFactory.version().forFile(localFile.Id).withName(fileName + '.pdf').withSize(sizeBytes).isLatest(true).insertRecord();
		return localFile;
	}

	private static void linkFileTo(Id fileId, Id recordId, String shareType) {
		GoogleCloudTestFactory.link().forFile(fileId).withLinkedRecord(recordId).withShareType(shareType).withVisibility('AllUsers').insertRecord();
	}

	private static void insertHiddenMergerFiles(Id hiddenRecordId) {
		List<GoogleFile__c> hiddenFiles = new List<GoogleFile__c>();
		for (Integer i = 1; i <= 4; i++) {
			hiddenFiles.add(GoogleCloudTestFactory.file().withName('Hidden Merger ' + i).build());
		}
		insert hiddenFiles;

		List<GoogleFileVersion__c> versions = new List<GoogleFileVersion__c>();
		List<GoogleFileLink__c> links = new List<GoogleFileLink__c>();
		for (GoogleFile__c hiddenFile : hiddenFiles) {
			versions.add(GoogleCloudTestFactory.version().forFile(hiddenFile.Id).withName(hiddenFile.Name + '.pdf').isLatest(true).build());
			links.add(GoogleCloudTestFactory.link().forFile(hiddenFile.Id).withLinkedRecord(hiddenRecordId).withShareType('Viewer').build());
		}
		insert versions;
		insert links;
	}

	private static List<Id> idsOf(List<GoogleFile__c> files) {
		List<Id> fileIds = new List<Id>();
		for (GoogleFile__c localFile : files) {
			fileIds.add(localFile.Id);
		}
		return fileIds;
	}

	private static String dayString(Date day) {
		return Datetime.newInstance(day, Time.newInstance(0, 0, 0, 0)).format('yyyy-MM-dd');
	}

	private static String forgedCursor(String valueType, String value, Id recordId) {
		return EncodingUtil.base64Encode(Blob.valueOf(JSON.serialize(new Map<String, Object>{
			'type' => valueType,
			'value' => value,
			'recordId' => recordId
		})));
	}

	private static String decodeCursor(String cursor) {
		return EncodingUtil.base64Decode(cursor).toString();
	}

	private static GoogleFileExplorerResultDTO runSearch(SearchInput input, Id userId) {
		return new GoogleLocalFileService().searchGoogleFilesPage(input.build(), userId);
	}

	private static SearchInput searchFor(String keyPhrases) {
		SearchInput input = new SearchInput();
		input.keyPhrases = keyPhrases;
		return input;
	}

	@IsTest
	private static void testSearchGoogleFilesPagePositiveCombinesEveryCriterion() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();

		List<String> roles = new List<String>{ 'Match', 'No Phrase', 'Wrong Type', 'Too Small', 'Created Earlier', 'Single Version', 'Unlinked' };
		Map<String, String> latestNameByRole = new Map<String, String>{
			'No Phrase' => 'Contract 2026.pdf',
			'Wrong Type' => 'Contract Renewal 2026.txt'
		};
		Map<String, GoogleFile__c> filesByRole = new Map<String, GoogleFile__c>();
		for (String role : roles) {
			filesByRole.put(role, GoogleCloudTestFactory.file().withName(role).build());
		}
		insert filesByRole.values();

		List<GoogleFileVersion__c> versions = new List<GoogleFileVersion__c>();
		List<GoogleFileLink__c> links = new List<GoogleFileLink__c>();
		for (String role : roles) {
			Id fileId = filesByRole.get(role).Id;

			if (role != 'Single Version') {
				versions.add(GoogleCloudTestFactory.version().forFile(fileId).withName('Old draft.pdf').isLatest(false).build());
			}

			versions.add(GoogleCloudTestFactory.version()
				.forFile(fileId)
				.withName(latestNameByRole.containsKey(role) ? latestNameByRole.get(role) : 'Contract Renewal 2026.pdf')
				.withType(role == 'Wrong Type' ? GoogleCloudConstants.MIME_TYPE_TEXT : GoogleCloudConstants.MIME_TYPE_PDF)
				.withSize(role == 'Too Small' ? 1000L : 2097152L)
				.isLatest(true)
				.build());

			if (role != 'Unlinked') {
				links.add(GoogleCloudTestFactory.link().forFile(fileId).withShareType('Viewer').build());
			}
		}
		insert versions;
		insert links;

		for (String role : roles) {
			Test.setCreatedDate(filesByRole.get(role).Id, role == 'Created Earlier' ? Datetime.newInstance(2025, 2, 1, 12, 0, 0) : Datetime.newInstance(2025, 3, 3, 12, 0, 0));
		}

		String currentDay = dayString(Date.today());
		SearchInput input = searchFor('renewal contract');
		input.fileExtensions = 'pdf;docx';
		input.minSizeBytes = 1048576L;
		input.maxSizeBytes = 10485760L;
		input.createdFrom = '2025-03-01';
		input.createdTo = '2025-03-05';
		input.modifiedFrom = currentDay;
		input.modifiedTo = currentDay;
		input.minVersions = 2;
		input.ownership = 'mine';
		input.linkState = 'linked';

		Test.startTest();
		GoogleFileExplorerResultDTO result = runSearch(input, UserInfo.getUserId());
		Test.stopTest();

		Assert.areEqual(new List<Id>{ filesByRole.get('Match').Id }, idsOf(result.files), 'Only the file meeting every criterion is listed');
		Assert.isFalse(result.hasMore);
	}

	@IsTest
	private static void testSearchGoogleFilesPagePositiveNothingEnteredListsEveryAccessibleFile() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();

		GoogleFile__c alpha = insertSearchFile('Alpha', 'Alpha.pdf');
		GoogleFile__c bravo = GoogleCloudTestFactory.file().withName('Bravo').insertRecord();
		GoogleFile__c charlie = insertSearchFile('Charlie', 'Charlie.txt');

		Test.startTest();
		GoogleFileExplorerResultDTO forUser = runSearch(new SearchInput(), UserInfo.getUserId());
		GoogleFileExplorerResultDTO forRunningUser = new GoogleLocalFileService().searchGoogleFilesPage(new SearchInput().build());
		Test.stopTest();

		Assert.areEqual(new List<Id>{ alpha.Id, bravo.Id, charlie.Id }, idsOf(forUser.files));
		Assert.areEqual(idsOf(forUser.files), idsOf(forRunningUser.files));
		Assert.isFalse(forUser.hasMore);
		Assert.isNull(forUser.nextCursor);
		Assert.isFalse(forUser.isPrivileged);
	}

	@IsTest
	private static void testSearchGoogleFilesPagePositiveSortsByTheChosenColumn() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();

		GoogleFile__c bravo = insertSearchFile('Bravo', 'Bravo report.pdf');
		GoogleFile__c alpha = insertSearchFile('Alpha', 'Alpha report.pdf');
		GoogleFile__c charlie = insertSearchFile('Charlie', 'Charlie report.pdf');
		insertSearchFile('Delta', 'Delta memo.pdf');

		SearchInput ascending = searchFor('report');
		SearchInput descending = searchFor('report');
		descending.sortDirection = 'DESC';

		Test.startTest();
		GoogleFileExplorerResultDTO ascendingResult = runSearch(ascending, UserInfo.getUserId());
		GoogleFileExplorerResultDTO descendingResult = runSearch(descending, UserInfo.getUserId());
		Test.stopTest();

		Assert.areEqual(new List<Id>{ alpha.Id, bravo.Id, charlie.Id }, idsOf(ascendingResult.files));
		Assert.areEqual(new List<Id>{ charlie.Id, bravo.Id, alpha.Id }, idsOf(descendingResult.files));
	}

	@IsTest
	private static void testSearchGoogleFilesPagePositivePagesThroughMatchesWithoutRepeats() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();

		List<Id> expectedIds = new List<Id>();
		for (Integer i = 1; i <= 7; i++) {
			expectedIds.add(insertSearchFile('Page ' + i, 'Page ' + i + ' probe.pdf').Id);
		}
		for (Integer i = 1; i <= 3; i++) {
			insertSearchFile('Decoy ' + i, 'Decoy ' + i + '.pdf');
		}

		SearchInput input = searchFor('probe');
		input.pageSize = 2;
		List<Id> seenIds = new List<Id>();

		Test.startTest();
		for (Integer page = 0; page < 10; page++) {
			GoogleFileExplorerResultDTO result = runSearch(input, UserInfo.getUserId());
			seenIds.addAll(idsOf(result.files));

			if (!result.hasMore) break;

			Assert.isNotNull(result.nextCursor, 'More files must come with a cursor');
			input.cursor = result.nextCursor;
		}
		Test.stopTest();

		Assert.areEqual(expectedIds, seenIds, 'Every match once, in order, and nothing else');
	}

	@IsTest
	private static void testSearchGoogleFilesPagePositiveOwnerChipUsesTheRealOwner() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();
		GoogleCloudTestFactory.denyAllRecordAccess();
		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		Id readableRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleCloudTestFactory.grantRecordAccess(readableRecordId, true, false);

		GoogleFile__c runningUsersFile = insertSearchFile('Owner Probe', 'Owner probe.pdf');
		linkFileTo(runningUsersFile.Id, readableRecordId, 'Viewer');

		SearchInput mine = new SearchInput();
		mine.ownership = 'mine';
		SearchInput others = new SearchInput();
		others.ownership = 'others';

		Test.startTest();
		GoogleFileExplorerResultDTO targetMine = runSearch(mine, targetUserId);
		GoogleFileExplorerResultDTO targetOthers = runSearch(others, targetUserId);
		GoogleFileExplorerResultDTO targetAnyone = runSearch(new SearchInput(), targetUserId);
		GoogleFileExplorerResultDTO ownerMine = runSearch(mine, UserInfo.getUserId());
		GoogleFileExplorerResultDTO ownerOthers = runSearch(others, UserInfo.getUserId());
		Test.stopTest();

		Assert.isTrue(targetMine.files.isEmpty(), 'Owner: Me lists only files the user owns');
		Assert.areEqual(new List<Id>{ runningUsersFile.Id }, idsOf(targetOthers.files));
		Assert.areEqual(new List<Id>{ runningUsersFile.Id }, idsOf(targetAnyone.files));
		Assert.areEqual(new List<Id>{ runningUsersFile.Id }, idsOf(ownerMine.files), 'The file owner finds it under Owner: Me');
		Assert.isTrue(ownerOthers.files.isEmpty());
	}

	@IsTest
	private static void testSearchGoogleFilesPagePositiveOwnerChipAppliesToViewAllUsers() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();
		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		GoogleCloudTestFactory.setPrivilegedFloor(GoogleFileAccessResolver.AccessLevel.View);

		GoogleFile__c someoneElsesFile = insertSearchFile('View All Probe', 'View all probe.pdf');

		SearchInput mine = new SearchInput();
		mine.ownership = 'mine';
		SearchInput others = new SearchInput();
		others.ownership = 'others';

		Test.startTest();
		GoogleFileExplorerResultDTO mineResult = runSearch(mine, targetUserId);
		GoogleFileExplorerResultDTO othersResult = runSearch(others, targetUserId);
		GoogleFileExplorerResultDTO anyoneResult = runSearch(new SearchInput(), targetUserId);
		Test.stopTest();

		Assert.isTrue(mineResult.isPrivileged);
		Assert.isTrue(mineResult.files.isEmpty(), 'Owner: Me narrows a View All user to their own files');
		Assert.areEqual(new List<Id>{ someoneElsesFile.Id }, idsOf(othersResult.files));
		Assert.areEqual('View', othersResult.files[0].UserAccessLevel__c);
		Assert.areEqual(new List<Id>{ someoneElsesFile.Id }, idsOf(anyoneResult.files));
	}

	@IsTest
	private static void testRetrieveFileExplorerFilesPositivePrivilegedFirstPageStillListsEveryOwner() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();
		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		GoogleCloudTestFactory.setPrivilegedFloor(GoogleFileAccessResolver.AccessLevel.View);

		GoogleFile__c someoneElsesFile = GoogleCloudTestFactory.file().withName('Someone Elses File').insertRecord();

		Test.startTest();
		GoogleFileExplorerResultDTO firstPage = new GoogleLocalFileService().retrieveFileExplorerFiles(targetUserId);
		Test.stopTest();

		Assert.isTrue(firstPage.isPrivileged);
		Assert.areEqual(new List<Id>{ someoneElsesFile.Id }, idsOf(firstPage.files), 'All Files opens on every owner\'s files');
		Assert.areEqual('View', firstPage.files[0].UserAccessLevel__c);
	}

	@IsTest
	private static void testSearchGoogleFilesPageNegativeNeverReturnsAMatchTheUserCannotOpen() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();
		GoogleCloudTestFactory.denyAllRecordAccess();
		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		Id readableRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		Id hiddenRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleCloudTestFactory.grantRecordAccess(readableRecordId, true, false);

		GoogleFile__c reachable = insertSearchFile('Quarterly A', 'Quarterly A.pdf');
		linkFileTo(reachable.Id, readableRecordId, 'Viewer');
		GoogleFile__c behindHiddenRecord = insertSearchFile('Quarterly B', 'Quarterly B.pdf');
		linkFileTo(behindHiddenRecord.Id, hiddenRecordId, 'Viewer');
		GoogleFile__c linkedForTracingOnly = insertSearchFile('Quarterly C', 'Quarterly C.pdf');
		linkFileTo(linkedForTracingOnly.Id, readableRecordId, 'None');
		insertSearchFile('Quarterly D', 'Quarterly D.pdf');

		SearchInput everyMatch = searchFor('quarterly');
		SearchInput narrowed = searchFor('quarterly');
		narrowed.ownership = 'others';
		narrowed.linkState = 'linked';

		Test.startTest();
		GoogleFileExplorerResultDTO everyMatchResult = runSearch(everyMatch, targetUserId);
		GoogleFileExplorerResultDTO narrowedResult = runSearch(narrowed, targetUserId);
		Test.stopTest();

		Assert.areEqual(new List<Id>{ reachable.Id }, idsOf(everyMatchResult.files), 'A match the user cannot open is never listed');
		Assert.areEqual('View', everyMatchResult.files[0].UserAccessLevel__c);
		Assert.isFalse(everyMatchResult.hasMore);
		Assert.areEqual(new List<Id>{ reachable.Id }, idsOf(narrowedResult.files), 'Filters only narrow, they never widen access');
	}

	@IsTest
	private static void testSearchGoogleFilesPagePositiveInferredRecordAccessDecidesTheLevel() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();
		GoogleCloudTestFactory.denyAllRecordAccess();
		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		Id editableRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		Id readOnlyRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		Id hiddenRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleCloudTestFactory.grantRecordAccess(editableRecordId, true, true);
		GoogleCloudTestFactory.grantRecordAccess(readOnlyRecordId, true, false);

		GoogleFile__c editable = insertSearchFile('Inferred Edit', 'Inferred edit.pdf');
		linkFileTo(editable.Id, editableRecordId, 'InferredFromRecord');
		GoogleFile__c hidden = insertSearchFile('Inferred Hidden', 'Inferred hidden.pdf');
		linkFileTo(hidden.Id, hiddenRecordId, 'InferredFromRecord');
		GoogleFile__c viewable = insertSearchFile('Inferred View', 'Inferred view.pdf');
		linkFileTo(viewable.Id, readOnlyRecordId, 'InferredFromRecord');

		Test.startTest();
		GoogleFileExplorerResultDTO result = runSearch(searchFor('inferred'), targetUserId);
		Test.stopTest();

		Assert.areEqual(new List<Id>{ editable.Id, viewable.Id }, idsOf(result.files));
		Assert.areEqual('Edit', result.files[0].UserAccessLevel__c, 'Edit rights on the record give Edit on the file');
		Assert.areEqual('View', result.files[1].UserAccessLevel__c, 'Read rights on the record give View on the file');
	}

	@IsTest
	private static void testSearchGoogleFilesPagePositiveCarriesConfiguredColumnsButNoDriveIds() {
		GoogleCloudTestFactory.config()
			.withFileExplorerColumns('title;Description__c;GoogleDriveFileId__c;GoogleDocsFileId__c;GoogleDriveFolderId__c')
			.apply();
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();

		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('Columns Probe').insertRecord();
		GoogleCloudTestFactory.version()
			.forFile(localFile.Id)
			.withName('Columns probe.pdf')
			.withDescription('Configured column value')
			.withDocsId('DOCS_COPY_ID')
			.withFolderId('FOLDER_ID')
			.isLatest(true)
			.insertRecord();

		Test.startTest();
		GoogleFileExplorerResultDTO result = runSearch(searchFor('columns'), UserInfo.getUserId());
		Test.stopTest();

		Assert.areEqual(1, result.files.size());
		GoogleFileVersion__c latestVersion = result.files[0].GoogleFileVersions__r[0];
		Assert.areEqual('Configured column value', latestVersion.get('Description__c'), 'A configured column comes back with the results');
		Assert.isFalse(latestVersion.isSet('GoogleDriveFileId__c'), 'Drive Ids stay on the server');
		Assert.isFalse(latestVersion.isSet('GoogleDocsFileId__c'), 'Drive Ids stay on the server');
		Assert.isFalse(latestVersion.isSet('GoogleDriveFolderId__c'), 'Drive Ids stay on the server');
	}

	@IsTest
	private static void testSearchGoogleFilesPageNegativeCursorNeverCarriesAHiddenFilesName() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();
		GoogleCloudTestFactory.denyAllRecordAccess();
		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		GoogleCloudTestFactory.mockNoGroupMemberships();
		GoogleFileAccessResolver.WIDE_SCAN_SIZE = 2;
		insertHiddenMergerFiles(GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType));

		SearchInput byName = searchFor('merger');
		byName.pageSize = 1;
		SearchInput byOwner = searchFor('merger');
		byOwner.pageSize = 1;
		byOwner.sortField = 'fileOwner';

		Test.startTest();
		GoogleFileExplorerResultDTO nameSorted = runSearch(byName, targetUserId);
		GoogleFileExplorerResultDTO ownerSorted = runSearch(byOwner, targetUserId);
		Test.stopTest();

		Assert.isTrue(nameSorted.files.isEmpty());
		Assert.isNotNull(nameSorted.nextCursor, 'Rows remain past the hidden files, so the page hands back a cursor');
		Assert.isFalse(decodeCursor(nameSorted.nextCursor).contains('Hidden'), 'The cursor must not carry the name of a file the user cannot open');
		Assert.isFalse(decodeCursor(nameSorted.nextCursor).contains('Merger'), 'The cursor must not carry the name of a file the user cannot open');
		Assert.isNotNull(ownerSorted.nextCursor, 'Rows remain past the hidden files, so the page hands back a cursor');
		Assert.isFalse(decodeCursor(ownerSorted.nextCursor).contains(UserInfo.getName()), 'The cursor must not carry the owner of a file the user cannot open');
	}

	@IsTest
	private static void testRetrieveGoogleFilesPageNegativeCursorNeverCarriesAHiddenFilesName() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();
		GoogleCloudTestFactory.denyAllRecordAccess();
		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		GoogleCloudTestFactory.mockNoGroupMemberships();
		GoogleFileAccessResolver.WIDE_SCAN_SIZE = 2;
		insertHiddenMergerFiles(GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType));

		GoogleFileExplorerPageRequestDTO request = GoogleFileExplorerPageRequestDTO.of('fileName', 'ASC', 'merger', null, 1, GoogleCloudConstants.FILE_EXPLORER_BUCKET_SHARED);

		Test.startTest();
		GoogleFileExplorerResultDTO result = new GoogleLocalFileService().retrieveGoogleFilesPage(request, targetUserId);
		Test.stopTest();

		Assert.isTrue(result.files.isEmpty());
		Assert.isNotNull(result.nextCursor, 'Rows remain past the hidden files, so the page hands back a cursor');
		Assert.isFalse(decodeCursor(result.nextCursor).contains('Hidden'), 'Shared with Me must not carry the name of a file the user cannot open');
		Assert.isFalse(decodeCursor(result.nextCursor).contains('Merger'), 'Shared with Me must not carry the name of a file the user cannot open');
	}

	@IsTest
	private static void testSearchGoogleFilesPagePositiveTamperedCursorValueIsIgnored() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();

		GoogleFile__c alpha = insertSearchFile('Alpha', 'Alpha probe.pdf');
		GoogleFile__c bravo = insertSearchFile('Bravo', 'Bravo probe.pdf');
		GoogleFile__c charlie = insertSearchFile('Charlie', 'Charlie probe.pdf');
		GoogleFile__c delta = insertSearchFile('Delta', 'Delta probe.pdf');

		SearchInput input = searchFor('probe');
		input.pageSize = 2;

		Test.startTest();
		GoogleFileExplorerResultDTO firstPage = runSearch(input, UserInfo.getUserId());
		input.cursor = forgedCursor('string', 'Zulu', bravo.Id);
		GoogleFileExplorerResultDTO valuePastTheEnd = runSearch(input, UserInfo.getUserId());
		input.cursor = forgedCursor('string', 'Aaa', bravo.Id);
		GoogleFileExplorerResultDTO valueBeforeTheStart = runSearch(input, UserInfo.getUserId());
		Test.stopTest();

		Assert.areEqual(new List<Id>{ alpha.Id, bravo.Id }, idsOf(firstPage.files));
		Assert.areEqual(new List<Id>{ charlie.Id, delta.Id }, idsOf(valuePastTheEnd.files), 'The page continues after the cursor row, whatever value the cursor carries');
		Assert.areEqual(new List<Id>{ charlie.Id, delta.Id }, idsOf(valueBeforeTheStart.files), 'The page continues after the cursor row, whatever value the cursor carries');
	}

	@IsTest
	private static void testRetrieveGoogleFilesPagePositiveTamperedCursorValueIsIgnored() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();

		GoogleFile__c alpha = insertSearchFile('Alpha', 'Alpha probe.pdf');
		GoogleFile__c bravo = insertSearchFile('Bravo', 'Bravo probe.pdf');
		GoogleFile__c charlie = insertSearchFile('Charlie', 'Charlie probe.pdf');
		GoogleFile__c delta = insertSearchFile('Delta', 'Delta probe.pdf');

		GoogleFileExplorerPageRequestDTO request = GoogleFileExplorerPageRequestDTO.of('fileName', 'ASC', 'probe', null, 2, GoogleCloudConstants.FILE_EXPLORER_BUCKET_OWNED);

		Test.startTest();
		GoogleFileExplorerResultDTO firstPage = new GoogleLocalFileService().retrieveGoogleFilesPage(request, UserInfo.getUserId());
		request.cursor = forgedCursor('string', 'Zulu', bravo.Id);
		GoogleFileExplorerResultDTO tamperedPage = new GoogleLocalFileService().retrieveGoogleFilesPage(request, UserInfo.getUserId());
		Test.stopTest();

		Assert.areEqual(new List<Id>{ alpha.Id, bravo.Id }, idsOf(firstPage.files));
		Assert.areEqual(new List<Id>{ charlie.Id, delta.Id }, idsOf(tamperedPage.files), 'Owned by Me continues after the cursor row, whatever value the cursor carries');
	}

	@IsTest
	private static void testSearchGoogleFilesPagePositiveMissingCursorRowRestartsFromTheTop() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();

		GoogleFile__c alpha = insertSearchFile('Alpha', 'Alpha probe.pdf');
		GoogleFile__c bravo = insertSearchFile('Bravo', 'Bravo probe.pdf');
		GoogleFile__c charlie = insertSearchFile('Charlie', 'Charlie probe.pdf');
		insertSearchFile('Delta', 'Delta probe.pdf');

		SearchInput input = searchFor('probe');
		input.pageSize = 2;

		Test.startTest();
		GoogleFileExplorerResultDTO firstPage = runSearch(input, UserInfo.getUserId());
		String cursorAtBravo = firstPage.nextCursor;
		delete bravo;
		input.cursor = cursorAtBravo;
		GoogleFileExplorerResultDTO restarted = runSearch(input, UserInfo.getUserId());
		Test.stopTest();

		Assert.isNotNull(cursorAtBravo, 'The first page has more to give');
		Assert.areEqual(new List<Id>{ alpha.Id, charlie.Id }, idsOf(restarted.files), 'A cursor whose file is gone starts the list again from the top');
	}

	@IsTest
	private static void testRetrieveGoogleFilesPagePositiveMissingCursorRowRestartsFromTheTop() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();

		GoogleFile__c alpha = GoogleCloudTestFactory.file().withName('Alpha').insertRecord();
		GoogleFile__c bravo = GoogleCloudTestFactory.file().withName('Bravo').insertRecord();
		GoogleFile__c charlie = GoogleCloudTestFactory.file().withName('Charlie').insertRecord();
		GoogleCloudTestFactory.file().withName('Delta').insertRecord();

		GoogleFileExplorerPageRequestDTO request = GoogleFileExplorerPageRequestDTO.of('fileName', 'ASC', null, null, 2, GoogleCloudConstants.FILE_EXPLORER_BUCKET_OWNED);

		Test.startTest();
		GoogleFileExplorerResultDTO firstPage = new GoogleLocalFileService().retrieveGoogleFilesPage(request, UserInfo.getUserId());
		request.cursor = firstPage.nextCursor;
		delete bravo;
		GoogleFileExplorerResultDTO restarted = new GoogleLocalFileService().retrieveGoogleFilesPage(request, UserInfo.getUserId());
		Test.stopTest();

		Assert.isNotNull(request.cursor, 'The first page has more to give');
		Assert.areEqual(new List<Id>{ alpha.Id, charlie.Id }, idsOf(restarted.files), 'A cursor whose file is gone starts the list again from the top');
	}

	@IsTest
	private static void testSearchGoogleFilesPageNegativeForgedCursorStaysWithinAccess() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();
		GoogleCloudTestFactory.denyAllRecordAccess();
		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		Id readableRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		Id hiddenRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleCloudTestFactory.grantRecordAccess(readableRecordId, true, false);

		GoogleFile__c alpha = insertSearchFile('Alpha', 'Alpha probe.pdf');
		linkFileTo(alpha.Id, readableRecordId, 'Viewer');
		GoogleFile__c bravo = insertSearchFile('Bravo', 'Bravo probe.pdf');
		linkFileTo(bravo.Id, hiddenRecordId, 'Viewer');
		GoogleFile__c charlie = insertSearchFile('Charlie', 'Charlie probe.pdf');
		linkFileTo(charlie.Id, readableRecordId, 'Viewer');
		GoogleFile__c delta = insertSearchFile('Delta', 'Delta probe.pdf');
		linkFileTo(delta.Id, readableRecordId, 'Viewer');

		SearchInput input = searchFor('probe');
		input.pageSize = 2;

		Test.startTest();
		input.cursor = forgedCursor('string', null, bravo.Id);
		GoogleFileExplorerResultDTO afterHiddenRow = runSearch(input, targetUserId);
		input.cursor = 'not a cursor';
		GoogleFileExplorerResultDTO unreadableCursor = runSearch(input, targetUserId);
		Test.stopTest();

		Assert.areEqual(new List<Id>{ charlie.Id, delta.Id }, idsOf(afterHiddenRow.files), 'A cursor naming a hidden file only moves the start, it never lists that file');
		Assert.areEqual(new List<Id>{ alpha.Id, charlie.Id }, idsOf(unreadableCursor.files), 'An unreadable cursor is the first page');
	}

	@IsTest
	private static void testSearchGoogleFilesPageNegativeFailureIsUserSafe() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();
		GoogleCloudTestFactory.denyAllRecordAccess();
		Id unknownUserId = GoogleCloudTestFactory.otherUserId();

		GoogleFile__c linkedFile = insertSearchFile('Linked Probe', 'Linked probe.pdf');
		linkFileTo(linkedFile.Id, GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType), 'Viewer');

		Test.startTest();
		try {
			runSearch(new SearchInput(), unknownUserId);
			Assert.fail('A failure while resolving access must surface as the service exception');
		} catch (GoogleLocalFileService.GoogleLocalFileException ex) {
			Assert.isTrue(ex.getMessage().startsWith('Unable to retrieve files'), ex.getMessage());
			Assert.isFalse(ex.getMessage().contains(String.valueOf(unknownUserId)), ex.getMessage());
		}
		Test.stopTest();
	}

	@IsTest
	private static void testSearchGoogleFilesPagePositiveEveryCriterionAddsNoQuery() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();

		GoogleFile__c onlyFile = GoogleCloudTestFactory.file().withName('Only File').insertRecord();
		insert new List<GoogleFileVersion__c>{
			GoogleCloudTestFactory.version().forFile(onlyFile.Id).withName('Old draft.pdf').isLatest(false).build(),
			GoogleCloudTestFactory.version().forFile(onlyFile.Id).withName('Contract Renewal.pdf').withSize(2097152L).isLatest(true).build()
		};
		linkFileTo(onlyFile.Id, GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType), 'Viewer');

		String currentDay = dayString(Date.today());
		SearchInput everyCriterion = searchFor('contract "renewal"');
		everyCriterion.fileExtensions = 'pdf;docx';
		everyCriterion.minSizeBytes = 1048576L;
		everyCriterion.maxSizeBytes = 10485760L;
		everyCriterion.createdFrom = currentDay;
		everyCriterion.createdTo = currentDay;
		everyCriterion.modifiedFrom = currentDay;
		everyCriterion.modifiedTo = currentDay;
		everyCriterion.minVersions = 2;
		everyCriterion.maxVersions = 10;
		everyCriterion.ownership = 'mine';
		everyCriterion.linkState = 'linked';

		GoogleLocalFileService localFileService = new GoogleLocalFileService();
		localFileService.searchGoogleFilesPage(new SearchInput().build(), UserInfo.getUserId());

		Integer queriesBefore = Limits.getQueries();
		GoogleFileExplorerResultDTO blankResult = localFileService.searchGoogleFilesPage(new SearchInput().build(), UserInfo.getUserId());
		Integer blankQueries = Limits.getQueries() - queriesBefore;

		queriesBefore = Limits.getQueries();
		GoogleFileExplorerResultDTO fullResult = localFileService.searchGoogleFilesPage(everyCriterion.build(), UserInfo.getUserId());
		Integer fullQueries = Limits.getQueries() - queriesBefore;

		Assert.areEqual(new List<Id>{ onlyFile.Id }, idsOf(blankResult.files));
		Assert.areEqual(new List<Id>{ onlyFile.Id }, idsOf(fullResult.files));
		Assert.areEqual(blankQueries, fullQueries, 'The search criteria add no query to the page');
	}

	@IsTest
	private static void testSearchGoogleFilesPagePositiveFreshInstallConfiguration() {
		GoogleMetadataConfigService.configRecordOverride = null;
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();

		GoogleFile__c localFile = insertSearchFile('Fresh Install', 'Fresh install.pdf');

		Test.startTest();
		GoogleFileExplorerResultDTO result = runSearch(searchFor('fresh'), UserInfo.getUserId());
		Test.stopTest();

		Assert.areEqual(new List<Id>{ localFile.Id }, idsOf(result.files));
		Assert.areEqual(1, result.files[0].GoogleFileVersions__r.size());
		Assert.isFalse(result.isPrivileged);
	}

	@IsTest
	private static void testSearchGoogleFilesPagePositiveOldRowsMatchByWhatTheyHave() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();

		GoogleFile__c legacyNamed = GoogleCloudTestFactory.file().withName('Legacy Named').insertRecord();
		GoogleFile__c legacyBare = GoogleCloudTestFactory.file().withName('Legacy Bare').insertRecord();
		GoogleFileVersion__c namedVersion = GoogleCloudTestFactory.version().forFile(legacyNamed.Id).withName('legacy plan.pdf').isLatest(true).build();
		GoogleFileVersion__c bareVersion = GoogleCloudTestFactory.version().forFile(legacyBare.Id).withName('legacy scan').isLatest(true).build();
		namedVersion.Type__c = null;
		bareVersion.Type__c = null;
		insert new List<GoogleFileVersion__c>{ namedVersion, bareVersion };

		SearchInput byWord = searchFor('legacy');
		SearchInput byWordAndType = searchFor('legacy');
		byWordAndType.fileExtensions = 'pdf';

		Test.startTest();
		GoogleFileExplorerResultDTO wordResult = runSearch(byWord, UserInfo.getUserId());
		GoogleFileExplorerResultDTO typeResult = runSearch(byWordAndType, UserInfo.getUserId());
		Test.stopTest();

		Assert.areEqual(new List<Id>{ legacyBare.Id, legacyNamed.Id }, idsOf(wordResult.files), 'A blank summary, labels or type does not stop a name match');
		Assert.areEqual(new List<Id>{ legacyNamed.Id }, idsOf(typeResult.files), 'Without a stored type, the name decides the file type');
	}

	@IsTest
	private static void testSearchGoogleFilesPagePositiveStoredSummariesAreSearchedWithAiOff() {
		GoogleCloudTestFactory.config().withFileIntelligence(false).apply();
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();

		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('Board Pack').insertRecord();
		GoogleCloudTestFactory.version()
			.forFile(localFile.Id)
			.withName('untitled.pdf')
			.withSummary('Mentions the merger timeline')
			.withAiLabels('Board; Finance')
			.isLatest(true)
			.insertRecord();

		Test.startTest();
		GoogleFileExplorerResultDTO bySummary = runSearch(searchFor('merger'), UserInfo.getUserId());
		GoogleFileExplorerResultDTO byLabel = runSearch(searchFor('finance'), UserInfo.getUserId());
		Test.stopTest();

		Assert.areEqual(new List<Id>{ localFile.Id }, idsOf(bySummary.files), 'A stored summary is searched even with AI turned off');
		Assert.areEqual(new List<Id>{ localFile.Id }, idsOf(byLabel.files), 'Stored labels are searched even with AI turned off');
	}

	@IsTest
	private static void testSearchGoogleFilesPagePositiveSizeRangesFollowTheMebibyteRule() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();

		GoogleFile__c justUnderOne = insertSizedFile('Just Under One', 1048575L);
		GoogleFile__c exactlyOne = insertSizedFile('Exactly One', 1048576L);
		GoogleFile__c exactlyTen = insertSizedFile('Exactly Ten', 10485760L);
		GoogleFile__c exactlyHundred = insertSizedFile('Exactly Hundred', 104857600L);

		SearchInput smallerThanOne = new SearchInput();
		smallerThanOne.maxSizeBytes = 1048576L;
		SearchInput oneToTen = new SearchInput();
		oneToTen.minSizeBytes = 1048576L;
		oneToTen.maxSizeBytes = 10485760L;
		SearchInput tenToHundred = new SearchInput();
		tenToHundred.minSizeBytes = 10485760L;
		tenToHundred.maxSizeBytes = 104857600L;
		SearchInput largerThanHundred = new SearchInput();
		largerThanHundred.minSizeBytes = 104857600L;

		Test.startTest();
		List<Id> smallerThanOneIds = idsOf(runSearch(smallerThanOne, UserInfo.getUserId()).files);
		List<Id> oneToTenIds = idsOf(runSearch(oneToTen, UserInfo.getUserId()).files);
		List<Id> tenToHundredIds = idsOf(runSearch(tenToHundred, UserInfo.getUserId()).files);
		List<Id> largerThanHundredIds = idsOf(runSearch(largerThanHundred, UserInfo.getUserId()).files);
		Test.stopTest();

		Assert.areEqual(new List<Id>{ justUnderOne.Id }, smallerThanOneIds);
		Assert.areEqual(new List<Id>{ exactlyOne.Id }, oneToTenIds, 'A range includes its lower limit and stops just before its upper one');
		Assert.areEqual(new List<Id>{ exactlyTen.Id }, tenToHundredIds);
		Assert.areEqual(new List<Id>{ exactlyHundred.Id }, largerThanHundredIds);
	}

	@IsTest
	private static void testSearchGoogleFilesPagePositiveCreatedRangeIncludesBothDays() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();

		GoogleFile__c beforeStart = GoogleCloudTestFactory.file().withName('Before Start').insertRecord();
		GoogleFile__c atStart = GoogleCloudTestFactory.file().withName('At Start').insertRecord();
		GoogleFile__c atEnd = GoogleCloudTestFactory.file().withName('At End').insertRecord();
		GoogleFile__c afterEnd = GoogleCloudTestFactory.file().withName('After End').insertRecord();
		Test.setCreatedDate(beforeStart.Id, Datetime.newInstance(2025, 2, 28, 23, 59, 59));
		Test.setCreatedDate(atStart.Id, Datetime.newInstance(2025, 3, 1, 0, 0, 0));
		Test.setCreatedDate(atEnd.Id, Datetime.newInstance(2025, 3, 5, 23, 59, 59));
		Test.setCreatedDate(afterEnd.Id, Datetime.newInstance(2025, 3, 6, 0, 0, 0));

		SearchInput bothSides = new SearchInput();
		bothSides.createdFrom = '2025-03-01';
		bothSides.createdTo = '2025-03-05';
		bothSides.sortField = 'createdDateDisplay';
		SearchInput fromOnly = new SearchInput();
		fromOnly.createdFrom = '2025-03-01';
		fromOnly.sortField = 'createdDateDisplay';
		SearchInput untilOnly = new SearchInput();
		untilOnly.createdTo = '2025-03-05';
		untilOnly.sortField = 'createdDateDisplay';

		Test.startTest();
		List<Id> bothSidesIds = idsOf(runSearch(bothSides, UserInfo.getUserId()).files);
		List<Id> fromOnlyIds = idsOf(runSearch(fromOnly, UserInfo.getUserId()).files);
		List<Id> untilOnlyIds = idsOf(runSearch(untilOnly, UserInfo.getUserId()).files);
		Test.stopTest();

		Assert.areEqual(new List<Id>{ atStart.Id, atEnd.Id }, bothSidesIds, 'Both the from day and the to day are included, as whole days');
		Assert.areEqual(new List<Id>{ atStart.Id, atEnd.Id, afterEnd.Id }, fromOnlyIds);
		Assert.areEqual(new List<Id>{ beforeStart.Id, atStart.Id, atEnd.Id }, untilOnlyIds);
	}

	@IsTest
	private static void testSearchGoogleFilesPagePositiveModifiedRangeEndsWithTheToDay() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();

		GoogleFile__c earlierFile = GoogleCloudTestFactory.file().withName('Earlier Modified').insertRecord();
		GoogleFile__c laterFile = GoogleCloudTestFactory.file().withName('Later Modified').insertRecord();

		SearchInput changedThisDay = new SearchInput();
		changedThisDay.modifiedFrom = dayString(Date.today());
		changedThisDay.modifiedTo = dayString(Date.today());
		SearchInput untilThePreviousDay = new SearchInput();
		untilThePreviousDay.modifiedTo = dayString(Date.today().addDays(-1));
		SearchInput fromTheNextDay = new SearchInput();
		fromTheNextDay.modifiedFrom = dayString(Date.today().addDays(1));

		Test.startTest();
		List<Id> changedThisDayIds = idsOf(runSearch(changedThisDay, UserInfo.getUserId()).files);
		List<Id> untilThePreviousDayIds = idsOf(runSearch(untilThePreviousDay, UserInfo.getUserId()).files);
		List<Id> fromTheNextDayIds = idsOf(runSearch(fromTheNextDay, UserInfo.getUserId()).files);
		Test.stopTest();

		Assert.areEqual(new List<Id>{ earlierFile.Id, laterFile.Id }, changedThisDayIds, 'A file changed today matches a range ending today');
		Assert.isTrue(untilThePreviousDayIds.isEmpty());
		Assert.isTrue(fromTheNextDayIds.isEmpty());
	}

	@IsTest
	private static void testSearchGoogleFilesPagePositiveVersionAndLinkChipsUseTheFileCounts() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();

		GoogleFile__c five = GoogleCloudTestFactory.file().withName('Five Versions').insertRecord();
		GoogleFile__c one = GoogleCloudTestFactory.file().withName('One Version').insertRecord();
		GoogleFile__c two = GoogleCloudTestFactory.file().withName('Two Versions').insertRecord();

		List<GoogleFileVersion__c> versions = new List<GoogleFileVersion__c>();
		Map<Id, Integer> versionCountByFileId = new Map<Id, Integer>{ five.Id => 5, one.Id => 1, two.Id => 2 };
		for (Id fileId : versionCountByFileId.keySet()) {
			Integer versionCount = versionCountByFileId.get(fileId);
			for (Integer i = 1; i <= versionCount; i++) {
				versions.add(GoogleCloudTestFactory.version().forFile(fileId).withName('Version ' + i + '.pdf').isLatest(i == versionCount).build());
			}
		}
		insert versions;
		linkFileTo(two.Id, GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType), 'Viewer');
		linkFileTo(five.Id, GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType), 'None');

		SearchInput onlyOne = new SearchInput();
		onlyOne.minVersions = 1;
		onlyOne.maxVersions = 1;
		SearchInput twoOrMore = new SearchInput();
		twoOrMore.minVersions = 2;
		SearchInput fiveOrMore = new SearchInput();
		fiveOrMore.minVersions = 5;
		SearchInput linked = new SearchInput();
		linked.linkState = 'linked';
		SearchInput unlinked = new SearchInput();
		unlinked.linkState = 'unlinked';

		Test.startTest();
		List<Id> onlyOneIds = idsOf(runSearch(onlyOne, UserInfo.getUserId()).files);
		List<Id> twoOrMoreIds = idsOf(runSearch(twoOrMore, UserInfo.getUserId()).files);
		List<Id> fiveOrMoreIds = idsOf(runSearch(fiveOrMore, UserInfo.getUserId()).files);
		List<Id> linkedIds = idsOf(runSearch(linked, UserInfo.getUserId()).files);
		List<Id> unlinkedIds = idsOf(runSearch(unlinked, UserInfo.getUserId()).files);
		Test.stopTest();

		Assert.areEqual(new List<Id>{ one.Id }, onlyOneIds);
		Assert.areEqual(new List<Id>{ five.Id, two.Id }, twoOrMoreIds);
		Assert.areEqual(new List<Id>{ five.Id }, fiveOrMoreIds);
		Assert.areEqual(new List<Id>{ five.Id, two.Id }, linkedIds, 'Any link counts, the same rule as the Is Linked? column');
		Assert.areEqual(new List<Id>{ one.Id }, unlinkedIds);
	}

	@IsTest
	private static void testSearchGoogleFilesPagePositiveReversedRangeMatchesNothing() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();

		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('Mid Range').insertRecord();
		Test.setCreatedDate(localFile.Id, Datetime.newInstance(2025, 3, 3, 12, 0, 0));

		SearchInput reversed = new SearchInput();
		reversed.createdFrom = '2025-03-05';
		reversed.createdTo = '2025-03-01';

		Test.startTest();
		GoogleFileExplorerResultDTO result = runSearch(reversed, UserInfo.getUserId());
		Test.stopTest();

		Assert.isTrue(result.files.isEmpty(), 'A range that ends before it starts matches nothing');
		Assert.isFalse(result.hasMore);
	}

	@IsTest
	private static void testSearchGoogleFilesPagePositiveInvalidExtensionsMeanNoTypeFilter() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();

		GoogleFile__c pdfFile = insertSearchFile('Pdf File', 'Pdf file.pdf');
		GoogleFile__c textFile = GoogleCloudTestFactory.file().withName('Text File').insertRecord();
		GoogleCloudTestFactory.version().forFile(textFile.Id).withName('Text file.txt').withType(GoogleCloudConstants.MIME_TYPE_TEXT).isLatest(true).insertRecord();

		SearchInput input = new SearchInput();
		input.fileExtensions = '%;dw g;x\'y';

		Test.startTest();
		GoogleFileExplorerResultDTO result = runSearch(input, UserInfo.getUserId());
		Test.stopTest();

		Assert.areEqual(new List<Id>{ pdfFile.Id, textFile.Id }, idsOf(result.files), 'Extensions that are all invalid mean no type filter');
	}

	@IsTest
	private static void testSearchGoogleFilesPagePositiveCapIgnoresPhrasesPastTheTenth() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();

		GoogleFile__c localFile = insertSearchFile('Phonetic', 'alpha bravo charlie delta echo foxtrot golf hotel india juliet.pdf');

		Test.startTest();
		GoogleFileExplorerResultDTO result = runSearch(searchFor('alpha bravo charlie delta echo foxtrot golf hotel india juliet kilo'), UserInfo.getUserId());
		Test.stopTest();

		Assert.areEqual(new List<Id>{ localFile.Id }, idsOf(result.files), 'The eleventh word is ignored, so its absence does not exclude the file');
	}

	@IsTest
	private static void testSearchGoogleFilesPagePositiveUnclosedQuoteIsOnePhrase() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();

		GoogleFile__c exactOrder = insertSearchFile('Exact Order', 'Acme renewal terms.pdf');
		GoogleFile__c otherOrder = insertSearchFile('Other Order', 'Acme terms of renewal.pdf');

		Test.startTest();
		List<Id> unclosedIds = idsOf(runSearch(searchFor('acme "renewal terms'), UserInfo.getUserId()).files);
		List<Id> closedIds = idsOf(runSearch(searchFor('acme "renewal terms"'), UserInfo.getUserId()).files);
		List<Id> wordIds = idsOf(runSearch(searchFor('acme renewal terms'), UserInfo.getUserId()).files);
		Test.stopTest();

		Assert.areEqual(new List<Id>{ exactOrder.Id }, unclosedIds, 'Text after a quote that is never closed is one phrase');
		Assert.areEqual(new List<Id>{ exactOrder.Id }, closedIds);
		Assert.areEqual(new List<Id>{ exactOrder.Id, otherOrder.Id }, wordIds);
	}

	@IsTest
	private static void testRetrieveFileExplorerOwnersPositiveMapsEveryOwner() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.mockInternalUser();
		GoogleCloudTestFactory.setPrivilegedFloor(GoogleFileAccessResolver.AccessLevel.View);
		Id userOwnerId = GoogleCloudTestFactory.fakeId(User.SObjectType);
		Id queueOwnerId = GoogleCloudTestFactory.fakeId('00G');
		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(new List<Map<String, Object>>{
			new Map<String, Object>{ GoogleFileSelector.OWNER_ID_KEY => userOwnerId, GoogleFileSelector.OWNER_NAME_KEY => 'Dana Reyes' },
			new Map<String, Object>{ GoogleFileSelector.OWNER_ID_KEY => queueOwnerId, GoogleFileSelector.OWNER_NAME_KEY => 'Contracts Queue' }
		});

		Test.startTest();
		List<GoogleFileOwnerDTO> owners = new GoogleLocalFileService().retrieveFileExplorerOwners();
		Test.stopTest();

		Assert.areEqual(2, owners.size(), 'Each owner becomes one entry');
		Assert.areEqual(queueOwnerId, owners[0].ownerId);
		Assert.areEqual('Contracts Queue', owners[0].name);
		Assert.areEqual(userOwnerId, owners[1].ownerId);
		Assert.areEqual('Dana Reyes', owners[1].name);
	}

	@IsTest
	private static void testRetrieveFileExplorerOwnersNegativeFailureIsUserSafe() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.setPrivilegedFloor(GoogleFileAccessResolver.AccessLevel.View);
		GSOQL.mock(GoogleUserSelector.MOCK_ID).thenReturn(new List<SObject>());

		Test.startTest();
		try {
			new GoogleLocalFileService().retrieveFileExplorerOwners();
			Assert.fail('A failure while resolving owners must surface as the service exception');
		} catch (GoogleLocalFileService.GoogleLocalFileException ex) {
			Assert.areEqual('Unable to retrieve file owners. Please try again or contact your system administrator', ex.getMessage());
		}
		Test.stopTest();
	}

	private class SearchInput {
		public String keyPhrases;
		public String fileExtensions;
		public Long minSizeBytes;
		public Long maxSizeBytes;
		public String createdFrom;
		public String createdTo;
		public String modifiedFrom;
		public String modifiedTo;
		public Integer minVersions;
		public Integer maxVersions;
		public String ownership;
		public String linkState;
		public String sortField = 'fileName';
		public String sortDirection = 'ASC';
		public String cursor;
		public Integer pageSize = 50;

		public GoogleFileExplorerSearchRequestDTO build() {
			return GoogleFileExplorerSearchRequestDTO.of(keyPhrases, fileExtensions, minSizeBytes, maxSizeBytes, createdFrom, createdTo, modifiedFrom, modifiedTo, minVersions, maxVersions, ownership, linkState, sortField, sortDirection, cursor, pageSize);
		}
	}
}
