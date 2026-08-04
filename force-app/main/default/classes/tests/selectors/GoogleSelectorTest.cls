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
private class GoogleSelectorTest {
	@IsTest
	private static void testUserSelectorResolvesTheRunningUser() {
		List<User> users = (List<User>) GoogleUserSelector.query()
			.withTypeFields()
			.byUserId(UserInfo.getUserId())
			.limitTo(1)
			.toList();

		Assert.areEqual(1, users.size());
		Assert.areEqual(UserInfo.getUserId(), users[0].Id);
		Assert.isTrue(String.isNotBlank(users[0].UserType));
	}

	@IsTest
	private static void testUserSelectorNameAndContactFields() {
		List<User> namedUsers = (List<User>) GoogleUserSelector.query()
			.withNameFields()
			.byUserIds(new Set<Id>{ UserInfo.getUserId() })
			.toList();

		List<User> contactableUsers = (List<User>) GoogleUserSelector.query()
			.withContactFields()
			.byUserId(UserInfo.getUserId())
			.toList();

		Assert.areEqual(1, namedUsers.size());
		Assert.areEqual(UserInfo.getLastName(), namedUsers[0].LastName);
		Assert.areEqual(1, contactableUsers.size());
		Assert.areEqual(UserInfo.getName(), contactableUsers[0].Name);
	}

	@IsTest
	private static void testUserSelectorIsMockable() {
		Id mockedUserId = GoogleCloudTestFactory.mockInternalUser();

		List<User> users = (List<User>) GoogleUserSelector.query()
			.withTypeFields()
			.byUserId(UserInfo.getUserId())
			.toList();

		Assert.areEqual(1, users.size());
		Assert.areEqual(mockedUserId, users[0].Id);
	}

	@IsTest
	private static void testFileShareSelectorExcludesTheOwnerShare() {
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('Shared Selector File').insertRecord();

		List<GoogleFile__Share> allShares = (List<GoogleFile__Share>) GoogleFileShareSelector.query()
			.withBaseFields()
			.byParentId(localFile.Id)
			.toList();

		List<GoogleFile__Share> nonOwnerShares = (List<GoogleFile__Share>) GoogleFileShareSelector.query()
			.withBaseFields()
			.byParentId(localFile.Id)
			.excludingPrincipalId(UserInfo.getUserId())
			.toList();

		Assert.isFalse(allShares.isEmpty());
		Assert.areEqual(0, nonOwnerShares.size());
	}

	@IsTest
	private static void testFileShareSelectorExcludesImplicitOwnerShares() {
		GoogleCloudTestFactory.file().withName('Owner Share File').insertRecord();

		List<GoogleFile__Share> ownerShares = (List<GoogleFile__Share>) GoogleFileShareSelector.query()
			.withBaseFields()
			.byPrincipalIds(new Set<Id>{ UserInfo.getUserId() })
			.toList();

		List<GoogleFile__Share> realShares = (List<GoogleFile__Share>) GoogleFileShareSelector.query()
			.withBaseFields()
			.byPrincipalIds(new Set<Id>{ UserInfo.getUserId() })
			.excludingOwnerShares()
			.toList();

		Assert.isFalse(ownerShares.isEmpty(), 'A privately shared object always carries an implicit owner share');
		Assert.areEqual(0, realShares.size(), 'Owner rows must not be counted as files shared with the user');
	}

	@IsTest
	private static void testFileShareSelectorIsMockable() {
		Id fileId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		Id principalId = GoogleCloudTestFactory.fakeId(User.SObjectType);
		GoogleCloudTestFactory.mockShares(new List<GoogleFile__Share>{
			GoogleCloudTestFactory.share().forFile(fileId).sharedWith(principalId).withAccessLevel('Edit').build()
		});

		List<GoogleFile__Share> shares = (List<GoogleFile__Share>) GoogleFileShareSelector.query()
			.withPrincipalName()
			.byParentIds(new Set<Id>{ fileId })
			.byPrincipalIds(new Set<Id>{ principalId })
			.limitTo(10)
			.toList();

		Assert.areEqual(1, shares.size());
		Assert.areEqual('Edit', shares[0].AccessLevel);
	}

