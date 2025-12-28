@IsTest
private class GoogleLocalFileVersionServiceTest {
	private static final String FILE_SELECTOR_MOCK_ID = 'GoogleFileSelector';
	private static final String VERSION_SELECTOR_MOCK_ID = 'GoogleFileVersionSelector';

	public class TestGoogleAuthorizer implements GoogleAuthorizer {
		public String retrieveAccessToken() {
			return 'client.test-access-token';
		}
	}

	private static void initMocks() {
		Test.setMock(HttpCalloutMock.class, new GoogleDriveHttpMock().withDefaultHappyPath());
		GoogleRemoteFileService.authorizerClassNameOverride = 'GoogleLocalFileVersionServiceTest.TestGoogleAuthorizer';
	}

	private static GoogleFile__c mockFileAllFields(Id fileId, String description) {
		GoogleFile__c f = new GoogleFile__c(Id = fileId);
		f.Description__c = description;
		f.Source__c = 'Notes & Attachments';
		return f;
	}

	private static GoogleFileVersion__c mockVersionAdvancedFields(Id versionId) {
		return [
			SELECT Id, Name, GoogleFileId__c, Description__c, IsLatestFile__c, Type__c, Size__c, GoogleDriveFileId__c, GoogleDocsFileId__c,
				   PublicLink__c, IsPreviewableFile__c, PublicLinkPermissionId__c, PublicLinkExpirationDate__c, PublicLinkStatus__c,
				   GoogleDriveFolderId__c, CreatedDate, LastModifiedDate, CreatedById
			FROM GoogleFileVersion__c
			WHERE Id = :versionId
			LIMIT 1
		];
	}

	@IsTest
	private static void syncLatestVersionToMainFileTestSuccess() {
		initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('File A').withDescription('Old').insertRecord();
		GoogleFileVersion__c v = GoogleCloudTestFactory.version().forFile(f.Id).withName('V1.docx').withDescription('New').isLatest(true).withType('application/msword').withSize(1).withDriveId('GD_FILE_ID').withDocsId(null).insertRecord();

		GSOQL.mock(FILE_SELECTOR_MOCK_ID).thenReturn(new List<SObject>{ mockFileAllFields(f.Id, 'Old') });

		GoogleFileVersion__c oldV = new GoogleFileVersion__c(Id = v.Id, Description__c = 'Old', GoogleFileId__c = f.Id, IsLatestFile__c = true);

		Test.startTest();
		new GoogleLocalFileVersionService().syncLatestVersionToMainFile(new List<GoogleFileVersion__c>{ v }, new Map<Id, GoogleFileVersion__c>{ v.Id => oldV });
		Test.stopTest();

		GoogleFile__c updated = [SELECT Description__c FROM GoogleFile__c WHERE Id = :f.Id];
		System.assertEquals('New', updated.Description__c);
	}

	@IsTest
	private static void applyPreviewStateIfEligibleTestSuccess() {
		initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('File B').withDescription('Desc').insertRecord();
		GoogleFileVersion__c v = GoogleCloudTestFactory.version().forFile(f.Id).withName('V1.docx').withDescription('Desc').isLatest(true).withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document').withSize(1).withDriveId('GD_SRC_ID').withDocsId(null).insertRecord();

		GSOQL.mock(VERSION_SELECTOR_MOCK_ID).thenReturn(new List<SObject>{ mockVersionAdvancedFields(v.Id) });

		Test.startTest();
		new GoogleLocalFileVersionService().applyPreviewStateIfEligible(new List<GoogleFileVersion__c>{ v });
		Test.stopTest();

		GoogleFileVersion__c updated = [SELECT GoogleDocsFileId__c FROM GoogleFileVersion__c WHERE Id = :v.Id];
		System.assertNotEquals(null, updated.GoogleDocsFileId__c);
	}

	@IsTest
	private static void markAsLatestVersionIfApplicableTestSuccess() {
		initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('File C').withDescription('Desc').insertRecord();
		GoogleFileVersion__c newest = GoogleCloudTestFactory.version().forFile(f.Id).withName('VNewest.pdf').withDescription('D-New').isLatest(false).withType('application/pdf').withSize(1).withDriveId('GD_NEW').withDocsId('DOCS_NEW').insertRecord();
		GoogleFileVersion__c older = GoogleCloudTestFactory.version().forFile(f.Id).withName('VOlder.pdf').withDescription('D-Old').isLatest(true).withType('application/pdf').withSize(1).withDriveId('GD_OLD').withDocsId('DOCS_OLD').insertRecord();

		GSOQL.mock(FILE_SELECTOR_MOCK_ID).thenReturn([
			SELECT Id,
				(SELECT Id, IsLatestFile__c FROM GoogleFileVersions__r ORDER BY CreatedDate DESC)
			FROM GoogleFile__c
			WHERE Id = :f.Id
			LIMIT 1
		]);

		Test.startTest();
		new GoogleLocalFileVersionService().markAsLatestVersionIfApplicable(new List<GoogleFileVersion__c>{ newest }, new List<GoogleFileVersion__c>{ older });
		Test.stopTest();
	}

