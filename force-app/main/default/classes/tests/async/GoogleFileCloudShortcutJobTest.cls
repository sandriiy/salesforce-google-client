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
	private static final String DESTINATION_FOLDER_ID = 'DEST_FOLDER_01';
	private static final String RECORD_NAME = 'Acme Brochure';
	private static final String TODAYS_RECORD_FOLDER_NAME = 'GoogleFile__c : Acme Brochure';
	private static final String DRIVE_SERVER_ERROR_BODY = '{"error":{"code":500,"message":"Internal Error","errors":[{"domain":"global","reason":"internalError","message":"Internal Error"}]}}';

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
		GoogleDriveHttpMock driveMock = buildExistingFolderMock('DEST_FOLDER_01');
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig('ROOT_FOLDER_01', '{Record}');
		GoogleCloudTestFactory.bypassTriggers();
		GoogleFileCloudShortcutJob.skipExecution = true;

		Id relatedRecordId = GoogleCloudTestFactory.linkedRecord('Skipped Shortcut Record');

		GoogleFile__c localFile = GoogleCloudTestFactory.file()
			.withName('Skipped Shortcut File')
			.insertRecord();

		GoogleCloudTestFactory.version()
			.forFile(localFile.Id)
			.withName('Skipped Shortcut File.pdf')
			.withDriveId('GD_SKIPPED_TARGET')
			.insertRecord();

		GoogleFileLink__c link = GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withLinkedRecord(relatedRecordId)
			.withLinkedType('GoogleFile__c')
			.insertRecord();

		Test.startTest();
		new GoogleFileCloudShortcutJob(UserInfo.getUserId(), localFile.Id, link.Id).work();
		Test.stopTest();

		Assert.isTrue(driveMock.getCapturedRequests().isEmpty(), 'A skipped job must not reach Google Drive');
	}

	@IsTest
	private static void testExecutePositiveNullLinkId() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig('ROOT_FOLDER_01', '{Record}');

		Test.startTest();
		new GoogleFileCloudShortcutJob(UserInfo.getUserId(), GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType), null).work();
		Test.stopTest();

		Assert.isTrue(driveMock.getCapturedRequests().isEmpty(), 'Without a link there is no record folder to place a shortcut in');
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

	private static void applyRenameConfig(String patternsJson) {
		GoogleClientConfig__mdt config = buildFolderConfig('ROOT_FOLDER_01', '{Record}');
		config.IsFolderRenameEnabled__c = true;
		config.RecordFolderNamePatterns__c = patternsJson;
		GoogleMetadataConfigService.configRecordOverride = config;
	}

	private static GoogleDriveHttpMock buildRenameMock(Integer renameStatus, String renameBody) {
		GoogleDriveHttpMock driveMock = buildExistingFolderMock(DESTINATION_FOLDER_ID);
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('PATCH')
				.endpointContains('/files/' + DESTINATION_FOLDER_ID)
		).thenReturnStatus(renameStatus, renameBody);
		return driveMock;
	}

	private static GoogleFileCloudShortcutJob buildAttachJob() {
		GoogleCloudTestFactory.bypassTriggers();
		GoogleFile__c record = GoogleCloudTestFactory.file().withName(RECORD_NAME).insertRecord();
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('Attached File').insertRecord();

		GoogleCloudTestFactory.version()
			.forFile(localFile.Id)
			.withName('Attached File.pdf')
			.withDriveId('GD_ATTACHED_TARGET')
			.isLatest(true)
			.insertRecord();

		GoogleFileLink__c link = GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withLinkedRecord(record.Id)
			.withLinkedType('GoogleFile__c')
			.insertRecord();

		return new GoogleFileCloudShortcutJob(UserInfo.getUserId(), localFile.Id, link.Id);
	}

	private static List<GoogleDriveHttpMock.CapturedRequest> renamesOf(GoogleDriveHttpMock driveMock) {
		List<GoogleDriveHttpMock.CapturedRequest> renames = new List<GoogleDriveHttpMock.CapturedRequest>();
		for (GoogleDriveHttpMock.CapturedRequest capturedRequest : driveMock.getCapturedRequests()) {
			String endpoint = capturedRequest.endpoint == null ? '' : capturedRequest.endpoint.toLowerCase();
			if (capturedRequest.method == 'PATCH' && endpoint.contains(('/files/' + DESTINATION_FOLDER_ID).toLowerCase())) renames.add(capturedRequest);
		}

		return renames;
	}

	private static Boolean hasShortcutRequest(GoogleDriveHttpMock driveMock) {
		for (GoogleDriveHttpMock.CapturedRequest capturedRequest : driveMock.getCapturedRequests()) {
			String endpoint = capturedRequest.endpoint == null ? '' : capturedRequest.endpoint.toLowerCase();
			String body = capturedRequest.body == null ? '' : capturedRequest.body;
			if (capturedRequest.method == 'POST' && endpoint.contains('uploadtype=multipart') && body.contains('GD_ATTACHED_TARGET')) return true;
		}

		return false;
	}

	@IsTest
	private static void testWorkPositiveRenamesTheRecordFolderOnAttachExisting() {
		GoogleDriveHttpMock driveMock = buildRenameMock(200, '{"id":"' + DESTINATION_FOLDER_ID + '"}');
		GoogleCloudTestFactory.initMocks(driveMock);
		applyRenameConfig(null);
		GoogleFileCloudShortcutJob attachJob = buildAttachJob();

		Test.startTest();
		attachJob.work();
		Test.stopTest();

		List<GoogleDriveHttpMock.CapturedRequest> renames = renamesOf(driveMock);
		Assert.areEqual(1, renames.size(), 'Attaching an existing file to a record renames the folder it reaches');
		Assert.isTrue(renames[0].body != null && renames[0].body.contains(TODAYS_RECORD_FOLDER_NAME));
		Assert.isTrue(hasShortcutRequest(driveMock));
	}

	@IsTest
	private static void testWorkPositiveFailedRenameStillCreatesTheShortcut() {
		GoogleDriveHttpMock driveMock = buildRenameMock(500, DRIVE_SERVER_ERROR_BODY);
		GoogleCloudTestFactory.initMocks(driveMock);
		applyRenameConfig(null);
		GoogleFileCloudShortcutJob attachJob = buildAttachJob();

		Exception jobFailure;
		Test.startTest();
		try {
			attachJob.work();
		} catch (Exception ex) {
			jobFailure = ex;
		}
		Test.stopTest();

		Assert.isNull(jobFailure, 'A rename never fails the shortcut');
		Assert.isTrue(hasShortcutRequest(driveMock), 'The shortcut lands in the folder as it would without renaming');
	}

	@IsTest
	private static void testWorkPositiveSavesTheLogAfterARecordedError() {
		GoogleDriveHttpMock driveMock = buildRenameMock(200, '{"id":"' + DESTINATION_FOLDER_ID + '"}');
		GoogleCloudTestFactory.initMocks(driveMock);
		applyRenameConfig(JSON.serialize(new List<Map<String, String>>{
			new Map<String, String>{ 'objectApiName' => 'GoogleFile__c', 'pattern' => 'Name & Nope__c' }
		}));
		GoogleFileCloudShortcutJob attachJob = buildAttachJob();

		Test.startTest();
		attachJob.work();
		Integer unsavedLogEntries = Logger.getBufferSize();
		Test.stopTest();

		Assert.isTrue(hasShortcutRequest(driveMock));
		Assert.areEqual(0, renamesOf(driveMock).size());
		Assert.areEqual(0, unsavedLogEntries, 'A run that recorded an error saves its log at its end');
	}

	@IsTest
	private static void testWorkPositiveSavesNothingAfterACleanRun() {
		GoogleDriveHttpMock driveMock = buildRenameMock(200, '{"id":"' + DESTINATION_FOLDER_ID + '"}');
		GoogleCloudTestFactory.initMocks(driveMock);
		applyRenameConfig(null);
		GoogleFileCloudShortcutJob attachJob = buildAttachJob();

		Test.startTest();
		attachJob.work();
		Integer unsavedLogEntries = Logger.getBufferSize();
		Test.stopTest();

		Assert.isTrue(unsavedLogEntries > 0, 'A run without an error saves nothing');
	}
}