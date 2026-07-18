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
private class GoogleRemoteFileUploaderTest {
	private static final String PRIMARY_FOLDER = 'PRIMARY_FOLDER_01';
	private static final String SECONDARY_FOLDER = 'SECONDARY_FOLDER_01';
	private static final String THIRD_FOLDER = 'THIRD_FOLDER_01';

	private static String buildCapacityErrorBody(String reason) {
		return '{"error":{"errors":[{"domain":"global","reason":"' + reason + '","message":"Shared drive full"}],"code":403,"message":"Shared drive full"}}';
	}

	private static String buildAuthErrorBody() {
		return '{"error":{"errors":[{"domain":"global","reason":"authError","message":"Invalid Credentials"}],"code":401,"message":"Invalid Credentials"}}';
	}

	private static String buildFileSuccessBody(String folderId) {
		return '{"id":"gfile_success_01","name":"Uploaded File","parents":["' + folderId + '"]}';
	}

	private static void configureMultiDrive(List<String> folderIds) {
		GoogleClientConfig__mdt config = new GoogleClientConfig__mdt();
		config.DefaultGoogleUploadFolderId__c = folderIds.isEmpty() ? null : folderIds[0];

		List<String> additional = new List<String>();
		for (Integer i = 1; i < folderIds.size(); i++) {
			additional.add(folderIds[i]);
		}
		config.AdditionalGoogleUploadFolderIds__c = additional.isEmpty() ? null : String.join(additional, ';');

		GoogleMetadataConfigService.configRecordOverride = config;
	}

	@IsTest
	private static void testUploadFilePositive() {
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		GoogleFileEntity result = new GoogleRemoteFileUploader().uploadFile('test.txt', 'aGVsbG8=');
		Test.stopTest();

		Assert.isNotNull(result);
	}

	@IsTest
	private static void testUploadBigFilePartialPositive() {
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		GoogleBigFileEntity result = new GoogleRemoteFileUploader().uploadBigFilePartial(
			'large.bin', 'aGVsbG8=', 'session_1', 0L, 10L
		);
		Test.stopTest();

		Assert.isNotNull(result);
	}

