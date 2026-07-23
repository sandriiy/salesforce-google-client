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

		Set<Id> ownedFileIds = new Set<Id>();
		Set<Id> nonOwnedFileIds = new Set<Id>();

		for (Id fileId : fileIds) {
			Id ownerId = fileIdToOwnerId.get(fileId);
			if (ownerId != null && ownerId == targetUserId) {
				ownedFileIds.add(fileId);
			} else {
				nonOwnedFileIds.add(fileId);
			}
		}

		List<GoogleFile__c> accessibleFiles = new List<GoogleFile__c>();

		if (!ownedFileIds.isEmpty()) {
			for (GoogleFile__c fileRecord : inputFiles) {
				if (fileRecord != null && fileRecord.Id != null && ownedFileIds.contains(fileRecord.Id)) {
					fileRecord.UserAccessLevel__c = toAccessLevelString(AccessLevel.Edit);
					accessibleFiles.add(fileRecord);
				}
			}
		}

		if (nonOwnedFileIds.isEmpty()) {
			return accessibleFiles;
		}

		Map<Id, List<GoogleFile__Share>> fileIdToShares = loadSharesForUserAndGroups(nonOwnedFileIds, targetUserId);

		Logger.info('Files Access Check: ' + fileIdToOwnerId.keySet()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

		LinkCompilationResult linkData = scopedRecordLinks == null
			? loadLinks(nonOwnedFileIds)
			: compileLinks(scopedRecordLinks, nonOwnedFileIds);
		Map<Id, UserRecordAccess> parentAccessByRecordId = loadUserRecordAccess(targetUserId, linkData.linkedRecordIds);

		List<GoogleFile__c> nonOwnedFiles = new List<GoogleFile__c>();
		for (GoogleFile__c fileRecord : inputFiles) {
			if (fileRecord != null && fileRecord.Id != null && nonOwnedFileIds.contains(fileRecord.Id)) {
				nonOwnedFiles.add(fileRecord);
			}
		}

		accessibleFiles.addAll(
			resolveAccessibleFilesInternal(
				nonOwnedFiles,
				targetUserId,
				isInternalUser,
				fileIdToOwnerId,
				fileIdToShares,
				linkData.linksByFileId,
				parentAccessByRecordId
			)
		);

		return accessibleFiles;
	}

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

	public List<GoogleFileLink__c> resolveAccessibleRecordLinks(List<GoogleFileLink__c> inputLinks, Id targetUserId) {
		if (inputLinks == null || inputLinks.isEmpty()) return new List<GoogleFileLink__c>();
		if (targetUserId == null) targetUserId = UserInfo.getUserId();

		User targetUser = loadTargetUser(targetUserId);
		Boolean isInternalUser = isInternalUserType(targetUser.UserType);
		Map<Id, UserRecordAccess> parentAccessByRecordId = loadUserRecordAccess(targetUserId, extractLinkedRecordIds(inputLinks));
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

		Map<Id, UserRecordAccess> parentAccessByRecordId = loadUserRecordAccess(targetUserId, extractLinkedRecordIds(inputLinks));
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
		List<User> rows = [
			SELECT Id, UserType
			FROM User
			WHERE Id = :userId
			LIMIT 1
		];

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
			for (GoogleFile__c row : [
				SELECT Id, OwnerId
				FROM GoogleFile__c
				WHERE Id IN :missingOwnerFileIds
			]) {
				fileIdToOwnerId.put(row.Id, row.OwnerId);
			}
		}

		return fileIdToOwnerId;
	}

	private Map<Id, List<GoogleFile__Share>> loadSharesForUserAndGroups(Set<Id> fileIds, Id userId) {
		Set<Id> principalIds = resolvePrincipalIds(userId);

		Map<Id, List<GoogleFile__Share>> sharesByFileId = new Map<Id, List<GoogleFile__Share>>();
		List<GoogleFile__Share> shares = [
			SELECT Id, ParentId, UserOrGroupId, AccessLevel, RowCause
			FROM GoogleFile__Share
			WHERE ParentId IN :fileIds
			AND UserOrGroupId IN :principalIds
		];

		for (GoogleFile__Share shareRecord : shares) {
			if (!sharesByFileId.containsKey(shareRecord.ParentId)) {
				sharesByFileId.put(shareRecord.ParentId, new List<GoogleFile__Share>());
			}
			sharesByFileId.get(shareRecord.ParentId).add(shareRecord);
		}

		return sharesByFileId;
	}

	private Set<Id> resolvePrincipalIds(Id userId) {
		Set<Id> principalIds = new Set<Id>();
		principalIds.add(userId);

		for (GroupMember groupMember : [
			SELECT GroupId, Group.Type
			FROM GroupMember
			WHERE UserOrGroupId = :userId
			AND Group.Type IN ('Regular', 'Queue')
		]) {
			principalIds.add(groupMember.GroupId);
		}

		return principalIds;
	}

	private List<GoogleFile__c> resolveAccessibleCandidateFiles(Id targetUserId, Set<Id> userAndGroupIds, List<String> additionalVersionFields) {
		Map<Id, GoogleFile__c> candidateFilesById = new Map<Id, GoogleFile__c>();

        candidateFilesById.putAll((Map<Id, GoogleFile__c>) GoogleFileSelector.query()
            .withAllFields()
            .withLatestVersionSubquery(additionalVersionFields)
            .byOwner(targetUserId)
            .toMap());

        candidateFilesById.putAll((Map<Id, GoogleFile__c>) GoogleFileSelector.query()
			.withAllFields()
			.withLatestVersionSubquery(additionalVersionFields)
			.bySharedToUserOrGroups(userAndGroupIds)
			.toMap());

        candidateFilesById.putAll((Map<Id, GoogleFile__c>) GoogleFileSelector.query()
            .withAllFields()
            .withLatestVersionSubquery(additionalVersionFields)
            .byDirectLinkForInternalVisibility()
			.orderByCreatedDesc()
            .limitTo(10000)
            .toMap());

		candidateFilesById.putAll((Map<Id, GoogleFile__c>) GoogleFileSelector.query()
			.withAllFields()
			.withLatestVersionSubquery(additionalVersionFields)
			.byInferredRecordLinks()
			.orderByCreatedDesc()
			.limitTo(10000)
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

	private Map<Id, UserRecordAccess> loadUserRecordAccess(Id userId, Set<Id> recordIds) {
		Map<Id, UserRecordAccess> recordAccessByRecordId = new Map<Id, UserRecordAccess>();
		if (recordIds.isEmpty()) {
			return recordAccessByRecordId;
		}

		for (UserRecordAccess userAccess : [
			SELECT RecordId, HasReadAccess, HasEditAccess
			FROM UserRecordAccess
			WHERE UserId = :userId
			AND RecordId IN :recordIds
		]) {
			recordAccessByRecordId.put(userAccess.RecordId, userAccess);
		}

		return recordAccessByRecordId;
	}

	private List<GoogleFile__c> resolveAccessibleFilesInternal(List<GoogleFile__c> files, Id userId, Boolean isInternalUser, Map<Id, Id> fileIdToOwnerId, Map<Id, List<GoogleFile__Share>> fileIdToShares, Map<Id, List<GoogleFileLink__c>> fileIdToLinks, Map<Id, UserRecordAccess> parentAccessByRecordId) {
		List<GoogleFile__c> accessibleFiles = new List<GoogleFile__c>();

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

			if (resolvedAccess != null) {
				localFile.UserAccessLevel__c = toAccessLevelString(resolvedAccess);
				accessibleFiles.add(localFile);
			}
		}

		return accessibleFiles;
	}

	private AccessLevel resolveFileAccess(Id fileId,Id userId, Boolean isInternalUser, Id ownerId, List<GoogleFile__Share> shares, List<GoogleFileLink__c> links, Map<Id, UserRecordAccess> parentAccessByRecordId) {
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

	private AccessLevel resolveBestAccessFromLinks(List<GoogleFileLink__c> links, Boolean isInternalUser, Map<Id, UserRecordAccess> parentAccessByRecordId) {
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

	private AccessLevel resolveLinkAccess(GoogleFileLink__c link, Boolean isInternalUser, Map<Id, UserRecordAccess> parentAccessByRecordId) {
		if (link == null || !grantsVisibility(link.Visibility__c, isInternalUser)) {
			return null;
		}

		return mapLinkAccessLevel(link, parentAccessByRecordId);
	}

	private AccessLevel mapShareAccessLevel(String shareAccessLevel) {
		if (String.isBlank(shareAccessLevel)) return null;
		return shareAccessLevel == 'Read' ? AccessLevel.View : AccessLevel.Edit;
	}

	private AccessLevel mapLinkAccessLevel(GoogleFileLink__c link, Map<Id, UserRecordAccess> parentAccessByRecordId) {
		if (link == null) return null;
		UserRecordAccess linkedRecordAccess = loadLinkedRecordAccess(link, parentAccessByRecordId);

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

	private UserRecordAccess loadLinkedRecordAccess(GoogleFileLink__c link, Map<Id, UserRecordAccess> parentAccessByRecordId) {
		if (link == null || parentAccessByRecordId == null || String.isBlank(link.LinkedObjectId__c)) {
			return null;
		}

		return parentAccessByRecordId.get((Id) link.LinkedObjectId__c);
	}

	private Boolean hasReadableParentAccess(UserRecordAccess userRecordAccess) {
		return userRecordAccess != null && userRecordAccess.HasReadAccess;
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

	private AccessLevel inferLevelFromParent(UserRecordAccess userRecordAccess) {
		if (userRecordAccess == null) return null;
		if (userRecordAccess.HasEditAccess) return AccessLevel.Edit;
		if (userRecordAccess.HasReadAccess) return AccessLevel.View;
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