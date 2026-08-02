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
private class GoogleDirectUploadServiceTest {
	private static final String UPLOAD_FOLDER = 'DIRECT_UPLOAD_FOLDER_01';
	private static final String SESSION_URI = 'https://resumable.session/mock/abc123';

	private static void enableDirectUpload(Boolean isEnabled) {
		GoogleClientConfig__mdt config = new GoogleClientConfig__mdt();
		config.DefaultGoogleUploadFolderId__c = UPLOAD_FOLDER;
		config.IsDirectBrowserUploadEnabled__c = isEnabled;
		GoogleMetadataConfigService.configRecordOverride = config;
	}

	private static GoogleDirectUploadService buildService() {
		return new GoogleDirectUploadService(new GoogleMetadataConfigService(), new GoogleRemoteFileUploader());
	}

	private static String buildFinalChunk(Integer byteCount) {
		return EncodingUtil.base64Encode(Blob.valueOf('x'.repeat(byteCount)));
	}

	@IsTest
	private static void testResolveSettingsNegativeDisabledByDefault() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt();
		GoogleCloudTestFactory.initMocks();

		GoogleDirectUploadSettingsDTO settings = buildService().resolveSettings();

		Assert.isFalse(settings.isDirectUploadEnabled, 'An org that never opted in must keep the standard upload path');
	}

	@IsTest
	private static void testResolveSettingsPositiveEnabled() {
		enableDirectUpload(true);
		GoogleCloudTestFactory.initMocks();

		Assert.isTrue(buildService().resolveSettings().isDirectUploadEnabled);
	}

	@IsTest
	private static void testResolveBrowserByteLimitPositiveAlignsToQuarterMegabyte() {
		Assert.areEqual(524288L, GoogleDirectUploadService.resolveBrowserByteLimit(700000L), 'The browser must stop on a 256 KB boundary so Google accepts every chunk it sends');
	}

	@IsTest
	private static void testResolveBrowserByteLimitPositiveReservesFinalChunkWhenAligned() {
		Assert.areEqual(262144L, GoogleDirectUploadService.resolveBrowserByteLimit(524288L), 'An exactly aligned total must still leave a final chunk for Apex to send');
	}

	@IsTest
	private static void testResolveBrowserByteLimitPositiveSmallFileGoesEntirelyThroughApex() {
		Assert.areEqual(0L, GoogleDirectUploadService.resolveBrowserByteLimit(1000L));
	}

	@IsTest
	private static void testStartUploadNegativeFeatureDisabled() {
		enableDirectUpload(false);
		GoogleCloudTestFactory.initMocks();

		try {
			buildService().startUpload('large.bin', 'application/octet-stream', 10L);
			Assert.fail('Starting an upload must be rejected while the feature is disabled');
		} catch (GoogleDirectUploadService.GoogleDirectUploadException ex) {
			Assert.isTrue(ex.getMessage().contains('not enabled'), ex.getMessage());
		}
	}

	@IsTest
	private static void testStartUploadNegativeBlankFileName() {
		enableDirectUpload(true);
		GoogleCloudTestFactory.initMocks();

		try {
			buildService().startUpload('   ', 'application/octet-stream', 10L);
			Assert.fail('A blank file name must be rejected');
		} catch (GoogleDirectUploadService.GoogleDirectUploadException ex) {
			Assert.isTrue(ex.getMessage().contains('file name'), ex.getMessage());
		}
	}

	@IsTest
	private static void testStartUploadNegativeInvalidTotalBytes() {
		enableDirectUpload(true);
		GoogleCloudTestFactory.initMocks();

		try {
			buildService().startUpload('large.bin', 'application/octet-stream', 0L);
			Assert.fail('A zero byte total must be rejected');
		} catch (GoogleDirectUploadService.GoogleDirectUploadException ex) {
			Assert.isTrue(ex.getMessage().contains('file size'), ex.getMessage());
		}
	}

	@IsTest
	private static void testStartUploadPositiveReturnsSessionAndByteLimit() {
		enableDirectUpload(true);
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		GoogleDirectUploadSessionDTO session = buildService().startUpload('large.bin', 'application/octet-stream', 700000L);
		Test.stopTest();

		Assert.areEqual(SESSION_URI, session.sessionUri);
		Assert.areEqual(524288L, session.browserByteLimit);
	}

	@IsTest
	private static void testCompleteUploadPositiveReturnsVerifiedFile() {
		enableDirectUpload(true);
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		GoogleDirectUploadResultDTO result = buildService().completeUpload('large.bin', SESSION_URI, buildFinalChunk(10), 0L, 10L);
		Test.stopTest();

		Assert.areEqual('gfile_big_001', result.googleDriveId, 'The Drive id must come from Google, never from the client');
		Assert.areEqual('large.bin', result.fileName);
		Assert.areEqual(10L, result.fileSize);
		Assert.areEqual(UPLOAD_FOLDER, result.parentFolderId);
	}

	@IsTest
	private static void testCompleteUploadPositiveUsesFolderReportedByGoogle() {
		enableDirectUpload(true);

		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher().withMethod('PUT')
		).thenReturnStatus(200, '{"id":"gfile_big_001","name":"large.bin","parents":["FALLOVER_FOLDER_02"]}');
		GoogleCloudTestFactory.initMocks(driveMock);

		Test.startTest();
		GoogleDirectUploadResultDTO result = buildService().completeUpload('large.bin', SESSION_URI, buildFinalChunk(10), 0L, 10L);
		Test.stopTest();

		Assert.areEqual('FALLOVER_FOLDER_02', result.parentFolderId, 'The folder Google reports wins, so capacity fallover is reflected on the record');
	}

	@IsTest
	private static void testCompleteUploadNegativeMissingSession() {
		enableDirectUpload(true);
		GoogleCloudTestFactory.initMocks();

		try {
			buildService().completeUpload('large.bin', '', buildFinalChunk(10), 0L, 10L);
			Assert.fail('A missing upload session must be rejected');
		} catch (GoogleDirectUploadService.GoogleDirectUploadException ex) {
			Assert.isTrue(ex.getMessage().contains('upload session is missing'), ex.getMessage());
		}
	}

	@IsTest
	private static void testCompleteUploadNegativeMissingFinalChunk() {
		enableDirectUpload(true);
		GoogleCloudTestFactory.initMocks();

		try {
			buildService().completeUpload('large.bin', SESSION_URI, '', 0L, 10L);
			Assert.fail('A missing final chunk must be rejected');
		} catch (GoogleDirectUploadService.GoogleDirectUploadException ex) {
			Assert.isTrue(ex.getMessage().contains('final upload chunk'), ex.getMessage());
		}
	}

	@IsTest
	private static void testCompleteUploadNegativeStartByteBeyondTotal() {
		enableDirectUpload(true);
		GoogleCloudTestFactory.initMocks();

		try {
			buildService().completeUpload('large.bin', SESSION_URI, buildFinalChunk(10), 10L, 10L);
			Assert.fail('A final chunk that starts at or past the declared total must be rejected');
		} catch (GoogleDirectUploadService.GoogleDirectUploadException ex) {
			Assert.isTrue(ex.getMessage().contains('range is invalid'), ex.getMessage());
		}
	}

	@IsTest
	private static void testCompleteUploadNegativeUploadNeverCompleted() {
		enableDirectUpload(true);

		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher().withMethod('PUT')
		).thenReturnStatus(308, '{ "status":"resume" }');
		GoogleCloudTestFactory.initMocks(driveMock);

		try {
			buildService().completeUpload('large.bin', SESSION_URI, buildFinalChunk(10), 0L, 10L);
			Assert.fail('A session that Google has not finished must not produce a Salesforce record');
		} catch (GoogleDirectUploadService.GoogleDirectUploadException ex) {
			Assert.isTrue(ex.getMessage().contains('did not complete'), ex.getMessage());
		}
	}

	@IsTest
	private static void testReportOutcomePositiveFailure() {
		enableDirectUpload(true);
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		buildService().reportOutcome(GoogleDirectUploadService.OUTCOME_BLOCKED, 'bytes 0-16777215 attempt 1 status 0');
		Test.stopTest();

		Assert.isTrue(true, 'Reporting an outcome must never surface an error to the uploading user');
	}

	@IsTest
	private static void testReportOutcomePositiveRecovered() {
		enableDirectUpload(true);
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		buildService().reportOutcome(GoogleDirectUploadService.OUTCOME_RECOVERED, 'retried once');
		Test.stopTest();

		Assert.isTrue(true, 'A recovered upload is informational, not an error');
	}
}
