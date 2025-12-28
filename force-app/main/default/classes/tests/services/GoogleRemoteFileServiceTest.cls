@IsTest
private class GoogleRemoteFileServiceTest {
	public class TestGoogleAuthorizer implements GoogleAuthorizer {
		public String retrieveAccessToken() {
			return 'client.test-access-token';
		}
	}

	private static GoogleRemoteFileService newSut() {
		return new GoogleRemoteFileService();
	}

	private static void setHappyMock() {
		Test.setMock(HttpCalloutMock.class, new GoogleDriveHttpMock().withDefaultHappyPath());
	}

	private static void setFailureMock(RequestFailurePlan plan) {
		GoogleDriveHttpMock mock = new GoogleDriveHttpMock()
			.withDefaultHappyPath()
			.whenRequestMatches(
				new GoogleDriveHttpMock.RequestMatcher()
					.withMethod(plan.method)
					.endpointContains(plan.endpointMustContain)
			)
			.thenReturn(
				new GoogleDriveHttpMock.MockResponse()
					.withStatus(500)
					.withHeader('Content-Type', 'application/json')
					.withBody('{ "error": { "message":"boom" } }')
			);

		Test.setMock(HttpCalloutMock.class, mock);
	}

	private class RequestFailurePlan {
		public String method;
		public String endpointMustContain;
		public RequestFailurePlan(String method, String endpointMustContain) {
			this.method = method;
			this.endpointMustContain = endpointMustContain;
		}
	}

	@IsTest
	private static void validateCustomGoogleAuthorizerClass_returnsMessage() {
		String msg = newSut().validateCustomGoogleAuthorizerClass('GoogleRemoteFileServiceTest.TestGoogleAuthorizer');
		System.assert(msg.contains('returned a valid access token'));
	}

	@IsTest
	private static void cloneFileToPreviewableFormat_happyPath() {
		GoogleRemoteFileService.authorizerClassNameOverride = 'GoogleRemoteFileServiceTest.TestGoogleAuthorizer';
		setHappyMock();

		Test.startTest();
		GoogleFileEntity out = newSut().cloneFileToPreviewableFormat('MyFile', 'FILE_ID');
		Test.stopTest();

		System.assertNotEquals(null, out);
	}

	@IsTest
	private static void exportGoogleDocFileAsPdf_happyPath() {
		GoogleRemoteFileService.authorizerClassNameOverride = 'GoogleRemoteFileServiceTest.TestGoogleAuthorizer';
		setHappyMock();

		Test.startTest();
		GoogleFileEntity out = newSut().exportGoogleDocFileAsPdf('DOC_ID');
		Test.stopTest();

		System.assertNotEquals(null, out);
	}

	@IsTest
	private static void exportGoogleDocFileAsPdf_exceptionPath() {
		GoogleRemoteFileService.authorizerClassNameOverride = 'GoogleRemoteFileServiceTest.TestGoogleAuthorizer';
		setFailureMock(new RequestFailurePlan('GET', 'export'));

		Test.startTest();
		try {
			newSut().exportGoogleDocFileAsPdf('DOC_ID');
			System.assert(false);
		} catch (GoogleRemoteFileService.GoogleRemoteFileServiceException ex) {
			System.assert(true);
		}
		Test.stopTest();
	}

	@IsTest
	private static void exportGoogleFileDetails_happyPath() {
		GoogleRemoteFileService.authorizerClassNameOverride = 'GoogleRemoteFileServiceTest.TestGoogleAuthorizer';
		setHappyMock();

		Test.startTest();
		GoogleFileEntity out = newSut().exportGoogleFileDetails('DOC_ID');
		Test.stopTest();

		System.assertNotEquals(null, out);
	}

	@IsTest
	private static void exportGoogleFileDetails_exceptionPath() {
		GoogleRemoteFileService.authorizerClassNameOverride = 'GoogleRemoteFileServiceTest.TestGoogleAuthorizer';
		setFailureMock(new RequestFailurePlan('GET', 'fields='));

		Test.startTest();
		try {
			newSut().exportGoogleFileDetails('DOC_ID');
			System.assert(false);
		} catch (GoogleRemoteFileService.GoogleRemoteFileServiceException ex) {
			System.assert(true);
		}
		Test.stopTest();
	}

	@IsTest
	private static void createFilePublicLink_happyPath() {
		GoogleRemoteFileService.authorizerClassNameOverride = 'GoogleRemoteFileServiceTest.TestGoogleAuthorizer';
		setHappyMock();

		Test.startTest();
		GooglePermissionEntity out = newSut().createFilePublicLink('DOC_ID');
		Test.stopTest();

		System.assertNotEquals(null, out);
	}

	@IsTest
	private static void createFilePublicLink_exceptionPath() {
		GoogleRemoteFileService.authorizerClassNameOverride = 'GoogleRemoteFileServiceTest.TestGoogleAuthorizer';
		setFailureMock(new RequestFailurePlan('POST', 'permissions'));

		Test.startTest();
		try {
			newSut().createFilePublicLink('DOC_ID');
			System.assert(false);
		} catch (GoogleRemoteFileService.GoogleRemoteFileServiceException ex) {
			System.assert(true);
		}
		Test.stopTest();
	}

