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
private class GoogleFileCloudShortcutJobTest {
	private static GoogleClientConfig__mdt buildFolderConfig(String uploadFolderId, String folderStructure) {
		GoogleClientConfig__mdt config = new GoogleClientConfig__mdt();
		config.DefaultGoogleUploadFolderId__c = uploadFolderId;
		config.CustomGoogleUploadFolderStructure__c = folderStructure;
		return config;
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
	private static void testExecutePositiveSkipExecution() {
		GoogleFileCloudShortcutJob.skipExecution = true;

		Test.startTest();
		new GoogleFileCloudShortcutJob(null, null, null).work();
		Test.stopTest();

		Assert.isTrue(true);
	}

	@IsTest
	private static void testExecutePositiveNullLinkId() {
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		new GoogleFileCloudShortcutJob(UserInfo.getUserId(), (Id) 'a0A000000000001AAA', null).work();
		Test.stopTest();

		Assert.isTrue(true);
	}

	@IsTest
	private static void testCreateShortcutPositiveRecordStructure() {
		GoogleDriveHttpMock driveMock = buildExistingFolderMock('DEST_FOLDER_01');
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig('ROOT_FOLDER_01', '{Record}');

		Id relatedRecordId = GoogleCloudTestFactory.linkedRecord('Shortcut Record');

		GoogleFile__c localFile = GoogleCloudTestFactory.file()
			.withName('Shortcut File')
			.insertRecord();

		GoogleCloudTestFactory.version()
			.forFile(localFile.Id)
			.withName('Shortcut File.pdf')
			.withDriveId('GD_SHORTCUT_TARGET')
			.insertRecord();

		GoogleFileLink__c link = GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withLinkedRecord(relatedRecordId)
			.withLinkedType('GoogleFile__c')
			.insertRecord();

		Test.startTest();
		new GoogleFileShortcutPlacementCommand()
			.initiatedBy(UserInfo.getUserId())
			.forFile(localFile.Id)
			.forLink(link.Id)
			.execute();
		Test.stopTest();

		Boolean shortcutRequestFound = false;
		for (GoogleDriveHttpMock.CapturedRequest capturedRequest : driveMock.getCapturedRequests()) {
			String endpoint = capturedRequest.endpoint == null ? '' : capturedRequest.endpoint.toLowerCase();
			String body = capturedRequest.body == null ? '' : capturedRequest.body;
			if (capturedRequest.method == 'POST' && endpoint.contains('uploadtype=multipart') && body.contains('application/vnd.google-apps.shortcut') && body.contains('GD_SHORTCUT_TARGET')) {
				shortcutRequestFound = true;
			}
		}

		Assert.isTrue(shortcutRequestFound);
	}

	@IsTest
	private static void testCreateShortcutPositiveAlreadyPlacedFileResolvesFolderUnderUploadRoot() {
		GoogleDriveHttpMock driveMock = buildExistingFolderMock('DEST_FOLDER_01');
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig('ROOT_FOLDER_01', '{Record}');

		Id relatedRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);

		GoogleFile__c localFile = GoogleCloudTestFactory.file()
			.withName('Placed Shortcut File')
			.insertRecord();

		GoogleCloudTestFactory.version()
			.forFile(localFile.Id)
			.withName('Placed Shortcut File.pdf')
			.withDriveId('GD_PLACED_TARGET')
			.withFolderId('SOURCE_RECORD_FOLDER_01')
			.insertRecord();

		GoogleFileLink__c link = GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withLinkedRecord(relatedRecordId)
			.withLinkedType('GoogleFile__c')
			.insertRecord();

		Test.startTest();
		new GoogleFileShortcutPlacementCommand()
			.initiatedBy(UserInfo.getUserId())
			.forFile(localFile.Id)
			.forLink(link.Id)
			.execute();
		Test.stopTest();

		Boolean searchedUnderUploadRoot = false;
		Boolean searchedUnderSourceRecordFolder = false;
		for (GoogleDriveHttpMock.CapturedRequest capturedRequest : driveMock.getCapturedRequests()) {
			String endpoint = capturedRequest.endpoint == null ? '' : capturedRequest.endpoint;
			if (!endpoint.contains('appProperties')) continue;

			if (endpoint.contains('ROOT_FOLDER_01')) searchedUnderUploadRoot = true;
			if (endpoint.contains('SOURCE_RECORD_FOLDER_01')) searchedUnderSourceRecordFolder = true;
		}

		Assert.isTrue(searchedUnderUploadRoot, 'The record folder must be resolved under the configured upload root');
		Assert.isFalse(searchedUnderSourceRecordFolder, 'The record folder must never be nested inside the folder the attached file already lives in');
	}

	@IsTest
	private static void testCreateShortcutPositiveUserStructureEarlyReturn() {
		GoogleDriveHttpMock driveMock = buildExistingFolderMock('USER_FOLDER_01');
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig('ROOT_FOLDER_01', '{User}');

		GTriggerHandler.setBypass('GoogleFileVersionTriggerHandler', true);
		GTriggerHandler.setBypass('GoogleFileLinkTriggerHandler', true);

		GoogleFile__c localFile = GoogleCloudTestFactory.file()
			.withName('Shortcut User Structure File')
			.insertRecord();

		GoogleCloudTestFactory.version()
			.forFile(localFile.Id)
			.withName('Shortcut User Structure File.pdf')
			.withDriveId('GD_USER_STRUCTURE_TARGET')
			.insertRecord();

		GoogleFileLink__c link = GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withLinkedRecord(localFile.Id)
			.withLinkedType('GoogleFile__c')
			.insertRecord();

		Test.startTest();
		new GoogleFileShortcutPlacementCommand()
			.initiatedBy(UserInfo.getUserId())
			.forFile(localFile.Id)
			.forLink(link.Id)
			.execute();
		Test.stopTest();

		Assert.areEqual(0, driveMock.getCapturedRequests().size());
	}
}