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
private class GoogleLocalDriveAccessServiceTest {
	private static final String ACTING_USER_EMAIL = 'file.owner@example.com';

	@IsTest
	private static void testOpenInDrivePositiveCreatesViewPermission() {
		enableOpenInDrive();
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.mockUser(UserInfo.getUserId(), 'Standard', ACTING_USER_EMAIL);

		GoogleFileVersion__c localFileVersion = insertFileWithVersion('OID_1', 'GD_OID_1');
		Datetime beforeCall = Datetime.now();

		Test.startTest();
		GoogleDriveAccessDTO driveAccess = new GoogleLocalDriveAccessService()
			.openInDrive(localFileVersion.GoogleFileId__c, localFileVersion.Id);
		Test.stopTest();

		Assert.isNotNull(driveAccess);
		Assert.isTrue(String.isNotBlank(driveAccess.driveUrl));
		Assert.isFalse(driveAccess.wasAlreadyShared);
		Assert.isTrue(driveAccess.expiresOn > beforeCall);
	}

	@IsTest
	private static void testOpenInDrivePositiveReusesExistingPermission() {
		enableOpenInDrive();

		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
				new GoogleDriveHttpMock.RequestMatcher().withMethod('GET').endpointContains('fields=')
			)
			.thenReturn(
				new GoogleDriveHttpMock.JsonResponses()
					.fileDetailsWithPermissionsSuccess('GD_OID_2', 'perm_existing_001', 'user', ACTING_USER_EMAIL)
			);

		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleCloudTestFactory.mockUser(UserInfo.getUserId(), 'Standard', ACTING_USER_EMAIL);

		GoogleFileVersion__c localFileVersion = insertFileWithVersion('OID_2', 'GD_OID_2');

		Test.startTest();
		GoogleDriveAccessDTO driveAccess = new GoogleLocalDriveAccessService()
			.openInDrive(localFileVersion.GoogleFileId__c, localFileVersion.Id);
		Test.stopTest();

