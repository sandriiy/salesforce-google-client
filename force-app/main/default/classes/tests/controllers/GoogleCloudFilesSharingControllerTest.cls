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
private class GoogleCloudFilesSharingControllerTest {
	@IsTest
	private static void testFetchSharingDetailsPositive() {
		GoogleCloudTestFactory.initMocks();

		User sharedUser = GoogleCloudTestFactory.newUser();
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('FS1').withDescription('D').insertRecord();

		insert new GoogleFile__Share(
			ParentId = localFile.Id,
			UserOrGroupId = sharedUser.Id,
			AccessLevel = 'Read',
			RowCause = Schema.GoogleFile__Share.RowCause.Manual
		);

		Id linkedAccountId = GoogleCloudTestFactory.fakeId(Account.SObjectType);

		GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.withLinkedRecord(linkedAccountId)
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
		GoogleCloudTestFactory.initMocks();

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
		GoogleCloudTestFactory.initMocks();

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
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('MV1').withDescription('D').insertRecord();
		Id linkedAccountId = GoogleCloudTestFactory.fakeId(Account.SObjectType);

		GoogleFileLink__c fileLink = GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.withLinkedRecord(linkedAccountId)
			.withLinkedType('Account')
			.insertRecord();

		Test.startTest();
		GoogleCloudFilesSharingController.modifyExistingSharingVisibility(localFile.Id, linkedAccountId, 'InternalUsers');
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
		GoogleCloudTestFactory.initMocks();

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
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('DS2').withDescription('D').insertRecord();
		Id linkedAccountId = GoogleCloudTestFactory.fakeId(Account.SObjectType);

		GoogleFileLink__c fileLink = GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.withLinkedRecord(linkedAccountId)
			.withLinkedType('Account')
			.insertRecord();

		Test.startTest();
		GoogleCloudFilesSharingController.deleteExistingSharing(localFile.Id, linkedAccountId);
		Test.stopTest();

		System.assertEquals(0, [
			SELECT count()
			FROM GoogleFileLink__c
			WHERE Id = :fileLink.Id
		]);
	}

	@IsTest
	private static void testCreateNewPublicLinkPositive() {
		GoogleCloudTestFactory.initMocks();

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
		Test.stopTest();

		GoogleFileVersion__c reloaded = [
			SELECT PublicLink__c, PublicLinkExpirationDate__c, PublicLinkPermissionId__c, PublicLinkStatus__c
			FROM GoogleFileVersion__c
			WHERE Id = :localFileVersion.Id
			LIMIT 1
		];

		System.assert(String.isNotBlank(reloaded.PublicLink__c));
		System.assertNotEquals(null, reloaded.PublicLinkExpirationDate__c);
		System.assert(String.isNotBlank(reloaded.PublicLinkPermissionId__c));
		System.assertEquals('Pending Expiration', reloaded.PublicLinkStatus__c);
	}

	@IsTest
	private static void testDeleteExistingPublicLinkPositive() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('PL2').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(localFile.Id)
			.withName('V2.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId('GD2')
			.withDocsId('DOCS2')
			.insertRecord();

		localFileVersion.PublicLink__c = 'https://example.test/view';
		localFileVersion.PublicLinkExpirationDate__c = System.now().addDays(7);
		localFileVersion.PublicLinkPermissionId__c = 'perm_123';
		localFileVersion.PublicLinkStatus__c = 'Active';
		update localFileVersion;

		Test.startTest();
		GoogleCloudFilesSharingController.deleteExistingPublicLink(localFileVersion.Id);
		Test.stopTest();

		GoogleFileVersion__c reloaded = [
			SELECT PublicLink__c, PublicLinkExpirationDate__c, PublicLinkPermissionId__c, PublicLinkStatus__c
			FROM GoogleFileVersion__c
			WHERE Id = :localFileVersion.Id
			LIMIT 1
		];

		System.assertEquals(null, reloaded.PublicLink__c);
		System.assertEquals(null, reloaded.PublicLinkExpirationDate__c);
		System.assertEquals(null, reloaded.PublicLinkPermissionId__c);
		System.assertEquals('None', reloaded.PublicLinkStatus__c);
	}

