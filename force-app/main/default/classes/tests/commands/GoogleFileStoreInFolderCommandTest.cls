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
private class GoogleFileStoreInFolderCommandTest {
	private static final String ROOT_FOLDER_ID = 'ROOT_FOLDER_01';
	private static final String DESTINATION_FOLDER_ID = 'DEST_FOLDER_01';
	private static final String COPIES_FOLDER_ID = 'COPIES_FOLDER_01';
	private static final String ORIGINAL_DRIVE_ID = 'GD_ORIGINAL_01';
	private static final String COPY_DRIVE_ID = 'GWS_COPY_01';
	private static final String RECORD_NAME = 'Acme Brochure';
	private static final String TODAYS_RECORD_FOLDER_NAME = 'GoogleFile__c : Acme Brochure';
	private static final String DRIVE_SERVER_ERROR_BODY = '{"error":{"code":500,"message":"Internal Error","errors":[{"domain":"global","reason":"internalError","message":"Internal Error"}]}}';
	private static final String DRIVE_NOT_FOUND_BODY = '{"error":{"code":404,"message":"File not found.","errors":[{"domain":"global","reason":"notFound","message":"File not found."}]}}';

	private static GoogleClientConfig__mdt buildFolderConfig(String uploadFolderId, String folderStructure) {
		GoogleClientConfig__mdt config = new GoogleClientConfig__mdt();
		config.DefaultGoogleUploadFolderId__c = uploadFolderId;
		config.CustomGoogleUploadFolderStructure__c = folderStructure;
		return config;
	}

	private static IGoogleUnitOfWork buildUow() {
		return GoogleCloudTestFactory.unitOfWork();
	}

	@IsTest
	private static void testPlaceFileNegativeNullRequest() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig('ROOT_01', '{User}');

