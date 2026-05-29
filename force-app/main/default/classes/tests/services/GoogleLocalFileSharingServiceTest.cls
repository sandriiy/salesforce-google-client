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
private class GoogleLocalFileSharingServiceTest {
	@IsTest
	private static void testFetchSharingDetailsPositiveEmpty() {
		GoogleCloudTestFactory.initMocks();

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
	private static void testFetchSharingDetailsPositiveIncludeAll() {
		GoogleCloudTestFactory.initMocks();

		User u = GoogleCloudTestFactory.newUser();
		Account linkedAccount = new Account(Name = 'Visible Linked Account');
		insert linkedAccount;
		GoogleFile__c f = GoogleCloudTestFactory.file().withName('RS2').withDescription('D').insertRecord();

		GoogleFile__Share sh = new GoogleFile__Share(
			ParentId = f.Id,
			UserOrGroupId = u.Id,
			AccessLevel = 'Read',
			RowCause = Schema.GoogleFile__Share.RowCause.Manual
		);
		insert sh;

		GoogleCloudTestFactory.link()
			.forFile(f.Id)
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.withLinkedRecord(linkedAccount.Id)
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
		System.assertEquals(String.valueOf(linkedAccount.Id), dto.recordsSharedTo[0].LinkedObjectId__c);
	}

	@IsTest
	private static void testFetchSharingDetailsFiltersInaccessibleRecordLinks() {
		GoogleCloudTestFactory.initMocks();

		User targetUser = GoogleCloudTestFactory.newUser();
		Account linkedAccount = new Account(Name = 'Sharing Visible Account', OwnerId = targetUser.Id);
		insert linkedAccount;
		Id hiddenAccountId = GoogleCloudTestFactory.fakeId(Account.SObjectType);
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('RS_Filtered').withDescription('D').insertRecord();

		insert new GoogleFile__Share(
			ParentId = localFile.Id,
			UserOrGroupId = targetUser.Id,
			AccessLevel = 'Edit',
			RowCause = Schema.GoogleFile__Share.RowCause.Manual
		);

		GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withLinkedRecord(linkedAccount.Id)
			.withLinkedType('Account')
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.insertRecord();

		GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withLinkedRecord(hiddenAccountId)
			.withLinkedType('Account')
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.insertRecord();

		System.runAs(targetUser) {
			Test.startTest();
			GoogleSharingInfoDTO dto = new GoogleLocalFileSharingService().fetchSharingDetails(localFile.Id);
			Test.stopTest();

			Assert.areEqual(1, dto.recordsSharedTo.size());
			Assert.areEqual(String.valueOf(linkedAccount.Id), dto.recordsSharedTo[0].LinkedObjectId__c);
		}
	}

	@IsTest
	private static void testCreateSharingPositiveViewer() {
		GoogleCloudTestFactory.initMocks();

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
	private static void testCreateSharingPositiveCollaborator() {
		GoogleCloudTestFactory.initMocks();

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
	private static void testCreateSharingNegativeNullFileId() {
		GoogleCloudTestFactory.initMocks();

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
	private static void testCreateSharingNegativeNullShareTo() {
		GoogleCloudTestFactory.initMocks();

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
	private static void testCreateSharingNegativeBlankAccess() {
		GoogleCloudTestFactory.initMocks();

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
	private static void testCreateSharingNegativeBadAccess() {
		GoogleCloudTestFactory.initMocks();

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
	private static void testDeleteSharingPositiveUser() {
		GoogleCloudTestFactory.initMocks();

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
	private static void testDeleteSharingNegativeUserShareMissing() {
		GoogleCloudTestFactory.initMocks();

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
	private static void testDeleteSharingPositiveLink() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('DS3').withDescription('D').insertRecord();
		Id fakeAccountId = GoogleCloudTestFactory.fakeId(Account.SObjectType);

		GoogleFileLink__c link = GoogleCloudTestFactory.link()
			.forFile(f.Id)
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.withLinkedRecord(fakeAccountId)
			.withLinkedType('Account')
			.insertRecord();

		Test.startTest();
		new GoogleLocalFileSharingService()
			.deleteExistingSharing(f.Id, fakeAccountId);
		Test.stopTest();

		System.assertEquals(0, [
			SELECT count()
			FROM GoogleFileLink__c
			WHERE Id = :link.Id
		]);
	}

	@IsTest
	private static void testDeleteSharingNegativeLinkMissing() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('DS4').withDescription('D').insertRecord();
		Id fakeAccountId = GoogleCloudTestFactory.fakeId(Account.SObjectType);

		try {
			new GoogleLocalFileSharingService()
				.deleteExistingSharing(f.Id, fakeAccountId);
			System.assert(false);
		} catch (GoogleLocalFileSharingService.GoogleLocalFileSharingException ex) {
			System.assertEquals(true, ex.getMessage().contains('Unable to remove sharing'));
		}
	}

	@IsTest
	private static void testModifySharingPositiveUser() {
		GoogleCloudTestFactory.initMocks();

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
	private static void testModifySharingNegativeMissingAccess() {
		GoogleCloudTestFactory.initMocks();

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
	private static void testModifySharingNegativeUserShareMissing() {
		GoogleCloudTestFactory.initMocks();

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
	private static void testModifySharingPositiveLink() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('ML1').withDescription('D').insertRecord();
		Id fakeAccountId = GoogleCloudTestFactory.fakeId(Account.SObjectType);

		GoogleFileLink__c link = GoogleCloudTestFactory.link()
			.forFile(f.Id)
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.withLinkedRecord(fakeAccountId)
			.withLinkedType('Account')
			.insertRecord();

		Test.startTest();
		GoogleLocalFileSharingService service = new GoogleLocalFileSharingService();
		service.modifyExistingSharingAccess(f.Id, fakeAccountId, 'Collaborator');
		service.modifyExistingSharingVisibility(f.Id, fakeAccountId, 'InternalUsers');
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
	private static void testModifySharingNegativeNoInput() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('ML2').withDescription('D').insertRecord();
		Id fakeAccountId = GoogleCloudTestFactory.fakeId(Account.SObjectType);

		GoogleCloudTestFactory.link()
			.forFile(f.Id)
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.withLinkedRecord(fakeAccountId)
			.withLinkedType('Account')
			.insertRecord();

		try {
			GoogleLocalFileSharingService service = new GoogleLocalFileSharingService();
			service.modifyExistingSharingAccess(f.Id, fakeAccountId, ' ');
			service.modifyExistingSharingVisibility(f.Id, fakeAccountId, null);
			System.assert(false);
		} catch (GoogleLocalFileSharingService.GoogleLocalFileSharingException ex) {
			System.assertEquals(true, ex.getMessage().contains('Unable to update sharing'));
		}
	}

	@IsTest
	private static void testModifySharingNegativeLinkMissing() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('ML3').withDescription('D').insertRecord();
		Id fakeAccountId = GoogleCloudTestFactory.fakeId(Account.SObjectType);

		try {
			new GoogleLocalFileSharingService()
				.modifyExistingSharingAccess(f.Id, fakeAccountId, 'Viewer');
			System.assert(false);
		} catch (GoogleLocalFileSharingService.GoogleLocalFileSharingException ex) {
			System.assertEquals(true, ex.getMessage().contains('Unable to update sharing'));
		}
	}

	@IsTest
	private static void testModifySharingNegativeBadShareType() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('ML4').withDescription('D').insertRecord();
		Id fakeAccountId = GoogleCloudTestFactory.fakeId(Account.SObjectType);

		GoogleCloudTestFactory.link()
			.forFile(f.Id)
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.withLinkedRecord(fakeAccountId)
			.withLinkedType('Account')
			.insertRecord();

		try {
			new GoogleLocalFileSharingService()
				.modifyExistingSharingAccess(f.Id, fakeAccountId, 'NotARealType');
			System.assert(false);
		} catch (GoogleLocalFileSharingService.GoogleLocalFileSharingException ex) {
			System.assertEquals(true, ex.getMessage().contains('Unable to update sharing'));
		}
	}

	@IsTest
	private static void testModifySharingNegativeBadVisibility() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('ML5').withDescription('D').insertRecord();
		Id fakeAccountId = GoogleCloudTestFactory.fakeId(Account.SObjectType);

		GoogleCloudTestFactory.link()
			.forFile(f.Id)
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.withLinkedRecord(fakeAccountId)
			.withLinkedType('Account')
			.insertRecord();

		try {
			new GoogleLocalFileSharingService()
				.modifyExistingSharingVisibility(f.Id, fakeAccountId, 'Public');
			System.assert(false);
		} catch (GoogleLocalFileSharingService.GoogleLocalFileSharingException ex) {
			System.assertEquals(true, ex.getMessage().contains('Unable to update sharing'));
		}
	}

	@IsTest
	private static void testRetrieveLinkedRecordsFiltersInaccessibleRecordLinks() {
		GoogleCloudTestFactory.initMocks();

		User fileOwner = GoogleCloudTestFactory.newUser();
		User targetUser = GoogleCloudTestFactory.newUser();
		Account linkedAccount = new Account(Name = 'Linked Record Visible', OwnerId = targetUser.Id);
		insert linkedAccount;
		Id hiddenAccountId = GoogleCloudTestFactory.fakeId(Account.SObjectType);
		GoogleFile__c localFile = GoogleCloudTestFactory.file()
			.withName('Linked Records Filtered')
			.withDescription('D')
			.withOwner(fileOwner.Id)
			.insertRecord();

		GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withLinkedRecord(linkedAccount.Id)
			.withLinkedType('Account')
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.insertRecord();

		GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withLinkedRecord(hiddenAccountId)
			.withLinkedType('Account')
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.insertRecord();

		System.runAs(targetUser) {
			Test.startTest();
			List<GoogleFileLink__c> linkedRecords = new GoogleLocalFileSharingService().retrieveLinkedRecords(localFile.Id);
			Test.stopTest();

			Assert.areEqual(1, linkedRecords.size());
			Assert.areEqual(String.valueOf(linkedAccount.Id), linkedRecords[0].LinkedObjectId__c);
		}
	}
}