	@IsTest
	private static void testAttachExistingFileToRecordCreatesSingleLink() {
		GoogleCloudTestFactory.initMocks();

		Account relatedAccount = new Account(Name = 'Linked Account');
		insert relatedAccount;

		GoogleFile__c localFile = createOwnedFileRecord('Attach Once', UserInfo.getUserId(), 'GD_ATTACH_ONCE', 'Uploader');

		Test.startTest();
		Id firstLinkId = GoogleCloudFilesSharingController.attachExistingFileToRecord(localFile.Id, relatedAccount.Id, 'Notes & Attachments');
		Id secondLinkId = GoogleCloudFilesSharingController.attachExistingFileToRecord(localFile.Id, relatedAccount.Id, 'Notes & Attachments');
		Test.stopTest();

		List<GoogleFileLink__c> createdLinks = [
			SELECT Id, ShareType__c, Visibility__c, Source__c
			FROM GoogleFileLink__c
			WHERE GoogleFileId__c = :localFile.Id
			AND LinkedObjectId__c = :String.valueOf(relatedAccount.Id)
		];

		Assert.areEqual(1, createdLinks.size());
		Assert.areEqual(createdLinks[0].Id, firstLinkId);
		Assert.areEqual(createdLinks[0].Id, secondLinkId);
		Assert.areEqual('Viewer', createdLinks[0].ShareType__c);
		Assert.areEqual('InternalUsers', createdLinks[0].Visibility__c);
		Assert.areEqual('Notes & Attachments', createdLinks[0].Source__c);
		GoogleFile__c updatedFile = [
			SELECT Source__c
			FROM GoogleFile__c
			WHERE Id = :localFile.Id
			LIMIT 1
		];
		Assert.areEqual('Uploader', updatedFile.Source__c);
	}

	@IsTest
	private static void testAttachExistingFileToRecordRejectsSharedButNotOwnedFile() {
		GoogleCloudTestFactory.initMocks();

		User otherOwner = GoogleCloudTestFactory.newUser();
		Account relatedAccount = new Account(Name = 'Restricted Account');
		insert relatedAccount;

		GoogleFile__c sharedFile = createOwnedFileRecord('Shared Edit File', otherOwner.Id, 'GD_SHARED_EDIT');
		insert new GoogleFile__Share(
			ParentId = sharedFile.Id,
			UserOrGroupId = UserInfo.getUserId(),
			AccessLevel = 'Edit',
			RowCause = Schema.GoogleFile__Share.RowCause.Manual
		);

		try {
			Test.startTest();
			GoogleCloudFilesSharingController.attachExistingFileToRecord(sharedFile.Id, relatedAccount.Id, 'Notes & Attachments');
			Test.stopTest();
			Assert.fail('Expected the owner-only attach validation to reject the request');
		} catch (GoogleLocalFileSharingService.GoogleLocalFileSharingException ex) {
			Assert.isTrue(String.isNotBlank(ex.getMessage()));
		}

		Assert.areEqual(0, [
			SELECT count()
			FROM GoogleFileLink__c
			WHERE GoogleFileId__c = :sharedFile.Id
			AND LinkedObjectId__c = :String.valueOf(relatedAccount.Id)
		]);
	}

	@IsTest
	private static void testRetrieveLinkedRecordsReturnsAllLinkedRecords() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c localFile = createOwnedFileRecord('Linked Records File', UserInfo.getUserId(), 'GD_LINKED_RECORDS');
		Account firstAccount = new Account(Name = 'First Related Record');
		Account secondAccount = new Account(Name = 'Second Related Record');
		insert new List<Account>{ firstAccount, secondAccount };

		GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withLinkedRecord(firstAccount.Id)
			.withLinkedType('Account')
			.withShareType('Viewer')
			.withVisibility('InternalUsers')
			.insertRecord();

		GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withLinkedRecord(secondAccount.Id)
			.withLinkedType('Account')
			.withShareType('Viewer')
			.withVisibility('InternalUsers')
			.insertRecord();

		Test.startTest();
		List<GoogleFileLink__c> linkedRecords = GoogleCloudFilesSharingController.retrieveLinkedRecords(localFile.Id);
		Test.stopTest();

		Set<String> linkedRecordIds = new Set<String>();
		for (GoogleFileLink__c linkedRecord : linkedRecords) {
			linkedRecordIds.add(linkedRecord.LinkedObjectId__c);
			Assert.isTrue(String.isNotBlank(linkedRecord.LinkedObjectName__c));
		}

		Assert.areEqual(2, linkedRecords.size());
		Assert.areEqual(new Set<String>{ String.valueOf(firstAccount.Id), String.valueOf(secondAccount.Id) }, linkedRecordIds);
	}

	private static GoogleFile__c createOwnedFileRecord(String fileName, Id ownerId, String driveId) {
		return createOwnedFileRecord(fileName, ownerId, driveId, 'Notes & Attachments');
	}

	private static GoogleFile__c createOwnedFileRecord(String fileName, Id ownerId, String driveId, String source) {
		GoogleFile__c localFile = GoogleCloudTestFactory.file()
			.withName(fileName)
			.withDescription('D')
			.withSource(source)
			.withOwner(ownerId)
			.insertRecord();

		GoogleCloudTestFactory.version()
			.forFile(localFile.Id)
			.withName(fileName + '.pdf')
			.withType('application/pdf')
			.withSize(10L)
			.withDriveId(driveId)
			.insertRecord();

		return localFile;
	}

	@IsTest
	private static void testIsPublicLinkDomainPositive() {
		Test.startTest();
		Boolean isDomainConfigured = GoogleCloudFilesSharingController.isPublicLinkDomain();
		Test.stopTest();

		System.assertNotEquals(null, isDomainConfigured);
	}
}