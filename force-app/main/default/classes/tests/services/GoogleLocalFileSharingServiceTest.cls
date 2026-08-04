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
	private static List<GoogleFileLink__c> readableLinksFor(Id localFileId, Id targetUserId) {
		List<GoogleFileLink__c> allLinks = (List<GoogleFileLink__c>) GoogleFileLinkSelector.query()
			.withBaseFields()
			.byParentId(localFileId)
			.toList();

		return new GoogleFileAccessResolver().resolveReadableRecordLinks(allLinks, targetUserId);
	}

	private static GoogleClientConfig__mdt buildFolderConfig(String uploadFolderId, String folderStructure) {
		GoogleClientConfig__mdt config = new GoogleClientConfig__mdt();
		config.DefaultGoogleUploadFolderId__c = uploadFolderId;
		config.CustomGoogleUploadFolderStructure__c = folderStructure;
		return config;
	}

	@IsTest
	private static void testFetchSharingDetailsPositiveEmpty() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file()
			.withName('RS_Empty')
			.withDescription('D')
			.insertRecord();

		GoogleLocalFileSharingService service = new GoogleLocalFileSharingService();
		GoogleSharingInfoDTO dto = service.fetchSharingDetails(f.Id);

		Assert.areNotEqual(null, dto);
		Assert.areEqual(f.Id, dto.fileId);
		Assert.areNotEqual(null, dto.owner);
		Assert.areEqual(UserInfo.getUserId(), dto.owner.Id);
		Assert.areNotEqual(null, dto.entitiesSharedTo);
		Assert.areEqual(0, dto.entitiesSharedTo.size());
		Assert.areNotEqual(null, dto.recordsSharedTo);
		Assert.areEqual(0, dto.recordsSharedTo.size());
	}

	@IsTest
	private static void testFetchSharingDetailsPositiveIncludeAll() {
		GoogleCloudTestFactory.initMocks();

		Id targetUserId = GoogleCloudTestFactory.otherUserId();
		Id linkedRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleCloudTestFactory.grantRecordAccess(linkedRecordId, true, true);
		GoogleFile__c f = GoogleCloudTestFactory.file().withName('RS2').withDescription('D').insertRecord();

		GoogleCloudTestFactory.mockShares(new List<GoogleFile__Share>{
			GoogleCloudTestFactory.share().forFile(f.Id).sharedWith(targetUserId).withAccessLevel('Read').build()
		});

		GoogleCloudTestFactory.link()
			.forFile(f.Id)
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.withLinkedRecord(linkedRecordId)
			.withLinkedType('GoogleFile__c')
			.insertRecord();

		GoogleLocalFileSharingService service = new GoogleLocalFileSharingService();
		GoogleSharingInfoDTO dto = service.fetchSharingDetails(f.Id);

		Assert.areNotEqual(null, dto);
		Assert.areEqual(f.Id, dto.fileId);

		Assert.areNotEqual(null, dto.owner);
		Assert.areEqual(UserInfo.getUserId(), dto.owner.Id);

		Assert.areNotEqual(null, dto.entitiesSharedTo);
		Assert.areEqual(1, dto.entitiesSharedTo.size());
		Assert.areEqual(targetUserId, dto.entitiesSharedTo[0].UserOrGroupId);

		Assert.areNotEqual(null, dto.recordsSharedTo);
		Assert.areEqual(1, dto.recordsSharedTo.size());
		Assert.areEqual(String.valueOf(linkedRecordId), dto.recordsSharedTo[0].LinkedObjectId__c);
	}

	@IsTest
	private static void testFetchSharingDetailsFiltersInaccessibleRecordLinks() {
		GoogleCloudTestFactory.initMocks();

		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		Id linkedRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleCloudTestFactory.grantRecordAccess(linkedRecordId, true, true);
		Id hiddenRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('RS_Filtered').withDescription('D').insertRecord();

		GoogleCloudTestFactory.mockShares(new List<GoogleFile__Share>{
			GoogleCloudTestFactory.share().forFile(localFile.Id).sharedWith(targetUserId).withAccessLevel('Edit').build()
		});

		GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withLinkedRecord(linkedRecordId)
			.withLinkedType('GoogleFile__c')
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.insertRecord();

		GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withLinkedRecord(hiddenRecordId)
			.withLinkedType('GoogleFile__c')
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.insertRecord();

		Test.startTest();
		GoogleSharingInfoDTO dto = new GoogleLocalFileSharingService().fetchSharingDetails(localFile.Id);
		Test.stopTest();

		Assert.areEqual(2, dto.recordsSharedTo.size());
		Assert.areEqual(String.valueOf(linkedRecordId), dto.recordsSharedTo[0].LinkedObjectId__c);
	}

	@IsTest
	private static void testFetchSharingDetailsIncludesNoneRecordLinksForEditableUser() {
		GoogleCloudTestFactory.initMocks();

		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		Id linkedRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('RS_None').withDescription('D').insertRecord();

		GoogleCloudTestFactory.mockShares(new List<GoogleFile__Share>{
			GoogleCloudTestFactory.share().forFile(localFile.Id).sharedWith(targetUserId).withAccessLevel('Edit').build()
		});

		GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withLinkedRecord(linkedRecordId)
			.withLinkedType('GoogleFile__c')
			.withShareType('None')
			.withVisibility('AllUsers')
			.insertRecord();

		Test.startTest();
		GoogleSharingInfoDTO dto = new GoogleLocalFileSharingService().fetchSharingDetails(localFile.Id);
		Test.stopTest();

		Assert.areEqual(1, dto.recordsSharedTo.size());
		Assert.areEqual(String.valueOf(linkedRecordId), dto.recordsSharedTo[0].LinkedObjectId__c);
		Assert.areEqual('None', dto.recordsSharedTo[0].ShareType__c);
	}

	@IsTest
	private static void testCreateSharingPositiveViewer() {
		GoogleCloudTestFactory.initMocks();

		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		GoogleFile__c f = GoogleCloudTestFactory.file().withName('CS1').withDescription('D').insertRecord();

		GoogleCapturingUnitOfWork uow = new GoogleCapturingUnitOfWork();

		Test.startTest();
		new GoogleLocalFileSharingService(uow).createNewSharing(f.Id, 'User', targetUserId, 'viewer');
		Test.stopTest();

		Assert.areEqual(1, uow.registeredNew.size());
		Assert.areEqual(1, uow.commitCount);

		GoogleFile__Share created = (GoogleFile__Share) uow.firstNew();
		Assert.areEqual(f.Id, created.ParentId);
		Assert.areEqual(targetUserId, created.UserOrGroupId);
		Assert.areEqual('Read', created.AccessLevel);
		Assert.areEqual(
			String.valueOf(Schema.GoogleFile__Share.RowCause.Manual),
			String.valueOf(created.RowCause)
		);
	}

	@IsTest
	private static void testCreateSharingPositiveCollaborator() {
		GoogleCloudTestFactory.initMocks();

		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		GoogleFile__c f = GoogleCloudTestFactory.file().withName('CS2').withDescription('D').insertRecord();

		GoogleCapturingUnitOfWork uow = new GoogleCapturingUnitOfWork();

		Test.startTest();
		new GoogleLocalFileSharingService(uow).createNewSharing(f.Id, 'User', targetUserId, 'Collaborator');
		Test.stopTest();

		Assert.areEqual(1, uow.registeredNew.size());
		Assert.areEqual('Edit', ((GoogleFile__Share) uow.firstNew()).AccessLevel);
	}

	@IsTest
	private static void testCreateSharingNegativeNullFileId() {
		GoogleCloudTestFactory.initMocks();

		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();

		try {
			Id shareId = new GoogleLocalFileSharingService()
				.createNewSharing(null, 'User', targetUserId, 'viewer');
			Assert.areEqual(null, shareId);
		} catch (GoogleLocalFileSharingService.GoogleLocalFileSharingException ex) {
			Assert.areNotEqual(null, ex);
		}

		Assert.areEqual(0, [
			SELECT count()
			FROM GoogleFile__Share
			WHERE UserOrGroupId = :targetUserId
		]);
	}

	@IsTest
	private static void testCreateSharingNegativeNullShareTo() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('CS3').withDescription('D').insertRecord();

		try {
			new GoogleLocalFileSharingService()
				.createNewSharing(f.Id, 'User', null, 'viewer');
			Assert.isTrue(false);
		} catch (GoogleLocalFileSharingService.GoogleLocalFileSharingException ex) {
			Assert.areEqual(true, ex.getMessage().contains('Unable to share'));
		}
	}

	@IsTest
	private static void testCreateSharingNegativeBlankAccess() {
		GoogleCloudTestFactory.initMocks();

		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		GoogleFile__c f = GoogleCloudTestFactory.file().withName('CS4').withDescription('D').insertRecord();

		try {
			new GoogleLocalFileSharingService()
				.createNewSharing(f.Id, 'User', targetUserId, '   ');
			Assert.isTrue(false);
		} catch (GoogleLocalFileSharingService.GoogleLocalFileSharingException ex) {
			Assert.areEqual(true, ex.getMessage().contains('Unable to share'));
		}
	}

	@IsTest
	private static void testCreateSharingNegativeBadAccess() {
		GoogleCloudTestFactory.initMocks();

		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		GoogleFile__c f = GoogleCloudTestFactory.file().withName('CS5').withDescription('D').insertRecord();

		try {
			new GoogleLocalFileSharingService()
				.createNewSharing(f.Id, 'User', targetUserId, 'admin');
			Assert.isTrue(false);
		} catch (GoogleLocalFileSharingService.GoogleLocalFileSharingException ex) {
			Assert.areEqual(true, ex.getMessage().contains('Unable to share'));
		}
	}

	@IsTest
	private static void testDeleteSharingPositiveUser() {
		GoogleCloudTestFactory.initMocks();

		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		GoogleFile__c f = GoogleCloudTestFactory.file().withName('DS1').withDescription('D').insertRecord();

		GoogleCloudTestFactory.mockShares(new List<GoogleFile__Share>{
			GoogleCloudTestFactory.share().forFile(f.Id).sharedWith(targetUserId).withAccessLevel('Read').build()
		});

		GoogleCapturingUnitOfWork uow = new GoogleCapturingUnitOfWork();

		Test.startTest();
		new GoogleLocalFileSharingService(uow).deleteExistingSharing(f.Id, targetUserId);
		Test.stopTest();

		Assert.areEqual(1, uow.registeredDeleted.size());
		Assert.areEqual(1, uow.commitCount);
		Assert.areEqual(targetUserId, ((GoogleFile__Share) uow.firstDeleted()).UserOrGroupId);
	}

	@IsTest
	private static void testDeleteSharingNegativeUserShareMissing() {
		GoogleCloudTestFactory.initMocks();

		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		GoogleFile__c f = GoogleCloudTestFactory.file().withName('DS2').withDescription('D').insertRecord();

		try {
			new GoogleLocalFileSharingService()
				.deleteExistingSharing(f.Id, targetUserId);
			Assert.isTrue(false);
		} catch (GoogleLocalFileSharingService.GoogleLocalFileSharingException ex) {
			Assert.areEqual(true, ex.getMessage().contains('Unable to remove sharing'));
		}
	}

	@IsTest
	private static void testDeleteSharingPositiveLink() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('DS3').withDescription('D').insertRecord();
		Id fakeRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);

		GoogleFileLink__c link = GoogleCloudTestFactory.link()
			.forFile(f.Id)
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.withLinkedRecord(fakeRecordId)
			.withLinkedType('GoogleFile__c')
			.insertRecord();

		Test.startTest();
		new GoogleLocalFileSharingService()
			.deleteExistingSharing(f.Id, fakeRecordId);
		Test.stopTest();

		Assert.areEqual(0, [
			SELECT count()
			FROM GoogleFileLink__c
			WHERE Id = :link.Id
		]);
	}

	@IsTest
	private static void testDeleteSharingNegativeLinkMissing() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('DS4').withDescription('D').insertRecord();
		Id fakeRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);

		try {
			new GoogleLocalFileSharingService()
				.deleteExistingSharing(f.Id, fakeRecordId);
			Assert.isTrue(false);
		} catch (GoogleLocalFileSharingService.GoogleLocalFileSharingException ex) {
			Assert.areEqual(true, ex.getMessage().contains('Unable to remove sharing'));
		}
	}

	@IsTest
	private static void testModifySharingPositiveUser() {
		GoogleCloudTestFactory.initMocks();

		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		GoogleFile__c f = GoogleCloudTestFactory.file().withName('MS1').withDescription('D').insertRecord();

		GoogleCloudTestFactory.mockShares(new List<GoogleFile__Share>{
			GoogleCloudTestFactory.share().forFile(f.Id).sharedWith(targetUserId).withAccessLevel('Read').build()
		});

		GoogleCapturingUnitOfWork uow = new GoogleCapturingUnitOfWork();

		Test.startTest();
		new GoogleLocalFileSharingService(uow).modifyExistingSharingAccess(f.Id, targetUserId, 'Collaborator');
		Test.stopTest();

		Assert.areEqual(1, uow.registeredDirty.size());
		Assert.areEqual(1, uow.commitCount);
		Assert.areEqual('Edit', ((GoogleFile__Share) uow.firstDirty()).AccessLevel);
	}

	@IsTest
	private static void testModifySharingNegativeMissingAccess() {
		GoogleCloudTestFactory.initMocks();

		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		GoogleFile__c f = GoogleCloudTestFactory.file().withName('MS2').withDescription('D').insertRecord();

		GoogleCloudTestFactory.mockShares(new List<GoogleFile__Share>{
			GoogleCloudTestFactory.share().forFile(f.Id).sharedWith(targetUserId).withAccessLevel('Read').build()
		});

		try {
			new GoogleLocalFileSharingService()
				.modifyExistingSharingAccess(f.Id, targetUserId, null);
			Assert.isTrue(false);
		} catch (GoogleLocalFileSharingService.GoogleLocalFileSharingException ex) {
			Assert.areEqual(true, ex.getMessage().contains('Unable to update sharing'));
		}
	}

	@IsTest
	private static void testModifySharingNegativeUserShareMissing() {
		GoogleCloudTestFactory.initMocks();

		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		GoogleFile__c f = GoogleCloudTestFactory.file().withName('MS3').withDescription('D').insertRecord();

		try {
			new GoogleLocalFileSharingService()
				.modifyExistingSharingAccess(f.Id, targetUserId, 'viewer');
			Assert.isTrue(false);
		} catch (GoogleLocalFileSharingService.GoogleLocalFileSharingException ex) {
			Assert.areEqual(true, ex.getMessage().contains('Unable to update sharing'));
		}
	}

	@IsTest
	private static void testModifySharingPositiveLink() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('ML1').withDescription('D').insertRecord();
		Id fakeRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);

		GoogleFileLink__c link = GoogleCloudTestFactory.link()
			.forFile(f.Id)
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.withLinkedRecord(fakeRecordId)
			.withLinkedType('GoogleFile__c')
			.insertRecord();

		Test.startTest();
		GoogleLocalFileSharingService service = new GoogleLocalFileSharingService();
		service.modifyExistingSharingAccess(f.Id, fakeRecordId, 'Collaborator');
		service.modifyExistingSharingVisibility(f.Id, fakeRecordId, 'InternalUsers');
		Test.stopTest();

		GoogleFileLink__c updated = [
			SELECT ShareType__c, Visibility__c
			FROM GoogleFileLink__c
			WHERE Id = :link.Id
			LIMIT 1
		];
		Assert.areEqual('Collaborator', updated.ShareType__c);
		Assert.areEqual('InternalUsers', updated.Visibility__c);
	}

	@IsTest
	private static void testModifySharingNegativeNoInput() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('ML2').withDescription('D').insertRecord();
		Id fakeRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);

		GoogleCloudTestFactory.link()
			.forFile(f.Id)
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.withLinkedRecord(fakeRecordId)
			.withLinkedType('GoogleFile__c')
			.insertRecord();

		try {
			GoogleLocalFileSharingService service = new GoogleLocalFileSharingService();
			service.modifyExistingSharingAccess(f.Id, fakeRecordId, ' ');
			service.modifyExistingSharingVisibility(f.Id, fakeRecordId, null);
			Assert.isTrue(false);
		} catch (GoogleLocalFileSharingService.GoogleLocalFileSharingException ex) {
			Assert.areEqual(true, ex.getMessage().contains('Unable to update sharing'));
		}
	}

	@IsTest
	private static void testModifySharingNegativeLinkMissing() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('ML3').withDescription('D').insertRecord();
		Id fakeRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);

		try {
			new GoogleLocalFileSharingService()
				.modifyExistingSharingAccess(f.Id, fakeRecordId, 'Viewer');
			Assert.isTrue(false);
		} catch (GoogleLocalFileSharingService.GoogleLocalFileSharingException ex) {
			Assert.areEqual(true, ex.getMessage().contains('Unable to update sharing'));
		}
	}

	@IsTest
	private static void testModifySharingNegativeBadShareType() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('ML4').withDescription('D').insertRecord();
		Id fakeRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);

		GoogleCloudTestFactory.link()
			.forFile(f.Id)
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.withLinkedRecord(fakeRecordId)
			.withLinkedType('GoogleFile__c')
			.insertRecord();

		try {
			new GoogleLocalFileSharingService()
				.modifyExistingSharingAccess(f.Id, fakeRecordId, 'NotARealType');
			Assert.isTrue(false);
		} catch (GoogleLocalFileSharingService.GoogleLocalFileSharingException ex) {
			Assert.areEqual(true, ex.getMessage().contains('Unable to update sharing'));
		}
	}

	@IsTest
	private static void testModifySharingNegativeBadVisibility() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c f = GoogleCloudTestFactory.file().withName('ML5').withDescription('D').insertRecord();
		Id fakeRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);

		GoogleCloudTestFactory.link()
			.forFile(f.Id)
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.withLinkedRecord(fakeRecordId)
			.withLinkedType('GoogleFile__c')
			.insertRecord();

		try {
			new GoogleLocalFileSharingService()
				.modifyExistingSharingVisibility(f.Id, fakeRecordId, 'Public');
			Assert.isTrue(false);
		} catch (GoogleLocalFileSharingService.GoogleLocalFileSharingException ex) {
			Assert.areEqual(true, ex.getMessage().contains('Unable to update sharing'));
		}
	}

	@IsTest
	private static void testRetrieveLinkedRecordsFiltersInaccessibleRecordLinks() {
		GoogleCloudTestFactory.initMocks();

		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		Id linkedRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleCloudTestFactory.grantRecordAccess(linkedRecordId, true, true);
		Id hiddenRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleFile__c localFile = GoogleCloudTestFactory.file()
			.withName('Linked Records Filtered')
			.withDescription('D')
			.insertRecord();

		GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withLinkedRecord(linkedRecordId)
			.withLinkedType('GoogleFile__c')
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.insertRecord();

		GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withLinkedRecord(hiddenRecordId)
			.withLinkedType('GoogleFile__c')
			.withShareType('Viewer')
			.withVisibility('AllUsers')
			.insertRecord();

		Test.startTest();
		List<GoogleFileLink__c> linkedRecords = readableLinksFor(localFile.Id, targetUserId);
		Test.stopTest();

		Assert.areEqual(1, linkedRecords.size());
		Assert.areEqual(String.valueOf(linkedRecordId), linkedRecords[0].LinkedObjectId__c);
	}

	@IsTest
	private static void testRetrieveLinkedRecordsIncludesReadableNoneLinks() {
		GoogleCloudTestFactory.initMocks();

		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		Id linkedRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleCloudTestFactory.grantRecordAccess(linkedRecordId, true, true);
		GoogleFile__c localFile = GoogleCloudTestFactory.file()
			.withName('Linked Records None Visible')
			.withDescription('D')
			.insertRecord();

		GoogleCloudTestFactory.mockShares(new List<GoogleFile__Share>{
			GoogleCloudTestFactory.share().forFile(localFile.Id).sharedWith(targetUserId).withAccessLevel('Read').build()
		});

		GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withLinkedRecord(linkedRecordId)
			.withLinkedType('GoogleFile__c')
			.withShareType('None')
			.withVisibility('AllUsers')
			.insertRecord();

		Test.startTest();
		List<GoogleFileLink__c> linkedRecords = readableLinksFor(localFile.Id, targetUserId);
		Test.stopTest();

		Assert.areEqual(1, linkedRecords.size());
		Assert.areEqual(String.valueOf(linkedRecordId), linkedRecords[0].LinkedObjectId__c);
		Assert.areEqual('None', linkedRecords[0].ShareType__c);
	}

	@IsTest
	private static void testAttachExistingFileToRecordPositiveRecordStructure() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildFolderConfig('ROOT_FOLDER_01', '{Record}');
		GoogleFileCloudShortcutJob.skipExecution = true;

		Id relatedRecordId = GoogleCloudTestFactory.linkedRecord('Attach Shortcut Record');

		GoogleFile__c localFile = GoogleCloudTestFactory.file()
			.withName('Attach Shortcut File')
			.insertRecord();

		GoogleCloudTestFactory.version()
			.forFile(localFile.Id)
			.withName('Attach Shortcut File.pdf')
			.withDriveId('GD_ATTACH_SHORTCUT')
			.insertRecord();

		Test.startTest();
		Id linkId = new GoogleLocalFileSharingService().attachExistingFileToRecord(localFile.Id, relatedRecordId, 'Notes & Attachments');
		Test.stopTest();

		Assert.isNotNull(linkId);
		Assert.areEqual(1, [
			SELECT count()
			FROM GoogleFileLink__c
			WHERE GoogleFileId__c = :localFile.Id
			AND LinkedObjectId__c = :String.valueOf(relatedRecordId)
		]);
	}
}