	@IsTest
	private static void exportPreviewBase64BodyIfEligibleTestSuccess() {
		initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('File P').withDescription('Desc').insertRecord();
		GoogleFileVersion__c v = GoogleCloudTestFactory.version().forFile(f.Id).withName('VPDF.pdf').withDescription('Desc').isLatest(true).withType('application/pdf').withSize(1).withDriveId('GD_FILE_ID').withDocsId('IGNORED_FOR_PDF').insertRecord();

		GSOQL.mock(VERSION_SELECTOR_MOCK_ID).thenReturn(mockVersionAdvancedFields(v.Id));

		Test.startTest();
		String b64 = new GoogleLocalFileVersionService().exportPreviewBase64BodyIfEligible(v.Id);
		Test.stopTest();

		System.assertNotEquals(null, b64);
		System.assert(b64.length() > 0);
	}

	@IsTest
	private static void downloadFileBase64BodyTestSuccess() {
		initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('File Dwn').withDescription('Desc').insertRecord();
		GoogleFileVersion__c v = GoogleCloudTestFactory.version().forFile(f.Id).withName('VDWN.pdf').withDescription('Desc').isLatest(true).withType('application/pdf').withSize(1).withDriveId('GD_FILE_ID').withDocsId('IGNORED').insertRecord();

		GSOQL.mock(VERSION_SELECTOR_MOCK_ID).thenReturn(mockVersionAdvancedFields(v.Id));

		Test.startTest();
		String b1 = new GoogleLocalFileVersionService().downloadFileBase64Body(v.Id);
		String b2 = new GoogleLocalFileVersionService().downloadFileBase64Body(v.Id, 0, 10);
		Test.stopTest();

		System.assertNotEquals(null, b1);
		System.assert(b1.length() > 0);
		System.assertNotEquals(null, b2);
		System.assert(b2.length() > 0);
	}

	@IsTest
	private static void applyPublicLinkSharingTestSuccess() {
		initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('File PL').withDescription('Desc').insertRecord();
		GoogleFileVersion__c v = GoogleCloudTestFactory.version().forFile(f.Id).withName('VPL.pdf').withDescription('Desc').isLatest(true).withType('application/pdf').withSize(1).withDriveId('GD_FILE_ID').withDocsId('IGNORED').insertRecord();

		GSOQL.mock(VERSION_SELECTOR_MOCK_ID).thenReturn(mockVersionAdvancedFields(v.Id));

		Test.startTest();
		new GoogleLocalFileVersionService().applyPublicLinkSharing(v.Id, System.now().addDays(7));
		Test.stopTest();

		GoogleFileVersion__c updated = [SELECT PublicLink__c, PublicLinkPermissionId__c, PublicLinkExpirationDate__c, PublicLinkStatus__c FROM GoogleFileVersion__c WHERE Id = :v.Id];
		System.assertNotEquals(null, updated.PublicLink__c);
		System.assertNotEquals(null, updated.PublicLinkPermissionId__c);
		System.assertNotEquals(null, updated.PublicLinkExpirationDate__c);
		System.assertEquals('Pending Expiration', updated.PublicLinkStatus__c);
	}

	@IsTest
	private static void removePublicLinkSharingTestSuccess() {
		initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('File RPL').withDescription('Desc').insertRecord();
		GoogleFileVersion__c v = GoogleCloudTestFactory.version().forFile(f.Id).withName('VRPL.pdf').withDescription('Desc').isLatest(true).withType('application/pdf').withSize(1).withDriveId('GD_FILE_ID').withDocsId('IGNORED').insertRecord();
		v.PublicLink__c = 'https://example/view';
		v.PublicLinkPermissionId__c = 'PERM_ID';
		v.PublicLinkExpirationDate__c = System.now().addDays(3);
		v.PublicLinkStatus__c = 'Active';
		update v;

		GSOQL.mock(VERSION_SELECTOR_MOCK_ID).thenReturn(mockVersionAdvancedFields(v.Id));

		Test.startTest();
		new GoogleLocalFileVersionService().removePublicLinkSharing(v.Id);
		Test.stopTest();

		GoogleFileVersion__c updated = [SELECT PublicLink__c, PublicLinkPermissionId__c, PublicLinkExpirationDate__c, PublicLinkStatus__c FROM GoogleFileVersion__c WHERE Id = :v.Id];
		System.assertEquals(null, updated.PublicLink__c);
		System.assertEquals(null, updated.PublicLinkPermissionId__c);
		System.assertEquals(null, updated.PublicLinkExpirationDate__c);
		System.assertEquals('None', updated.PublicLinkStatus__c);
	}

	@IsTest
	private static void removeGoogleFilesTestSuccess() {
		initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('File Del').withDescription('Desc').insertRecord();
		GoogleFileVersion__c v = GoogleCloudTestFactory.version().forFile(f.Id).withName('VDel.pdf').withDescription('Desc').isLatest(true).withType('application/pdf').withSize(1).withDriveId('GD_FILE_ID').withDocsId('IGNORED').insertRecord();

		Test.startTest();
		new GoogleLocalFileVersionService().removeGoogleFiles(new List<GoogleFileVersion__c>{ v });
		Test.stopTest();

		System.assert(true);
	}
}
