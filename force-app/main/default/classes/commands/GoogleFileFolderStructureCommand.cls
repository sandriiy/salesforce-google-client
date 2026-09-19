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
/**
 * Resolves, and creates when missing, the Drive folder a file belongs in under the configured
 * structure: "{User}", "{Record}", "{User}-{Record}" or "{Record}-{User}". A folder is
 * identified by the Salesforce Id stamped into its appProperties, never by its name, and a
 * resolved Id is memoised in the org cache because Drive search does not reliably return a
 * folder that was just created. When another transaction is already creating the same folder
 * the resolution defers instead of making a duplicate, so check isResolutionDeferred() before
 * reading a null as "no folder". Every Drive call goes through GoogleClientApiProvider.
 */
public without sharing class GoogleFileFolderStructureCommand {
	public class GoogleFileFolderStructureCommandException extends Exception {}

	private static final String FOLDER_MIME_TYPE = GoogleCloudConstants.MIME_TYPE_GOOGLE_FOLDER;
	private static final String APP_PROPERTY_RECORD_ID = 'record-id';
	private static final String TARGET_TYPE_USER = 'User';
	private static final String TARGET_TYPE_RECORD = 'Record';
	private static final Integer SEARCH_MAX_RESULT = 25;

	private final GoogleDrive remoteGoogleDrive;
	private final GoogleMetadataConfigService metadataService;
	private final GoogleLocalFileLinkEnrichmentService linkEnrichmentService;
	private final GoogleCacheDriveFolderService folderCache;
	private final Map<String, String> resolvedFolderIdsByKey = new Map<String, String>();

	private Boolean isResolutionDeferred = false;
	private Boolean ignoresPendingClaims = false;

	public GoogleFileFolderStructureCommand() {
		this.remoteGoogleDrive = new GoogleClientApiProvider().retrieveGoogleDriveClient();
		this.metadataService = new GoogleMetadataConfigService();
		this.linkEnrichmentService = new GoogleLocalFileLinkEnrichmentService();
		this.folderCache = new GoogleCacheDriveFolderService();
	}

	/**
	 * Makes the command create the folder even while another transaction holds a pending claim
	 * on it. Only the final placement attempt should use this: it trades a possible duplicate
	 * folder for never leaving a file unplaced.
	 *
	 * @return This same instance, so the call chains onto ensureFolder().
	 */
	public GoogleFileFolderStructureCommand ignorePendingClaims() {
		this.ignoresPendingClaims = true;
		return this;
	}

	/**
	 * Tells whether the last ensureFolder() or findExistingFolder() call returned null because
	 * another transaction is creating that folder, rather than because there is no folder.
	 *
	 * @return True when the caller should retry later instead of giving up.
	 */
	public Boolean isResolutionDeferred() {
		return this.isResolutionDeferred == true;
	}

	/**
	 * Forgets every folder this instance resolved, in memory and in the org cache. Call it when
	 * a Drive operation against a resolved folder failed, so the next attempt searches Drive
	 * again instead of trusting a cached Id that may no longer work.
	 */
	public void evictResolvedFolders() {
		for (String folderKey : this.resolvedFolderIdsByKey.keySet()) {
			this.folderCache.evict(folderKey);
		}

		this.resolvedFolderIdsByKey.clear();
	}

	/**
	 * Resolves the destination folder for the running user and the given record under the first
	 * configured upload folder, creating whatever part of the path is missing.
	 *
	 * @param relatedRecordId The record the file is linked to; may be null for a "{User}" structure.
	 * @return The Drive folder Id, or null when no structure or upload folder is configured, the
	 * structure needs a record and none was given, or the resolution was deferred.
	 */
	public String ensureFolder(Id relatedRecordId) {
		return ensureFolder(UserInfo.getUserId(), relatedRecordId);
	}

	/**
	 * Same as ensureFolder(Id), for a specific user. Jobs use this because they run as the
	 * automated process user and must still place the file under the user who uploaded it.
	 *
	 * @param initiatorUserId The user whose folder is used when the structure has a user level.
	 * @param relatedRecordId The record the file is linked to; may be null for a "{User}" structure.
	 * @return The Drive folder Id, or null as described on ensureFolder(Id).
	 */
	public String ensureFolder(Id initiatorUserId, Id relatedRecordId) {
		return resolveFolderId(initiatorUserId, relatedRecordId, true);
	}

	/**
	 * Same as ensureFolder(Id, Id), but under an explicit root instead of the first configured
	 * upload folder. Use it when the file already sits in a known upload folder, so the structure
	 * is built where the file is rather than where the default points.
	 *
	 * @param rootFolderId The Drive folder the structure hangs off.
	 * @param initiatorUserId The user whose folder is used when the structure has a user level.
	 * @param relatedRecordId The record the file is linked to; may be null for a "{User}" structure.
	 * @return The Drive folder Id, or null as described on ensureFolder(Id).
	 */
	public String ensureFolder(String rootFolderId, Id initiatorUserId, Id relatedRecordId) {
		return resolveFolderId(rootFolderId, initiatorUserId, relatedRecordId, true);
	}

	/**
	 * Looks the folder up without ever creating it, so a caller can tell an existing record
	 * folder apart from one it is about to create.
	 *
	 * @param initiatorUserId The user whose folder is used when the structure has a user level.
	 * @param relatedRecordId The record the file is linked to.
	 * @return The Drive folder Id, or null when any part of the path does not exist yet.
	 */
	public String findExistingFolder(Id initiatorUserId, Id relatedRecordId) {
		return resolveFolderId(initiatorUserId, relatedRecordId, false);
	}

	/**
	 * Same as findExistingFolder(Id, Id), under an explicit root folder.
	 *
	 * @param rootFolderId The Drive folder the structure hangs off.
	 * @param initiatorUserId The user whose folder is used when the structure has a user level.
	 * @param relatedRecordId The record the file is linked to.
	 * @return The Drive folder Id, or null when any part of the path does not exist yet.
	 */
	public String findExistingFolder(String rootFolderId, Id initiatorUserId, Id relatedRecordId) {
		return resolveFolderId(rootFolderId, initiatorUserId, relatedRecordId, false);
	}

	private String resolveFolderId(Id initiatorUserId, Id relatedRecordId, Boolean createIfMissing) {
		List<String> uploadParentFolderIds = metadataService.getTargetFolderResolver().resolveUploadFolderId();
		String rootFolderId = getFirstFolderId(uploadParentFolderIds);
		return resolveFolderId(rootFolderId, initiatorUserId, relatedRecordId, createIfMissing);
	}

	private String resolveFolderId(String rootFolderId, Id initiatorUserId, Id relatedRecordId, Boolean createIfMissing) {
		this.isResolutionDeferred = false;
		if (String.isBlank(rootFolderId)) return null;

		String folderStructure = metadataService.getGoogleDriveFolderStructure();
		if (String.isBlank(folderStructure)) return null;

		return resolveDestinationFolderId(folderStructure, rootFolderId, initiatorUserId, relatedRecordId, createIfMissing);
	}

	private String buildFolderName(String folderTargetType, Id uniqueIdValue) {
		return folderTargetType == TARGET_TYPE_USER
			? buildUserFolderName(uniqueIdValue)
			: buildRecordFolderName(uniqueIdValue);
	}

	private String buildUserFolderName(Id userId) {
		User initiatingUser = loadUser(userId);
		if (initiatingUser == null) return 'Unknown User';

		String fullName = String.join(new List<String>{
			String.isBlank(initiatingUser.FirstName) ? null : initiatingUser.FirstName,
			String.isBlank(initiatingUser.LastName) ? null : initiatingUser.LastName
		}, ' ').trim();

		return 'User : ' + fullName;
	}

	private User loadUser(Id userId) {
		if (userId == null) return null;

		List<User> users = (List<User>) GoogleUserSelector.query()
			.withNameFields()
			.byUserId(userId)
			.limitTo(1)
			.toList();

		return users.isEmpty() ? null : users[0];
	}

	private String buildRecordFolderName(Id relatedRecordId) {
		if (relatedRecordId == null) return null;

		Schema.SObjectType objectType = relatedRecordId.getSObjectType();
		String objectApiName = objectType.getDescribe().getName();
		String recordName = linkEnrichmentService.resolveLinkedRecordName(relatedRecordId);

		return objectApiName + ' : ' + (String.isBlank(recordName) ? 'Unknown Record' : recordName);
	}

	private String resolveDestinationFolderId(String folderStructure, String rootFolderId, Id userId, Id recordId, Boolean createIfMissing) {
		if (String.isBlank(folderStructure)) return null;

		if (folderStructure == GoogleCloudConstants.STRUCTURE_USER) {
			return resolveFolder(rootFolderId, TARGET_TYPE_USER, userId, createIfMissing);
		}

		if (folderStructure == GoogleCloudConstants.STRUCTURE_RECORD) {
			if (recordId == null) return null;
			return resolveFolder(rootFolderId, TARGET_TYPE_RECORD, recordId, createIfMissing);
		}

		if (folderStructure == GoogleCloudConstants.STRUCTURE_USER_RECORD) {
			if (recordId == null) return null;
			String userFolderId = resolveFolder(rootFolderId, TARGET_TYPE_USER, userId, createIfMissing);
			if (String.isBlank(userFolderId)) return null;

			return resolveFolder(userFolderId, TARGET_TYPE_RECORD, recordId, createIfMissing);
		}

		if (folderStructure == GoogleCloudConstants.STRUCTURE_RECORD_USER) {
			if (recordId == null) return null;
			String recordFolderId = resolveFolder(rootFolderId, TARGET_TYPE_RECORD, recordId, createIfMissing);
			if (String.isBlank(recordFolderId)) return null;

			return resolveFolder(recordFolderId, TARGET_TYPE_USER, userId, createIfMissing);
		}

		return null;
	}

	private String resolveFolder(String parentFolderId, String folderTargetType, Id uniqueIdValue, Boolean createIfMissing) {
		if (String.isBlank(parentFolderId) || uniqueIdValue == null) return null;

		String folderKey = this.folderCache.buildFolderKey(parentFolderId, uniqueIdValue);
		if (this.resolvedFolderIdsByKey.containsKey(folderKey)) {
			return this.resolvedFolderIdsByKey.get(folderKey);
		}

		String cachedFolderId = this.folderCache.getFolderId(folderKey);
		if (String.isNotBlank(cachedFolderId)) {
			return rememberFolder(folderKey, cachedFolderId);
		}

		if (this.ignoresPendingClaims != true && this.folderCache.isPending(folderKey)) {
			this.isResolutionDeferred = true;

			Logger.info(
				'Folder Structure --> Deferred, another transaction is creating the folder' +
				', ParentFolderId=' + String.valueOf(parentFolderId) +
				', UniqueId=' + String.valueOf(uniqueIdValue)
			).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

			return null;
		}

		String existingFolderId = findFolderIdByUniqueId(parentFolderId, uniqueIdValue);
		if (String.isNotBlank(existingFolderId)) {
			this.folderCache.putFolderId(folderKey, existingFolderId);
			return rememberFolder(folderKey, existingFolderId);
		}

		if (createIfMissing != true) return null;

		this.folderCache.markPending(folderKey);

		String createdFolderId;
		try {
			createdFolderId = createFolder(parentFolderId, buildFolderName(folderTargetType, uniqueIdValue), uniqueIdValue);
		} catch (Exception ex) {
			this.folderCache.evict(folderKey);
			throw ex;
		}

		if (String.isBlank(createdFolderId)) {
			this.folderCache.evict(folderKey);
			return null;
		}

		this.folderCache.putFolderId(folderKey, createdFolderId);
		return rememberFolder(folderKey, createdFolderId);
	}

	private String rememberFolder(String folderKey, String folderId) {
		this.resolvedFolderIdsByKey.put(folderKey, folderId);
		return folderId;
	}

	private String findFolderIdByUniqueId(String parentFolderId, Id uniqueIdValue) {
		String escapedParentId = escapeQueryValue(parentFolderId);
		String escapedUniqueId = escapeQueryValue(uniqueIdValue);

		String query = 'mimeType = \'' + FOLDER_MIME_TYPE + '\' ';
		query += 'and \'' + escapedParentId + '\' in parents ';
		query += 'and trashed = false ';
		query += 'and appProperties has { key=\'' + APP_PROPERTY_RECORD_ID + '\' and value=\'' + escapedUniqueId + '\' }';

		GoogleFileSearchResult searchResult = remoteGoogleDrive.files().search()
			.setMaxResult(SEARCH_MAX_RESULT)
			.setSearchQuery(query)
			.setSearchOnAllDrives(true)
			.setFields('files(id,name)')
			.execute();

		if (searchResult == null || searchResult.files == null) return null;

		return selectAdoptableFolderId(searchResult.files);
	}

	private String selectAdoptableFolderId(List<GoogleFileEntity> matchingFolders) {
		String adoptedFolderId = null;

		for (GoogleFileEntity matchingFolder : matchingFolders) {
			if (matchingFolder == null || String.isBlank(matchingFolder.id)) continue;
			if (adoptedFolderId == null || matchingFolder.id.compareTo(adoptedFolderId) < 0) {
				adoptedFolderId = matchingFolder.id;
			}
		}

		return adoptedFolderId;
	}

	private String createFolder(String parentFolderId, String folderName, Id uniqueIdValue) {
		Map<String, Object> customAttributes = new Map<String, Object>{
			APP_PROPERTY_RECORD_ID => uniqueIdValue
		};

		String entityName = String.isBlank(folderName) ? 'Untitled' : folderName.trim();
		GoogleFileEntity createdFolder = remoteGoogleDrive.files().multipartCreate()
			.setFileName(entityName)
			.setMimeType(FOLDER_MIME_TYPE)
			.setParentFolders(new List<String>{ parentFolderId })
			.setCustomAttributes(customAttributes)
			.setSupportsAllDrives(true)
			.setBody('')
			.execute();

		return createdFolder == null ? null : createdFolder.id;
	}

	private String getFirstFolderId(List<String> folderIds) {
		if (folderIds == null || folderIds.isEmpty()) return null;

		for (String folderId : folderIds) {
			if (String.isNotBlank(folderId)) return folderId;
		}

		return null;
	}

	private String escapeQueryValue(String value) {
		if (value == null) return '';
		return value.replace('\\', '\\\\').replace('\'', '\\\'');
	}

}