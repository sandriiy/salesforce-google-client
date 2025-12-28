public without sharing class GoogleFileAccessCheckCommand {
	public class GoogleFileAccessCheckException extends Exception {}

	private List<GoogleFile__c> inputFiles = new List<GoogleFile__c>();
	private Set<Id> fileIds = new Set<Id>();
	private Id targetUserId;

	public GoogleFileAccessCheckCommand forFiles(List<GoogleFile__c> files) {
		if (files != null) inputFiles.addAll(files);
		return this;
	}

	public GoogleFileAccessCheckCommand forFile(GoogleFile__c fileRecord) {
		if (fileRecord != null) inputFiles.add(fileRecord);
		return this;
	}

	public GoogleFileAccessCheckCommand forFile(Id fileRecordId) {
		if (fileRecordId != null) {
			inputFiles.add(new GoogleFile__c(Id = fileRecordId));
		}
		
		return this;
	}

	public GoogleFileAccessCheckCommand forUser(Id userId) {
		this.targetUserId = userId;
		return this;
	}

	public List<GoogleFile__c> strip() {
		if (inputFiles.isEmpty()) return new List<GoogleFile__c>();

		resolveDefaults();
		extractGoogleFileIds();

		if (fileIds.isEmpty()) return new List<GoogleFile__c>();

		User targetUser = loadTargetUser(targetUserId);
		Boolean isInternalUser = isInternalUserType(targetUser.UserType);

		Map<Id, Id> fileIdToOwnerId = loadFileOwners(fileIds, inputFiles);
		Map<Id, List<GoogleFile__Share>> fileIdToShares = loadSharesForUserAndGroups(fileIds, targetUserId);

		Logger.info('Files Access Check: ' + fileIdToOwnerId.keySet());

		LinkCompilationResult linkData = loadLinks(fileIds);
		Map<Id, UserRecordAccess> parentAccessByRecordId = loadUserRecordAccess(targetUserId, linkData.inferredRecordIds);

		return resolveAccessibleFiles(
			inputFiles,
			targetUserId,
			isInternalUser,
			fileIdToOwnerId,
			fileIdToShares,
			linkData.linksByFileId,
			parentAccessByRecordId
		);
	}

	private void resolveDefaults() {
		if (targetUserId == null) {
			targetUserId = UserInfo.getUserId();
		}
	}

	private void extractGoogleFileIds() {
		fileIds.clear();

		for (GoogleFile__c googleFile : inputFiles) {
			if (googleFile != null && googleFile.Id != null) {
				fileIds.add(googleFile.Id);
			}
		}
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

	private class LinkCompilationResult {
		public Set<Id> inferredRecordIds = new Set<Id>();
		public Map<Id, List<GoogleFileLink__c>> linksByFileId = new Map<Id, List<GoogleFileLink__c>>();
	}

	private LinkCompilationResult loadLinks(Set<Id> fileIds) {
		LinkCompilationResult result = new LinkCompilationResult();

		List<GoogleFileLink__c> fileLinks = GoogleFileLinkSelector.query()
			.withBaseFields()
			.byParentIds(fileIds)
			.toList();

		for (GoogleFileLink__c link : fileLinks) {
			if (!result.linksByFileId.containsKey(link.GoogleFileId__c)) {
				result.linksByFileId.put(link.GoogleFileId__c, new List<GoogleFileLink__c>());
			}

			result.linksByFileId.get(link.GoogleFileId__c).add(link);

			if (link.ShareType__c == 'InferredFromRecord' && link.LinkedObjectId__c != null) {
				result.inferredRecordIds.add((Id) link.LinkedObjectId__c);
			}
		}

		return result;
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

	private List<GoogleFile__c> resolveAccessibleFiles(
		List<GoogleFile__c> files,
		Id userId,
		Boolean isInternalUser,
		Map<Id, Id> fileIdToOwnerId,
		Map<Id, List<GoogleFile__Share>> fileIdToShares,
		Map<Id, List<GoogleFileLink__c>> fileIdToLinks,
		Map<Id, UserRecordAccess> parentAccessByRecordId
	) {
		List<GoogleFile__c> accessibleFiles = new List<GoogleFile__c>();

		for (GoogleFile__c localFile : files) {
			if (localFile == null || localFile.Id == null) continue;

			String resolvedAccess = resolveFileAccess(
				localFile.Id,
				userId,
				isInternalUser,
				fileIdToOwnerId.get(localFile.Id),
				fileIdToShares.get(localFile.Id),
				fileIdToLinks.get(localFile.Id),
				parentAccessByRecordId
			);

			if (resolvedAccess != null) {
				localFile.UserAccessLevel__c = resolvedAccess;
				accessibleFiles.add(localFile);
			}
		}

		return accessibleFiles;
	}

	private String resolveFileAccess(
		Id fileId,
		Id userId,
		Boolean isInternalUser,
		Id ownerId,
		List<GoogleFile__Share> shares,
		List<GoogleFileLink__c> links,
		Map<Id, UserRecordAccess> parentAccessByRecordId
	) {
		if (ownerId != null && ownerId == userId) {
			return 'Edit';
		}

		String accessFromShares = resolveBestAccessFromShares(shares);
		if (accessFromShares == 'Edit') {
			return 'Edit';
		}

		String accessFromLinks = resolveBestAccessFromLinks(links, isInternalUser, parentAccessByRecordId);
		return pickHigherAccess(accessFromShares, accessFromLinks);
	}

	private String resolveBestAccessFromShares(List<GoogleFile__Share> shares) {
		if (shares == null || shares.isEmpty()) return null;

		String resolved = null;

		for (GoogleFile__Share shareRecord : shares) {
			String candidate = mapShareAccessLevel(shareRecord.AccessLevel);
			resolved = pickHigherAccess(resolved, candidate);

			if (resolved == 'Edit') {
				return 'Edit';
			}
		}

		return resolved;
	}

	private String resolveBestAccessFromLinks(List<GoogleFileLink__c> links, Boolean isInternalUser, Map<Id, UserRecordAccess> parentAccessByRecordId) {
		if (links == null || links.isEmpty()) return null;

		String resolved = null;

		for (GoogleFileLink__c link : links) {
			if (!grantsVisibility(link.Visibility__c, isInternalUser)) {
				continue;
			}

			String candidate = mapLinkAccessLevel(link, parentAccessByRecordId);
			resolved = pickHigherAccess(resolved, candidate);

			if (resolved == 'Edit') {
				return 'Edit';
			}
		}

		return resolved;
	}

	private String mapShareAccessLevel(String shareAccessLevel) {
		if (String.isBlank(shareAccessLevel)) return null;
		return shareAccessLevel == 'Read' ? 'View' : 'Edit';
	}

	private String mapLinkAccessLevel(GoogleFileLink__c link, Map<Id, UserRecordAccess> parentAccessByRecordId) {
		if (link == null) return null;

		if (link.ShareType__c == 'Viewer') {
			return 'View';
		}
		if (link.ShareType__c == 'Collaborator') {
			return 'Edit';
		}
		if (link.ShareType__c == 'InferredFromRecord') {
			return inferLevelFromParent(parentAccessByRecordId.get((Id) link.LinkedObjectId__c));
		}

		return null;
	}

	private String pickHigherAccess(String current, String candidate) {
		if (candidate == null) return current;
		if (current == null) return candidate;

		Integer currentRank = accessRank(current);
		Integer candidateRank = accessRank(candidate);

		return candidateRank > currentRank ? candidate : current;
	}

	private Integer accessRank(String accessLevel) {
		if (accessLevel == 'Edit') return 2;
		if (accessLevel == 'View') return 1;
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

	private String inferLevelFromParent(UserRecordAccess userRecordAccess) {
		if (userRecordAccess == null) return null;
		if (userRecordAccess.HasEditAccess) return 'Edit';
		if (userRecordAccess.HasReadAccess) return 'View';
		return null;
	}
}