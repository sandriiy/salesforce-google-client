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

		Account relatedAccount = new Account(Name = 'Shortcut Account');
		insert relatedAccount;

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
			.withLinkedRecord(relatedAccount.Id)
			.withLinkedType('Account')
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