		Assert.isTrue(driveAccess.wasAlreadyShared);
		Assert.isFalse(hasCapturedRequest(driveMock, 'POST', '/permissions'));
	}

	@IsTest
	private static void testOpenInDriveNegativeIgnoresDomainPermission() {
		enableOpenInDrive();

		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
				new GoogleDriveHttpMock.RequestMatcher().withMethod('GET').endpointContains('fields=')
			)
			.thenReturn(
				new GoogleDriveHttpMock.JsonResponses()
					.fileDetailsWithPermissionsSuccess('GD_OID_3', 'perm_domain_001', 'domain', ACTING_USER_EMAIL)
			);

		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleCloudTestFactory.mockUser(UserInfo.getUserId(), 'Standard', ACTING_USER_EMAIL);

		GoogleFileVersion__c localFileVersion = insertFileWithVersion('OID_3', 'GD_OID_3');

		Test.startTest();
		GoogleDriveAccessDTO driveAccess = new GoogleLocalDriveAccessService()
			.openInDrive(localFileVersion.GoogleFileId__c, localFileVersion.Id);
		Test.stopTest();

		Assert.isFalse(driveAccess.wasAlreadyShared);
		Assert.isTrue(hasCapturedRequest(driveMock, 'POST', '/permissions'));
	}

	@IsTest
	private static void testOpenInDriveNegativeFeatureDisabled() {
		GoogleMetadataConfigService.configRecordOverride = GoogleCloudTestFactory.config()
			.asPackagedRecord()
			.withOpenInDrive(false)
			.build();

		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.mockUser(UserInfo.getUserId(), 'Standard', ACTING_USER_EMAIL);

		GoogleFileVersion__c localFileVersion = insertFileWithVersion('OID_4', 'GD_OID_4');

		Test.startTest();
		Boolean isDenied = didOpenInDriveFail(localFileVersion.GoogleFileId__c, localFileVersion.Id);
		Test.stopTest();

		Assert.isTrue(isDenied);
	}

	@IsTest
	private static void testOpenInDriveNegativeExternalUser() {
		enableOpenInDrive();
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.mockUser(UserInfo.getUserId(), 'CspLitePortal', ACTING_USER_EMAIL);

		GoogleFileVersion__c localFileVersion = insertFileWithVersion('OID_5', 'GD_OID_5');

		Test.startTest();
		Boolean isDenied = didOpenInDriveFail(localFileVersion.GoogleFileId__c, localFileVersion.Id);
		Test.stopTest();

		Assert.isTrue(isDenied);
	}

	@IsTest
	private static void testOpenInDriveNegativeNotOwner() {
		enableOpenInDrive();
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.mockUser(UserInfo.getUserId(), 'Standard', ACTING_USER_EMAIL);

		GoogleFileVersion__c localFileVersion = insertFileWithVersion('OID_6', 'GD_OID_6');
		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(new List<SObject>());

		Test.startTest();
		Boolean isDenied = didOpenInDriveFail(localFileVersion.GoogleFileId__c, localFileVersion.Id);
		Test.stopTest();

		Assert.isTrue(isDenied);
	}

	@IsTest
	private static void testOpenInDriveNegativeVersionOfAnotherFile() {
		enableOpenInDrive();
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.mockUser(UserInfo.getUserId(), 'Standard', ACTING_USER_EMAIL);

		GoogleFileVersion__c ownedVersion = insertFileWithVersion('OID_7', 'GD_OID_7');
		GoogleFileVersion__c foreignVersion = insertFileWithVersion('OID_8', 'GD_OID_8');

		Test.startTest();
		Boolean isDenied = didOpenInDriveFail(ownedVersion.GoogleFileId__c, foreignVersion.Id);
		Test.stopTest();

		Assert.isTrue(isDenied);
	}

	@IsTest
	private static void testOpenInDriveNegativeMissingRemoteFile() {
		enableOpenInDrive();
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.mockUser(UserInfo.getUserId(), 'Standard', ACTING_USER_EMAIL);

		GoogleFileVersion__c localFileVersion = insertFileWithVersion('OID_9', 'GD_OID_9');

		GSOQL.mock(GoogleFileVersionSelector.MOCK_ID).thenReturn(new List<SObject>{
			new GoogleFileVersion__c(
				Id = localFileVersion.Id,
				Name = localFileVersion.Name,
				GoogleFileId__c = localFileVersion.GoogleFileId__c
			)
		});

		Test.startTest();
		Boolean isDenied = didOpenInDriveFail(localFileVersion.GoogleFileId__c, localFileVersion.Id);
		Test.stopTest();

		Assert.isTrue(isDenied);
	}

	@IsTest
	private static void testOpenInDriveNegativeRemoteFailure() {
		enableOpenInDrive();

		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
				new GoogleDriveHttpMock.RequestMatcher().withMethod('GET').endpointContains('GD_OID_10')
			)
			.thenReturnStatus(403, '{ "error": { "message":"Insufficient permissions" } }');

		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleCloudTestFactory.bypassTriggers();
		GoogleCloudTestFactory.mockUser(UserInfo.getUserId(), 'Standard', ACTING_USER_EMAIL);

		GoogleFileVersion__c localFileVersion = insertFileWithVersion('OID_10', 'GD_OID_10');

		Test.startTest();
		Boolean isDenied = didOpenInDriveFail(localFileVersion.GoogleFileId__c, localFileVersion.Id);
		Test.stopTest();

		Assert.isTrue(isDenied);
	}

	@IsTest
	private static void testCanOpenInDrivePositiveForOwner() {
		enableOpenInDrive();
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.mockUser(UserInfo.getUserId(), 'Standard', ACTING_USER_EMAIL);

		GoogleFileVersion__c localFileVersion = insertFileWithVersion('OID_11', 'GD_OID_11');

		Test.startTest();
		Boolean isAvailable = new GoogleLocalDriveAccessService().canOpenInDrive(localFileVersion.GoogleFileId__c);
		Test.stopTest();

		Assert.isTrue(isAvailable);
	}

	@IsTest
	private static void testCanOpenInDriveNegativeFeatureDisabled() {
		GoogleMetadataConfigService.configRecordOverride = GoogleCloudTestFactory.config()
			.asPackagedRecord()
			.withOpenInDrive(false)
			.build();

		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.mockUser(UserInfo.getUserId(), 'Standard', ACTING_USER_EMAIL);

		GoogleFileVersion__c localFileVersion = insertFileWithVersion('OID_12', 'GD_OID_12');

		Test.startTest();
		Boolean isAvailable = new GoogleLocalDriveAccessService().canOpenInDrive(localFileVersion.GoogleFileId__c);
		Test.stopTest();

		Assert.isFalse(isAvailable);
	}

	@IsTest
	private static void testCanOpenInDriveNegativeExternalUser() {
		enableOpenInDrive();
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.mockUser(UserInfo.getUserId(), 'CspLitePortal', ACTING_USER_EMAIL);

		GoogleFileVersion__c localFileVersion = insertFileWithVersion('OID_13', 'GD_OID_13');

		Test.startTest();
		Boolean isAvailable = new GoogleLocalDriveAccessService().canOpenInDrive(localFileVersion.GoogleFileId__c);
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

	private static Boolean didOpenInDriveFail(Id localFileRecordId, Id localFileVersionId) {
		try {
			new GoogleLocalDriveAccessService().openInDrive(localFileRecordId, localFileVersionId);
			return false;
		} catch (GoogleLocalDriveAccessService.GoogleLocalDriveAccessException ex) {
			return true;
		}
	}

	private static Boolean hasCapturedRequest(GoogleDriveHttpMock driveMock, String method, String endpointFragment) {
		for (GoogleDriveHttpMock.CapturedRequest capturedRequest : driveMock.getCapturedRequests()) {
			if (capturedRequest.method != method) continue;
			if (capturedRequest.endpoint != null && capturedRequest.endpoint.contains(endpointFragment)) {
				return true;
			}
		}

		return false;
	}
}
