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
private class GoogleDriveAccessGrantCommandTest {
	private static final String GRANTEE_EMAIL = 'grantee@example.com';

	@IsTest
	private static void testGrantViewAccessPositiveCreatesReaderPermission() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		GoogleCloudTestFactory.initMocks(driveMock);

		Datetime accessEndsOn = Datetime.now().addDays(7);

		Test.startTest();
		GoogleDriveAccessGrantCommand.GrantResult grantResult = new GoogleDriveAccessGrantCommand()
			.grantViewAccess('GD_GRANT_1', GRANTEE_EMAIL, accessEndsOn);
		Test.stopTest();

		Assert.isNotNull(grantResult);
		Assert.isFalse(grantResult.wasAlreadyShared);
		Assert.isTrue(String.isNotBlank(grantResult.permissionId));
		Assert.isTrue(String.isNotBlank(grantResult.viewLink));

		String createBody = findRequestBody(driveMock, 'POST', '/permissions');
		Assert.isNotNull(createBody);
		Assert.isTrue(createBody.contains('"role":"reader"'), 'Grant must be view only: ' + createBody);
		Assert.isTrue(createBody.contains('"type":"user"'), 'Grant must target a single user: ' + createBody);
		Assert.isTrue(createBody.contains(GRANTEE_EMAIL), 'Grant must target the acting user: ' + createBody);
		Assert.isFalse(createBody.contains('"role":"writer"'), 'Grant must never allow editing: ' + createBody);
	}

	@IsTest
	private static void testGrantViewAccessPositiveSuppressesNotificationEmail() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		GoogleCloudTestFactory.initMocks(driveMock);

		Test.startTest();
		new GoogleDriveAccessGrantCommand().grantViewAccess('GD_GRANT_2', GRANTEE_EMAIL, Datetime.now().addDays(7));
		Test.stopTest();

		String createEndpoint = findRequestEndpoint(driveMock, 'POST', '/permissions');
		Assert.isNotNull(createEndpoint);
		Assert.isTrue(createEndpoint.toLowerCase().contains('sendnotificationemail=false'), 'Opening a file must not email anyone: ' + createEndpoint);
	}

	@IsTest
	private static void testGrantViewAccessPositiveSetsFutureExpiration() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		GoogleCloudTestFactory.initMocks(driveMock);

		Datetime accessEndsOn = Datetime.now().addDays(7);

		Test.startTest();
		new GoogleDriveAccessGrantCommand().grantViewAccess('GD_GRANT_3', GRANTEE_EMAIL, accessEndsOn);
		Test.stopTest();

		String expirationBody = findRequestBody(driveMock, 'PATCH', '/permissions/');
		if (expirationBody == null) {
			expirationBody = findRequestBody(driveMock, 'PUT', '/permissions/');
		}

		Assert.isNotNull(expirationBody, 'Access must always be given an end date');
		Assert.isTrue(expirationBody.contains('"role":"reader"'), 'Google rejects an expiration change without the role: ' + expirationBody);
		Assert.isTrue(expirationBody.contains('expirationTime'), 'Access must always be given an end date: ' + expirationBody);
		Assert.isTrue(expirationBody.contains(accessEndsOn.formatGmt('yyyy-MM-dd')), 'Expiration must match the requested date: ' + expirationBody);
	}

	@IsTest
	private static void testGrantViewAccessPositiveReusesExistingUserPermission() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
				new GoogleDriveHttpMock.RequestMatcher().withMethod('GET').endpointContains('fields=')
			)
			.thenReturn(
				new GoogleDriveHttpMock.JsonResponses()
					.fileDetailsWithPermissionsSuccess('GD_GRANT_4', 'perm_existing_004', 'user', GRANTEE_EMAIL)
			);

		GoogleCloudTestFactory.initMocks(driveMock);

		Test.startTest();
		GoogleDriveAccessGrantCommand.GrantResult grantResult = new GoogleDriveAccessGrantCommand()
			.grantViewAccess('GD_GRANT_4', GRANTEE_EMAIL, Datetime.now().addDays(7));
		Test.stopTest();

		Assert.isTrue(grantResult.wasAlreadyShared);
		Assert.areEqual('perm_existing_004', grantResult.permissionId);
		Assert.isNull(findRequestBody(driveMock, 'POST', '/permissions'), 'An existing permission must not be duplicated');
	}

	@IsTest
	private static void testGrantViewAccessPositiveKeepsAccessWhenExpirationUnsupported() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
				new GoogleDriveHttpMock.RequestMatcher().endpointContains('/permissions/')
			)
			.thenReturnStatus(403, '{ "error": { "code": 403, "message": "Expiration dates cannot be set on this item.", "errors": [ { "reason": "cannotSetExpiration" } ] } }');

		GoogleCloudTestFactory.initMocks(driveMock);

		Test.startTest();
		GoogleDriveAccessGrantCommand.GrantResult grantResult = new GoogleDriveAccessGrantCommand()
			.grantViewAccess('GD_GRANT_8', GRANTEE_EMAIL, Datetime.now().addDays(7));
		Test.stopTest();

		Assert.isTrue(String.isNotBlank(grantResult.permissionId), 'View access must survive when an end date is not supported');
		Assert.isNull(grantResult.accessEndsOn, 'An end date Google refused must not be reported as applied');
	}
	@IsTest
	private static void testGrantViewAccessNegativeBlankRemoteFileId() {
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		Boolean isRejected = didGrantFail(null, GRANTEE_EMAIL, Datetime.now().addDays(7));
		Test.stopTest();

		Assert.isTrue(isRejected);
	}

	@IsTest
	private static void testGrantViewAccessNegativeBlankEmail() {
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		Boolean isRejected = didGrantFail('GD_GRANT_5', '  ', Datetime.now().addDays(7));
		Test.stopTest();

		Assert.isTrue(isRejected);
	}

	@IsTest
	private static void testGrantViewAccessNegativeExpirationBeyondOneYear() {
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		Boolean isRejected = didGrantFail('GD_GRANT_7', GRANTEE_EMAIL, Datetime.now().addDays(400));
		Test.stopTest();

		Assert.isTrue(isRejected);
	}

	@IsTest
	private static void testGrantViewAccessNegativePastExpiration() {
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		Boolean isRejected = didGrantFail('GD_GRANT_6', GRANTEE_EMAIL, Datetime.now().addDays(-1));
		Test.stopTest();

		Assert.isTrue(isRejected);
	}

	private static Boolean didGrantFail(String remoteFileId, String emailAddress, Datetime accessEndsOn) {
		try {
			new GoogleDriveAccessGrantCommand().grantViewAccess(remoteFileId, emailAddress, accessEndsOn);
			return false;
		} catch (GoogleDriveAccessGrantCommand.GoogleDriveAccessGrantException ex) {
			return true;
		}
	}

	private static String findRequestBody(GoogleDriveHttpMock driveMock, String method, String endpointFragment) {
		for (GoogleDriveHttpMock.CapturedRequest capturedRequest : driveMock.getCapturedRequests()) {
			if (capturedRequest.method != method) continue;
			if (capturedRequest.endpoint != null && capturedRequest.endpoint.contains(endpointFragment)) {
				return capturedRequest.body;
			}
		}

		return null;
	}

	private static String findRequestEndpoint(GoogleDriveHttpMock driveMock, String method, String endpointFragment) {
		for (GoogleDriveHttpMock.CapturedRequest capturedRequest : driveMock.getCapturedRequests()) {
			if (capturedRequest.method != method) continue;
			if (capturedRequest.endpoint != null && capturedRequest.endpoint.contains(endpointFragment)) {
				return capturedRequest.endpoint;
			}
		}

		return null;
	}
}
