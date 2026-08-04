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
	private static GoogleCapturingUnitOfWork injectSharingService() {
		GoogleCapturingUnitOfWork uow = new GoogleCapturingUnitOfWork();
		GoogleCloudFilesSharingController.sharingServiceOverride = new GoogleLocalFileSharingService(uow);
		return uow;
	}

	@IsTest
	private static void testFetchSharingDetailsPositive() {
		GoogleCloudTestFactory.initMocks();

		Id sharedUserId = GoogleCloudTestFactory.otherUserId();
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('FS1').withDescription('D').insertRecord();

		GoogleCloudTestFactory.mockShares(new List<GoogleFile__Share>{
			GoogleCloudTestFactory.share().forFile(localFile.Id).sharedWith(sharedUserId).withAccessLevel('Read').build()
		});

		Id linkedRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);

		GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.withLinkedRecord(linkedRecordId)
			.withLinkedType('GoogleFile__c')
			.insertRecord();

		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(new List<SObject>{
			new GoogleFile__c(Id = localFile.Id, OwnerId = UserInfo.getUserId(), Name = localFile.Name)
		});

		Test.startTest();
		GoogleSharingInfoDTO sharingInfo = GoogleCloudFilesSharingController.fetchSharingDetails(localFile.Id);
		Test.stopTest();

		Assert.areNotEqual(null, sharingInfo);
		Assert.areEqual(localFile.Id, sharingInfo.fileId);
	}

	@IsTest
	private static void testCreateNewSharingPositiveViewer() {
		GoogleCloudTestFactory.initMocks();

		Id targetUserId = GoogleCloudTestFactory.otherUserId();
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('CS1').withDescription('D').insertRecord();

		GoogleCapturingUnitOfWork uow = injectSharingService();

		Test.startTest();
		GoogleCloudFilesSharingController.createNewSharing(localFile.Id, 'User', targetUserId, 'viewer');
		Test.stopTest();

		Assert.areEqual(1, uow.registeredNew.size());

		GoogleFile__Share createdShare = (GoogleFile__Share) uow.firstNew();
		Assert.areEqual(localFile.Id, createdShare.ParentId);
		Assert.areEqual(targetUserId, createdShare.UserOrGroupId);
		Assert.areEqual('Read', createdShare.AccessLevel);
		Assert.areEqual(String.valueOf(Schema.GoogleFile__Share.RowCause.Manual), String.valueOf(createdShare.RowCause));
	}

	@IsTest
	private static void testModifyExistingSharingAccessPositive() {
		GoogleCloudTestFactory.initMocks();

		Id targetUserId = GoogleCloudTestFactory.otherUserId();
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('MS1').withDescription('D').insertRecord();

		GoogleCloudTestFactory.mockShares(new List<GoogleFile__Share>{
			GoogleCloudTestFactory.share().forFile(localFile.Id).sharedWith(targetUserId).withAccessLevel('Read').build()
		});
		GoogleCapturingUnitOfWork uow = injectSharingService();

		Test.startTest();
		GoogleCloudFilesSharingController.modifyExistingSharingAccess(localFile.Id, targetUserId, 'Collaborator');
		Test.stopTest();

		Assert.areEqual(1, uow.registeredDirty.size());
		Assert.areEqual('Edit', ((GoogleFile__Share) uow.firstDirty()).AccessLevel);
	}

	@IsTest
	private static void testModifyExistingSharingVisibilityPositive() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('MV1').withDescription('D').insertRecord();
		Id linkedRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);

		GoogleFileLink__c fileLink = GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.withLinkedRecord(linkedRecordId)
			.withLinkedType('GoogleFile__c')
			.insertRecord();

		Test.startTest();
		GoogleCloudFilesSharingController.modifyExistingSharingVisibility(localFile.Id, linkedRecordId, 'InternalUsers');
		Test.stopTest();

		GoogleFileLink__c updatedLink = [
			SELECT Visibility__c
			FROM GoogleFileLink__c
			WHERE Id = :fileLink.Id
			LIMIT 1
		];
		Assert.areEqual('InternalUsers', updatedLink.Visibility__c);
	}

	@IsTest
	private static void testDeleteExistingSharingPositiveUser() {
		GoogleCloudTestFactory.initMocks();

		Id targetUserId = GoogleCloudTestFactory.otherUserId();
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('DS1').withDescription('D').insertRecord();

		GoogleCloudTestFactory.mockShares(new List<GoogleFile__Share>{
			GoogleCloudTestFactory.share().forFile(localFile.Id).sharedWith(targetUserId).withAccessLevel('Read').build()
		});
		GoogleCapturingUnitOfWork uow = injectSharingService();

		Test.startTest();
		GoogleCloudFilesSharingController.deleteExistingSharing(localFile.Id, targetUserId);
		Test.stopTest();

		Assert.areEqual(1, uow.registeredDeleted.size());
		Assert.areEqual(targetUserId, ((GoogleFile__Share) uow.firstDeleted()).UserOrGroupId);
	}

	@IsTest
	private static void testDeleteExistingSharingPositiveLink() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('DS2').withDescription('D').insertRecord();
		Id linkedRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);

		GoogleFileLink__c fileLink = GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.withLinkedRecord(linkedRecordId)
			.withLinkedType('GoogleFile__c')
			.insertRecord();

		Test.startTest();
		GoogleCloudFilesSharingController.deleteExistingSharing(localFile.Id, linkedRecordId);
		Test.stopTest();

		Assert.areEqual(0, [
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

		Assert.isTrue(String.isNotBlank(reloaded.PublicLink__c));
		Assert.areNotEqual(null, reloaded.PublicLinkExpirationDate__c);
		Assert.isTrue(String.isNotBlank(reloaded.PublicLinkPermissionId__c));
		Assert.areEqual('Pending Expiration', reloaded.PublicLinkStatus__c);
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

		Assert.areEqual(null, reloaded.PublicLink__c);
		Assert.areEqual(null, reloaded.PublicLinkExpirationDate__c);
		Assert.areEqual(null, reloaded.PublicLinkPermissionId__c);
		Assert.areEqual('None', reloaded.PublicLinkStatus__c);
	}

	@IsTest
	private static void testAttachExistingFileToRecordCreatesSingleLink() {
		GoogleCloudTestFactory.initMocks();

		Id relatedRecordId = GoogleCloudTestFactory.linkedRecord('Linked Record');

		GoogleFile__c localFile = createOwnedFileRecord('Attach Once', UserInfo.getUserId(), 'GD_ATTACH_ONCE', 'Uploader');

		Test.startTest();
		Id firstLinkId = GoogleCloudFilesSharingController.attachExistingFileToRecord(localFile.Id, relatedRecordId, 'Notes & Attachments');
		Id secondLinkId = GoogleCloudFilesSharingController.attachExistingFileToRecord(localFile.Id, relatedRecordId, 'Notes & Attachments');
		Test.stopTest();

		List<GoogleFileLink__c> createdLinks = [
			SELECT Id, ShareType__c, Visibility__c, Source__c
			FROM GoogleFileLink__c
			WHERE GoogleFileId__c = :localFile.Id
			AND LinkedObjectId__c = :String.valueOf(relatedRecordId)
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

		Id relatedRecordId = GoogleCloudTestFactory.linkedRecord('Restricted Record');
		GoogleFile__c sharedFile = createOwnedFileRecord('Shared Edit File', UserInfo.getUserId(), 'GD_SHARED_EDIT');

		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(new List<SObject>());

		try {
			Test.startTest();
			GoogleCloudFilesSharingController.attachExistingFileToRecord(sharedFile.Id, relatedRecordId, 'Notes & Attachments');
			Test.stopTest();
			Assert.fail('Expected the owner-only attach validation to reject the request');
		} catch (GoogleLocalFileSharingService.GoogleLocalFileSharingException ex) {
			Assert.isTrue(String.isNotBlank(ex.getMessage()));
		}

		Assert.areEqual(0, [
			SELECT count()
			FROM GoogleFileLink__c
			WHERE GoogleFileId__c = :sharedFile.Id
			AND LinkedObjectId__c = :String.valueOf(relatedRecordId)
		]);
	}

	@IsTest
	private static void testRetrieveLinkedRecordsReturnsAllLinkedRecords() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c localFile = createOwnedFileRecord('Linked Records File', UserInfo.getUserId(), 'GD_LINKED_RECORDS');
		Id firstRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		Id secondRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleCloudTestFactory.grantRecordAccess(firstRecordId, true, true);
		GoogleCloudTestFactory.grantRecordAccess(secondRecordId, true, true);
		GSOQL.mock(GoogleFileLinkedRecordSelector.MOCK_ID).thenReturn(new List<SObject>{
			new GoogleFile__c(Id = firstRecordId, Name = 'First Related Record'),
			new GoogleFile__c(Id = secondRecordId, Name = 'Second Related Record')
		});

		GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withLinkedRecord(firstRecordId)
			.withLinkedType('GoogleFile__c')
			.withShareType('Viewer')
			.withVisibility('InternalUsers')
			.insertRecord();

		GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withLinkedRecord(secondRecordId)
			.withLinkedType('GoogleFile__c')
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
		Assert.areEqual(new Set<String>{ String.valueOf(firstRecordId), String.valueOf(secondRecordId) }, linkedRecordIds);
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

		Assert.areNotEqual(null, isDomainConfigured);
	}
}