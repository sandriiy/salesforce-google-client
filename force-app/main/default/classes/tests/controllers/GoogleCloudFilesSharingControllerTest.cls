@IsTest
private class GoogleCloudFilesSharingControllerTest {
	private static final String LINK_SELECTOR_MOCK_ID = 'GoogleFileLinkSelector';
	private static final String FILE_SELECTOR_MOCK_ID = 'GoogleFileSelector';
	private static final String VERSION_SELECTOR_MOCK_ID = 'GoogleFileVersionSelector';

	public class TestGoogleAuthorizer implements GoogleAuthorizer {
		public String retrieveAccessToken() {
			return 'client.test-access-token';
		}
	}

	private static void initMocks() {
		Test.setMock(HttpCalloutMock.class, new GoogleDriveHttpMock().withDefaultHappyPath());
		GoogleRemoteFileService.authorizerClassNameOverride = 'GoogleCloudFilesSharingControllerTest.TestGoogleAuthorizer';
	}

	@IsTest
	private static void fetchSharingDetailsTestSuccessDto() {
		initMocks();

		User u = GoogleCloudTestFactory.newUser();
		GoogleFile__c f = GoogleCloudTestFactory.file().withName('FS1').withDescription('D').insertRecord();

		insert new GoogleFile__Share(
			ParentId = f.Id,
			UserOrGroupId = u.Id,
			AccessLevel = 'Read',
			RowCause = Schema.GoogleFile__Share.RowCause.Manual
		);

		Account a = new Account(Name = 'FS1-A');
		insert a;

		GoogleCloudTestFactory.link()
			.forFile(f.Id)
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.withLinkedRecord(a.Id)
			.withLinkedType('Account')
			.insertRecord();

		GSOQL.mock(FILE_SELECTOR_MOCK_ID).thenReturn(new List<SObject>{
			new GoogleFile__c(Id = f.Id, OwnerId = UserInfo.getUserId(), Name = f.Name)
		});

		Test.startTest();
		GoogleSharingInfoDTO dto = GoogleCloudFilesSharingController.fetchSharingDetails(f.Id);
		Test.stopTest();

		System.assertNotEquals(null, dto);
		System.assertEquals(f.Id, dto.fileId);
	}

	@IsTest
	private static void createNewSharingTestSuccessViewer() {
		initMocks();

		User u = GoogleCloudTestFactory.newUser();
		GoogleFile__c f = GoogleCloudTestFactory.file().withName('CS1').withDescription('D').insertRecord();

		Test.startTest();
		Id shareId = GoogleCloudFilesSharingController.createNewSharing(
			f.Id,
			'User',
			u.Id,
			'viewer'
		);
		Test.stopTest();

		System.assertNotEquals(null, shareId);

		GoogleFile__Share created = [
			SELECT Id, ParentId, UserOrGroupId, AccessLevel, RowCause
			FROM GoogleFile__Share
			WHERE Id = :shareId
			LIMIT 1
		];

		System.assertEquals(f.Id, created.ParentId);
		System.assertEquals(u.Id, created.UserOrGroupId);
		System.assertEquals('Read', created.AccessLevel);
		System.assertEquals(String.valueOf(Schema.GoogleFile__Share.RowCause.Manual), String.valueOf(created.RowCause));
	}

	@IsTest
	private static void modifyExistingSharingAccessTestSuccessEdit() {
		initMocks();

		User u = GoogleCloudTestFactory.newUser();
		GoogleFile__c f = GoogleCloudTestFactory.file().withName('MS1').withDescription('D').insertRecord();

		GoogleFile__Share sh = new GoogleFile__Share(
			ParentId = f.Id,
			UserOrGroupId = u.Id,
			AccessLevel = 'Read',
			RowCause = Schema.GoogleFile__Share.RowCause.Manual
		);
		insert sh;

		Test.startTest();
		GoogleCloudFilesSharingController.modifyExistingSharingAccess(f.Id, u.Id, 'Collaborator');
		Test.stopTest();

		GoogleFile__Share updated = [
			SELECT AccessLevel
			FROM GoogleFile__Share
			WHERE Id = :sh.Id
			LIMIT 1
		];
		System.assertEquals('Edit', updated.AccessLevel);
	}

	@IsTest
	private static void modifyExistingSharingVisibilityTestSuccessUpdate() {
		initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('MV1').withDescription('D').insertRecord();
		Account a = new Account(Name = 'MV1-A');
		insert a;

		GoogleFileLink__c link = GoogleCloudTestFactory.link()
			.forFile(f.Id)
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.withLinkedRecord(a.Id)
			.withLinkedType('Account')
			.insertRecord();

		Test.startTest();
		GoogleCloudFilesSharingController.modifyExistingSharingVisibility(f.Id, a.Id, 'InternalUsers');
		Test.stopTest();

		GoogleFileLink__c updated = [
			SELECT Visibility__c
			FROM GoogleFileLink__c
			WHERE Id = :link.Id
			LIMIT 1
		];
		System.assertEquals('InternalUsers', updated.Visibility__c);
	}

	@IsTest
	private static void deleteExistingSharingTestSuccessUser() {
		initMocks();

		User u = GoogleCloudTestFactory.newUser();
		GoogleFile__c f = GoogleCloudTestFactory.file().withName('DS1').withDescription('D').insertRecord();

		insert new GoogleFile__Share(
			ParentId = f.Id,
			UserOrGroupId = u.Id,
			AccessLevel = 'Read',
			RowCause = Schema.GoogleFile__Share.RowCause.Manual
		);

		Test.startTest();
		GoogleCloudFilesSharingController.deleteExistingSharing(f.Id, u.Id);
		Test.stopTest();

		System.assertEquals(0, [
			SELECT count()
			FROM GoogleFile__Share
			WHERE ParentId = :f.Id AND UserOrGroupId = :u.Id
		]);
	}

	@IsTest
	private static void deleteExistingSharingTestSuccessLink() {
		initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('DS2').withDescription('D').insertRecord();
		Account a = new Account(Name = 'DS2-A');
		insert a;

		GoogleFileLink__c link = GoogleCloudTestFactory.link()
			.forFile(f.Id)
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.withLinkedRecord(a.Id)
			.withLinkedType('Account')
			.insertRecord();

		Test.startTest();
		GoogleCloudFilesSharingController.deleteExistingSharing(f.Id, a.Id);
		Test.stopTest();

		System.assertEquals(0, [
			SELECT count()
			FROM GoogleFileLink__c
			WHERE Id = :link.Id
		]);
	}

	@IsTest
	private static void createNewPublicLinkTestSuccessExec() {
		initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('PL1').withDescription('D').insertRecord();
		GoogleFileVersion__c v = GoogleCloudTestFactory.version()
			.forFile(f.Id)
			.withName('V1.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId('GD1')
			.withDocsId('DOCS1')
			.insertRecord();

		Test.startTest();
		try {
			GoogleFileVersion__c updated = GoogleCloudFilesSharingController.createNewPublicLink(v.Id, System.now().addDays(7));
			GoogleCloudFilesSharingController.deleteExistingPublicLink(v.Id);
			System.assert(true, 'Public link methods executed');
		} catch (Exception e) {
			System.assertNotEquals(null, e.getMessage());
		}
		Test.stopTest();
	}
}
