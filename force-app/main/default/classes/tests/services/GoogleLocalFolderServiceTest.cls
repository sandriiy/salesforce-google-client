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
private class GoogleLocalFolderServiceTest {
	private static final String ROOT_FOLDER = 'ROOT_FOLDER_01';
	private static final String COPIES_FOLDER = 'COPIES_FOLDER_01';
	private static final String COPIES_FOLDER_NAME = 'Google Client Copies';
	private static final String RECORD_NAME = 'Acme Brochure';

	private static GoogleDriveHttpMock mockWithoutMatchingFolders() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.queryContains('q=')
		).thenReturnStatus(200, '{"files":[]}');
		return driveMock;
	}

	@IsTest
	private static void testCreateFolderPositiveCreatesNamedFolderUnderParent() {
		GoogleCloudTestFactory.config().withUploadFolderId(ROOT_FOLDER).apply();
		GoogleDriveHttpMock driveMock = mockWithoutMatchingFolders();
		GoogleCloudTestFactory.initMocks(driveMock);

		GoogleFolderCreateRequestDTO request = new GoogleFolderCreateRequestDTO();
		request.folderName = '  Invoices  ';
		request.parentFolderId = 'PARENT_FOLDER';

		Test.startTest();
		GoogleFolderCreateResultDTO result = new GoogleLocalFolderService().createFolder(request);
		Test.stopTest();

		Assert.areEqual('gfile_small_001', result.folderId);
		Assert.areEqual('PARENT_FOLDER', result.parentFolderId);
		Assert.isTrue(result.wasCreated);

		Boolean createdUnderParent = false;
		for (GoogleDriveHttpMock.CapturedRequest captured : driveMock.getCapturedRequests()) {
			if (captured.method == 'POST' && captured.body != null && captured.body.contains('"Invoices"') && captured.body.contains('PARENT_FOLDER')) {
				createdUnderParent = true;
			}
		}
		Assert.isTrue(createdUnderParent, 'The trimmed name and the parent must be sent to Google Drive');
	}

	@IsTest
	private static void testCreateFolderPositiveReusesExistingFolderDeterministically() {
		GoogleCloudTestFactory.config().withUploadFolderId(ROOT_FOLDER).apply();
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.queryContains('q=')
		).thenReturnStatus(200, '{"files":[{"id":"FOLDER_B","name":"Invoices","parents":["ROOT_FOLDER_01"],"webViewLink":"https://drive/b"},{"id":"FOLDER_A","name":"Invoices","parents":["ROOT_FOLDER_01"],"webViewLink":"https://drive/a"}]}');
		GoogleCloudTestFactory.initMocks(driveMock);

		GoogleFolderCreateRequestDTO request = new GoogleFolderCreateRequestDTO();
		request.folderName = 'Invoices';

		Test.startTest();
		GoogleFolderCreateResultDTO result = new GoogleLocalFolderService().createFolder(request);
		Test.stopTest();

		Assert.areEqual('FOLDER_A', result.folderId, 'Duplicates are adopted by the lowest Id so every run lands in the same folder');
		Assert.areEqual(ROOT_FOLDER, result.parentFolderId, 'Without a parent or a record the default upload folder is used');
		Assert.areEqual('https://drive/a', result.folderUrl);
		Assert.isFalse(result.wasCreated);
	}

	@IsTest
	private static void testCreateFolderPositiveAlwaysCreatesWhenReuseIsOff() {
		GoogleCloudTestFactory.config().withUploadFolderId(ROOT_FOLDER).apply();
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.queryContains('q=')
		).thenReturnStatus(200, '{"files":[{"id":"FOLDER_A","name":"Invoices"}]}');
		GoogleCloudTestFactory.initMocks(driveMock);

		GoogleFolderCreateRequestDTO request = new GoogleFolderCreateRequestDTO();
		request.folderName = 'Invoices';
		request.reuseExistingFolder = false;

		Test.startTest();
		GoogleFolderCreateResultDTO result = new GoogleLocalFolderService().createFolder(request);
		Test.stopTest();

		Assert.isTrue(result.wasCreated);
		Assert.areEqual('gfile_small_001', result.folderId);
	}

	@IsTest
	private static void testCreateFolderPositiveReturnsRecordFolderWhenNoNameIsGiven() {
		GoogleCloudTestFactory.config().withUploadFolderId(ROOT_FOLDER).withFolderStructure('{Record}').apply();
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.queryContains('appProperties')
		).thenReturnStatus(200, '{"files":[{"id":"RECORD_FOLDER","name":"GoogleFile__c : Any"}]}');
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.endpointContains('/files/RECORD_FOLDER')
		).thenReturnStatus(200, '{"id":"RECORD_FOLDER","name":"GoogleFile__c : Any","parents":["ROOT_FOLDER_01"],"webViewLink":"https://drive/record"}');
		GoogleCloudTestFactory.initMocks(driveMock);

		GoogleFolderCreateRequestDTO request = new GoogleFolderCreateRequestDTO();
		request.relatedRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);

		Test.startTest();
		GoogleFolderCreateResultDTO result = new GoogleLocalFolderService().createFolder(request);
		Test.stopTest();

		Assert.areEqual('RECORD_FOLDER', result.folderId);
		Assert.areEqual(ROOT_FOLDER, result.parentFolderId);
		Assert.areEqual('https://drive/record', result.folderUrl);
		Assert.isFalse(result.wasCreated, 'The record folder already existed in Google Drive');
	}

	@IsTest
	private static void testCreateFolderPositiveNamedFolderLandsInsideRecordFolder() {
		GoogleCloudTestFactory.config().withUploadFolderId(ROOT_FOLDER).withFolderStructure('{Record}').apply();
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.queryContains('appProperties')
		).thenReturnStatus(200, '{"files":[{"id":"RECORD_FOLDER","name":"GoogleFile__c : Any"}]}');
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.queryContains('name+%3D')
		).thenReturnStatus(200, '{"files":[]}');
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.queryContains('name%20%3D')
		).thenReturnStatus(200, '{"files":[]}');
		GoogleCloudTestFactory.initMocks(driveMock);

		GoogleFolderCreateRequestDTO request = new GoogleFolderCreateRequestDTO();
		request.folderName = 'Attachments';
		request.relatedRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);

		Test.startTest();
		GoogleFolderCreateResultDTO result = new GoogleLocalFolderService().createFolder(request);
		Test.stopTest();

		Assert.areEqual('RECORD_FOLDER', result.parentFolderId, 'A named folder for a record goes inside that record’s folder');
		Assert.isTrue(result.wasCreated);
	}

	@IsTest
	private static void testCreateFolderNegativeNothingToCreate() {
		GoogleCloudTestFactory.config().withUploadFolderId(ROOT_FOLDER).apply();
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		try {
			new GoogleLocalFolderService().createFolder(new GoogleFolderCreateRequestDTO());
			Assert.fail('A request without a name or a record must be refused');
		} catch (GoogleLocalFolderService.GoogleLocalFolderException ex) {
			Assert.isTrue(ex.getMessage().contains('Enter a folder name'), ex.getMessage());
		}
		Test.stopTest();
	}

	@IsTest
	private static void testCreateFolderNegativeRecordFolderNeedsAStructure() {
		GoogleCloudTestFactory.config().withUploadFolderId(ROOT_FOLDER).apply();
		GoogleCloudTestFactory.initMocks();

		GoogleFolderCreateRequestDTO request = new GoogleFolderCreateRequestDTO();
		request.relatedRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);

		Test.startTest();
		try {
			new GoogleLocalFolderService().createFolder(request);
			Assert.fail('Without a record folder structure there is no record folder to return');
		} catch (GoogleLocalFolderService.GoogleLocalFolderException ex) {
			Assert.isTrue(ex.getMessage().contains('folder per record'), ex.getMessage());
		}
		Test.stopTest();
	}

	@IsTest
	private static void testCreateFolderNegativeNoUploadFolderConfigured() {
		GoogleCloudTestFactory.initMocks();

		GoogleFolderCreateRequestDTO request = new GoogleFolderCreateRequestDTO();
		request.folderName = 'Invoices';

		Test.startTest();
		try {
			new GoogleLocalFolderService().createFolder(request);
			Assert.fail('A fresh install without an upload folder cannot place the folder anywhere');
		} catch (GoogleLocalFolderService.GoogleLocalFolderException ex) {
			Assert.isTrue(ex.getMessage().contains('No Google Drive upload folder'), ex.getMessage());
		}
		Test.stopTest();
	}

	private static GoogleFile__c insertLinkedRecord(String recordName, Datetime linkedAt) {
		GoogleCloudTestFactory.bypassTriggers();
		GoogleFile__c record = GoogleCloudTestFactory.file().withName(recordName).insertRecord();
		GoogleFile__c holder = GoogleCloudTestFactory.file().withName(recordName + ' attachment').insertRecord();
		GoogleFileLink__c link = GoogleCloudTestFactory.link()
			.forFile(holder.Id)
			.withLinkedRecord(record.Id)
			.withLinkedType('GoogleFile__c')
			.insertRecord();
		Test.setCreatedDate(link.Id, linkedAt);
		return record;
	}

	private static GoogleFile__c ownedByRunningUser(Id recordId, String recordName) {
		return (GoogleFile__c) JSON.deserialize(JSON.serialize(new Map<String, Object>{
			'attributes' => new Map<String, Object>{ 'type' => 'GoogleFile__c' },
			'Id' => recordId,
			'Name' => recordName,
			'Owner' => new Map<String, Object>{
				'attributes' => new Map<String, Object>{ 'type' => 'User' },
				'Id' => UserInfo.getUserId(),
				'LastName' => UserInfo.getLastName()
			}
		}), GoogleFile__c.class);
	}

	private static GoogleDriveHttpMock mockCopiesFolder(Integer statusCode, String body) {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.endpointContains('/files/' + COPIES_FOLDER)
		).thenReturnStatus(statusCode, body);
		return driveMock;
	}

	private static String folderAnswer(String mimeType, Boolean isTrashed, Boolean canAddChildren) {
		return JSON.serialize(new Map<String, Object>{
			'id' => COPIES_FOLDER,
			'name' => COPIES_FOLDER_NAME,
			'mimeType' => mimeType,
			'trashed' => isTrashed,
			'capabilities' => new Map<String, Object>{ 'canAddChildren' => canAddChildren }
		});
	}

	@IsTest
	private static void testCreateFolderPositiveRecordFolderIsNeverRenamed() {
		GoogleClientConfig__mdt config = GoogleCloudTestFactory.config().withUploadFolderId(ROOT_FOLDER).withFolderStructure('{Record}').apply();
		config.IsFolderRenameEnabled__c = true;
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.queryContains('appProperties')
		).thenReturnStatus(200, '{"files":[{"id":"RECORD_FOLDER","name":"GoogleFile__c : Old Name"}]}');
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.endpointContains('/files/RECORD_FOLDER')
		).thenReturnStatus(200, '{"id":"RECORD_FOLDER","name":"GoogleFile__c : Old Name","parents":["ROOT_FOLDER_01"],"webViewLink":"https://drive/record"}');
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleFile__c record = GoogleCloudTestFactory.file().withName(RECORD_NAME).insertRecord();

		GoogleFolderCreateRequestDTO request = new GoogleFolderCreateRequestDTO();
		request.relatedRecordId = record.Id;

		Test.startTest();
		GoogleFolderCreateResultDTO result = new GoogleLocalFolderService().createFolder(request);
		Test.stopTest();

		Assert.areEqual('RECORD_FOLDER', result.folderId);
		for (GoogleDriveHttpMock.CapturedRequest capturedRequest : driveMock.getCapturedRequests()) {
			Assert.areNotEqual('PATCH', capturedRequest.method, 'The Create Folder action never renames a record folder');
		}
	}

	@IsTest
	private static void testCheckRecordFolderNamePatternPositiveShowsTheObjectLabelAndAnExample() {
		GoogleCloudTestFactory.initMocks();
		GoogleFile__c record = insertLinkedRecord(RECORD_NAME, Datetime.now().addDays(-1));
		GoogleCloudTestFactory.grantRecordAccess(record.Id, true, false);

		Test.startTest();
		GoogleFolderNamePatternCheckDTO check = new GoogleLocalFolderService().checkRecordFolderNamePattern('GoogleFile__c', 'Name & " (folder)"');
		Test.stopTest();

		Assert.isTrue(check.isValid);
		Assert.areEqual(GoogleFile__c.SObjectType.getDescribe().getLabel(), check.objectLabel);
		Assert.areEqual('Acme Brochure (folder)', check.exampleName, 'The example is built from a record that has a Google Client file');
		Assert.isTrue(check.warnings == null || check.warnings.isEmpty());
	}

	@IsTest
	private static void testCheckRecordFolderNamePatternPositiveExampleComesFromTheNewestLinkedRecord() {
		GoogleCloudTestFactory.initMocks();
		GoogleFile__c olderRecord = insertLinkedRecord('Older Brochure', Datetime.now().addDays(-2));
		GoogleFile__c newerRecord = insertLinkedRecord('Newer Brochure', Datetime.now().addDays(-1));
		GoogleCloudTestFactory.grantRecordAccess(olderRecord.Id, true, false);
		GoogleCloudTestFactory.grantRecordAccess(newerRecord.Id, true, false);

		Test.startTest();
		GoogleFolderNamePatternCheckDTO check = new GoogleLocalFolderService().checkRecordFolderNamePattern('GoogleFile__c', 'Name');
		Test.stopTest();

		Assert.areEqual('Newer Brochure', check.exampleName);
	}

	@IsTest
	private static void testCheckRecordFolderNamePatternNegativeNoExampleForARecordTheAdminCannotRead() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.denyAllRecordAccess();
		GoogleFile__c record = insertLinkedRecord(RECORD_NAME, Datetime.now().addDays(-1));
		GoogleCloudTestFactory.grantRecordAccess(record.Id, false, false);

		Test.startTest();
		GoogleFolderNamePatternCheckDTO check = new GoogleLocalFolderService().checkRecordFolderNamePattern('GoogleFile__c', 'Name');
		Test.stopTest();

		Assert.isTrue(check.isValid, 'The pattern itself is still usable');
		Assert.isTrue(String.isBlank(check.exampleName), 'An administrator never sees values of a record they cannot read');
	}

	@IsTest
	private static void testCheckRecordFolderNamePatternPositiveNoExampleWhenNoFileIsLinked() {
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		GoogleFolderNamePatternCheckDTO check = new GoogleLocalFolderService().checkRecordFolderNamePattern('GoogleFile__c', 'Name');
		Test.stopTest();

		Assert.isTrue(check.isValid);
		Assert.isTrue(String.isBlank(check.exampleName));
	}

	@IsTest
	private static void testCheckRecordFolderNamePatternPositiveMatchesTheObjectWhateverItsCase() {
		GoogleCloudTestFactory.initMocks();
		GoogleFile__c record = insertLinkedRecord(RECORD_NAME, Datetime.now().addDays(-1));
		GoogleCloudTestFactory.grantRecordAccess(record.Id, true, false);

		Test.startTest();
		GoogleFolderNamePatternCheckDTO check = new GoogleLocalFolderService().checkRecordFolderNamePattern('googlefile__c', 'Name');
		Test.stopTest();

		Assert.isTrue(check.isValid);
		Assert.areEqual(GoogleFile__c.SObjectType.getDescribe().getLabel(), check.objectLabel);
		Assert.areEqual(RECORD_NAME, check.exampleName);
	}

	@IsTest
	private static void testCheckRecordFolderNamePatternPositiveExampleForUserIsTheNewestUploader() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();
		GoogleFile__c uploadedFile = GoogleCloudTestFactory.file().withName(RECORD_NAME).insertRecord();
		GoogleCloudTestFactory.version().forFile(uploadedFile.Id).withName(RECORD_NAME + '.pdf').withType(GoogleCloudConstants.MIME_TYPE_PDF).withSize(10L).withDriveId('GD_UPLOADER_EXAMPLE').insertRecord();
		GoogleCloudTestFactory.grantRecordAccess(UserInfo.getUserId(), true, false);

		Test.startTest();
		GoogleFolderNamePatternCheckDTO check = new GoogleLocalFolderService().checkRecordFolderNamePattern('User', 'LastName & " team"');
		Test.stopTest();

		Assert.isTrue(check.isValid);
		Assert.areEqual(UserInfo.getLastName() + ' team', check.exampleName);
	}

	@IsTest
	private static void testCheckRecordFolderNamePatternNegativeRefusesAnUnknownObject() {
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		GoogleFolderNamePatternCheckDTO check = new GoogleLocalFolderService().checkRecordFolderNamePattern('NoSuchObject__c', 'Name');
		Test.stopTest();

		Assert.isFalse(check.isValid);
		Assert.isTrue(String.isNotBlank(check.message));
	}

	@IsTest
	private static void testCheckRecordFolderNamePatternNegativeExplainsAFormulaSalesforceRefuses() {
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		GoogleFolderNamePatternCheckDTO unknownFieldCheck = new GoogleLocalFolderService().checkRecordFolderNamePattern('GoogleFile__c', 'Name & Nope__c');
		GoogleFolderNamePatternCheckDTO runningUserCheck = new GoogleLocalFolderService().checkRecordFolderNamePattern('GoogleFile__c', 'Name & $User.LastName');
		Test.stopTest();

		Assert.isFalse(unknownFieldCheck.isValid);
		Assert.isTrue(String.isNotBlank(unknownFieldCheck.message), 'Salesforce\'s own message explains the refusal');
		Assert.isTrue(String.isBlank(unknownFieldCheck.exampleName));
		Assert.isFalse(runningUserCheck.isValid);
	}

	@IsTest
	private static void testCheckRecordFolderNamePatternNegativeRefusesAFieldTheAdminCannotSee() {
		GoogleCloudTestFactory.initMocks();
		GoogleFile__c record = insertLinkedRecord(RECORD_NAME, Datetime.now().addDays(-1));
		GoogleCloudTestFactory.grantRecordAccess(record.Id, true, false);
		GoogleLocalFolderService.hiddenFieldPathsOverride = new Set<String>{ 'salesforcefileid__c' };

		Test.startTest();
		GoogleFolderNamePatternCheckDTO check = new GoogleLocalFolderService().checkRecordFolderNamePattern('GoogleFile__c', 'Name & " " & SalesforceFileId__c');
		Test.stopTest();

		Assert.isFalse(check.isValid, 'A field the administrator cannot see would carry its values into folder names in Google Drive');
		Assert.isTrue(check.message != null && check.message.contains('SalesforceFileId__c') && check.message.contains('can\'t see it'), 'The row names the field it cannot use');
		Assert.isTrue(String.isBlank(check.exampleName));
	}

	@IsTest
	private static void testCheckRecordFolderNamePatternNegativeRefusesFieldsTheFolderJobsCannotRead() {
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		GoogleFolderNamePatternCheckDTO check = new GoogleLocalFolderService().checkRecordFolderNamePattern('User', 'Manager.Manager.Manager.Manager.Manager.Manager.Manager.LastName');
		Test.stopTest();

		Assert.isFalse(check.isValid, 'Salesforce accepts the formula but no folder job could read seven relationships away');
		Assert.isTrue(check.message != null && check.message.contains('five relationships'));
	}

	@IsTest
	private static void testCheckRecordFolderNamePatternPositiveShowsAnExampleForAnOwnerThatCanAlsoBeAQueue() {
		GoogleCloudTestFactory.initMocks();
		GoogleFile__c record = insertLinkedRecord(RECORD_NAME, Datetime.now().addDays(-1));
		GoogleCloudTestFactory.grantRecordAccess(record.Id, true, false);
		GSOQL.mock(GoogleFileLinkedRecordSelector.MOCK_ID).thenReturn(ownedByRunningUser(record.Id, RECORD_NAME));

		Test.startTest();
		GoogleFolderNamePatternCheckDTO check = new GoogleLocalFolderService().checkRecordFolderNamePattern('GoogleFile__c', 'Name & " - " & Owner:User.LastName');
		Test.stopTest();

		Assert.isTrue(check.isValid, check.message == null ? 'valid' : check.message);
		Assert.areEqual(RECORD_NAME + ' - ' + UserInfo.getLastName(), check.exampleName, 'Salesforce asks for Owner:User on an owner that can be a queue, and the example must still be built');
	}

	@IsTest
	private static void testCheckRecordFolderNamePatternPositiveWarnsForAPatternThatChangesByItself() {
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		GoogleFolderNamePatternCheckDTO check = new GoogleLocalFolderService().checkRecordFolderNamePattern('GoogleFile__c', 'Name & " " & TEXT(TODAY())');
		Test.stopTest();

		Assert.isTrue(check.isValid, 'The pattern compiles; the administrator decides whether to use it');
		Assert.isFalse(check.warnings == null || check.warnings.isEmpty(), 'A name that changes by itself is shown with a warning first');
	}

	@IsTest
	private static void testCheckRecordFolderNamePatternNegativeRefusesBlankInputs() {
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		GoogleFolderNamePatternCheckDTO blankObjectCheck = new GoogleLocalFolderService().checkRecordFolderNamePattern(null, 'Name');
		GoogleFolderNamePatternCheckDTO blankPatternCheck = new GoogleLocalFolderService().checkRecordFolderNamePattern('GoogleFile__c', '  ');
		Test.stopTest();

		Assert.isFalse(blankObjectCheck.isValid);
		Assert.isFalse(blankPatternCheck.isValid);
	}

	@IsTest
	private static void testCheckWorkspaceCopyFolderPositiveNamesAUsableFolder() {
		GoogleCloudTestFactory.initMocks(mockCopiesFolder(200, folderAnswer(GoogleCloudConstants.MIME_TYPE_GOOGLE_FOLDER, false, true)));

		Test.startTest();
		GoogleDriveFolderCheckDTO check = new GoogleLocalFolderService().checkWorkspaceCopyFolder(COPIES_FOLDER);
		Test.stopTest();

		Assert.isTrue(check.isUsable);
		Assert.areEqual(COPIES_FOLDER_NAME, check.folderName, 'The wizard shows the folder\'s name so the administrator knows it is the right one');
	}

	@IsTest
	private static void testCheckWorkspaceCopyFolderNegativeUnreachableFolderGivesAPlainReason() {
		GoogleCloudTestFactory.initMocks(mockCopiesFolder(404, '{"error":{"code":404,"message":"File not found: COPIES_FOLDER_01.","errors":[{"domain":"global","reason":"notFound","message":"File not found: COPIES_FOLDER_01."}]}}'));

		Test.startTest();
		GoogleDriveFolderCheckDTO check = new GoogleLocalFolderService().checkWorkspaceCopyFolder(COPIES_FOLDER);
		Test.stopTest();

		Assert.isFalse(check.isUsable);
		Assert.isTrue(check.message != null && check.message.contains('reach this folder'), 'The reason is said in plain words, never as Google\'s raw answer');
		Assert.isFalse(check.message.contains('notFound'));
	}

	@IsTest
	private static void testCheckWorkspaceCopyFolderNegativeRefusesAFile() {
		GoogleCloudTestFactory.initMocks(mockCopiesFolder(200, folderAnswer(GoogleCloudConstants.MIME_TYPE_PDF, false, false)));

		Test.startTest();
		GoogleDriveFolderCheckDTO check = new GoogleLocalFolderService().checkWorkspaceCopyFolder(COPIES_FOLDER);
		Test.stopTest();

		Assert.isFalse(check.isUsable);
		Assert.isTrue(check.message != null && check.message.contains('not a folder'));
	}

	@IsTest
	private static void testCheckWorkspaceCopyFolderNegativeRefusesAFolderThatAcceptsNoFiles() {
		GoogleCloudTestFactory.initMocks(mockCopiesFolder(200, folderAnswer(GoogleCloudConstants.MIME_TYPE_GOOGLE_FOLDER, false, false)));

		Test.startTest();
		GoogleDriveFolderCheckDTO check = new GoogleLocalFolderService().checkWorkspaceCopyFolder(COPIES_FOLDER);
		Test.stopTest();

		Assert.isFalse(check.isUsable, 'A folder shared with the service account as Viewer cannot hold the copies');
		Assert.isTrue(check.message != null && check.message.contains('add files to this folder'));
	}

	@IsTest
	private static void testCheckWorkspaceCopyFolderNegativeRefusesAFolderInTheTrash() {
		GoogleCloudTestFactory.initMocks(mockCopiesFolder(200, folderAnswer(GoogleCloudConstants.MIME_TYPE_GOOGLE_FOLDER, true, true)));

		Test.startTest();
		GoogleDriveFolderCheckDTO check = new GoogleLocalFolderService().checkWorkspaceCopyFolder(COPIES_FOLDER);
		Test.stopTest();

		Assert.isFalse(check.isUsable);
		Assert.isTrue(String.isNotBlank(check.message));
	}

	@IsTest
	private static void testCheckWorkspaceCopyFolderNegativeBlankIdIsRefusedWithoutACallout() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		GoogleCloudTestFactory.initMocks(driveMock);

		Test.startTest();
		GoogleDriveFolderCheckDTO check = new GoogleLocalFolderService().checkWorkspaceCopyFolder('   ');
		Test.stopTest();

		Assert.isFalse(check.isUsable);
		Assert.isTrue(driveMock.getCapturedRequests().isEmpty());
	}
}
