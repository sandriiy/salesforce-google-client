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
private class GoogleFileAccessResolverTest {
	private static Id fileId;
	private static Id ownerId;

	private static void setUpMocks() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.denyAllRecordAccess();

		fileId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		ownerId = GoogleCloudTestFactory.fakeId(User.SObjectType);
	}

	private static List<GoogleFile__c> fileOwnedBy(Id fileOwnerId) {
		return new List<GoogleFile__c>{ new GoogleFile__c(Id = fileId, Name = 'Access File', OwnerId = fileOwnerId) };
	}

	private static GoogleFileLink__c linkTo(Id linkedRecordId, String shareType, String visibility) {
		return new GoogleFileLink__c(
			Id = GoogleCloudTestFactory.fakeId(GoogleFileLink__c.SObjectType),
			GoogleFileId__c = fileId,
			LinkedObjectId__c = String.valueOf(linkedRecordId),
			LinkedObjectType__c = 'GoogleFile__c',
			ShareType__c = shareType,
			Visibility__c = visibility
		);
	}

	private static String resolveLevelFor(Id targetUserId, List<GoogleFileLink__c> links) {
		List<GoogleFile__c> accessibleFiles = new GoogleFileAccessResolver()
			.resolveAccessibleFiles(fileOwnedBy(ownerId), targetUserId, links);

		return accessibleFiles.isEmpty() ? null : accessibleFiles[0].UserAccessLevel__c;
	}

	@IsTest
	private static void testResolutionPreservesInputOrder() {
		setUpMocks();
		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		GoogleCloudTestFactory.setPrivilegedFloor(GoogleFileAccessResolver.AccessLevel.View);

		Id foreignFileId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		List<GoogleFile__c> orderedInput = new List<GoogleFile__c>{
			new GoogleFile__c(Id = foreignFileId, Name = 'A Foreign File', OwnerId = ownerId),
			new GoogleFile__c(Id = fileId, Name = 'B Owned File', OwnerId = targetUserId)
		};

		List<GoogleFile__c> accessibleFiles = new GoogleFileAccessResolver()
			.resolveAccessibleFiles(orderedInput, targetUserId);

		Assert.areEqual(2, accessibleFiles.size());
		Assert.areEqual(foreignFileId, accessibleFiles[0].Id, 'Sort order from the caller must survive access resolution');
		Assert.areEqual(fileId, accessibleFiles[1].Id, 'Owned files must not be hoisted to the front of the page');
	}

	@IsTest
	private static void testPageReportsMoreWhenAccessFilteringEmptiesIt() {
		setUpMocks();
		GoogleCloudTestFactory.mockInternalUser();
		GoogleFileAccessResolver.WIDE_SCAN_SIZE = 2;

		List<SObject> candidates = new List<SObject>();
		for (Integer i = 0; i < 3; i++) {
			candidates.add(new GoogleFile__c(Id = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType), Name = 'Page File ' + i, OwnerId = ownerId));
		}

		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(candidates);
		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(candidates);

		GoogleFileAccessResolver.FilePageCriteria criteria = new GoogleFileAccessResolver.FilePageCriteria();
		criteria.pageSize = 2;

		GoogleFileAccessResolver.FilePage page = new GoogleFileAccessResolver().resolveFilePage(criteria);

		Assert.isTrue(page.hasMore, 'An unexhausted source must keep hasMore true even when the page filters down to nothing');
		Assert.areNotEqual(null, page.cursorRow, 'A cursor row must survive even when every row is filtered out');
		Assert.areEqual(0, page.records.size(), 'None of the mocked files are reachable by this user');
	}

	@IsTest
	private static void testSparsePageWidensScanUntilAccessibleRecordsAppear() {
		setUpMocks();
		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();

		List<SObject> unreachable = new List<SObject>();
		for (Integer i = 0; i < 3; i++) {
			unreachable.add(new GoogleFile__c(Id = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType), Name = 'Unreachable ' + i, OwnerId = ownerId));
		}

		List<SObject> reachable = new List<SObject>();
		for (Integer i = 0; i < 3; i++) {
			reachable.add(new GoogleFile__c(Id = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType), Name = 'Reachable ' + i, OwnerId = targetUserId));
		}

		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(unreachable);
		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(reachable);

		GoogleFileAccessResolver.FilePageCriteria criteria = new GoogleFileAccessResolver.FilePageCriteria();
		criteria.pageSize = 2;

		GoogleFileAccessResolver.FilePage page = new GoogleFileAccessResolver().resolveFilePage(criteria, targetUserId);

		Assert.areEqual(2, page.records.size(), 'The wider scan must recover a full page when the first narrow scan finds nothing');
		Assert.areEqual(reachable[0].Id, page.records[0].Id);
		Assert.areEqual(reachable[1].Id, page.records[1].Id);
		Assert.areEqual(page.records[1].Id, page.cursorRow.Id, 'The cursor must resume from the last record actually returned');
		Assert.isTrue(page.hasMore, 'A trimmed page still has more to give');
	}

	@IsTest
	private static void testPageCursorRowIsLastRowOfRequestedPage() {
		setUpMocks();
		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();

		List<SObject> candidates = new List<SObject>();
		for (Integer i = 0; i < 3; i++) {
			candidates.add(new GoogleFile__c(Id = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType), Name = 'Cursor File ' + i, OwnerId = targetUserId));
		}
		
		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(candidates);

		GoogleFileAccessResolver.FilePageCriteria criteria = new GoogleFileAccessResolver.FilePageCriteria();
		criteria.pageSize = 2;

		GoogleFileAccessResolver.FilePage page = new GoogleFileAccessResolver().resolveFilePage(criteria, targetUserId);

		Assert.isTrue(page.hasMore);
		Assert.areEqual(2, page.records.size(), 'The lookahead row must be trimmed before the page is returned');
		Assert.areEqual(candidates[1].Id, page.cursorRow.Id, 'The cursor must continue from the last row of the trimmed page');
	}

	@IsTest
	private static void testOwnerAlwaysResolvesToEdit() {
		setUpMocks();
		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();

		List<GoogleFile__c> accessibleFiles = new GoogleFileAccessResolver()
			.resolveAccessibleFiles(fileOwnedBy(targetUserId), targetUserId);

		Assert.areEqual(1, accessibleFiles.size());
		Assert.areEqual('Edit', accessibleFiles[0].UserAccessLevel__c);
	}

	@IsTest
	private static void testNoAccessPathFiltersFileOut() {
		setUpMocks();
		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();

		List<GoogleFile__c> accessibleFiles = new GoogleFileAccessResolver()
			.resolveAccessibleFiles(fileOwnedBy(ownerId), targetUserId);

		Assert.areEqual(0, accessibleFiles.size());
	}

	@IsTest
	private static void testDirectShareReadResolvesToView() {
		setUpMocks();
		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		GoogleCloudTestFactory.mockShares(new List<GoogleFile__Share>{
			GoogleCloudTestFactory.share().forFile(fileId).sharedWith(targetUserId).withAccessLevel('Read').build()
		});

		Assert.areEqual('View', resolveLevelFor(targetUserId, new List<GoogleFileLink__c>()));
	}

	@IsTest
	private static void testDirectShareEditResolvesToEdit() {
		setUpMocks();
		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		GoogleCloudTestFactory.mockShares(new List<GoogleFile__Share>{
			GoogleCloudTestFactory.share().forFile(fileId).sharedWith(targetUserId).withAccessLevel('Edit').build()
		});

		Assert.areEqual('Edit', resolveLevelFor(targetUserId, new List<GoogleFileLink__c>()));
	}

	@IsTest
	private static void testViewerLinkResolvesToViewWhenRecordIsReadable() {
		setUpMocks();
		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		Id linkedRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleCloudTestFactory.grantRecordAccess(linkedRecordId, true, false);

		Assert.areEqual('View', resolveLevelFor(targetUserId, new List<GoogleFileLink__c>{
			linkTo(linkedRecordId, 'Viewer', 'AllUsers')
		}));
	}

	@IsTest
	private static void testCollaboratorLinkResolvesToEditWhenRecordIsReadable() {
		setUpMocks();
		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		Id linkedRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleCloudTestFactory.grantRecordAccess(linkedRecordId, true, false);

		Assert.areEqual('Edit', resolveLevelFor(targetUserId, new List<GoogleFileLink__c>{
			linkTo(linkedRecordId, 'Collaborator', 'AllUsers')
		}));
	}

	@IsTest
	private static void testInferredLinkMirrorsRecordEditAccess() {
		setUpMocks();
		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		Id linkedRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleCloudTestFactory.grantRecordAccess(linkedRecordId, true, true);

		Assert.areEqual('Edit', resolveLevelFor(targetUserId, new List<GoogleFileLink__c>{
			linkTo(linkedRecordId, 'InferredFromRecord', 'AllUsers')
		}));
	}

	@IsTest
	private static void testInferredLinkMirrorsRecordReadAccess() {
		setUpMocks();
		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		Id linkedRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleCloudTestFactory.grantRecordAccess(linkedRecordId, true, false);

		Assert.areEqual('View', resolveLevelFor(targetUserId, new List<GoogleFileLink__c>{
			linkTo(linkedRecordId, 'InferredFromRecord', 'AllUsers')
		}));
	}

	@IsTest
	private static void testNoneShareTypeGrantsNothing() {
		setUpMocks();
		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		Id linkedRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleCloudTestFactory.grantRecordAccess(linkedRecordId, true, true);

		Assert.isNull(resolveLevelFor(targetUserId, new List<GoogleFileLink__c>{
			linkTo(linkedRecordId, 'None', 'AllUsers')
		}));
	}

	@IsTest
	private static void testLinkGrantsNothingWithoutRecordAccess() {
		setUpMocks();
		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		Id unreachableRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);

		Assert.isNull(resolveLevelFor(targetUserId, new List<GoogleFileLink__c>{
			linkTo(unreachableRecordId, 'Collaborator', 'AllUsers')
		}));
	}

	@IsTest
	private static void testMultipleLinksResolveToTheHighestReachableAccess() {
		setUpMocks();
		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		Id unreachableRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		Id reachableRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleCloudTestFactory.grantRecordAccess(reachableRecordId, true, true);

		Assert.areEqual('Edit', resolveLevelFor(targetUserId, new List<GoogleFileLink__c>{
			linkTo(unreachableRecordId, 'Collaborator', 'AllUsers'),
			linkTo(reachableRecordId, 'Viewer', 'AllUsers'),
			linkTo(reachableRecordId, 'InferredFromRecord', 'AllUsers')
		}));
	}

	@IsTest
	private static void testInternalOnlyVisibilityHidesFileFromExternalUser() {
		setUpMocks();
		Id externalUserId = GoogleCloudTestFactory.mockExternalUser();
		Id linkedRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleCloudTestFactory.grantRecordAccess(linkedRecordId, true, true);

		Assert.isNull(resolveLevelFor(externalUserId, new List<GoogleFileLink__c>{
			linkTo(linkedRecordId, 'Viewer', 'InternalUsers')
		}));
	}

	@IsTest
	private static void testAllUsersVisibilityReachesExternalUser() {
		setUpMocks();
		Id externalUserId = GoogleCloudTestFactory.mockExternalUser();
		Id linkedRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleCloudTestFactory.grantRecordAccess(linkedRecordId, true, true);

		Assert.areEqual('View', resolveLevelFor(externalUserId, new List<GoogleFileLink__c>{
			linkTo(linkedRecordId, 'Viewer', 'AllUsers')
		}));
	}

	@IsTest
	private static void testViewAllFloorGrantsViewToInternalUser() {
		setUpMocks();
		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		GoogleCloudTestFactory.setPrivilegedFloor(GoogleFileAccessResolver.AccessLevel.View);

		Assert.areEqual('View', resolveLevelFor(targetUserId, new List<GoogleFileLink__c>()));
	}

	@IsTest
	private static void testEditAllFloorGrantsEditToInternalUser() {
		setUpMocks();
		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		GoogleCloudTestFactory.setPrivilegedFloor(GoogleFileAccessResolver.AccessLevel.Edit);

		Assert.areEqual('Edit', resolveLevelFor(targetUserId, new List<GoogleFileLink__c>()));
	}

	@IsTest
	private static void testFloorNeverDowngradesAnOwner() {
		setUpMocks();
		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		GoogleCloudTestFactory.setPrivilegedFloor(GoogleFileAccessResolver.AccessLevel.View);

		List<GoogleFile__c> accessibleFiles = new GoogleFileAccessResolver()
			.resolveAccessibleFiles(fileOwnedBy(targetUserId), targetUserId);

		Assert.areEqual('Edit', accessibleFiles[0].UserAccessLevel__c);
	}

	@IsTest
	private static void testFloorIsNotAppliedToExternalUsers() {
		setUpMocks();
		Id externalUserId = GoogleCloudTestFactory.mockExternalUser();
		GoogleCloudTestFactory.setPrivilegedFloor(GoogleFileAccessResolver.AccessLevel.Edit);

		Assert.isNull(resolveLevelFor(externalUserId, new List<GoogleFileLink__c>()));
	}

	@IsTest
	private static void testResolveAccessibleFilesReturnsEmptyForEmptyInput() {
		setUpMocks();
		GoogleFileAccessResolver accessResolver = new GoogleFileAccessResolver();

		Assert.areEqual(0, accessResolver.resolveAccessibleFiles(null, UserInfo.getUserId()).size());
		Assert.areEqual(0, accessResolver.resolveAccessibleFiles(new List<GoogleFile__c>(), UserInfo.getUserId()).size());
	}

	@IsTest
	private static void testUnknownTargetUserIsRejected() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.denyAllRecordAccess();
		fileId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		ownerId = GoogleCloudTestFactory.fakeId(User.SObjectType);

		try {
			new GoogleFileAccessResolver().resolveAccessibleFiles(fileOwnedBy(ownerId), GoogleCloudTestFactory.fakeId(User.SObjectType));
			Assert.fail('An unresolvable target user must be rejected');
		} catch (GoogleFileAccessResolver.GoogleFileAccessCheckException ex) {
			Assert.isTrue(ex.getMessage().contains('Target user was not found'));
		}
	}

	@IsTest
	private static void testResolveReadableRecordLinksKeepsOnlyReachableRecords() {
		setUpMocks();
		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		Id reachableRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		Id unreachableRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleCloudTestFactory.grantRecordAccess(reachableRecordId, true, false);

		List<GoogleFileLink__c> readableLinks = new GoogleFileAccessResolver().resolveReadableRecordLinks(
			new List<GoogleFileLink__c>{
				linkTo(reachableRecordId, 'Viewer', 'AllUsers'),
				linkTo(unreachableRecordId, 'Viewer', 'AllUsers')
			},
			targetUserId
		);

		Assert.areEqual(1, readableLinks.size());
		Assert.areEqual(String.valueOf(reachableRecordId), readableLinks[0].LinkedObjectId__c);
	}

	@IsTest
	private static void testResolveAccessibleRecordLinksHonoursShareType() {
		setUpMocks();
		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		Id reachableRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleCloudTestFactory.grantRecordAccess(reachableRecordId, true, true);

		List<GoogleFileLink__c> accessibleLinks = new GoogleFileAccessResolver().resolveAccessibleRecordLinks(
			new List<GoogleFileLink__c>{
				linkTo(reachableRecordId, 'Viewer', 'AllUsers'),
				linkTo(reachableRecordId, 'None', 'AllUsers')
			},
			targetUserId
		);

		Assert.areEqual(1, accessibleLinks.size());
		Assert.areEqual('Viewer', accessibleLinks[0].ShareType__c);
	}

	@IsTest
	private static void testPrivilegedFloorIsMemoizedPerResolver() {
		setUpMocks();
		GoogleCloudTestFactory.setPrivilegedFloor(GoogleFileAccessResolver.AccessLevel.Edit);

		GoogleFileAccessResolver accessResolver = new GoogleFileAccessResolver();
		Assert.areEqual(GoogleFileAccessResolver.AccessLevel.Edit, accessResolver.privilegedFloor());
		Assert.areEqual(GoogleFileAccessResolver.AccessLevel.Edit, accessResolver.privilegedFloor());
	}

	@IsTest
	private static void testNoPrivilegedFloorByDefault() {
		setUpMocks();
		GoogleCloudTestFactory.setPrivilegedFloor(null);

		Assert.isNull(new GoogleFileAccessResolver().privilegedFloor());
	}

	private static void setUpRealRecords() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();
		GoogleCloudTestFactory.denyAllRecordAccess();
	}

	private static GoogleFile__c insertNamedFile(String fileName) {
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName(fileName).insertRecord();
		GoogleCloudTestFactory.version().forFile(localFile.Id).withName(fileName + '.pdf').isLatest(true).insertRecord();
		return localFile;
	}

	private static GoogleFileAccessResolver.FilePageCriteria sortedByName(Integer pageSize) {
		GoogleFileAccessResolver.FilePageCriteria criteria = new GoogleFileAccessResolver.FilePageCriteria();
		criteria.pageSize = pageSize;
		criteria.sortPath = 'Name';
		criteria.sortDirection = 'ASC';
		return criteria;
	}

	private static List<Id> idsOf(List<GoogleFile__c> files) {
		List<Id> fileIds = new List<Id>();
		for (GoogleFile__c localFile : files) {
			fileIds.add(localFile.Id);
		}
		return fileIds;
	}

	@IsTest
	private static void testResolveFilePagePositiveSearchPagesWithoutRepeatsOrGapsPastHiddenFiles() {
		setUpRealRecords();
		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		GoogleCloudTestFactory.mockNoGroupMemberships();
		Id readableRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		Id hiddenRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleCloudTestFactory.grantRecordAccess(readableRecordId, true, false);
		GoogleFileAccessResolver.WIDE_SCAN_SIZE = 3;

		List<GoogleFile__c> files = new List<GoogleFile__c>();
		for (Integer i = 1; i <= 10; i++) {
			files.add(GoogleCloudTestFactory.file().withName('Match ' + String.valueOf(i).leftPad(2, '0')).build());
		}
		for (Integer i = 1; i <= 3; i++) {
			files.add(GoogleCloudTestFactory.file().withName('Other ' + i).build());
		}
		insert files;

		List<GoogleFileVersion__c> versions = new List<GoogleFileVersion__c>();
		List<GoogleFileLink__c> links = new List<GoogleFileLink__c>();
		List<Id> expectedIds = new List<Id>();
		for (Integer i = 0; i < files.size(); i++) {
			GoogleFile__c localFile = files[i];
			Boolean isMatch = localFile.Name.startsWith('Match');
			Boolean isReachable = !isMatch || Math.mod(i, 2) == 0;

			versions.add(GoogleCloudTestFactory.version().forFile(localFile.Id).withName(localFile.Name + '.pdf').isLatest(true).build());
			links.add(GoogleCloudTestFactory.link().forFile(localFile.Id).withLinkedRecord(isReachable ? readableRecordId : hiddenRecordId).withShareType('Viewer').build());

			if (isMatch && isReachable) expectedIds.add(localFile.Id);
		}
		insert versions;
		insert links;

		GoogleFileAccessResolver.FilePageCriteria criteria = sortedByName(2);
		criteria.searchPhrases = new List<String>{ 'match' };

		List<Id> seenIds = new List<Id>();
		for (Integer page = 0; page < 12; page++) {
			GoogleFileAccessResolver.FilePage result = new GoogleFileAccessResolver().resolveFilePage(criteria, targetUserId);
			seenIds.addAll(idsOf(result.records));

			if (!result.hasMore) break;

			criteria.cursorId = result.cursorRow.Id;
			criteria.cursorValue = result.cursorRow.Name;
		}

		Assert.areEqual(5, expectedIds.size());
		Assert.areEqual(expectedIds, seenIds, 'Every reachable match once, in name order, with no hidden file and no gap');
	}

	@IsTest
	private static void testResolveFilePagePositiveBlankSearchFieldsKeepTodaysPage() {
		setUpRealRecords();

		GoogleFile__c alpha = insertNamedFile('Alpha');
		GoogleFile__c bravo = GoogleCloudTestFactory.file().withName('Bravo').insertRecord();
		GoogleFile__c charlie = insertNamedFile('Charlie');

		GoogleFileAccessResolver.FilePageCriteria criteria = sortedByName(50);
		criteria.searchPhrases = new List<String>();
		criteria.fileExtensions = new Set<String>();
		criteria.ownerFilter = GoogleFileAccessResolver.OwnershipScope.AnyOwner;

		GoogleFileAccessResolver.FilePage page = new GoogleFileAccessResolver().resolveFilePage(criteria, UserInfo.getUserId());

		Assert.areEqual(new List<Id>{ alpha.Id, bravo.Id, charlie.Id }, idsOf(page.records), 'Blank search fields must not narrow the page, not even to files with a current version');
		Assert.isFalse(page.hasMore);
	}

	@IsTest
	private static void testResolveFilePagePositiveOwnerFilterNarrowsPrivilegedUsers() {
		setUpRealRecords();
		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		GoogleCloudTestFactory.setPrivilegedFloor(GoogleFileAccessResolver.AccessLevel.View);

		GoogleFile__c someoneElsesFile = insertNamedFile('Owned By The Running User');

		GoogleFileAccessResolver.FilePageCriteria mine = sortedByName(50);
		mine.ownerFilter = GoogleFileAccessResolver.OwnershipScope.OwnedByUser;
		GoogleFileAccessResolver.FilePageCriteria others = sortedByName(50);
		others.ownerFilter = GoogleFileAccessResolver.OwnershipScope.NotOwnedByUser;
		GoogleFileAccessResolver.FilePageCriteria ownedBucket = sortedByName(50);
		ownedBucket.ownerScope = GoogleFileAccessResolver.OwnershipScope.OwnedByUser;

		GoogleFileAccessResolver.FilePage minePage = new GoogleFileAccessResolver().resolveFilePage(mine, targetUserId);
		GoogleFileAccessResolver.FilePage othersPage = new GoogleFileAccessResolver().resolveFilePage(others, targetUserId);
		GoogleFileAccessResolver.FilePage ownedBucketPage = new GoogleFileAccessResolver().resolveFilePage(ownedBucket, targetUserId);

		Assert.isTrue(minePage.records.isEmpty(), 'The owner filter narrows a View All user to their own files');
		Assert.areEqual(new List<Id>{ someoneElsesFile.Id }, idsOf(othersPage.records));
		Assert.areEqual('View', othersPage.records[0].UserAccessLevel__c);
		Assert.areEqual(new List<Id>{ someoneElsesFile.Id }, idsOf(ownedBucketPage.records), 'The owned bucket still lists every owner for a View All user, as All Files does on open');
	}

	@IsTest
	private static void testResolveFilePagePositiveOwnerFilterNarrowsUsersWithoutTheFloor() {
		setUpRealRecords();
		Id targetUserId = GoogleCloudTestFactory.mockInternalUser();
		Id readableRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleCloudTestFactory.grantRecordAccess(readableRecordId, true, false);

		GoogleFile__c someoneElsesFile = insertNamedFile('Linked Elsewhere');
		GoogleCloudTestFactory.link().forFile(someoneElsesFile.Id).withLinkedRecord(readableRecordId).withShareType('Viewer').insertRecord();

		GoogleFileAccessResolver.FilePageCriteria mine = sortedByName(50);
		mine.ownerFilter = GoogleFileAccessResolver.OwnershipScope.OwnedByUser;
		GoogleFileAccessResolver.FilePageCriteria others = sortedByName(50);
		others.ownerFilter = GoogleFileAccessResolver.OwnershipScope.NotOwnedByUser;

		Assert.isTrue(new GoogleFileAccessResolver().resolveFilePage(mine, targetUserId).records.isEmpty());
		Assert.areEqual(new List<Id>{ someoneElsesFile.Id }, idsOf(new GoogleFileAccessResolver().resolveFilePage(others, targetUserId).records));
		Assert.areEqual(new List<Id>{ someoneElsesFile.Id }, idsOf(new GoogleFileAccessResolver().resolveFilePage(mine, UserInfo.getUserId()).records), 'The owner is the file owner, whoever is asking');
	}

	@IsTest
	private static void testResolveFilePagePositiveHeaderTermMustMatchTheSameVersionAsTheSearchCriteria() {
		setUpRealRecords();
		Long twoMebibytes = 2097152L;

		GoogleFile__c match = GoogleCloudTestFactory.file().withName('A Match').insertRecord();
		GoogleFile__c criteriaOnly = GoogleCloudTestFactory.file().withName('B Criteria Only').insertRecord();
		GoogleFile__c termOnly = GoogleCloudTestFactory.file().withName('C Term Only').insertRecord();
		GoogleFile__c splitAcrossVersions = GoogleCloudTestFactory.file().withName('D Split Across Versions').insertRecord();
		insert new List<GoogleFileVersion__c>{
			GoogleCloudTestFactory.version().forFile(match.Id).withName('Contract renewal.pdf').withSize(twoMebibytes).isLatest(true).build(),
			GoogleCloudTestFactory.version().forFile(criteriaOnly.Id).withName('Annual renewal.pdf').withSize(twoMebibytes).isLatest(true).build(),
			GoogleCloudTestFactory.version().forFile(termOnly.Id).withName('Contract notes.txt').withType(GoogleCloudConstants.MIME_TYPE_TEXT).withSize(100L).isLatest(true).build(),
			GoogleCloudTestFactory.version().forFile(splitAcrossVersions.Id).withName('Contract terms.txt').withType(GoogleCloudConstants.MIME_TYPE_TEXT).withSize(100L).isLatest(true).build(),
			GoogleCloudTestFactory.version().forFile(splitAcrossVersions.Id).withName('Spring renewal.pdf').withSize(twoMebibytes).isLatest(true).build()
		};

		GoogleFileAccessResolver.FilePageCriteria termAlone = sortedByName(50);
		termAlone.searchTerm = 'contract';
		GoogleFileAccessResolver.FilePageCriteria phraseAlone = sortedByName(50);
		phraseAlone.searchPhrases = new List<String>{ 'renewal' };
		GoogleFileAccessResolver.FilePageCriteria termAndPhrase = sortedByName(50);
		termAndPhrase.searchTerm = 'contract';
		termAndPhrase.searchPhrases = new List<String>{ 'renewal' };
		GoogleFileAccessResolver.FilePageCriteria termAndExtension = sortedByName(50);
		termAndExtension.searchTerm = 'contract';
		termAndExtension.fileExtensions = new Set<String>{ 'pdf' };
		GoogleFileAccessResolver.FilePageCriteria termAndSize = sortedByName(50);
		termAndSize.searchTerm = 'contract';
		termAndSize.minSizeBytes = 1048576;

		Assert.areEqual(
			new List<Id>{ match.Id, termOnly.Id, splitAcrossVersions.Id },
			idsOf(new GoogleFileAccessResolver().resolveFilePage(termAlone, UserInfo.getUserId()).records),
			'The term alone finds every file with a current version containing it'
		);
		Assert.areEqual(
			new List<Id>{ match.Id, criteriaOnly.Id, splitAcrossVersions.Id },
			idsOf(new GoogleFileAccessResolver().resolveFilePage(phraseAlone, UserInfo.getUserId()).records),
			'The phrase alone finds every file with a current version containing it'
		);
		Assert.areEqual(
			new List<Id>{ match.Id },
			idsOf(new GoogleFileAccessResolver().resolveFilePage(termAndPhrase, UserInfo.getUserId()).records),
			'With a phrase, the term is one more phrase on the same current version, never dropped and never a separate match'
		);
		Assert.areEqual(
			new List<Id>{ match.Id },
			idsOf(new GoogleFileAccessResolver().resolveFilePage(termAndExtension, UserInfo.getUserId()).records),
			'With an extension, the term must match the same current version as the extension'
		);
		Assert.areEqual(
			new List<Id>{ match.Id },
			idsOf(new GoogleFileAccessResolver().resolveFilePage(termAndSize, UserInfo.getUserId()).records),
			'With a size bound, the term must match the same current version as the size'
		);
	}

	private static Map<String, Object> ownerRow(Id rowOwnerId, String ownerName) {
		return new Map<String, Object>{
			GoogleFileSelector.OWNER_ID_KEY => rowOwnerId,
			GoogleFileSelector.OWNER_NAME_KEY => ownerName
		};
	}

	private static GoogleFile__c candidateOwnedBy(Id fileOwnerId, String ownerName) {
		return (GoogleFile__c) JSON.deserialize(
			JSON.serialize(new Map<String, Object>{
				'attributes' => new Map<String, Object>{ 'type' => 'GoogleFile__c' },
				'Id' => GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType),
				'OwnerId' => fileOwnerId,
				'Owner' => new Map<String, Object>{
					'attributes' => new Map<String, Object>{ 'type' => 'Name' },
					'Id' => fileOwnerId,
					'Name' => ownerName
				}
			}),
			GoogleFile__c.class
		);
	}

	private static GoogleFileLink__c candidateLink(Id candidateFileId, Id linkedRecordId, String visibility) {
		return new GoogleFileLink__c(
			Id = GoogleCloudTestFactory.fakeId(GoogleFileLink__c.SObjectType),
			GoogleFileId__c = candidateFileId,
			LinkedObjectId__c = String.valueOf(linkedRecordId),
			LinkedObjectType__c = 'GoogleFile__c',
			ShareType__c = 'Viewer',
			Visibility__c = visibility
		);
	}

	private static List<Id> ownerIdsOf(List<GoogleFileAccessResolver.FileOwner> owners) {
		List<Id> ownerIds = new List<Id>();
		for (GoogleFileAccessResolver.FileOwner fileOwner : owners) {
			ownerIds.add(fileOwner.ownerId);
		}
		return ownerIds;
	}

	private static List<String> ownerNamesOf(List<GoogleFileAccessResolver.FileOwner> owners) {
		List<String> ownerNames = new List<String>();
		for (GoogleFileAccessResolver.FileOwner fileOwner : owners) {
			ownerNames.add(fileOwner.name);
		}
		return ownerNames;
	}

	@IsTest
	private static void testResolveAccessibleFileOwnersPositivePrivilegedUserGetsEveryOwnerSortedAndCapped() {
		setUpMocks();
		GoogleCloudTestFactory.mockInternalUser();
		Id carolId = GoogleCloudTestFactory.fakeId(User.SObjectType);
		Id accountsQueueId = GoogleCloudTestFactory.fakeId('00G');
		Id bobId = GoogleCloudTestFactory.fakeId(User.SObjectType);
		Id aliceId = GoogleCloudTestFactory.fakeId(User.SObjectType);
		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(new List<Map<String, Object>>{
			ownerRow(carolId, 'carol Xu'),
			ownerRow(accountsQueueId, 'ACCOUNTS Queue'),
			ownerRow(bobId, 'Bob Young'),
			ownerRow(aliceId, 'alice Zimmer')
		});

		for (GoogleFileAccessResolver.AccessLevel floor : new List<GoogleFileAccessResolver.AccessLevel>{ GoogleFileAccessResolver.AccessLevel.View, GoogleFileAccessResolver.AccessLevel.Edit }) {
			GoogleCloudTestFactory.setPrivilegedFloor(floor);

			List<GoogleFileAccessResolver.FileOwner> everyOwner = new GoogleFileAccessResolver().resolveAccessibleFileOwners(10);
			List<GoogleFileAccessResolver.FileOwner> cappedOwners = new GoogleFileAccessResolver().resolveAccessibleFileOwners(3);

			Assert.areEqual(new List<Id>{ accountsQueueId, aliceId, bobId, carolId }, ownerIdsOf(everyOwner), 'Every owner, users and queues alike, sorted by name ignoring case, for ' + floor);
			Assert.areEqual(new List<String>{ 'ACCOUNTS Queue', 'alice Zimmer', 'Bob Young', 'carol Xu' }, ownerNamesOf(everyOwner));
			Assert.areEqual(new List<Id>{ accountsQueueId, aliceId, bobId }, ownerIdsOf(cappedOwners), 'At most maxOwners, the first by name, for ' + floor);
		}
	}

	@IsTest
	private static void testResolveAccessibleFileOwnersPositiveUserWithoutTheFloorGetsOnlyOwnersOfFilesTheyCanOpen() {
		setUpMocks();
		GoogleCloudTestFactory.mockNoGroupMemberships();
		Id runningUserId = UserInfo.getUserId();
		Id sharingOwnerId = GoogleCloudTestFactory.fakeId(User.SObjectType);
		Id hiddenOwnerId = GoogleCloudTestFactory.fakeId(User.SObjectType);
		Id hiddenRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);

		GoogleFile__c ownFile = candidateOwnedBy(runningUserId, 'Running User');
		GoogleFile__c sharedFile = candidateOwnedBy(sharingOwnerId, 'Sharing Owner');
		GoogleFile__c secondSharedFile = candidateOwnedBy(sharingOwnerId, 'Sharing Owner');
		GoogleFile__c hiddenFile = candidateOwnedBy(hiddenOwnerId, 'Hidden Owner');
		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(new List<SObject>{ hiddenFile, sharedFile, ownFile, secondSharedFile });
		GoogleCloudTestFactory.mockShares(new List<GoogleFile__Share>{
			GoogleCloudTestFactory.share().forFile(sharedFile.Id).sharedWith(runningUserId).withAccessLevel('Read').build(),
			GoogleCloudTestFactory.share().forFile(secondSharedFile.Id).sharedWith(runningUserId).withAccessLevel('Read').build()
		});
		GoogleCloudTestFactory.mockLinks(new List<GoogleFileLink__c>{ candidateLink(hiddenFile.Id, hiddenRecordId, 'AllUsers') });

		List<GoogleFileAccessResolver.FileOwner> owners = new GoogleFileAccessResolver().resolveAccessibleFileOwners(200);

		Assert.areEqual(new List<Id>{ runningUserId, sharingOwnerId }, ownerIdsOf(owners), 'The user as an owner, then the owner who shared with them, once each; never the owner of a file on a record they cannot open');
		Assert.areEqual(new List<String>{ 'Running User', 'Sharing Owner' }, ownerNamesOf(owners));
		Assert.isFalse(new Set<Id>(ownerIdsOf(owners)).contains(hiddenOwnerId));
	}

	@IsTest
	private static void testResolveAccessibleFileOwnersNegativeExternalUserWithViewAllIsResolvedLikeAnyoneElse() {
		setUpMocks();
		GoogleCloudTestFactory.mockExternalUser();
		GoogleCloudTestFactory.mockNoGroupMemberships();
		GoogleCloudTestFactory.mockShares(new List<GoogleFile__Share>());
		GoogleCloudTestFactory.setPrivilegedFloor(GoogleFileAccessResolver.AccessLevel.View);
		Id everyoneOwnerId = GoogleCloudTestFactory.fakeId(User.SObjectType);
		Id unreachableOwnerId = GoogleCloudTestFactory.fakeId(User.SObjectType);
		Id internalOnlyOwnerId = GoogleCloudTestFactory.fakeId(User.SObjectType);
		Id readableRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleCloudTestFactory.grantRecordAccess(readableRecordId, true, false);

		GoogleFile__c everyoneFile = candidateOwnedBy(everyoneOwnerId, 'Everyone Owner');
		GoogleFile__c unreachableFile = candidateOwnedBy(unreachableOwnerId, 'Unreachable Owner');
		GoogleFile__c internalOnlyFile = candidateOwnedBy(internalOnlyOwnerId, 'Internal Only Owner');
		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(new List<SObject>{ unreachableFile, internalOnlyFile, everyoneFile });
		GoogleCloudTestFactory.mockLinks(new List<GoogleFileLink__c>{
			candidateLink(everyoneFile.Id, readableRecordId, 'AllUsers'),
			candidateLink(internalOnlyFile.Id, readableRecordId, 'InternalUsers')
		});

		List<GoogleFileAccessResolver.FileOwner> owners = new GoogleFileAccessResolver().resolveAccessibleFileOwners(200);

		Assert.areEqual(new List<Id>{ everyoneOwnerId }, ownerIdsOf(owners), 'View All gives an external user no owner of a file they cannot open');
		Assert.areEqual(new List<String>{ 'Everyone Owner' }, ownerNamesOf(owners));
	}

	@IsTest
	private static void testResolveAccessibleFileOwnersNegativeNoOwnersAskedForReturnsNone() {
		setUpMocks();

		Assert.isTrue(new GoogleFileAccessResolver().resolveAccessibleFileOwners(null).isEmpty());
		Assert.isTrue(new GoogleFileAccessResolver().resolveAccessibleFileOwners(0).isEmpty());
	}

	@IsTest
	private static void testResolveFilePagePositiveOwnerIdKeepsOnlyThatOwnersFiles() {
		setUpRealRecords();

		GoogleFile__c alpha = insertNamedFile('Alpha');
		GoogleFile__c bravo = insertNamedFile('Bravo');

		GoogleFileAccessResolver.FilePageCriteria runningUsersFiles = sortedByName(50);
		runningUsersFiles.ownerId = UserInfo.getUserId();
		GoogleFileAccessResolver.FilePageCriteria anotherOwnersFiles = sortedByName(50);
		anotherOwnersFiles.ownerId = GoogleCloudTestFactory.otherUserId();
		GoogleFileAccessResolver.FilePageCriteria aQueuesFiles = sortedByName(50);
		aQueuesFiles.ownerId = GoogleCloudTestFactory.fakeId('00G');

		Assert.areEqual(new List<Id>{ alpha.Id, bravo.Id }, idsOf(new GoogleFileAccessResolver().resolveFilePage(runningUsersFiles, UserInfo.getUserId()).records), 'The running user\'s Id keeps their files');
		Assert.isTrue(new GoogleFileAccessResolver().resolveFilePage(anotherOwnersFiles, UserInfo.getUserId()).records.isEmpty(), 'Another owner\'s Id keeps none of them');
		Assert.isTrue(new GoogleFileAccessResolver().resolveFilePage(aQueuesFiles, UserInfo.getUserId()).records.isEmpty());

		GoogleCloudTestFactory.setPrivilegedFloor(GoogleFileAccessResolver.AccessLevel.View);

		Assert.areEqual(new List<Id>{ alpha.Id, bravo.Id }, idsOf(new GoogleFileAccessResolver().resolveFilePage(runningUsersFiles, UserInfo.getUserId()).records));
		Assert.isTrue(new GoogleFileAccessResolver().resolveFilePage(anotherOwnersFiles, UserInfo.getUserId()).records.isEmpty(), 'The owner only narrows, View All users included');
	}
}
