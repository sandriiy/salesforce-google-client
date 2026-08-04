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
public without sharing class GoogleFileAccessResolver {
	public class GoogleFileAccessCheckException extends Exception {}
	public enum AccessLevel { View, Edit }
	public enum OwnershipScope { AnyOwner, OwnedByUser, NotOwnedByUser }

	private static final String PERMISSION_VIEW_ALL_ACCESS = 'GoogleClientViewAllAccess';
	private static final String PERMISSION_EDIT_ALL_ACCESS = 'GoogleClientEditAllAccess';

	private static final Integer HAS_MORE_FLAG_ROW = 1;
	private static final Integer MAX_SHARED_CANDIDATE_IDS = 5000;
	private static final Integer MAX_CANDIDATE_FILES = 10000;
	@TestVisible
	private static Integer WIDE_SCAN_SIZE = 1000;
	private static final Integer DEFAULT_PAGE_SIZE = 50;
	private static final Integer MAX_PAGE_SIZE = 200;
	private static final String DEFAULT_SORT_PATH = 'LastModifiedDate';

	@TestVisible
	private static AccessLevel privilegedFloorOverride;
	@TestVisible
	private static Boolean privilegedFloorOverrideSet = false;

	private AccessLevel memoFloor;
	private Boolean floorResolved = false;
	private Map<Id, Set<Id>> memoPrincipalIdsByUserId = new Map<Id, Set<Id>>();

	public List<GoogleFile__c> resolveAccessibleFiles(List<GoogleFile__c> inputFiles, Id targetUserId) {
		return resolveAccessibleFiles(inputFiles, targetUserId, null);
	}

	public List<GoogleFile__c> resolveAccessibleFiles(List<GoogleFile__c> inputFiles, Id targetUserId, List<GoogleFileLink__c> scopedRecordLinks) {
		if (inputFiles == null || inputFiles.isEmpty()) return new List<GoogleFile__c>();
		if (targetUserId == null) targetUserId = UserInfo.getUserId();

		Set<Id> fileIds = extractFileIds(inputFiles);
		if (fileIds.isEmpty()) return new List<GoogleFile__c>();

		User targetUser = loadTargetUser(targetUserId);
		Boolean isInternalUser = isInternalUserType(targetUser.UserType);

		Map<Id, Id> fileIdToOwnerId = loadFileOwners(fileIds, inputFiles);

		Set<Id> nonOwnedFileIds = new Set<Id>();

		for (Id fileId : fileIds) {
			Id ownerId = fileIdToOwnerId.get(fileId);
			if (ownerId == null || ownerId != targetUserId) {
				nonOwnedFileIds.add(fileId);
			}
		}

		Map<Id, List<GoogleFile__Share>> fileIdToShares = new Map<Id, List<GoogleFile__Share>>();
		Map<Id, List<GoogleFileLink__c>> fileIdToLinks = new Map<Id, List<GoogleFileLink__c>>();
		Map<Id, GoogleRecordAccessDTO> parentAccessByRecordId = new Map<Id, GoogleRecordAccessDTO>();

		if (!nonOwnedFileIds.isEmpty()) {
			fileIdToShares = loadSharesForUserAndGroups(nonOwnedFileIds, targetUserId);

			Logger.info('Files Access Check: ' + fileIdToOwnerId.keySet()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

			LinkCompilationResult linkData = scopedRecordLinks == null
				? loadLinks(nonOwnedFileIds)
				: compileLinks(scopedRecordLinks, nonOwnedFileIds);
			fileIdToLinks = linkData.linksByFileId;
			parentAccessByRecordId = loadUserRecordAccess(targetUserId, linkData.linkedRecordIds);
		}

		return resolveAccessibleFilesInternal(
			inputFiles,
			targetUserId,
			isInternalUser,
			fileIdToOwnerId,
			fileIdToShares,
			fileIdToLinks,
			parentAccessByRecordId
		);
	}

	/**
	 * Deprecated. Use resolveFilePage(...) instead.
	 */
	public List<GoogleFile__c> resolveAccessibleFilesForUser(Id targetUserId) {
		return resolveAccessibleFilesForUser(targetUserId, new List<String>());
	}

	public List<GoogleFile__c> resolveAccessibleFilesForUser(Id targetUserId, List<String> additionalVersionFields) {
		if (targetUserId == null) targetUserId = UserInfo.getUserId();

		Set<Id> userAndGroupIds = resolvePrincipalIds(targetUserId);
		List<GoogleFile__c> candidateFiles = resolveAccessibleCandidateFiles(targetUserId, userAndGroupIds, additionalVersionFields);

		if (candidateFiles.isEmpty()) return new List<GoogleFile__c>();
		return resolveAccessibleFiles(candidateFiles, targetUserId);
	}

	public AccessLevel privilegedFloor() {
		if (floorResolved) return memoFloor;
		floorResolved = true;

		if (privilegedFloorOverrideSet) {
			memoFloor = privilegedFloorOverride;
			return memoFloor;
		}

		if (FeatureManagement.checkPermission(PERMISSION_EDIT_ALL_ACCESS)) {
			memoFloor = AccessLevel.Edit;
		} else if (FeatureManagement.checkPermission(PERMISSION_VIEW_ALL_ACCESS)) {
			memoFloor = AccessLevel.View;
		} else {
			memoFloor = null;
		}

		return memoFloor;
	}

	public FilePage resolveFilePage(FilePageCriteria criteria) {
		return resolveFilePage(criteria, UserInfo.getUserId());
	}

	public FilePage resolveFilePage(FilePageCriteria criteria, Id targetUserId) {
		if (criteria == null) criteria = new FilePageCriteria();
		if (targetUserId == null) targetUserId = UserInfo.getUserId();

		Integer pageSize = criteria.effectivePageSize();
		FilePage page = scanForAccessibleRecords(criteria, targetUserId, pageSize, pageSize);

		if (page.records.size() >= pageSize || !page.hasMore) return page;
		return scanForAccessibleRecords(criteria, targetUserId, pageSize, WIDE_SCAN_SIZE);
	}

	private FilePage scanForAccessibleRecords(FilePageCriteria criteria, Id targetUserId, Integer pageSize, Integer scanSize) {
		List<GoogleFile__c> candidates = (List<GoogleFile__c>) buildPageSelector(criteria, targetUserId)
			.limitTo(scanSize + HAS_MORE_FLAG_ROW)
			.toList();

		Boolean sourceExhausted = candidates.size() <= scanSize;
		if (!sourceExhausted) candidates.remove(candidates.size() - 1);

		GoogleFile__c lastScannedRow = candidates.isEmpty() ? null : candidates.get(candidates.size() - 1);
		List<GoogleFile__c> accessibleRecords = resolveAccessibleFiles(candidates, targetUserId);

		FilePage page = new FilePage();
		page.hasMore = accessibleRecords.size() > pageSize || !sourceExhausted;

		while (accessibleRecords.size() > pageSize) {
			accessibleRecords.remove(accessibleRecords.size() - 1);
		}

		page.records = accessibleRecords;
		page.cursorRow = accessibleRecords.isEmpty() ? lastScannedRow : accessibleRecords.get(accessibleRecords.size() - 1);
		return page;
	}

	private GoogleFileSelector buildPageSelector(FilePageCriteria criteria, Id targetUserId) {
		GoogleFileSelector selector = GoogleFileSelector.query()
			.withAllFields()
			.withCreatedByName()
			.withLatestVersionSubquery(criteria.additionalVersionFields)
			.bySearchTerm(criteria.searchTerm);

		if (privilegedFloor() == null) {
			applyOwnershipScope(selector, criteria.ownerScope, targetUserId);
			selector.byAccessibleCandidates(targetUserId, resolveSharedFileIds(targetUserId));
		}

		selector.orderByFieldThenId(criteria.effectiveSortPath(), criteria.sortDirection);

		if (criteria.cursorId != null) {
			selector.afterKeyset(criteria.effectiveSortPath(), criteria.cursorValue, criteria.cursorId, criteria.sortDirection);
		}

		return selector;
	}

	private void applyOwnershipScope(GoogleFileSelector selector, OwnershipScope scope, Id targetUserId) {
		if (scope == OwnershipScope.OwnedByUser) selector.byOwner(targetUserId);
		else if (scope == OwnershipScope.NotOwnedByUser) selector.byOwnerOtherThan(targetUserId);
	}

	private Set<Id> resolveSharedFileIds(Id targetUserId) {
		Set<Id> sharedFileIds = new Set<Id>();

		for (GoogleFile__Share shareRecord : (List<GoogleFile__Share>) GoogleFileShareSelector.query()
			.withBaseFields()
			.byPrincipalIds(resolvePrincipalIds(targetUserId))
			.excludingOwnerShares()
			.limitTo(MAX_SHARED_CANDIDATE_IDS)
			.toList()
		) {
			sharedFileIds.add(shareRecord.ParentId);
		}

		return sharedFileIds;
	}

	public class FilePageCriteria {
		public Integer pageSize;
		public String sortPath;
		public String sortDirection = 'DESC';
		public String searchTerm;
		public Object cursorValue;
		public Id cursorId;
		public OwnershipScope ownerScope = OwnershipScope.AnyOwner;
		public List<String> additionalVersionFields = new List<String>();

		public Integer effectivePageSize() {
			if (pageSize == null || pageSize <= 0) return DEFAULT_PAGE_SIZE;
			return Math.min(pageSize, MAX_PAGE_SIZE);
		}

		public String effectiveSortPath() {
			return String.isBlank(sortPath) ? DEFAULT_SORT_PATH : sortPath;
		}
	}

	public class FilePage {
		public List<GoogleFile__c> records = new List<GoogleFile__c>();
		public GoogleFile__c cursorRow;
		public Boolean hasMore = false;
	}

	public List<GoogleFileLink__c> resolveAccessibleRecordLinks(List<GoogleFileLink__c> inputLinks, Id targetUserId) {
		if (inputLinks == null || inputLinks.isEmpty()) return new List<GoogleFileLink__c>();
		if (targetUserId == null) targetUserId = UserInfo.getUserId();

		User targetUser = loadTargetUser(targetUserId);
		Boolean isInternalUser = isInternalUserType(targetUser.UserType);
		Map<Id, GoogleRecordAccessDTO> parentAccessByRecordId = loadUserRecordAccess(targetUserId, extractLinkedRecordIds(inputLinks));
		List<GoogleFileLink__c> accessibleLinks = new List<GoogleFileLink__c>();

		for (GoogleFileLink__c linkRecord : inputLinks) {
			if (resolveLinkAccess(linkRecord, isInternalUser, parentAccessByRecordId) != null) {
				accessibleLinks.add(linkRecord);
			}
		}

		return accessibleLinks;
	}

	public List<GoogleFileLink__c> resolveReadableRecordLinks(List<GoogleFileLink__c> inputLinks, Id targetUserId) {
		if (inputLinks == null || inputLinks.isEmpty()) return new List<GoogleFileLink__c>();
		if (targetUserId == null) targetUserId = UserInfo.getUserId();

		Map<Id, GoogleRecordAccessDTO> parentAccessByRecordId = loadUserRecordAccess(targetUserId, extractLinkedRecordIds(inputLinks));
		List<GoogleFileLink__c> readableLinks = new List<GoogleFileLink__c>();

		for (GoogleFileLink__c linkRecord : inputLinks) {
			if (hasReadableParentAccess(loadLinkedRecordAccess(linkRecord, parentAccessByRecordId))) {
				readableLinks.add(linkRecord);
			}
		}

		return readableLinks;
	}

	private Set<Id> extractFileIds(List<GoogleFile__c> inputFiles) {
		Set<Id> fileIds = new Set<Id>();

		for (GoogleFile__c googleFile : inputFiles) {
			if (googleFile != null && googleFile.Id != null) {
				fileIds.add(googleFile.Id);
			}
		}

		return fileIds;
	}

	private Set<Id> extractLinkedRecordIds(List<GoogleFileLink__c> inputLinks) {
		Set<Id> linkedRecordIds = new Set<Id>();

		for (GoogleFileLink__c linkRecord : inputLinks) {
			if (linkRecord == null || String.isBlank(linkRecord.LinkedObjectId__c)) {
				continue;
			}

			linkedRecordIds.add((Id) linkRecord.LinkedObjectId__c);
		}

		return linkedRecordIds;
	}

	private User loadTargetUser(Id userId) {
		List<User> rows = (List<User>) GoogleUserSelector.query()
			.withTypeFields()
			.byUserId(userId)
			.limitTo(1)
			.toList();

		if (rows.isEmpty()) {
			throw new GoogleFileAccessCheckException('Target user was not found: ' + userId);
		}

		return rows[0];
	}

	private Map<Id, Id> loadFileOwners(Set<Id> fileIds, List<GoogleFile__c> providedFiles) {
		Map<Id, Id> fileIdToOwnerId = new Map<Id, Id>();
		Set<Id> missingOwnerFileIds = new Set<Id>();

		for (GoogleFile__c providedFile : providedFiles) {
			if (providedFile == null || providedFile.Id == null) continue;

			if (providedFile.isSet('OwnerId')) {
				fileIdToOwnerId.put(providedFile.Id, providedFile.OwnerId);
			} else {
				missingOwnerFileIds.add(providedFile.Id);
			}
		}

		if (!missingOwnerFileIds.isEmpty()) {
			for (GoogleFile__c row : (List<GoogleFile__c>) GoogleFileSelector.query().withOwnerOnly().byIds(missingOwnerFileIds).toList()) {
				fileIdToOwnerId.put(row.Id, row.OwnerId);
			}
		}

		return fileIdToOwnerId;
	}

	private Map<Id, List<GoogleFile__Share>> loadSharesForUserAndGroups(Set<Id> fileIds, Id userId) {
		Set<Id> principalIds = resolvePrincipalIds(userId);

		Map<Id, List<GoogleFile__Share>> sharesByFileId = new Map<Id, List<GoogleFile__Share>>();
		List<GoogleFile__Share> shares = (List<GoogleFile__Share>) GoogleFileShareSelector.query()
			.withBaseFields()
			.byParentIds(fileIds)
			.byPrincipalIds(principalIds)
			.toList();

		for (GoogleFile__Share shareRecord : shares) {
			if (!sharesByFileId.containsKey(shareRecord.ParentId)) {
				sharesByFileId.put(shareRecord.ParentId, new List<GoogleFile__Share>());
			}
			sharesByFileId.get(shareRecord.ParentId).add(shareRecord);
		}

		return sharesByFileId;
	}

	private Set<Id> resolvePrincipalIds(Id userId) {
		if (memoPrincipalIdsByUserId.containsKey(userId)) {
			return memoPrincipalIdsByUserId.get(userId);
		}

		Set<Id> principalIds = new Set<Id>();
		principalIds.add(userId);

		for (GroupMember groupMember : (List<GroupMember>) GoogleGroupMemberSelector.query()
			.withGroupFields()
			.byMemberId(userId)
			.byShareableGroupTypes()
			.toList()
		) {
			principalIds.add(groupMember.GroupId);
		}

		memoPrincipalIdsByUserId.put(userId, principalIds);
		return principalIds;
	}

	private List<GoogleFile__c> resolveAccessibleCandidateFiles(Id targetUserId, Set<Id> userAndGroupIds, List<String> additionalVersionFields) {
		Map<Id, GoogleFile__c> candidateFilesById = new Map<Id, GoogleFile__c>();

        candidateFilesById.putAll((Map<Id, GoogleFile__c>) GoogleFileSelector.query()
            .withAllFields()
            .withLatestVersionSubquery(additionalVersionFields)
            .byOwner(targetUserId)
			.orderByCreatedDesc()
            .limitTo(MAX_CANDIDATE_FILES + HAS_MORE_FLAG_ROW)
            .toMap());

        candidateFilesById.putAll((Map<Id, GoogleFile__c>) GoogleFileSelector.query()
			.withAllFields()
			.withLatestVersionSubquery(additionalVersionFields)
			.bySharedToUserOrGroups(userAndGroupIds)
			.orderByCreatedDesc()
			.limitTo(MAX_CANDIDATE_FILES + HAS_MORE_FLAG_ROW)
			.toMap());

        candidateFilesById.putAll((Map<Id, GoogleFile__c>) GoogleFileSelector.query()
            .withAllFields()
            .withLatestVersionSubquery(additionalVersionFields)
            .byDirectLinkForInternalVisibility()
			.orderByCreatedDesc()
            .limitTo(MAX_CANDIDATE_FILES + HAS_MORE_FLAG_ROW)
            .toMap());

		candidateFilesById.putAll((Map<Id, GoogleFile__c>) GoogleFileSelector.query()
			.withAllFields()
			.withLatestVersionSubquery(additionalVersionFields)
			.byInferredRecordLinks()
			.orderByCreatedDesc()
			.limitTo(MAX_CANDIDATE_FILES + HAS_MORE_FLAG_ROW)
			.toMap());

		if (candidateFilesById.isEmpty()) return new List<GoogleFile__c>();
		else return new List<GoogleFile__c>(candidateFilesById.values());
	}

	private LinkCompilationResult compileLinks(List<GoogleFileLink__c> fileLinks, Set<Id> fileIds) {
		LinkCompilationResult result = new LinkCompilationResult();

		for (GoogleFileLink__c link : fileLinks) {
			if (link == null || link.GoogleFileId__c == null || !fileIds.contains(link.GoogleFileId__c)) {
				continue;
			}

			if (!result.linksByFileId.containsKey(link.GoogleFileId__c)) {
				result.linksByFileId.put(link.GoogleFileId__c, new List<GoogleFileLink__c>());
			}

			result.linksByFileId.get(link.GoogleFileId__c).add(link);

			if (!String.isBlank(link.LinkedObjectId__c)) {
				result.linkedRecordIds.add((Id) link.LinkedObjectId__c);
			}
		}

		return result;
	}

	private LinkCompilationResult loadLinks(Set<Id> fileIds) {
		List<GoogleFileLink__c> fileLinks = GoogleFileLinkSelector.query()
			.withBaseFields()
			.byParentIds(fileIds)
			.toList();

		return compileLinks(fileLinks, fileIds);
	}

	private Map<Id, GoogleRecordAccessDTO> loadUserRecordAccess(Id userId, Set<Id> recordIds) {
		return new GoogleRecordAccessResolver().resolveAccess(userId, recordIds);
	}

	private List<GoogleFile__c> resolveAccessibleFilesInternal(List<GoogleFile__c> files, Id userId, Boolean isInternalUser, Map<Id, Id> fileIdToOwnerId, Map<Id, List<GoogleFile__Share>> fileIdToShares, Map<Id, List<GoogleFileLink__c>> fileIdToLinks, Map<Id, GoogleRecordAccessDTO> parentAccessByRecordId) {
		List<GoogleFile__c> accessibleFiles = new List<GoogleFile__c>();
		AccessLevel floor = isInternalUser ? privilegedFloor() : null;

		for (GoogleFile__c localFile : files) {
			if (localFile == null || localFile.Id == null) continue;

			AccessLevel resolvedAccess = resolveFileAccess(
				localFile.Id,
				userId,
				isInternalUser,
				fileIdToOwnerId.get(localFile.Id),
				fileIdToShares.get(localFile.Id),
				fileIdToLinks.get(localFile.Id),
				parentAccessByRecordId
			);

			if (floor != null) {
				resolvedAccess = pickHigherAccess(resolvedAccess, floor);
			}

			if (resolvedAccess != null) {
				localFile.UserAccessLevel__c = toAccessLevelString(resolvedAccess);
				accessibleFiles.add(localFile);
			}
		}

		return accessibleFiles;
	}

	private AccessLevel resolveFileAccess(Id fileId,Id userId, Boolean isInternalUser, Id ownerId, List<GoogleFile__Share> shares, List<GoogleFileLink__c> links, Map<Id, GoogleRecordAccessDTO> parentAccessByRecordId) {
		if (ownerId != null && ownerId == userId) {
			return AccessLevel.Edit;
		}

		AccessLevel accessFromShares = resolveBestAccessFromShares(shares);
		if (accessFromShares == AccessLevel.Edit) {
			return AccessLevel.Edit;
		}

		AccessLevel accessFromLinks = resolveBestAccessFromLinks(links, isInternalUser, parentAccessByRecordId);
		return pickHigherAccess(accessFromShares, accessFromLinks);
	}

	private AccessLevel resolveBestAccessFromShares(List<GoogleFile__Share> shares) {
		if (shares == null || shares.isEmpty()) return null;

		AccessLevel resolved = null;

		for (GoogleFile__Share shareRecord : shares) {
			AccessLevel candidate = mapShareAccessLevel(shareRecord.AccessLevel);
			resolved = pickHigherAccess(resolved, candidate);

			if (resolved == AccessLevel.Edit) {
				return AccessLevel.Edit;
			}
		}

		return resolved;
	}

	private AccessLevel resolveBestAccessFromLinks(List<GoogleFileLink__c> links, Boolean isInternalUser, Map<Id, GoogleRecordAccessDTO> parentAccessByRecordId) {
		if (links == null || links.isEmpty()) return null;

		AccessLevel resolved = null;

		for (GoogleFileLink__c link : links) {
			AccessLevel candidate = resolveLinkAccess(link, isInternalUser, parentAccessByRecordId);
			resolved = pickHigherAccess(resolved, candidate);

			if (resolved == AccessLevel.Edit) {
				return AccessLevel.Edit;
			}
		}

		return resolved;
	}

	private AccessLevel resolveLinkAccess(GoogleFileLink__c link, Boolean isInternalUser, Map<Id, GoogleRecordAccessDTO> parentAccessByRecordId) {
		if (link == null || !grantsVisibility(link.Visibility__c, isInternalUser)) {
			return null;
		}

		return mapLinkAccessLevel(link, parentAccessByRecordId);
	}

	private AccessLevel mapShareAccessLevel(String shareAccessLevel) {
		if (String.isBlank(shareAccessLevel)) return null;
		return shareAccessLevel == 'Read' ? AccessLevel.View : AccessLevel.Edit;
	}

	private AccessLevel mapLinkAccessLevel(GoogleFileLink__c link, Map<Id, GoogleRecordAccessDTO> parentAccessByRecordId) {
		if (link == null) return null;
		GoogleRecordAccessDTO linkedRecordAccess = loadLinkedRecordAccess(link, parentAccessByRecordId);

		if (link.ShareType__c == 'None') {
			return null;
		}
		if (link.ShareType__c == 'Viewer') {
			return hasReadableParentAccess(linkedRecordAccess) ? AccessLevel.View : null;
		}
		if (link.ShareType__c == 'Collaborator') {
			return hasReadableParentAccess(linkedRecordAccess) ? AccessLevel.Edit : null;
		}
		if (link.ShareType__c == 'InferredFromRecord') {
			return inferLevelFromParent(linkedRecordAccess);
		}

		return null;
	}

	private GoogleRecordAccessDTO loadLinkedRecordAccess(GoogleFileLink__c link, Map<Id, GoogleRecordAccessDTO> parentAccessByRecordId) {
		if (link == null || parentAccessByRecordId == null || String.isBlank(link.LinkedObjectId__c)) {
			return null;
		}

		return parentAccessByRecordId.get((Id) link.LinkedObjectId__c);
	}

	private Boolean hasReadableParentAccess(GoogleRecordAccessDTO userRecordAccess) {
		return userRecordAccess != null && userRecordAccess.hasReadAccess == true;
	}

	private AccessLevel pickHigherAccess(AccessLevel current, AccessLevel candidate) {
		if (candidate == null) return current;
		if (current == null) return candidate;

		Integer currentRank = accessRank(current);
		Integer candidateRank = accessRank(candidate);

		return candidateRank > currentRank ? candidate : current;
	}

	private Integer accessRank(AccessLevel level) {
		if (level == AccessLevel.Edit) return 2;
		if (level == AccessLevel.View) return 1;
		return 0;
	}

	private Boolean isInternalUserType(String userType) {
		if (userType == null) return true;

		String normalized = userType.toLowerCase();
		if (normalized.contains('guest') ||
			normalized.contains('portal') ||
			normalized.contains('partner') ||
			normalized.contains('customer') ||
			normalized.contains('csn')) {
			return false;
		}

		return true;
	}

	private Boolean grantsVisibility(String visibility, Boolean isInternalUser) {
		if (visibility == null) return false;
		if (visibility == 'AllUsers') return true;
		if (visibility == 'InternalUsers') return isInternalUser == true;
		return false;
	}

	private AccessLevel inferLevelFromParent(GoogleRecordAccessDTO userRecordAccess) {
		if (userRecordAccess == null) return null;
		if (userRecordAccess.hasEditAccess == true) return AccessLevel.Edit;
		if (userRecordAccess.hasReadAccess == true) return AccessLevel.View;
		return null;
	}

	private String toAccessLevelString(AccessLevel level) {
		return level == null ? null : String.valueOf(level);
	}

	private class LinkCompilationResult {
		public Set<Id> linkedRecordIds = new Set<Id>();
		public Map<Id, List<GoogleFileLink__c>> linksByFileId = new Map<Id, List<GoogleFileLink__c>>();
	}
}