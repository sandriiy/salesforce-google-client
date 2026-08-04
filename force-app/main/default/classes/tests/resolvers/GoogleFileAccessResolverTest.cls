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
}