	@IsTest
	private static void removeFilePublicLink_happyPath() {
		GoogleRemoteFileService.authorizerClassNameOverride = 'GoogleRemoteFileServiceTest.TestGoogleAuthorizer';
		setHappyMock();

		Test.startTest();
		newSut().removeFilePublicLink('DOC_ID', 'PERM_ID');
		Test.stopTest();

		System.assert(true);
	}

	@IsTest
	private static void removeFilePublicLink_exceptionPath() {
		GoogleRemoteFileService.authorizerClassNameOverride = 'GoogleRemoteFileServiceTest.TestGoogleAuthorizer';
		setFailureMock(new RequestFailurePlan('DELETE', 'permissions/'));

		Test.startTest();
		try {
			newSut().removeFilePublicLink('DOC_ID', 'PERM_ID');
			System.assert(false);
		} catch (GoogleRemoteFileService.GoogleRemoteFileServiceException ex) {
			System.assert(true);
		}
		Test.stopTest();
	}

	@IsTest
	private static void deleteFile_happyPath() {
		GoogleRemoteFileService.authorizerClassNameOverride = 'GoogleRemoteFileServiceTest.TestGoogleAuthorizer';
		setHappyMock();

		Test.startTest();
		newSut().deleteFile('FILE_ID');
		Test.stopTest();

		System.assert(true);
	}

	@IsTest
	private static void uploadFile_happyPath() {
		GoogleRemoteFileService.authorizerClassNameOverride = 'GoogleRemoteFileServiceTest.TestGoogleAuthorizer';
		setHappyMock();

		String b64 = EncodingUtil.base64Encode(Blob.valueOf('hello'));

		Test.startTest();
		GoogleFileEntity out = newSut().uploadFile('a.txt', b64);
		Test.stopTest();

		System.assertNotEquals(null, out);
	}

	@IsTest
	private static void uploadFile_exceptionPath() {
		GoogleRemoteFileService.authorizerClassNameOverride = 'GoogleRemoteFileServiceTest.TestGoogleAuthorizer';
		setFailureMock(new RequestFailurePlan('POST', 'uploadtype=multipart'));

		String b64 = EncodingUtil.base64Encode(Blob.valueOf('hello'));

		Test.startTest();
		try {
			newSut().uploadFile('a.txt', b64);
			System.assert(false);
		} catch (GoogleRemoteFileService.GoogleRemoteFileServiceException ex) {
			System.assert(true);
		}
		Test.stopTest();
	}

	@IsTest
	private static void uploadBigFilePartial_happyPath_incompleteAndCompleteChunks() {
		GoogleRemoteFileService.authorizerClassNameOverride = 'GoogleRemoteFileServiceTest.TestGoogleAuthorizer';
		setHappyMock();

		String chunk = EncodingUtil.base64Encode(Blob.valueOf('chunk-1'));

		Test.startTest();
		GoogleBigFileEntity out1 = newSut().uploadBigFilePartial('big.bin', chunk, 'SESSION', 0, 100);
		GoogleBigFileEntity out2 = newSut().uploadBigFilePartial('big.bin', chunk, 'SESSION', 50, 100);
		Test.stopTest();

		System.assertNotEquals(null, out1);
		System.assertNotEquals(null, out2);
	}

	@IsTest
	private static void downloadFile_full_happyPath() {
		GoogleRemoteFileService.authorizerClassNameOverride = 'GoogleRemoteFileServiceTest.TestGoogleAuthorizer';
		setHappyMock();

		Test.startTest();
		GoogleFileEntity out = newSut().downloadFile('FILE_ID');
		Test.stopTest();

		System.assertNotEquals(null, out);
	}

	@IsTest
	private static void downloadFile_full_exceptionPath() {
		GoogleRemoteFileService.authorizerClassNameOverride = 'GoogleRemoteFileServiceTest.TestGoogleAuthorizer';
		setFailureMock(new RequestFailurePlan('GET', 'alt=media'));

		Test.startTest();
		try {
			newSut().downloadFile('FILE_ID');
			System.assert(false);
		} catch (GoogleRemoteFileService.GoogleRemoteFileServiceException ex) {
			System.assert(true);
		}
		Test.stopTest();
	}

	@IsTest
	private static void downloadFile_partial_happyPath() {
		GoogleRemoteFileService.authorizerClassNameOverride = 'GoogleRemoteFileServiceTest.TestGoogleAuthorizer';
		setHappyMock();

		Test.startTest();
		GoogleFileEntity out = newSut().downloadFile('FILE_ID', 0, 10);
		Test.stopTest();

		System.assertNotEquals(null, out);
	}

	@IsTest
	private static void downloadFile_partial_exceptionPath() {
		GoogleRemoteFileService.authorizerClassNameOverride = 'GoogleRemoteFileServiceTest.TestGoogleAuthorizer';
		setFailureMock(new RequestFailurePlan('GET', 'alt=media'));

		Test.startTest();
		try {
			newSut().downloadFile('FILE_ID', 0, 10);
			System.assert(false);
		} catch (GoogleRemoteFileService.GoogleRemoteFileServiceException ex) {
			System.assert(true);
		}
		Test.stopTest();
	}
}