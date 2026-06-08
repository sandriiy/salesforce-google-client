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
private class GoogleFileFolderStructureCommandTest {
	private static GoogleClientConfig__mdt buildFolderConfig(String uploadFolderId, String folderStructure) {
		GoogleClientConfig__mdt config = new GoogleClientConfig__mdt();
		config.DefaultGoogleUploadFolderId__c = uploadFolderId;
		config.CustomGoogleUploadFolderStructure__c = folderStructure;
		return config;
	}

	private static GoogleDriveHttpMock buildMissingFolderMock() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.queryContains('appProperties')
		).thenReturnStatus(200, '{"files":[]}');
		return driveMock;
	}

	private static GoogleDriveHttpMock buildExistingFolderMock(String folderId) {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.queryContains('appProperties')
		).thenReturnStatus(200, '{"files":[{"id":"' + folderId + '","name":"Existing Folder"}]}');
		return driveMock;
	}

	@IsTest
	private static void testEnsureFolderPositiveBlankStructure() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig('ROOT_FOLDER_01', '');

		Account linkedRecord = new Account(Name = 'Blank Structure Account');
		insert linkedRecord;

		Test.startTest();
		String folderId = new GoogleFileFolderStructureCommand().ensureFolder(linkedRecord.Id);
		Test.stopTest();

		Assert.areEqual(null, folderId);
	}

	@IsTest
	private static void testEnsureFolderPositiveUserStructure() {
		GoogleCloudTestFactory.initMocks(buildMissingFolderMock());
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig('ROOT_FOLDER_01', '{User}');

		Test.startTest();
		String folderId = new GoogleFileFolderStructureCommand().ensureFolder(null);
		Test.stopTest();

		Assert.isNotNull(folderId);
	}

	@IsTest
	private static void testEnsureFolderPositiveRecordStructure() {
		GoogleCloudTestFactory.initMocks(buildMissingFolderMock());
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig('ROOT_FOLDER_01', '{Record}');

		Account linkedRecord = new Account(Name = 'Record Structure Account');
		insert linkedRecord;

		Test.startTest();
		String folderId = new GoogleFileFolderStructureCommand().ensureFolder(linkedRecord.Id);
		Test.stopTest();

		Assert.isNotNull(folderId);
	}

	@IsTest
	private static void testEnsureFolderPositiveRecordStructureWithoutRecord() {
		GoogleCloudTestFactory.initMocks(buildMissingFolderMock());
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig('ROOT_FOLDER_01', '{Record}');

		Test.startTest();
		String folderId = new GoogleFileFolderStructureCommand().ensureFolder(null);
		Test.stopTest();

		Assert.areEqual(null, folderId);
	}

	@IsTest
	private static void testEnsureFolderPositiveRecordUserStructure() {
		GoogleCloudTestFactory.initMocks(buildMissingFolderMock());
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig('ROOT_FOLDER_01', '{Record}-{User}');

		Account linkedRecord = new Account(Name = 'Nested Structure Account');
		insert linkedRecord;

		Test.startTest();
		String folderId = new GoogleFileFolderStructureCommand().ensureFolder(linkedRecord.Id);
		Test.stopTest();

		Assert.isNotNull(folderId);
	}

	@IsTest
	private static void testEnsureFolderPositiveRecordUserStructureWithoutRecord() {
		GoogleCloudTestFactory.initMocks(buildMissingFolderMock());
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig('ROOT_FOLDER_01', '{Record}-{User}');

		Test.startTest();
		String folderId = new GoogleFileFolderStructureCommand().ensureFolder(null);
		Test.stopTest();

		Assert.areEqual(null, folderId);
	}

	@IsTest
	private static void testEnsureFolderPositiveUserRecordStructureWithoutRecord() {
		GoogleCloudTestFactory.initMocks(buildMissingFolderMock());
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig('ROOT_FOLDER_01', '{User}-{Record}');

		Test.startTest();
		String folderId = new GoogleFileFolderStructureCommand().ensureFolder(null);
		Test.stopTest();

		Assert.areEqual(null, folderId);
	}

	@IsTest
	private static void testFindExistingFolderPositive() {
		GoogleCloudTestFactory.initMocks(buildExistingFolderMock('EXISTING_FOLDER_01'));
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig('ROOT_FOLDER_01', '{Record}');

		Account linkedRecord = new Account(Name = 'Existing Folder Account');
		insert linkedRecord;

		Test.startTest();
		String folderId = new GoogleFileFolderStructureCommand().findExistingFolder(UserInfo.getUserId(), linkedRecord.Id);
		Test.stopTest();

		Assert.areEqual('EXISTING_FOLDER_01', folderId);
	}
}