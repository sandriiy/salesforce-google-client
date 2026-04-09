@IsTest
private class GoogleLocalFileSharingServiceTest {
	public class TestGoogleAuthorizer implements GoogleAuthorizer {
		public String retrieveAccessToken() {
			return 'client.test-access-token';
		}
	}

	private static void initMocks() {
		Test.setMock(HttpCalloutMock.class, new GoogleDriveHttpMock().withDefaultHappyPath());
		GoogleClientApiProvider.authorizerClassNameOverride = 'GoogleLocalFileSharingServiceTest.TestGoogleAuthorizer';
	}


	@IsTest
	private static void fetchSharingDetailsTestSuccessEmpty() {
		initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file()
			.withName('RS_Empty')
			.withDescription('D')
			.insertRecord();

		GoogleLocalFileSharingService service = new GoogleLocalFileSharingService();
		GoogleSharingInfoDTO dto = service.fetchSharingDetails(f.Id);

		System.assertNotEquals(null, dto);
		System.assertEquals(f.Id, dto.fileId);
		System.assertNotEquals(null, dto.owner);
		System.assertEquals(UserInfo.getUserId(), dto.owner.Id);
		System.assertNotEquals(null, dto.entitiesSharedTo);
		System.assertEquals(0, dto.entitiesSharedTo.size());
		System.assertNotEquals(null, dto.recordsSharedTo);
		System.assertEquals(0, dto.recordsSharedTo.size());
	}

	@IsTest
	private static void fetchSharingDetailsTestSuccessIncludeAll() {
		initMocks();

		User u = GoogleCloudTestFactory.newUser();
		GoogleFile__c f = GoogleCloudTestFactory.file().withName('RS2').withDescription('D').insertRecord();

		GoogleFile__Share sh = new GoogleFile__Share(
			ParentId = f.Id,
			UserOrGroupId = u.Id,
			AccessLevel = 'Read',
			RowCause = Schema.GoogleFile__Share.RowCause.Manual
		);
		insert sh;

		Account a = new Account(Name = 'RS2-A');
		insert a;

		GoogleCloudTestFactory.link()
			.forFile(f.Id)
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.withLinkedRecord(a.Id)
			.withLinkedType('Account')
			.insertRecord();

		GoogleLocalFileSharingService service = new GoogleLocalFileSharingService();
		GoogleSharingInfoDTO dto = service.fetchSharingDetails(f.Id);

		System.assertNotEquals(null, dto);
		System.assertEquals(f.Id, dto.fileId);

		System.assertNotEquals(null, dto.owner);
		System.assertEquals(UserInfo.getUserId(), dto.owner.Id);

		System.assertNotEquals(null, dto.entitiesSharedTo);
		System.assertEquals(1, dto.entitiesSharedTo.size());
		System.assertEquals(u.Id, dto.entitiesSharedTo[0].UserOrGroupId);

		System.assertNotEquals(null, dto.recordsSharedTo);
		System.assertEquals(1, dto.recordsSharedTo.size());
		System.assertEquals(String.valueOf(a.Id), dto.recordsSharedTo[0].LinkedObjectId__c);
	}

	@IsTest
	private static void createSharingTestSuccessViewer() {
		initMocks();

		User u = GoogleCloudTestFactory.newUser();
		GoogleFile__c f = GoogleCloudTestFactory.file().withName('CS1').withDescription('D').insertRecord();

		Test.startTest();
		Id shareId = new GoogleLocalFileSharingService()
			.createNewSharing(f.Id, 'User', u.Id, 'viewer');
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
		System.assertEquals(
			String.valueOf(Schema.GoogleFile__Share.RowCause.Manual),
			String.valueOf(created.RowCause)
		);
	}

	@IsTest
	private static void createSharingTestSuccessCollaborator() {
		initMocks();

		User u = GoogleCloudTestFactory.newUser();
		GoogleFile__c f = GoogleCloudTestFactory.file().withName('CS2').withDescription('D').insertRecord();

		Test.startTest();
		Id shareId = new GoogleLocalFileSharingService()
			.createNewSharing(f.Id, 'User', u.Id, 'Collaborator');
		Test.stopTest();

		System.assertNotEquals(null, shareId);

		GoogleFile__Share created = [
			SELECT Id, AccessLevel
			FROM GoogleFile__Share
			WHERE Id = :shareId
			LIMIT 1
		];
		System.assertEquals('Edit', created.AccessLevel);
	}

	@IsTest
	private static void createSharingTestFailNullFileId() {
		initMocks();

		User u = GoogleCloudTestFactory.newUser();

		try {
			new GoogleLocalFileSharingService()
				.createNewSharing(null, 'User', u.Id, 'viewer');
			System.assert(false);
		} catch (GoogleLocalFileSharingService.GoogleLocalFileSharingException ex) {
			System.assertEquals(true, ex.getMessage().contains('Unable to share'));
		}
	}

