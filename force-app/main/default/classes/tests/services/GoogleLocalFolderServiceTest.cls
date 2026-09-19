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
}
