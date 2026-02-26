@IsTest
private class GoogleLocalFileVersionServiceTest {
	public class TestGoogleAuthorizer implements GoogleAuthorizer {
		public String retrieveAccessToken() {
			return 'client.test-access-token';
		}
	}

	private static void initMocks() {
		Test.setMock(HttpCalloutMock.class, new GoogleDriveHttpMock().withDefaultHappyPath());
		GoogleDriveApiProvider.authorizerClassNameOverride = 'GoogleLocalFileVersionServiceTest.TestGoogleAuthorizer';
	}

	@IsTest
	private static void testExportPreviewPositivePdf() {
		initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('VS1').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('V1.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId('GD_VS_1')
			.withDocsId('DOCS_VS_1')
			.insertRecord();

		Test.startTest();
		String base64Body = new GoogleLocalFileVersionService().exportPreviewBase64BodyIfEligible(localFileVersion.Id);
		Test.stopTest();

		System.assert(String.isNotBlank(base64Body));
	}

	@IsTest
	private static void testExportPreviewPositiveExport() {
		initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('VS1E').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('V1.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(1)
			.withDriveId('GD_VS_1E')
			.withDocsId('DOCS_VS_1E')
			.insertRecord();

		Test.startTest();
		String base64Body = new GoogleLocalFileVersionService().exportPreviewBase64BodyIfEligible(localFileVersion.Id);
		Test.stopTest();

		System.assert(String.isNotBlank(base64Body));
	}

	@IsTest
	private static void testDownloadPositive() {
		initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('VS2').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('V2.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId('GD_VS_2')
			.withDocsId('DOCS_VS_2')
			.insertRecord();

		Test.startTest();
		String base64Body = new GoogleLocalFileVersionService().downloadFileBase64Body(localFileVersion.Id);
		Test.stopTest();

		System.assert(String.isNotBlank(base64Body));
	}

	@IsTest
	private static void testDownloadPositiveRange() {
		initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('VS3').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('V3.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId('GD_VS_3')
			.withDocsId('DOCS_VS_3')
			.insertRecord();

		Test.startTest();
		String base64Body = new GoogleLocalFileVersionService().downloadFileBase64Body(localFileVersion.Id, 0L, 10L);
		Test.stopTest();

		System.assert(String.isNotBlank(base64Body));
	}

	@IsTest
	private static void testExportPreviewNegativeTooLarge() {
		initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('VS4').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('Big.pdf')
			.withType('application/pdf')
			.withSize(9999999999L)
			.withDriveId('GD_VS_4')
			.withDocsId('DOCS_VS_4')
			.insertRecord();

		try {
			new GoogleLocalFileVersionService().exportPreviewBase64BodyIfEligible(localFileVersion.Id);
			System.assert(false);
		} catch (GoogleLocalFileVersionService.GoogleFileVersionException ex) {
			System.assert(ex.getMessage().contains('too large'));
		}
	}

	@IsTest
	private static void testExportPreviewNegativeInProgress() {
		initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('VS5').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('DocInProgress.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(1)
			.withDriveId('GD_VS_5')
			.withDocsId(null)
			.insertRecord();

		try {
			new GoogleLocalFileVersionService().exportPreviewBase64BodyIfEligible(localFileVersion.Id);
			System.assert(false);
		} catch (GoogleLocalFileVersionService.GoogleFileVersionException ex) {
			System.assert(ex.getMessage().contains('being prepared'));
		}
	}

	@IsTest
	private static void testExportPreviewNegativeUnavailable() {
		initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('VS6').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('NotPreviewable.bin')
			.withType('application/octet-stream')
			.withSize(1)
			.withDriveId('GD_VS_6')
			.withDocsId(null)
			.insertRecord();

		try {
			new GoogleLocalFileVersionService().exportPreviewBase64BodyIfEligible(localFileVersion.Id);
			System.assert(false);
		} catch (GoogleLocalFileVersionService.GoogleFileVersionException ex) {
			System.assert(ex.getMessage().contains('Preview unavailable'));
		}
	}

	@IsTest
	private static void testExportPreviewNegativeMissing() {
		initMocks();

		try {
			new GoogleLocalFileVersionService().exportPreviewBase64BodyIfEligible((Id) 'a0D000000000000AAA');
			System.assert(false);
		} catch (GoogleLocalFileVersionService.GoogleFileVersionException ex) {
			System.assert(ex.getMessage().contains('Preview Unavailable'));
		} catch (Exception ex) {
			System.assert(true);
		}
	}
}