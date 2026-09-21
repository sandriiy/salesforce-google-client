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
private class GoogleCloudDriveAccessControllerTest {
	private static final String ACTING_USER_EMAIL = 'controller.owner@example.com';

	@IsTest
	private static void testOpenInDrivePositive() {
		enableOpenInDrive();
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.mockUser(UserInfo.getUserId(), 'Standard', ACTING_USER_EMAIL);

		GoogleFileVersion__c localFileVersion = insertFileWithVersion('CTRL_1', 'GD_CTRL_1');

		Test.startTest();
		GoogleDriveAccessDTO driveAccess = GoogleCloudDriveAccessController.openInDrive(
			localFileVersion.GoogleFileId__c,
			localFileVersion.Id
		);
		Test.stopTest();

		Assert.isNotNull(driveAccess);
		Assert.isTrue(String.isNotBlank(driveAccess.driveUrl));
		Assert.isNotNull(driveAccess.expiresOn);
	}

	@IsTest
	private static void testOpenInDriveNegativeSurfacesUserSafeError() {
		GoogleMetadataConfigService.configRecordOverride = GoogleCloudTestFactory.config()
			.asPackagedRecord()
			.withOpenInDrive(false)
			.build();

		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.mockUser(UserInfo.getUserId(), 'Standard', ACTING_USER_EMAIL);

		GoogleFileVersion__c localFileVersion = insertFileWithVersion('CTRL_2', 'GD_CTRL_2');
		Boolean isDenied = false;

		Test.startTest();
		try {
			GoogleCloudDriveAccessController.openInDrive(localFileVersion.GoogleFileId__c, localFileVersion.Id);
		} catch (Exception ex) {
			isDenied = true;
		}
		Test.stopTest();

		Assert.isTrue(isDenied);
	}

	@IsTest
	private static void testCanOpenInDrivePositive() {
		enableOpenInDrive();
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.mockUser(UserInfo.getUserId(), 'Standard', ACTING_USER_EMAIL);

		GoogleFileVersion__c localFileVersion = insertFileWithVersion('CTRL_3', 'GD_CTRL_3');

		Test.startTest();
		Boolean isAvailable = GoogleCloudDriveAccessController.canOpenInDrive(localFileVersion.GoogleFileId__c);
		Test.stopTest();

		Assert.isTrue(isAvailable);
	}

	@IsTest
	private static void testCanOpenInDriveNegativeExternalUser() {
		enableOpenInDrive();
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.mockUser(UserInfo.getUserId(), 'CspLitePortal', ACTING_USER_EMAIL);

		GoogleFileVersion__c localFileVersion = insertFileWithVersion('CTRL_4', 'GD_CTRL_4');

		Test.startTest();
		Boolean isAvailable = GoogleCloudDriveAccessController.canOpenInDrive(localFileVersion.GoogleFileId__c);
		Test.stopTest();

		Assert.isFalse(isAvailable);
	}

	private static void enableOpenInDrive() {
		GoogleMetadataConfigService.configRecordOverride = GoogleCloudTestFactory.config()
			.asPackagedRecord()
			.withOpenInDrive(true)
			.build();
	}

	private static GoogleFileVersion__c insertFileWithVersion(String fileName, String remoteFileId) {
		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName(fileName).insertRecord();

		return GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName(fileName + '.pdf')
			.withType('application/pdf')
			.withDriveId(remoteFileId)
			.insertRecord();
	}
}