		Test.startTest();
		try {
			new GoogleFileStoreInFolderCommand(buildUow()).placeFile(null);
			Assert.isTrue(false);
		} catch (GoogleFileStoreInFolderCommand.GoogleFileStoreInFolderCommandException ex) {
			Assert.isTrue(ex.getMessage().contains('request is empty'));
		}
		Test.stopTest();
	}

	@IsTest
	private static void testPlaceFileNegativeNullVersionId() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig('ROOT_01', '{User}');

		GoogleFileRelocationRequestDTO request = new GoogleFileRelocationRequestDTO(
			UserInfo.getUserId(),
			GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType),
			null,
			null
		);

		Test.startTest();
		try {
			new GoogleFileStoreInFolderCommand(buildUow()).placeFile(request);
			Assert.isTrue(false);
		} catch (GoogleFileStoreInFolderCommand.GoogleFileStoreInFolderCommandException ex) {
			Assert.isTrue(ex.getMessage().contains('localGoogleFileVersionId is empty'));
		}
		Test.stopTest();
	}

	@IsTest
	private static void testPlaceFileNegativeVersionNotFound() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig('ROOT_01', '{User}');

		GoogleFileRelocationRequestDTO request = new GoogleFileRelocationRequestDTO(
			UserInfo.getUserId(),
			GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType),
			GoogleCloudTestFactory.fakeId(GoogleFileVersion__c.SObjectType),
			null
		);

		Test.startTest();
		try {
			new GoogleFileStoreInFolderCommand(buildUow()).placeFile(request);
			Assert.isTrue(false);
		} catch (GoogleFileStoreInFolderCommand.GoogleFileStoreInFolderCommandException ex) {
			Assert.isTrue(ex.getMessage().contains('Google File Version not found'));
		}
		Test.stopTest();
	}

	@IsTest
	private static void testPlaceFilePositiveRecordUserStructure() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.queryContains('appProperties')
		).thenReturnStatus(200, '{"files":[]}');
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('PATCH')
		).thenReturnStatus(200, '{"id":"MOVED_FILE_01"}');
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('PUT')
		).thenReturnStatus(200, '{"id":"MOVED_FILE_01"}');

		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig('ROOT_FOLDER_01', '{Record}-{User}');

		Id linkedRecordId = GoogleCloudTestFactory.linkedRecord('Placement Record');

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('Placement File')
			.insertRecord();

		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('Placement File.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId('GD_PLACE_1')
			.withDocsId('GWS_PLACE_1')
			.insertRecord();

		GoogleFileLink__c link = GoogleCloudTestFactory.link()
			.forFile(parentFile.Id)
			.withLinkedRecord(linkedRecordId)
			.withLinkedType('GoogleFile__c')
			.insertRecord();

		GoogleFileRelocationRequestDTO request = new GoogleFileRelocationRequestDTO(
			UserInfo.getUserId(),
			parentFile.Id,
			localFileVersion.Id,
			link.Id
		);

		IGoogleUnitOfWork uow = buildUow();

		Test.startTest();
		new GoogleFileStoreInFolderCommand(uow).placeFile(request);
		uow.commitWork(true);
		Test.stopTest();

		GoogleFileVersion__c updated = [
			SELECT GoogleDriveFolderId__c, GoogleDriveFileId__c
			FROM GoogleFileVersion__c
			WHERE Id = :localFileVersion.Id
			LIMIT 1
		];

		Assert.isNotNull(updated.GoogleDriveFolderId__c);
		Assert.areEqual('MOVED_FILE_01', updated.GoogleDriveFileId__c);
	}

	private static GoogleFileRelocationRequestDTO buildPlacementRequest(Id linkedRecordId, String driveFileId) {
		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('Placement File')
			.insertRecord();

		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('Placement File.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId(driveFileId)
			.withFolderId('ROOT_FOLDER_01')
			.insertRecord();

		GoogleFileLink__c link = GoogleCloudTestFactory.link()
			.forFile(parentFile.Id)
			.withLinkedRecord(linkedRecordId)
			.withLinkedType('GoogleFile__c')
			.insertRecord();

		return new GoogleFileRelocationRequestDTO(
			UserInfo.getUserId(),
			parentFile.Id,
			localFileVersion.Id,
			link.Id
		);
	}

	@IsTest
	private static void testPlaceFilePositiveManyFilesShareOneFolderResolution() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.queryContains('appProperties')
		).thenReturnStatus(200, '{"files":[{"id":"SHARED_FOLDER_01","name":"Existing Folder"}]}');
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('PATCH')
		).thenReturnStatus(200, '{"id":"MOVED_FILE_01"}');

		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig('ROOT_FOLDER_01', '{Record}');

		Id linkedRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		List<GoogleFileRelocationRequestDTO> requests = new List<GoogleFileRelocationRequestDTO>{
			buildPlacementRequest(linkedRecordId, 'GD_SHARED_1'),
			buildPlacementRequest(linkedRecordId, 'GD_SHARED_2'),
			buildPlacementRequest(linkedRecordId, 'GD_SHARED_3')
		};

		IGoogleUnitOfWork uow = buildUow();
		GoogleFileStoreInFolderCommand storeInFolderCommand = new GoogleFileStoreInFolderCommand(uow);

		Test.startTest();
		for (GoogleFileRelocationRequestDTO request : requests) {
			Assert.isTrue(storeInFolderCommand.placeFile(request));
		}
		uow.commitWork(true);
		Test.stopTest();

		Integer folderSearchCallouts = 0;
		for (GoogleDriveHttpMock.CapturedRequest capturedRequest : driveMock.getCapturedRequests()) {
			if (capturedRequest.endpoint != null && capturedRequest.endpoint.contains('appProperties')) {
				folderSearchCallouts++;
			}
		}

		Assert.areEqual(1, folderSearchCallouts, 'Every file of the same record must reuse a single folder resolution');

		for (GoogleFileVersion__c placedVersion : [SELECT GoogleDriveFolderId__c FROM GoogleFileVersion__c]) {
			Assert.areEqual('SHARED_FOLDER_01', placedVersion.GoogleDriveFolderId__c);
		}
	}

	@IsTest
	private static void testPlaceFileNegativeDefersWhileAnotherTransactionCreatesFolder() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.queryContains('appProperties')
		).thenReturnStatus(200, '{"files":[]}');

		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig('ROOT_FOLDER_01', '{Record}');

		Id linkedRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleFileRelocationRequestDTO request = buildPlacementRequest(linkedRecordId, 'GD_DEFERRED_1');

		GoogleCacheDriveFolderService folderCache = new GoogleCacheDriveFolderService();
		folderCache.markPending(folderCache.buildFolderKey('ROOT_FOLDER_01', linkedRecordId));

		IGoogleUnitOfWork uow = buildUow();

		Test.startTest();
		Boolean isSettled = new GoogleFileStoreInFolderCommand(uow).placeFile(request);
		uow.commitWork(true);
		Test.stopTest();

		Assert.isFalse(isSettled, 'A deferred placement must be reported so the job can retry it');

		GoogleFileVersion__c untouchedVersion = [
			SELECT GoogleDriveFolderId__c
			FROM GoogleFileVersion__c
			WHERE Id = :request.localGoogleFileVersionId
			LIMIT 1
		];

		Assert.areEqual('ROOT_FOLDER_01', untouchedVersion.GoogleDriveFolderId__c, 'A deferred file must stay in the upload root until the retry places it');
	}

	@IsTest
	private static void testPlaceFilePositiveExistingFolder() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.queryContains('appProperties')
		).thenReturnStatus(200, '{"files":[{"id":"DEST_FOLDER_01","name":"Existing Folder"}]}');
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('PATCH')
		).thenReturnStatus(200, '{"id":"MOVED_FILE_02"}');
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('PUT')
		).thenReturnStatus(200, '{"id":"MOVED_FILE_02"}');

		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig('ROOT_FOLDER_01', '{Record}-{User}');

		Id linkedRecordId = GoogleCloudTestFactory.linkedRecord('Existing Folder Record');

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('Existing Folder File')
			.insertRecord();

		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('Existing Folder File.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId('GD_EXISTING_1')
			.withDocsId('GWS_EXISTING_1')
			.insertRecord();

		GoogleFileLink__c link = GoogleCloudTestFactory.link()
			.forFile(parentFile.Id)
			.withLinkedRecord(linkedRecordId)
			.withLinkedType('GoogleFile__c')
			.insertRecord();

		GoogleFileRelocationRequestDTO request = new GoogleFileRelocationRequestDTO(
			UserInfo.getUserId(),
			parentFile.Id,
			localFileVersion.Id,
			link.Id
		);

		IGoogleUnitOfWork uow = buildUow();

		Test.startTest();
		new GoogleFileStoreInFolderCommand(uow).placeFile(request);
		uow.commitWork(true);
		Test.stopTest();

		GoogleFileVersion__c updated = [
			SELECT GoogleDriveFolderId__c, GoogleDriveFileId__c
			FROM GoogleFileVersion__c
			WHERE Id = :localFileVersion.Id
			LIMIT 1
		];

		Assert.areEqual('DEST_FOLDER_01', updated.GoogleDriveFolderId__c);
		Assert.areEqual('MOVED_FILE_02', updated.GoogleDriveFileId__c);
	}

	@IsTest
	private static void testPlaceFilePositiveBlankStructureEarlyReturn() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig('ROOT_FOLDER_01', '');

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('No Move File')
			.insertRecord();

		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('No Move File.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId('GD_NO_MOVE_1')
			.withDocsId('GWS_NO_MOVE_1')
			.insertRecord();

		GoogleFileRelocationRequestDTO request = new GoogleFileRelocationRequestDTO(
			UserInfo.getUserId(),
			parentFile.Id,
			localFileVersion.Id,
			null
		);

		IGoogleUnitOfWork uow = buildUow();

		Test.startTest();
		new GoogleFileStoreInFolderCommand(uow).placeFile(request);
		uow.commitWork(true);
		Test.stopTest();

		GoogleFileVersion__c sameVersion = [
			SELECT GoogleDriveFolderId__c, GoogleDriveFileId__c
			FROM GoogleFileVersion__c
			WHERE Id = :localFileVersion.Id
			LIMIT 1
		];

		Assert.areEqual(null, sameVersion.GoogleDriveFolderId__c);
		Assert.areEqual('GD_NO_MOVE_1', sameVersion.GoogleDriveFileId__c);
	}

	@IsTest
	private static void testPlaceFilePositiveRecordStructureWithoutLinkEarlyReturn() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig('ROOT_FOLDER_01', '{Record}');

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('Standalone File')
			.insertRecord();

		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('Standalone File.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId('GD_STANDALONE_1')
			.withDocsId('GWS_STANDALONE_1')
			.insertRecord();

		GoogleFileRelocationRequestDTO request = new GoogleFileRelocationRequestDTO(
			UserInfo.getUserId(),
			parentFile.Id,
			localFileVersion.Id,
			null
		);

		IGoogleUnitOfWork uow = buildUow();

		Test.startTest();
		new GoogleFileStoreInFolderCommand(uow).placeFile(request);
		uow.commitWork(true);
		Test.stopTest();

		GoogleFileVersion__c sameVersion = [
			SELECT GoogleDriveFolderId__c, GoogleDriveFileId__c
			FROM GoogleFileVersion__c
			WHERE Id = :localFileVersion.Id
			LIMIT 1
		];

		Assert.areEqual(null, sameVersion.GoogleDriveFolderId__c);
		Assert.areEqual('GD_STANDALONE_1', sameVersion.GoogleDriveFileId__c);
	}

	@IsTest
	private static void testPlaceFilePositiveUsesFallbackDriveAsEffectiveRoot() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.queryContains('appProperties')
		).thenReturnStatus(200, '{"files":[]}');
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('PATCH')
		).thenReturnStatus(200, '{"id":"MOVED_FILE_FALLBACK"}');
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('PUT')
		).thenReturnStatus(200, '{"id":"MOVED_FILE_FALLBACK"}');

		GoogleCloudTestFactory.initMocks(driveMock);

		GoogleClientConfig__mdt config = new GoogleClientConfig__mdt();
		config.DefaultGoogleUploadFolderId__c = 'PRIMARY_ROOT_FOLDER';
		config.AdditionalGoogleUploadFolderIds__c = 'FALLBACK_ROOT_FOLDER';
		config.CustomGoogleUploadFolderStructure__c = '{Record}';
		GoogleMetadataConfigService.configRecordOverride = config;

		Id linkedRecordId = GoogleCloudTestFactory.linkedRecord('Fallback Placement Record');

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('Fallback File')
			.insertRecord();

		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('Fallback File.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId('GD_FALLBACK_1')
			.withDocsId('GWS_FALLBACK_1')
			.insertRecord();

		localFileVersion.GoogleDriveFolderId__c = 'FALLBACK_ROOT_FOLDER';
		update localFileVersion;

		GoogleFileLink__c link = GoogleCloudTestFactory.link()
			.forFile(parentFile.Id)
			.withLinkedRecord(linkedRecordId)
			.withLinkedType('GoogleFile__c')
			.insertRecord();

		GoogleFileRelocationRequestDTO request = new GoogleFileRelocationRequestDTO(
			UserInfo.getUserId(),
			parentFile.Id,
			localFileVersion.Id,
			link.Id
		);

		IGoogleUnitOfWork uow = buildUow();

		Test.startTest();
		new GoogleFileStoreInFolderCommand(uow).placeFile(request);
		uow.commitWork(true);
		Test.stopTest();

		GoogleFileVersion__c updated = [
			SELECT GoogleDriveFolderId__c, GoogleDriveFileId__c
			FROM GoogleFileVersion__c
			WHERE Id = :localFileVersion.Id
			LIMIT 1
		];

		Assert.isNotNull(updated.GoogleDriveFolderId__c);
		Assert.areEqual('MOVED_FILE_FALLBACK', updated.GoogleDriveFileId__c);

		Boolean createdFolderInFallbackDrive = false;
		for (GoogleDriveHttpMock.CapturedRequest captured : driveMock.getCapturedRequests()) {
			if (captured.method == 'POST' && captured.body != null && captured.body.contains('FALLBACK_ROOT_FOLDER')) {
				createdFolderInFallbackDrive = true;
				break;
			}
		}
		Assert.isTrue(createdFolderInFallbackDrive, 'Expected a folder-creation POST whose body references the fallback root folder');
	}

	@IsTest
	private static void testPlaceFilePositiveSelfHealsFromDriveWhenStoredFolderBlank() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.endpointContains('GD_BIGFILE_1')
				.queryContains('fields=id')
		).thenReturnStatus(200, '{"id":"GD_BIGFILE_1","parents":["FALLBACK_ROOT_FOLDER"]}');
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.queryContains('appProperties')
		).thenReturnStatus(200, '{"files":[]}');
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('PATCH')
		).thenReturnStatus(200, '{"id":"MOVED_FILE_BIGFILE"}');

		GoogleCloudTestFactory.initMocks(driveMock);

		GoogleClientConfig__mdt config = new GoogleClientConfig__mdt();
		config.DefaultGoogleUploadFolderId__c = 'PRIMARY_ROOT_FOLDER';
		config.AdditionalGoogleUploadFolderIds__c = 'FALLBACK_ROOT_FOLDER';
		config.CustomGoogleUploadFolderStructure__c = '{Record}';
		GoogleMetadataConfigService.configRecordOverride = config;

		Id linkedRecordId = GoogleCloudTestFactory.linkedRecord('Self-Healing Placement Record');

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('Big File')
			.insertRecord();

		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('Big File.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId('GD_BIGFILE_1')
			.withDocsId('GWS_BIGFILE_1')
			.insertRecord();

		GoogleFileLink__c link = GoogleCloudTestFactory.link()
			.forFile(parentFile.Id)
			.withLinkedRecord(linkedRecordId)
			.withLinkedType('GoogleFile__c')
			.insertRecord();

		GoogleFileRelocationRequestDTO request = new GoogleFileRelocationRequestDTO(
			UserInfo.getUserId(),
			parentFile.Id,
			localFileVersion.Id,
			link.Id
		);

		IGoogleUnitOfWork uow = buildUow();

		Test.startTest();
		new GoogleFileStoreInFolderCommand(uow).placeFile(request);
		uow.commitWork(true);
		Test.stopTest();

		GoogleFileVersion__c updated = [
			SELECT GoogleDriveFolderId__c, GoogleDriveFileId__c
			FROM GoogleFileVersion__c
			WHERE Id = :localFileVersion.Id
			LIMIT 1
		];

		Assert.isNotNull(updated.GoogleDriveFolderId__c);
		Assert.areEqual('MOVED_FILE_BIGFILE', updated.GoogleDriveFileId__c);

		Boolean searchedInFallbackDrive = false;
		Boolean createdFolderInFallbackDrive = false;
		for (GoogleDriveHttpMock.CapturedRequest captured : driveMock.getCapturedRequests()) {
			if (captured.method == 'GET' && captured.endpoint != null && captured.endpoint.contains('FALLBACK_ROOT_FOLDER')) {
				searchedInFallbackDrive = true;
			}
			if (captured.method == 'POST' && captured.body != null && captured.body.contains('FALLBACK_ROOT_FOLDER')) {
				createdFolderInFallbackDrive = true;
			}
		}
		Assert.isTrue(searchedInFallbackDrive, 'Expected the subfolder search to run inside the fallback root discovered via Drive lookup');
		Assert.isTrue(createdFolderInFallbackDrive, 'Expected the subfolder creation POST to reference the fallback root');
	}

	private static void applyPlacementConfig(Boolean isRenameEnabled, String copiesFolderId) {
		GoogleClientConfig__mdt config = buildFolderConfig(ROOT_FOLDER_ID, '{Record}');
		config.IsFolderRenameEnabled__c = isRenameEnabled;
		config.WorkspaceCopyFolderId__c = copiesFolderId;
		GoogleMetadataConfigService.configRecordOverride = config;
	}

	private static GoogleDriveHttpMock buildPlacementMock() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.queryContains('appProperties')
		).thenReturnStatus(200, '{"files":[{"id":"' + DESTINATION_FOLDER_ID + '","name":"GoogleFile__c : Old Name"}]}');
		return driveMock;
	}

	private static void answerDrive(GoogleDriveHttpMock driveMock, String method, String driveId, Integer statusCode, String body) {
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod(method)
				.endpointContains('/files/' + driveId)
		).thenReturnStatus(statusCode, body);
	}

	private static void answerMoves(GoogleDriveHttpMock driveMock) {
		answerDrive(driveMock, 'PATCH', DESTINATION_FOLDER_ID, 200, '{"id":"' + DESTINATION_FOLDER_ID + '"}');
		answerDrive(driveMock, 'PATCH', ORIGINAL_DRIVE_ID, 200, '{"id":"' + ORIGINAL_DRIVE_ID + '"}');
		answerDrive(driveMock, 'PATCH', COPY_DRIVE_ID, 200, '{"id":"' + COPY_DRIVE_ID + '"}');
	}

	private static void answerCopyParent(GoogleDriveHttpMock driveMock, String parentFolderId) {
		answerDrive(driveMock, 'GET', COPY_DRIVE_ID, 200, '{"id":"' + COPY_DRIVE_ID + '","parents":["' + parentFolderId + '"]}');
	}

	private static GoogleFileRelocationRequestDTO insertPlacementFixture() {
		GoogleCloudTestFactory.bypassTriggers();
		GoogleFile__c record = GoogleCloudTestFactory.file().withName(RECORD_NAME).insertRecord();
		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('Placed Report').insertRecord();

		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('Placed Report.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(1024)
			.withDriveId(ORIGINAL_DRIVE_ID)
			.withDocsId(COPY_DRIVE_ID)
			.withFolderId(ROOT_FOLDER_ID)
			.insertRecord();

		GoogleFileLink__c link = GoogleCloudTestFactory.link()
			.forFile(parentFile.Id)
			.withLinkedRecord(record.Id)
			.withLinkedType('GoogleFile__c')
			.insertRecord();

		return new GoogleFileRelocationRequestDTO(UserInfo.getUserId(), parentFile.Id, localFileVersion.Id, link.Id);
	}

	private static Boolean placeAndCommit(GoogleFileRelocationRequestDTO request) {
		IGoogleUnitOfWork uow = buildUow();
		Boolean isSettled = new GoogleFileStoreInFolderCommand(uow).placeFile(request);
		uow.commitWork(true);
		return isSettled;
	}

	private static String placedFolderId(Id versionId) {
		return [SELECT GoogleDriveFolderId__c FROM GoogleFileVersion__c WHERE Id = :versionId LIMIT 1].GoogleDriveFolderId__c;
	}

	private static List<GoogleDriveHttpMock.CapturedRequest> requestsTo(GoogleDriveHttpMock driveMock, String method, String driveId) {
		List<GoogleDriveHttpMock.CapturedRequest> matchingRequests = new List<GoogleDriveHttpMock.CapturedRequest>();
		String drivePath = ('/files/' + driveId).toLowerCase();
		for (GoogleDriveHttpMock.CapturedRequest capturedRequest : driveMock.getCapturedRequests()) {
			String endpoint = capturedRequest.endpoint == null ? '' : capturedRequest.endpoint.toLowerCase();
			if (capturedRequest.method == method && endpoint.contains(drivePath)) matchingRequests.add(capturedRequest);
		}

		return matchingRequests;
	}

	@IsTest
	private static void testPlaceFilePositiveRenamesTheRecordFolderWhenRenamingIsOn() {
		GoogleDriveHttpMock driveMock = buildPlacementMock();
		answerMoves(driveMock);
		GoogleCloudTestFactory.initMocks(driveMock);
		applyPlacementConfig(true, null);
		GoogleFileRelocationRequestDTO request = insertPlacementFixture();

		Test.startTest();
		Boolean isSettled = placeAndCommit(request);
		Test.stopTest();

		Assert.isTrue(isSettled);
		Assert.areEqual(DESTINATION_FOLDER_ID, placedFolderId(request.localGoogleFileVersionId));
		List<GoogleDriveHttpMock.CapturedRequest> renames = requestsTo(driveMock, 'PATCH', DESTINATION_FOLDER_ID);
		Assert.areEqual(1, renames.size(), 'A file arriving on a record renames the folder it reaches');
		Assert.isTrue(renames[0].body != null && renames[0].body.contains(TODAYS_RECORD_FOLDER_NAME));
	}

	@IsTest
	private static void testPlaceFilePositiveFailedRenameStillPlacesTheFile() {
		GoogleDriveHttpMock driveMock = buildPlacementMock();
		answerDrive(driveMock, 'PATCH', DESTINATION_FOLDER_ID, 500, DRIVE_SERVER_ERROR_BODY);
		answerMoves(driveMock);
		GoogleCloudTestFactory.initMocks(driveMock);
		applyPlacementConfig(true, null);
		GoogleFileRelocationRequestDTO request = insertPlacementFixture();

		Exception placementFailure;
		Boolean isSettled;
		Test.startTest();
		try {
			isSettled = placeAndCommit(request);
		} catch (Exception ex) {
			placementFailure = ex;
		}
		Test.stopTest();

		Assert.isNull(placementFailure, 'A rename never fails a placement');
		Assert.isTrue(isSettled);
		Assert.areEqual(DESTINATION_FOLDER_ID, placedFolderId(request.localGoogleFileVersionId), 'The file is placed as it would be without renaming');
		Assert.areEqual(1, requestsTo(driveMock, 'PATCH', ORIGINAL_DRIVE_ID).size());
	}

	@IsTest
	private static void testPlaceFilePositiveLeavesACopyThatLivesInTheCopiesFolder() {
		GoogleDriveHttpMock driveMock = buildPlacementMock();
		answerCopyParent(driveMock, COPIES_FOLDER_ID);
		answerMoves(driveMock);
		GoogleCloudTestFactory.initMocks(driveMock);
		applyPlacementConfig(false, COPIES_FOLDER_ID);
		GoogleFileRelocationRequestDTO request = insertPlacementFixture();

		Test.startTest();
		placeAndCommit(request);
		Test.stopTest();

		Assert.areEqual(DESTINATION_FOLDER_ID, placedFolderId(request.localGoogleFileVersionId));
		Assert.areEqual(1, requestsTo(driveMock, 'PATCH', ORIGINAL_DRIVE_ID).size(), 'The original moves into its record folder');
		Assert.areEqual(0, requestsTo(driveMock, 'PATCH', COPY_DRIVE_ID).size(), 'A copy in the copies folder stays there, so record folders hold only originals');
	}

	@IsTest
	private static void testPlaceFilePositiveMovesACopyStillBesideItsOriginal() {
		GoogleDriveHttpMock driveMock = buildPlacementMock();
		answerCopyParent(driveMock, ROOT_FOLDER_ID);
		answerMoves(driveMock);
		GoogleCloudTestFactory.initMocks(driveMock);
		applyPlacementConfig(false, COPIES_FOLDER_ID);
		GoogleFileRelocationRequestDTO request = insertPlacementFixture();

		Test.startTest();
		placeAndCommit(request);
		Test.stopTest();

		Assert.areEqual(1, requestsTo(driveMock, 'PATCH', COPY_DRIVE_ID).size(), 'A copy made before the folder was set, or beside the original by the fallback, still moves with it');
	}

	@IsTest
	private static void testPlaceFilePositiveWithoutACopiesFolderMovesTheCopyWithoutReadingIt() {
		GoogleDriveHttpMock driveMock = buildPlacementMock();
		answerMoves(driveMock);
		GoogleCloudTestFactory.initMocks(driveMock);
		applyPlacementConfig(false, null);
		GoogleFileRelocationRequestDTO request = insertPlacementFixture();

		Test.startTest();
		placeAndCommit(request);
		Test.stopTest();

		Assert.areEqual(1, requestsTo(driveMock, 'PATCH', COPY_DRIVE_ID).size(), 'Without a copies folder the copy moves with the original, as before');
		Assert.areEqual(0, requestsTo(driveMock, 'GET', COPY_DRIVE_ID).size(), 'Without a copies folder placement costs no extra call');
	}

	@IsTest
	private static void testPlaceFilePositiveUnreadableCopyIsLeftAndTheFileIsStillPlaced() {
		GoogleDriveHttpMock driveMock = buildPlacementMock();
		answerDrive(driveMock, 'GET', COPY_DRIVE_ID, 404, DRIVE_NOT_FOUND_BODY);
		answerMoves(driveMock);
		GoogleCloudTestFactory.initMocks(driveMock);
		applyPlacementConfig(false, COPIES_FOLDER_ID);
		GoogleFileRelocationRequestDTO request = insertPlacementFixture();

		Exception placementFailure;
		Test.startTest();
		try {
			placeAndCommit(request);
		} catch (Exception ex) {
			placementFailure = ex;
		}
		Test.stopTest();

		Assert.isNull(placementFailure);
		Assert.areEqual(DESTINATION_FOLDER_ID, placedFolderId(request.localGoogleFileVersionId));
		Assert.areEqual(0, requestsTo(driveMock, 'PATCH', COPY_DRIVE_ID).size(), 'A copy whose folder cannot be read counts as not beside the original');
	}

	@IsTest
	private static void testPlaceFilePositiveFailedCopyMoveKeepsTheOriginalsPlacement() {
		GoogleDriveHttpMock driveMock = buildPlacementMock();
		answerDrive(driveMock, 'PATCH', COPY_DRIVE_ID, 500, DRIVE_SERVER_ERROR_BODY);
		answerMoves(driveMock);
		GoogleCloudTestFactory.initMocks(driveMock);
		applyPlacementConfig(false, null);
		GoogleFileRelocationRequestDTO request = insertPlacementFixture();

		Exception placementFailure;
		Boolean isSettled;
		Test.startTest();
		try {
			isSettled = placeAndCommit(request);
		} catch (Exception ex) {
			placementFailure = ex;
		}
		Test.stopTest();

		Assert.isNull(placementFailure, 'Moving the copy is best effort');
		Assert.isTrue(isSettled);
		Assert.areEqual(DESTINATION_FOLDER_ID, placedFolderId(request.localGoogleFileVersionId), 'The original\'s placement stands when its copy cannot follow');
	}
}