	@IsTest
	private static void testGroupMemberSelectorRunsAndIsMockable() {
		List<GroupMember> realMemberships = (List<GroupMember>) GoogleGroupMemberSelector.query()
			.withGroupFields()
			.byMemberId(UserInfo.getUserId())
			.byShareableGroupTypes()
			.toList();

		Assert.isNotNull(realMemberships);

		GoogleCloudTestFactory.mockNoGroupMemberships();
		List<GroupMember> mockedMemberships = (List<GroupMember>) GoogleGroupMemberSelector.query()
			.withGroupFields()
			.byMemberId(UserInfo.getUserId())
			.toList();

		Assert.areEqual(0, mockedMemberships.size());
	}

	@IsTest
	private static void testLinkedRecordSelectorResolvesPackageRecords() {
		GoogleFile__c firstFile = GoogleCloudTestFactory.file().withName('Linked Selector One').insertRecord();
		GoogleFile__c secondFile = GoogleCloudTestFactory.file().withName('Linked Selector Two').insertRecord();

		Map<Id, SObject> recordsById = GoogleFileLinkedRecordSelector.selectByIds(
			new Set<Id>{ firstFile.Id, secondFile.Id },
			new List<String>{ 'Name' }
		);

		Assert.areEqual(2, recordsById.size());
		Assert.areEqual('Linked Selector One', (String) recordsById.get(firstFile.Id).get('Name'));
		Assert.areEqual('Linked Selector Two', (String) recordsById.get(secondFile.Id).get('Name'));
	}

	@IsTest
	private static void testLinkedRecordSelectorIsMockable() {
		Id linkedRecordId = GoogleCloudTestFactory.linkedRecord('Mocked Linked Record');

		SObject record = GoogleFileLinkedRecordSelector.selectById(linkedRecordId, new List<String>{ 'Name' });

		Assert.isNotNull(record);
		Assert.areEqual('Mocked Linked Record', (String) record.get('Name'));
	}

	@IsTest
	private static void testLinkedRecordSelectorHandlesEmptyInput() {
		Assert.areEqual(0, GoogleFileLinkedRecordSelector.selectByIds(new Set<Id>()).size());
		Assert.areEqual(0, GoogleFileLinkedRecordSelector.selectByIds(null, new List<String>{ 'Name' }).size());
		Assert.isNull(GoogleFileLinkedRecordSelector.selectById(null, new List<String>{ 'Name' }));
	}

	@IsTest
	private static void testFileSelectorOwnerOnlyProjection() {
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('Owner Projection File').insertRecord();

		List<GoogleFile__c> files = (List<GoogleFile__c>) GoogleFileSelector.query()
			.withOwnerOnly()
			.byIds(new Set<Id>{ localFile.Id })
			.toList();

		Assert.areEqual(1, files.size());
		Assert.areEqual(UserInfo.getUserId(), files[0].OwnerId);
	}

	@IsTest
	private static void testFileLinkSelectorCombinesParentAndLinkedRecordFilters() {
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('Link Filter File').insertRecord();
		Id linkedRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		Id otherRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);

		GoogleCloudTestFactory.link().forFile(localFile.Id).withLinkedRecord(linkedRecordId).insertRecord();
		GoogleCloudTestFactory.link().forFile(localFile.Id).withLinkedRecord(otherRecordId).insertRecord();

		List<GoogleFileLink__c> links = (List<GoogleFileLink__c>) GoogleFileLinkSelector.query()
			.withBaseFields()
			.byParentId(localFile.Id)
			.byLinkedObjectId(linkedRecordId)
			.toList();