	@IsTest
	private static void testUploadFilePositiveFallsOverOnTeamDriveLimit() {
		configureMultiDrive(new List<String>{ PRIMARY_FOLDER, SECONDARY_FOLDER });

		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('POST')
				.queryContains('uploadtype=multipart')
				.bodyContains(PRIMARY_FOLDER)
		).thenReturnStatus(403, buildCapacityErrorBody('teamDriveFileLimitExceeded'));
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('POST')
				.queryContains('uploadtype=multipart')
				.bodyContains(SECONDARY_FOLDER)
		).thenReturnStatus(200, buildFileSuccessBody(SECONDARY_FOLDER));

		GoogleCloudTestFactory.initMocks(driveMock);

		Test.startTest();
		GoogleFileEntity result = new GoogleRemoteFileUploader().uploadFile('test.txt', 'aGVsbG8=');
		Test.stopTest();

		Assert.isNotNull(result);
		Assert.areEqual('gfile_success_01', result.id);
	}

	@IsTest
	private static void testUploadFilePositiveFallsOverOnStorageQuota() {
		configureMultiDrive(new List<String>{ PRIMARY_FOLDER, SECONDARY_FOLDER });

		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('POST')
				.queryContains('uploadtype=multipart')
				.bodyContains(PRIMARY_FOLDER)
		).thenReturnStatus(403, buildCapacityErrorBody('storageQuotaExceeded'));
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('POST')
				.queryContains('uploadtype=multipart')
				.bodyContains(SECONDARY_FOLDER)
		).thenReturnStatus(200, buildFileSuccessBody(SECONDARY_FOLDER));

		GoogleCloudTestFactory.initMocks(driveMock);

		Test.startTest();
		GoogleFileEntity result = new GoogleRemoteFileUploader().uploadFile('test.txt', 'aGVsbG8=');
		Test.stopTest();

		Assert.isNotNull(result);
		Assert.areEqual('gfile_success_01', result.id);
	}

	@IsTest
	private static void testUploadFilePositiveFallsOverOnNumChildren() {
		configureMultiDrive(new List<String>{ PRIMARY_FOLDER, SECONDARY_FOLDER });

		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('POST')
				.queryContains('uploadtype=multipart')
				.bodyContains(PRIMARY_FOLDER)
		).thenReturnStatus(403, buildCapacityErrorBody('numChildrenInNonRootLimitExceeded'));
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('POST')
				.queryContains('uploadtype=multipart')
				.bodyContains(SECONDARY_FOLDER)
		).thenReturnStatus(200, buildFileSuccessBody(SECONDARY_FOLDER));

		GoogleCloudTestFactory.initMocks(driveMock);

		Test.startTest();
		GoogleFileEntity result = new GoogleRemoteFileUploader().uploadFile('test.txt', 'aGVsbG8=');
		Test.stopTest();

		Assert.isNotNull(result);
		Assert.areEqual('gfile_success_01', result.id);
	}

	@IsTest
	private static void testUploadFilePositiveFallsOverThroughMultipleDrives() {
		configureMultiDrive(new List<String>{ PRIMARY_FOLDER, SECONDARY_FOLDER, THIRD_FOLDER });

		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('POST')
				.queryContains('uploadtype=multipart')
				.bodyContains(PRIMARY_FOLDER)
		).thenReturnStatus(403, buildCapacityErrorBody('teamDriveFileLimitExceeded'));
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('POST')
				.queryContains('uploadtype=multipart')
				.bodyContains(SECONDARY_FOLDER)
		).thenReturnStatus(403, buildCapacityErrorBody('storageQuotaExceeded'));
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('POST')
				.queryContains('uploadtype=multipart')
				.bodyContains(THIRD_FOLDER)
		).thenReturnStatus(200, buildFileSuccessBody(THIRD_FOLDER));

		GoogleCloudTestFactory.initMocks(driveMock);

		Test.startTest();
		GoogleFileEntity result = new GoogleRemoteFileUploader().uploadFile('test.txt', 'aGVsbG8=');
		Test.stopTest();

		Assert.isNotNull(result);
		Assert.areEqual('gfile_success_01', result.id);
	}

	@IsTest
	private static void testUploadFileNegativeNonCapacityErrorPropagates() {
		configureMultiDrive(new List<String>{ PRIMARY_FOLDER, SECONDARY_FOLDER });

		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('POST')
				.queryContains('uploadtype=multipart')
				.bodyContains(PRIMARY_FOLDER)
		).thenReturnStatus(401, buildAuthErrorBody());
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('POST')
				.queryContains('uploadtype=multipart')
				.bodyContains(SECONDARY_FOLDER)
		).thenReturnStatus(200, buildFileSuccessBody(SECONDARY_FOLDER));

		GoogleCloudTestFactory.initMocks(driveMock);

		Test.startTest();
		try {
			new GoogleRemoteFileUploader().uploadFile('test.txt', 'aGVsbG8=');
			Assert.isTrue(false);
		} catch (GoogleRemoteFileUploader.GoogleRemoteFileUploaderException ex) {
			Assert.isTrue(ex.getMessage().contains('Unable to upload the file'));
		}
		Test.stopTest();
	}

	@IsTest
	private static void testUploadFileNegativeAllDrivesExhausted() {
		configureMultiDrive(new List<String>{ PRIMARY_FOLDER, SECONDARY_FOLDER });

		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('POST')
				.queryContains('uploadtype=multipart')
				.bodyContains(PRIMARY_FOLDER)
		).thenReturnStatus(403, buildCapacityErrorBody('teamDriveFileLimitExceeded'));
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('POST')
				.queryContains('uploadtype=multipart')
				.bodyContains(SECONDARY_FOLDER)
		).thenReturnStatus(403, buildCapacityErrorBody('storageQuotaExceeded'));

		GoogleCloudTestFactory.initMocks(driveMock);

		Test.startTest();
		try {
			new GoogleRemoteFileUploader().uploadFile('test.txt', 'aGVsbG8=');
			Assert.isTrue(false);
		} catch (GoogleRemoteFileUploader.GoogleRemoteFileUploaderException ex) {
			Assert.isTrue(ex.getMessage().contains('All configured shared drives are full'));
		}
		Test.stopTest();
	}

	@IsTest
	private static void testUploadFileNegativeSingleDriveCapacityFails() {
		configureMultiDrive(new List<String>{ PRIMARY_FOLDER });

		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('POST')
				.queryContains('uploadtype=multipart')
		).thenReturnStatus(403, buildCapacityErrorBody('teamDriveFileLimitExceeded'));

		GoogleCloudTestFactory.initMocks(driveMock);

		Test.startTest();
		try {
			new GoogleRemoteFileUploader().uploadFile('test.txt', 'aGVsbG8=');
			Assert.isTrue(false);
		} catch (GoogleRemoteFileUploader.GoogleRemoteFileUploaderException ex) {
			Assert.isTrue(ex.getMessage().contains('Unable to upload the file'));
		}
		Test.stopTest();
	}

	@IsTest
	private static void testUploadBigFilePartialPositiveInitFallsOver() {
		configureMultiDrive(new List<String>{ PRIMARY_FOLDER, SECONDARY_FOLDER });

		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('POST')
				.queryContains('uploadtype=resumable')
				.bodyContains(PRIMARY_FOLDER)
		).thenReturnStatus(403, buildCapacityErrorBody('teamDriveFileLimitExceeded'));
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('POST')
				.queryContains('uploadtype=resumable')
				.bodyContains(SECONDARY_FOLDER)
		).thenReturn(
			new GoogleDriveHttpMock.MockResponse()
				.withStatus(200)
				.withHeader('Location', 'https://resumable.session/mock/fallover')
				.withBody('')
		);
		driveMock.withDefaultHappyPath();

		GoogleCloudTestFactory.initMocks(driveMock);

		Test.startTest();
		GoogleBigFileEntity result = new GoogleRemoteFileUploader().uploadBigFilePartial(
			'large.bin', 'aGVsbG8=', null, 0L, 10L
		);
		Test.stopTest();

		Assert.isNotNull(result);
	}

	@IsTest
	private static void testUploadBigFilePartialNegativeAllInitDrivesExhausted() {
		configureMultiDrive(new List<String>{ PRIMARY_FOLDER, SECONDARY_FOLDER });

		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('POST')
				.queryContains('uploadtype=resumable')
		).thenReturnStatus(403, buildCapacityErrorBody('teamDriveFileLimitExceeded'));

		GoogleCloudTestFactory.initMocks(driveMock);

		Test.startTest();
		try {
			new GoogleRemoteFileUploader().uploadBigFilePartial('large.bin', 'aGVsbG8=', null, 0L, 10L);
			Assert.isTrue(false);
		} catch (GoogleRemoteFileUploader.GoogleRemoteFileUploaderException ex) {
			Assert.isTrue(ex.getMessage().contains('All configured shared drives are full'));
		}
		Test.stopTest();
	}

	@IsTest
	private static void testUploadBigFilePartialNegativeInitNonCapacityPropagates() {
		configureMultiDrive(new List<String>{ PRIMARY_FOLDER, SECONDARY_FOLDER });

		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('POST')
				.queryContains('uploadtype=resumable')
				.bodyContains(PRIMARY_FOLDER)
		).thenReturnStatus(401, buildAuthErrorBody());

		GoogleCloudTestFactory.initMocks(driveMock);

		Test.startTest();
		try {
			new GoogleRemoteFileUploader().uploadBigFilePartial('large.bin', 'aGVsbG8=', null, 0L, 10L);
			Assert.isTrue(false);
		} catch (GoogleRemoteFileUploader.GoogleRemoteFileUploaderException ex) {
			Assert.isTrue(ex.getMessage().contains('Unable to upload the file chunk'));
		}
		Test.stopTest();
	}

	@IsTest
	private static void testUploadBigFilePartialPositiveChunkWithExistingSession() {
		configureMultiDrive(new List<String>{ PRIMARY_FOLDER, SECONDARY_FOLDER });
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		GoogleBigFileEntity result = new GoogleRemoteFileUploader().uploadBigFilePartial(
			'large.bin', 'aGVsbG8=', 'existing_session_uri', 0L, 10L
		);
		Test.stopTest();

		Assert.isNotNull(result);
	}
}
