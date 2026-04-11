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
}