		Assert.areEqual(1, links.size());
		Assert.areEqual(String.valueOf(linkedRecordId), links[0].LinkedObjectId__c);
	}

	@IsTest
	private static void testFileSelectorSearchMatchesLatestVersionNameAndSummary() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();

		GoogleFile__c namedFile = GoogleCloudTestFactory.file().withName('Search Parent One').insertRecord();
		GoogleFile__c summaryFile = GoogleCloudTestFactory.file().withName('Search Parent Two').insertRecord();

		GoogleCloudTestFactory.version().forFile(namedFile.Id).withName('Quarterly Forecast.pdf').isLatest(true).insertRecord();
		GoogleCloudTestFactory.version().forFile(summaryFile.Id).withName('untitled.pdf').withSummary('Discusses the quarterly forecast').isLatest(true).insertRecord();

		Set<Id> matchedByName = new Map<Id, GoogleFile__c>(
			(List<GoogleFile__c>) GoogleFileSelector.query().withBaseFields().bySearchTerm('Forecast').toList()
		).keySet();

		Assert.isTrue(matchedByName.contains(namedFile.Id), 'Search must match the latest version name');
		Assert.isTrue(matchedByName.contains(summaryFile.Id), 'Search must match the AI summary');
	}

	@IsTest
	private static void testFileSelectorSearchEscapesLikeWildcards() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();

		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('Wildcard Parent').insertRecord();
		GoogleCloudTestFactory.version().forFile(localFile.Id).withName('plain-name.pdf').isLatest(true).insertRecord();

		List<GoogleFile__c> matched = (List<GoogleFile__c>) GoogleFileSelector.query()
			.withBaseFields()
			.bySearchTerm('%')
			.toList();

		Assert.areEqual(0, matched.size(), 'A bare percent sign must be treated as a literal, not as match-everything');
	}

	@IsTest
	private static void testFileSelectorOwnershipFiltersSplitOnRealOwner() {
		GoogleFile__c ownedFile = GoogleCloudTestFactory.file().withName('Ownership Filter File').insertRecord();

		List<GoogleFile__c> owned = (List<GoogleFile__c>) GoogleFileSelector.query()
			.withBaseFields()
			.byOwner(UserInfo.getUserId())
			.toList();

		List<GoogleFile__c> notOwned = (List<GoogleFile__c>) GoogleFileSelector.query()
			.withBaseFields()
			.byOwnerOtherThan(UserInfo.getUserId())
			.toList();

		Assert.isTrue(new Map<Id, GoogleFile__c>(owned).containsKey(ownedFile.Id), 'byOwner must contain files owned by the user');
		Assert.isFalse(new Map<Id, GoogleFile__c>(notOwned).containsKey(ownedFile.Id), 'byOwnerOtherThan must exclude files owned by the user');
	}

	@IsTest
	private static void testFileSelectorAccessibleCandidatesCoversOwnerAndLinkedFiles() {
		GoogleFile__c ownedFile = GoogleCloudTestFactory.file().withName('Candidate Owned').insertRecord();
		GoogleFile__c linkedFile = GoogleCloudTestFactory.file().withName('Candidate Linked').insertRecord();
		GoogleCloudTestFactory.link().forFile(linkedFile.Id).withLinkedRecord(GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType)).insertRecord();

		Set<Id> ownedCandidateIds = new Map<Id, GoogleFile__c>(
			(List<GoogleFile__c>) GoogleFileSelector.query()
				.withBaseFields()
				.byAccessibleCandidates(UserInfo.getUserId(), new Set<Id>())
				.toList()
		).keySet();

		Set<Id> linkOnlyCandidateIds = new Map<Id, GoogleFile__c>(
			(List<GoogleFile__c>) GoogleFileSelector.query()
				.withBaseFields()
				.byAccessibleCandidates(GoogleCloudTestFactory.otherUserId(), new Set<Id>())
				.toList()
		).keySet();

		Assert.isTrue(ownedCandidateIds.contains(ownedFile.Id), 'Owned files must be candidates');
		Assert.isTrue(linkOnlyCandidateIds.contains(linkedFile.Id), 'Files carrying record links must be candidates');
		Assert.isFalse(linkOnlyCandidateIds.contains(ownedFile.Id), 'A link-less file owned by somebody else must not be a candidate');
	}
}