	@IsTest
	private static void createSharingTestFailNullShareTo() {
		initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('CS3').withDescription('D').insertRecord();

		try {
			new GoogleLocalFileSharingService()
				.createNewSharing(f.Id, 'User', null, 'viewer');
			System.assert(false);
		} catch (GoogleLocalFileSharingService.GoogleLocalFileSharingException ex) {
			System.assertEquals(true, ex.getMessage().contains('Unable to share'));
		}
	}

	@IsTest
	private static void createSharingTestFailBlankAccess() {
		initMocks();

		User u = GoogleCloudTestFactory.newUser();
		GoogleFile__c f = GoogleCloudTestFactory.file().withName('CS4').withDescription('D').insertRecord();

		try {
			new GoogleLocalFileSharingService()
				.createNewSharing(f.Id, 'User', u.Id, '   ');
			System.assert(false);
		} catch (GoogleLocalFileSharingService.GoogleLocalFileSharingException ex) {
			System.assertEquals(true, ex.getMessage().contains('Unable to share'));
		}
	}

	@IsTest
	private static void createSharingTestFailBadAccess() {
		initMocks();

		User u = GoogleCloudTestFactory.newUser();
		GoogleFile__c f = GoogleCloudTestFactory.file().withName('CS5').withDescription('D').insertRecord();

		try {
			new GoogleLocalFileSharingService()
				.createNewSharing(f.Id, 'User', u.Id, 'admin');
			System.assert(false);
		} catch (GoogleLocalFileSharingService.GoogleLocalFileSharingException ex) {
			System.assertEquals(true, ex.getMessage().contains('Unable to share'));
		}
	}

	@IsTest
	private static void deleteSharingTestSuccessUser() {
		initMocks();

		User u = GoogleCloudTestFactory.newUser();
		GoogleFile__c f = GoogleCloudTestFactory.file().withName('DS1').withDescription('D').insertRecord();

		GoogleFile__Share sh = new GoogleFile__Share(
			ParentId = f.Id,
			UserOrGroupId = u.Id,
			AccessLevel = 'Read',
			RowCause = Schema.GoogleFile__Share.RowCause.Manual
		);
		insert sh;

		Test.startTest();
		new GoogleLocalFileSharingService()
			.deleteExistingSharing(f.Id, u.Id);
		Test.stopTest();

		System.assertEquals(0, [
			SELECT count()
			FROM GoogleFile__Share
			WHERE ParentId = :f.Id AND UserOrGroupId = :u.Id
		]);
	}

	@IsTest
	private static void deleteSharingTestFailUserShareMissing() {
		initMocks();

		User u = GoogleCloudTestFactory.newUser();
		GoogleFile__c f = GoogleCloudTestFactory.file().withName('DS2').withDescription('D').insertRecord();

		try {
			new GoogleLocalFileSharingService()
				.deleteExistingSharing(f.Id, u.Id);
			System.assert(false);
		} catch (GoogleLocalFileSharingService.GoogleLocalFileSharingException ex) {
			System.assertEquals(true, ex.getMessage().contains('Unable to remove sharing'));
		}
	}

	@IsTest
	private static void deleteSharingTestSuccessLink() {
		initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('DS3').withDescription('D').insertRecord();
		Account a = new Account(Name = 'DS3-A');
		insert a;

		GoogleFileLink__c link = GoogleCloudTestFactory.link()
			.forFile(f.Id)
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.withLinkedRecord(a.Id)
			.withLinkedType('Account')
			.insertRecord();

		Test.startTest();
		new GoogleLocalFileSharingService()
			.deleteExistingSharing(f.Id, a.Id);
		Test.stopTest();

		System.assertEquals(0, [
			SELECT count()
			FROM GoogleFileLink__c
			WHERE Id = :link.Id
		]);
	}

	@IsTest
	private static void deleteSharingTestFailLinkMissing() {
		initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('DS4').withDescription('D').insertRecord();
		Account a = new Account(Name = 'DS4-A');
		insert a;

		try {
			new GoogleLocalFileSharingService()
				.deleteExistingSharing(f.Id, a.Id);
			System.assert(false);
		} catch (GoogleLocalFileSharingService.GoogleLocalFileSharingException ex) {
			System.assertEquals(true, ex.getMessage().contains('Unable to remove sharing'));
		}
	}

