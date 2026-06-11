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
public without sharing class GoogleFileFolderStructureCommand {
	public class GoogleFileFolderStructureCommandException extends Exception {}

	private static final String FOLDER_MIME_TYPE = 'application/vnd.google-apps.folder';
	private static final String APP_PROPERTY_RECORD_ID = 'record-id';

	private final GoogleDrive remoteGoogleDrive;
	private final GoogleMetadataConfigService metadataService;
	private final GoogleLocalFileLinkEnrichmentService linkEnrichmentService;

	public GoogleFileFolderStructureCommand() {
		this.remoteGoogleDrive = new GoogleClientApiProvider().retrieveGoogleDriveClient();
		this.metadataService = new GoogleMetadataConfigService();
		this.linkEnrichmentService = new GoogleLocalFileLinkEnrichmentService();
	}

	public String ensureFolder(Id relatedRecordId) {
		return ensureFolder(UserInfo.getUserId(), relatedRecordId);
	}

	public String ensureFolder(Id initiatorUserId, Id relatedRecordId) {
		return resolveFolderId(initiatorUserId, relatedRecordId, true);
	}

	public String findExistingFolder(Id initiatorUserId, Id relatedRecordId) {
		return resolveFolderId(initiatorUserId, relatedRecordId, false);
	}

	private String resolveFolderId(Id initiatorUserId, Id relatedRecordId, Boolean createIfMissing) {
		List<String> uploadParentFolderIds = metadataService.getTargetFolderResolver().resolveUploadFolderId();
		String rootFolderId = getFirstFolderId(uploadParentFolderIds);
		if (String.isBlank(rootFolderId)) return null;

		String folderStructure = metadataService.getGoogleDriveFolderStructure();
		if (String.isBlank(folderStructure)) return null;

		FolderTargets folderTargets = buildFolderTargets(initiatorUserId, relatedRecordId);
		return resolveDestinationFolderId(folderStructure, rootFolderId, initiatorUserId, folderTargets.userFolderName, folderTargets.relatedRecordId, folderTargets.recordFolderName, createIfMissing);
	}

	private FolderTargets buildFolderTargets(Id initiatorUserId, Id relatedRecordId) {
		FolderTargets targets = new FolderTargets();
		targets.relatedRecordId = relatedRecordId;
		targets.userFolderName = buildUserFolderName(initiatorUserId);
		targets.recordFolderName = buildRecordFolderName(relatedRecordId);
		return targets;
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

		List<User> users = [
			SELECT Id, FirstName, LastName
			FROM User
			WHERE Id = :userId
			LIMIT 1
		];

		return users.isEmpty() ? null : users[0];
	}

	private String buildRecordFolderName(Id relatedRecordId) {
		if (relatedRecordId == null) return null;

		Schema.SObjectType objectType = relatedRecordId.getSObjectType();
		String objectApiName = objectType.getDescribe().getName();
		String recordName = linkEnrichmentService.resolveLinkedRecordName(relatedRecordId);

		return objectApiName + ' : ' + (String.isBlank(recordName) ? 'Unknown Record' : recordName);
	}

	private String resolveDestinationFolderId(String folderStructure, String rootFolderId, Id userId, String userFolderName, Id recordId, String recordFolderName, Boolean createIfMissing) {
		if (String.isBlank(folderStructure)) return null;

		if (folderStructure == GoogleCloudConstants.STRUCTURE_USER) {
			return resolveFolder(rootFolderId, userFolderName, userId, createIfMissing);
		}

		if (folderStructure == GoogleCloudConstants.STRUCTURE_RECORD) {
			if (recordId == null) return null;
			return resolveFolder(rootFolderId, recordFolderName, recordId, createIfMissing);
		}

		if (folderStructure == GoogleCloudConstants.STRUCTURE_USER_RECORD) {
			if (recordId == null) return null;
			String userFolderId = resolveFolder(rootFolderId, userFolderName, userId, createIfMissing);
			if (String.isBlank(userFolderId)) return null;

			return resolveFolder(userFolderId, recordFolderName, recordId, createIfMissing);
		}

		if (folderStructure == GoogleCloudConstants.STRUCTURE_RECORD_USER) {
			if (recordId == null) return null;
			String recordFolderId = resolveFolder(rootFolderId, recordFolderName, recordId, createIfMissing);
			if (String.isBlank(recordFolderId)) return null;

			return resolveFolder(recordFolderId, userFolderName, userId, createIfMissing);
		}

		return null;
	}

	private String resolveFolder(String parentFolderId, String folderName, Id uniqueIdValue, Boolean createIfMissing) {
		if (String.isBlank(parentFolderId) || uniqueIdValue == null) return null;

		String existingFolderId = findFolderIdByUniqueId(parentFolderId, uniqueIdValue);
		if (String.isNotBlank(existingFolderId)) {
			return existingFolderId;
		}

		if (createIfMissing != true) return null;

		return createFolder(parentFolderId, folderName, uniqueIdValue);
	}

	private String findFolderIdByUniqueId(String parentFolderId, Id uniqueIdValue) {
		String escapedParentId = escapeQueryValue(parentFolderId);
		String escapedUniqueId = escapeQueryValue(uniqueIdValue);

		String query = 'mimeType = \'' + FOLDER_MIME_TYPE + '\' ';
		query += 'and \'' + escapedParentId + '\' in parents ';
		query += 'and trashed = false ';
		query += 'and appProperties has { key=\'' + APP_PROPERTY_RECORD_ID + '\' and value=\'' + escapedUniqueId + '\' }';

		GoogleFileSearchResult searchResult = remoteGoogleDrive.files().search()
			.setMaxResult(1)
			.setSearchQuery(query)
			.setSearchOnAllDrives(true)
			.setFields('files(id,name)')
			.execute();

		if (searchResult != null && searchResult.files != null && !searchResult.files.isEmpty()) {
			return searchResult.files[0].id;
		}

		return null;
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

	private class FolderTargets {
		public String userFolderName;
		public String recordFolderName;
		public Id relatedRecordId;
	}
}