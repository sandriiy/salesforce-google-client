@IsTest
private class GoogleCloudFilesSharingControllerTest {
	public class TestGoogleAuthorizer implements GoogleAuthorizer {
		public String retrieveAccessToken() {
			return 'client.test-access-token';
		}
	}

	private static void initMocks() {
		Test.setMock(HttpCalloutMock.class, new GoogleDriveHttpMock().withDefaultHappyPath());
		GoogleDriveApiProvider.authorizerClassNameOverride = 'GoogleCloudFilesSharingControllerTest.TestGoogleAuthorizer';
	}

	@IsTest
	private static void testFetchSharingDetailsPositive() {
		initMocks();

		User sharedUser = GoogleCloudTestFactory.newUser();
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('FS1').withDescription('D').insertRecord();

		insert new GoogleFile__Share(
			ParentId = localFile.Id,
			UserOrGroupId = sharedUser.Id,
			AccessLevel = 'Read',
			RowCause = Schema.GoogleFile__Share.RowCause.Manual
		);

		Account linkedAccount = new Account(Name = 'FS1-A');
		insert linkedAccount;

		GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.withLinkedRecord(linkedAccount.Id)
			.withLinkedType('Account')
			.insertRecord();

		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(new List<SObject>{
			new GoogleFile__c(Id = localFile.Id, OwnerId = UserInfo.getUserId(), Name = localFile.Name)
		});

		Test.startTest();
		GoogleSharingInfoDTO sharingInfo = GoogleCloudFilesSharingController.fetchSharingDetails(localFile.Id);
		Test.stopTest();

		System.assertNotEquals(null, sharingInfo);
		System.assertEquals(localFile.Id, sharingInfo.fileId);
	}

	@IsTest
	private static void testCreateNewSharingPositiveViewer() {
		initMocks();

		User targetUser = GoogleCloudTestFactory.newUser();
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('CS1').withDescription('D').insertRecord();

		Test.startTest();
		Id createdShareId = GoogleCloudFilesSharingController.createNewSharing(
			localFile.Id,
			'User',
			targetUser.Id,
			'viewer'
		);
		Test.stopTest();

		System.assertNotEquals(null, createdShareId);

		GoogleFile__Share createdShare = [
			SELECT Id, ParentId, UserOrGroupId, AccessLevel, RowCause
			FROM GoogleFile__Share
			WHERE Id = :createdShareId
			LIMIT 1
		];

		System.assertEquals(localFile.Id, createdShare.ParentId);
		System.assertEquals(targetUser.Id, createdShare.UserOrGroupId);
		System.assertEquals('Read', createdShare.AccessLevel);
		System.assertEquals(String.valueOf(Schema.GoogleFile__Share.RowCause.Manual), String.valueOf(createdShare.RowCause));
	}

	@IsTest
	private static void testModifyExistingSharingAccessPositive() {
		initMocks();

		User targetUser = GoogleCloudTestFactory.newUser();
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('MS1').withDescription('D').insertRecord();

		GoogleFile__Share existingShare = new GoogleFile__Share(
			ParentId = localFile.Id,
			UserOrGroupId = targetUser.Id,
			AccessLevel = 'Read',
			RowCause = Schema.GoogleFile__Share.RowCause.Manual
		);
		insert existingShare;

		Test.startTest();
		GoogleCloudFilesSharingController.modifyExistingSharingAccess(localFile.Id, targetUser.Id, 'Collaborator');
		Test.stopTest();

		GoogleFile__Share updatedShare = [
			SELECT AccessLevel
			FROM GoogleFile__Share
			WHERE Id = :existingShare.Id
			LIMIT 1
		];
		System.assertEquals('Edit', updatedShare.AccessLevel);
	}

	@IsTest
	private static void testModifyExistingSharingVisibilityPositive() {
		initMocks();

		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('MV1').withDescription('D').insertRecord();
		Account linkedAccount = new Account(Name = 'MV1-A');
		insert linkedAccount;

		GoogleFileLink__c fileLink = GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.withLinkedRecord(linkedAccount.Id)
			.withLinkedType('Account')
			.insertRecord();

		Test.startTest();
		GoogleCloudFilesSharingController.modifyExistingSharingVisibility(localFile.Id, linkedAccount.Id, 'InternalUsers');
		Test.stopTest();

		GoogleFileLink__c updatedLink = [
			SELECT Visibility__c
			FROM GoogleFileLink__c
			WHERE Id = :fileLink.Id
			LIMIT 1
		];
		System.assertEquals('InternalUsers', updatedLink.Visibility__c);
	}

	@IsTest
	private static void testDeleteExistingSharingPositiveUser() {
		initMocks();

		User targetUser = GoogleCloudTestFactory.newUser();
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('DS1').withDescription('D').insertRecord();

		insert new GoogleFile__Share(
			ParentId = localFile.Id,
			UserOrGroupId = targetUser.Id,
			AccessLevel = 'Read',
			RowCause = Schema.GoogleFile__Share.RowCause.Manual
		);

		Test.startTest();
		GoogleCloudFilesSharingController.deleteExistingSharing(localFile.Id, targetUser.Id);
		Test.stopTest();

		System.assertEquals(0, [
			SELECT count()
			FROM GoogleFile__Share
			WHERE ParentId = :localFile.Id AND UserOrGroupId = :targetUser.Id
		]);
	}

	@IsTest
	private static void testDeleteExistingSharingPositiveLink() {
		initMocks();

		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('DS2').withDescription('D').insertRecord();
		Account linkedAccount = new Account(Name = 'DS2-A');
		insert linkedAccount;

		GoogleFileLink__c fileLink = GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.withLinkedRecord(linkedAccount.Id)
			.withLinkedType('Account')
			.insertRecord();

		Test.startTest();
		GoogleCloudFilesSharingController.deleteExistingSharing(localFile.Id, linkedAccount.Id);
		Test.stopTest();

		System.assertEquals(0, [
			SELECT count()
			FROM GoogleFileLink__c
			WHERE Id = :fileLink.Id
		]);
	}

	@IsTest
	private static void testCreateDeletePublicLinkPositive() {
		initMocks();

		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('PL1').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(localFile.Id)
			.withName('V1.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId('GD1')
			.withDocsId('DOCS1')
			.insertRecord();

		Test.startTest();
		GoogleFileVersion__c updatedVersion = GoogleCloudFilesSharingController.createNewPublicLink(
			localFileVersion.Id,
			System.now().addDays(7),
			false
		);
		GoogleCloudFilesSharingController.deleteExistingPublicLink(localFileVersion.Id);
		Test.stopTest();

		System.assertNotEquals(null, updatedVersion);
	}

	@IsTest
	private static void testIsPublicLinkDomainPositive() {
		Test.startTest();
		Boolean isDomainConfigured = GoogleCloudFilesSharingController.isPublicLinkDomain();
		Test.stopTest();

		System.assertNotEquals(null, isDomainConfigured);
	}
}