	@IsTest
	private static void modifySharingTestSuccessUser() {
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
		new GoogleLocalFileSharingService()
			.modifyExistingSharingAccess(f.Id, u.Id, 'Collaborator');
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
	private static void modifySharingTestFailMissingAccess() {
		initMocks();

		User u = GoogleCloudTestFactory.newUser();
		GoogleFile__c f = GoogleCloudTestFactory.file().withName('MS2').withDescription('D').insertRecord();

		GoogleFile__Share sh = new GoogleFile__Share(
			ParentId = f.Id,
			UserOrGroupId = u.Id,
			AccessLevel = 'Read',
			RowCause = Schema.GoogleFile__Share.RowCause.Manual
		);
		insert sh;

		try {
			new GoogleLocalFileSharingService()
				.modifyExistingSharingAccess(f.Id, u.Id, null);
			System.assert(false);
		} catch (GoogleLocalFileSharingService.GoogleLocalFileSharingException ex) {
			System.assertEquals(true, ex.getMessage().contains('Unable to update sharing'));
		}
	}

	@IsTest
	private static void modifySharingTestFailUserShareMissing() {
		initMocks();

		User u = GoogleCloudTestFactory.newUser();
		GoogleFile__c f = GoogleCloudTestFactory.file().withName('MS3').withDescription('D').insertRecord();

		try {
			new GoogleLocalFileSharingService()
				.modifyExistingSharingAccess(f.Id, u.Id, 'viewer');
			System.assert(false);
		} catch (GoogleLocalFileSharingService.GoogleLocalFileSharingException ex) {
			System.assertEquals(true, ex.getMessage().contains('Unable to update sharing'));
		}
	}

	@IsTest
	private static void modifySharingTestSuccessLink() {
		initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('ML1').withDescription('D').insertRecord();
		Account a = new Account(Name = 'ML1-A');
		insert a;

		GoogleFileLink__c link = GoogleCloudTestFactory.link()
			.forFile(f.Id)
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.withLinkedRecord(a.Id)
			.withLinkedType('Account')
			.insertRecord();

		Test.startTest();
		GoogleLocalFileSharingService service = new GoogleLocalFileSharingService();
		service.modifyExistingSharingAccess(f.Id, a.Id, 'Collaborator');
		service.modifyExistingSharingVisibility(f.Id, a.Id, 'InternalUsers');
		Test.stopTest();

		GoogleFileLink__c updated = [
			SELECT ShareType__c, Visibility__c
			FROM GoogleFileLink__c
			WHERE Id = :link.Id
			LIMIT 1
		];
		System.assertEquals('Collaborator', updated.ShareType__c);
		System.assertEquals('InternalUsers', updated.Visibility__c);
	}

	@IsTest
	private static void modifySharingTestFailNoInput() {
		initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('ML2').withDescription('D').insertRecord();
		Account a = new Account(Name = 'ML2-A');
		insert a;

		GoogleCloudTestFactory.link()
			.forFile(f.Id)
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.withLinkedRecord(a.Id)
			.withLinkedType('Account')
			.insertRecord();

		try {
			GoogleLocalFileSharingService service = new GoogleLocalFileSharingService();
			service.modifyExistingSharingAccess(f.Id, a.Id, ' ');
			service.modifyExistingSharingVisibility(f.Id, a.Id, null);
			System.assert(false);
		} catch (GoogleLocalFileSharingService.GoogleLocalFileSharingException ex) {
			System.assertEquals(true, ex.getMessage().contains('Unable to update sharing'));
		}
	}

	@IsTest
	private static void modifySharingTestFailLinkMissing() {
		initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('ML3').withDescription('D').insertRecord();
		Account a = new Account(Name = 'ML3-A');
		insert a;

		try {
			new GoogleLocalFileSharingService()
				.modifyExistingSharingAccess(f.Id, a.Id, 'Viewer');
			System.assert(false);
		} catch (GoogleLocalFileSharingService.GoogleLocalFileSharingException ex) {
			System.assertEquals(true, ex.getMessage().contains('Unable to update sharing'));
		}
	}

	@IsTest
	private static void modifySharingTestFailBadShareType() {
		initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('ML4').withDescription('D').insertRecord();
		Account a = new Account(Name = 'ML4-A');
		insert a;

		GoogleCloudTestFactory.link()
			.forFile(f.Id)
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.withLinkedRecord(a.Id)
			.withLinkedType('Account')
			.insertRecord();

		try {
			new GoogleLocalFileSharingService()
				.modifyExistingSharingAccess(f.Id, a.Id, 'NotARealType');
			System.assert(false);
		} catch (GoogleLocalFileSharingService.GoogleLocalFileSharingException ex) {
			System.assertEquals(true, ex.getMessage().contains('Unable to update sharing'));
		}
	}

	@IsTest
	private static void modifySharingTestFailBadVisibility() {
		initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('ML5').withDescription('D').insertRecord();
		Account a = new Account(Name = 'ML5-A');
		insert a;

		GoogleCloudTestFactory.link()
			.forFile(f.Id)
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.withLinkedRecord(a.Id)
			.withLinkedType('Account')
			.insertRecord();

		try {
			new GoogleLocalFileSharingService()
				.modifyExistingSharingVisibility(f.Id, a.Id, 'Public');
			System.assert(false);
		} catch (GoogleLocalFileSharingService.GoogleLocalFileSharingException ex) {
			System.assertEquals(true, ex.getMessage().contains('Unable to update sharing'));
		}
	}
}