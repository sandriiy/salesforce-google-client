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
private class GoogleCloudDirectUploadControllerTest {
	private static final String UPLOAD_FOLDER = 'DIRECT_UPLOAD_FOLDER_01';
	private static final String SESSION_URI = 'https://resumable.session/mock/abc123';

	private static void configureController(Boolean isDirectUploadEnabled) {
		GoogleClientConfig__mdt config = new GoogleClientConfig__mdt();
		config.DefaultGoogleUploadFolderId__c = UPLOAD_FOLDER;
		config.IsDirectBrowserUploadEnabled__c = isDirectUploadEnabled;
		GoogleMetadataConfigService.configRecordOverride = config;

		GoogleCloudTestFactory.initMocks();

		GoogleCloudDirectUploadController.serviceOverride = new GoogleDirectUploadService(
			new GoogleMetadataConfigService(),
			new GoogleRemoteFileUploader()
		);
	}

	@IsTest
	private static void testRetrieveDirectUploadSettingsNegativeDisabledByDefault() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt();
		GoogleCloudTestFactory.initMocks();

		GoogleDirectUploadSettingsDTO settings = GoogleCloudDirectUploadController.retrieveDirectUploadSettings();

		Assert.isFalse(settings.isDirectUploadEnabled, 'An upgraded org that never opted in must keep the standard upload path');
	}

	@IsTest
	private static void testRetrieveDirectUploadSettingsPositiveEnabled() {
		configureController(true);

		Assert.isTrue(GoogleCloudDirectUploadController.retrieveDirectUploadSettings().isDirectUploadEnabled);
	}

	@IsTest
	private static void testInitializeDirectUploadPositive() {
		configureController(true);

		Test.startTest();
		GoogleDirectUploadSessionDTO session = GoogleCloudDirectUploadController.initializeDirectUpload('large.bin', 'application/octet-stream', 700000L);
		Test.stopTest();

		Assert.areEqual(SESSION_URI, session.sessionUri);
		Assert.areEqual(524288L, session.browserByteLimit);
	}

	@IsTest
	private static void testInitializeDirectUploadNegativeFeatureDisabled() {
		configureController(false);

		try {
			GoogleCloudDirectUploadController.initializeDirectUpload('large.bin', 'application/octet-stream', 700000L);
			Assert.fail('The controller must refuse to open a session while the feature is disabled');
		} catch (AuraHandledException ex) {
			Assert.isNotNull(ex);
		}
	}

	@IsTest
	private static void testFinalizeDirectUploadPositive() {
		configureController(true);

		Test.startTest();
		GoogleDirectUploadResultDTO result = GoogleCloudDirectUploadController.finalizeDirectUpload(
			'large.bin',
			SESSION_URI,
			EncodingUtil.base64Encode(Blob.valueOf('0123456789')),
			0L,
			10L
		);
		Test.stopTest();

		Assert.areEqual('gfile_big_001', result.googleDriveId);
		Assert.areEqual(UPLOAD_FOLDER, result.parentFolderId);
		Assert.areEqual(10L, result.fileSize);
	}

	@IsTest
	private static void testFinalizeDirectUploadNegativeMissingSession() {
		configureController(true);

		try {
			GoogleCloudDirectUploadController.finalizeDirectUpload(
				'large.bin',
				'',
				EncodingUtil.base64Encode(Blob.valueOf('0123456789')),
				0L,
				10L
			);
			Assert.fail('A missing upload session must be rejected');
		} catch (AuraHandledException ex) {
			Assert.isNotNull(ex);
		}
	}

	@IsTest
	private static void testReportDirectUploadOutcomePositive() {
		configureController(true);

		Test.startTest();
		GoogleCloudDirectUploadController.reportDirectUploadOutcome(
			GoogleCloudConstants.DIRECT_UPLOAD_OUTCOME_BLOCKED,
			'bytes 0-16777215 attempt 1 status 0'
		);
		Test.stopTest();

		Assert.isTrue(true, 'Reporting an outcome must never surface an error to the uploading user');
	}

	@IsTest
	private static void testReportDirectUploadOutcomeNegativeNeverThrows() {
		configureController(true);

		Test.startTest();
		GoogleCloudDirectUploadController.reportDirectUploadOutcome(null, null);
		Test.stopTest();

		Assert.isTrue(true, 'A malformed outcome report must not break the upload flow');
	}
}
