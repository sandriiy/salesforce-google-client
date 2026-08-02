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
	private static GoogleClientConfig__mdt buildFolderConfig(String uploadFolderId, String folderStructure) {
		GoogleClientConfig__mdt config = new GoogleClientConfig__mdt();
		config.DefaultGoogleUploadFolderId__c = uploadFolderId;
		config.CustomGoogleUploadFolderStructure__c = folderStructure;
		return config;
	}

	private static IGoogleUnitOfWork buildUow() {
		return new GoogleCloudUnitOfWork(new List<SObjectType>{
			GoogleFile__c.SObjectType,
			GoogleFileVersion__c.SObjectType,
			GoogleFileLink__c.SObjectType
		});
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
			(Id) 'a0A000000000001AAA',
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
			(Id) 'a0A000000000001AAA',
			(Id) 'a0B000000000001AAA',
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

		Account linkedRecord = new Account(Name = 'Placement Account');
		insert linkedRecord;

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
			.withLinkedRecord(linkedRecord.Id)
			.withLinkedType('Account')
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
			.withLinkedType('Account')
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

		Id linkedRecordId = GoogleCloudTestFactory.fakeId(Account.SObjectType);
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

		Id linkedRecordId = GoogleCloudTestFactory.fakeId(Account.SObjectType);
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

		Account linkedRecord = new Account(Name = 'Existing Folder Account');
		insert linkedRecord;

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
			.withLinkedRecord(linkedRecord.Id)
			.withLinkedType('Account')
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

		Account linkedRecord = new Account(Name = 'Fallback Placement Account');
		insert linkedRecord;

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
			.withLinkedRecord(linkedRecord.Id)
			.withLinkedType('Account')
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

		Account linkedRecord = new Account(Name = 'Self-Healing Placement Account');
		insert linkedRecord;

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
			.withLinkedRecord(linkedRecord.Id)
			.withLinkedType('Account')
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
}
