public without sharing class GoogleFileStoreInFolderCommand {
	public class GoogleFileStoreInFolderCommandException extends Exception {}

    private static final String FOLDER_MIME_TYPE = 'application/vnd.google-apps.folder';
    private static final String APP_PROPERTY_RECORD_ID = 'record-id';

    private static final String STRUCTURE_USER = '{User}';
    private static final String STRUCTURE_RECORD = '{Record}';
    private static final String STRUCTURE_USER_RECORD = '{User}-{Record}';
    private static final String STRUCTURE_RECORD_USER = '{Record}-{User}';

    private GoogleDrive remoteGoogleDrive;
    private GoogleMetadataConfigService metadataService;
    private final IGoogleUnitOfWork uowRef;

    public GoogleFileStoreInFolderCommand(IGoogleUnitOfWork uowRef) {
        this.remoteGoogleDrive = new GoogleDriveApiProvider().retrieveGoogleDriveClient();
        this.metadataService = new GoogleMetadataConfigService();
        this.uowRef = uowRef;
    }

    public void placeFile(GoogleFileRelocationRequestDTO request) {
        if (request == null) {
            Logger.error('Folder Placement Job Failed --> request is null').addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
            throw new GoogleFileStoreInFolderCommandException('Folder Placement Job Failed, request is empty');
        }

        if (request.localGoogleFileVersionId == null) {
            Logger.error('Folder Placement Job Failed --> localGoogleFileVersionId is null').addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
            throw new GoogleFileStoreInFolderCommandException('Folder Placement Job Failed, localGoogleFileVersionId is empty');
        }

        List<String> uploadParentFolderIds = this.metadataService.getTargetFolderResolver().resolveUploadFolderId();

        String folderStructure = this.metadataService.getGoogleDriveFolderStructure();
        if (String.isBlank(folderStructure)) return;

        Logger.info(
            'Folder Placement Job --> Config' +
            ', FolderStructure=' + String.valueOf(folderStructure) +
            ', UploadParentFolderIds=' + String.valueOf(uploadParentFolderIds)
        ).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

        String rootFolderId = getFirstFolderId(uploadParentFolderIds);
        if (String.isBlank(rootFolderId)) return;

        RemoteFileIds remoteFileIds = loadRemoteFileIds(request.localGoogleFileVersionId);

        Logger.info(
            'Folder Placement Job --> RemoteIds' +
            ', GoogleDriveFileId=' + String.valueOf(remoteFileIds == null ? null : remoteFileIds.googleDriveFileId) +
            ', GoogleWorkspaceFileId=' + String.valueOf(remoteFileIds == null ? null : remoteFileIds.googleWorkspaceFileId)
        ).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

        if (remoteFileIds == null || String.isBlank(remoteFileIds.googleDriveFileId)) {
            Logger.error('Folder Placement Job Failed --> Remote GoogleDriveFileId is blank' + ', VersionId=' + String.valueOf(request.localGoogleFileVersionId)).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			return;
        }

        FolderTargets folderTargets = loadFolderTargets(request);

        String destinationFolderId = resolveDestinationFolderId(
            folderStructure,
            rootFolderId,
            request.initiatorUserId,
            folderTargets.userFolderName,
            folderTargets.relatedRecordId,
            folderTargets.recordFolderName
        );
        if (String.isBlank(destinationFolderId)) return;

        Logger.info(
            'Folder Placement Job --> Move' +
            ', SourceFileId=' + String.valueOf(remoteFileIds.googleDriveFileId) +
            ', DestinationFolderId=' + String.valueOf(destinationFolderId) +
            ', RemoveParents=' + String.valueOf(uploadParentFolderIds)
        ).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

        GoogleFileEntity movedFile;
        try {
            movedFile = this.remoteGoogleDrive.files().modify().metadata(remoteFileIds.googleDriveFileId)
                .addParentFolders(new List<String>{destinationFolderId})
                .removeParentFolders(uploadParentFolderIds)
                .setSupportsAllDrives(true)
                .execute();
        } catch (Exception e) {
            Logger.error(
                'Folder Placement Job Failed --> Move failed' +
                ', SourceFileId=' + String.valueOf(remoteFileIds.googleDriveFileId) +
                ', DestinationFolderId=' + String.valueOf(destinationFolderId) +
                ', Error=' + e.getMessage()
            ).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

            throw new GoogleFileStoreInFolderCommandException('Folder Placement Job Failed, remote move failed');
        }

        String resultingGoogleDriveFileId = movedFile == null ? null : movedFile.id;
        if (String.isBlank(resultingGoogleDriveFileId)) return;

        if (!String.isBlank(remoteFileIds.googleWorkspaceFileId)) {
            moveRemoteFile(remoteFileIds.googleWorkspaceFileId, uploadParentFolderIds, destinationFolderId);
        }

        registerLatestVersionFolderUpdate(
            request.localGoogleFileVersionId,
            resultingGoogleDriveFileId,
            destinationFolderId
        );
    }

    private String moveRemoteFile(String remoteFileId, List<String> uploadParentFolderIds, String destinationFolderId) {
        GoogleFileEntity movedFile = this.remoteGoogleDrive.files().modify().metadata(remoteFileId)
            .addParentFolders(new List<String>{destinationFolderId})
            .removeParentFolders(uploadParentFolderIds)
            .setSupportsAllDrives(true)
            .execute();

        return movedFile == null ? null : movedFile.id;
    }

    private RemoteFileIds loadRemoteFileIds(Id localGoogleFileVersionId) {
        if (localGoogleFileVersionId == null) return null;

        GoogleFileVersion__c versionRecord = (GoogleFileVersion__c) GoogleFileVersionSelector.query()
            .withAdvancedFields()
            .byId(localGoogleFileVersionId)
            .toObject();

        if (versionRecord == null) {
            Logger.error(
                'Folder Placement Job Failed --> GoogleFileVersion__c not found' +
                ', VersionId=' + String.valueOf(localGoogleFileVersionId)
            ).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

            throw new GoogleFileStoreInFolderCommandException('Folder Placement Job Failed, Google File Version not found');
        }

        return new RemoteFileIds(
            versionRecord.GoogleDriveFileId__c,
            versionRecord.GoogleDocsFileId__c
        );
    }

    private FolderTargets loadFolderTargets(GoogleFileRelocationRequestDTO request) {
        FolderTargets targets = new FolderTargets();

        GoogleFileLink__c fileLink;
        if (request != null && request.linkLocalGoogleFileId != null) {
            fileLink = (GoogleFileLink__c) GoogleFileLinkSelector.query()
                .withBaseFields()
                .byId(request.linkLocalGoogleFileId)
                .toObject();
        }

        targets.userFolderName = buildUserFolderName(request == null ? null : request.initiatorUserId);
        targets.relatedRecordId = fileLink == null || String.isBlank(fileLink.LinkedObjectId__c)
            ? null
            : (Id) fileLink.LinkedObjectId__c;
        targets.recordFolderName = buildRecordFolderName(fileLink, targets.relatedRecordId);

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

    private String buildRecordFolderName(GoogleFileLink__c fileLink, Id relatedRecordId) {
        if (relatedRecordId == null) return null;

        String explicitType = fileLink == null ? '' : fileLink.LinkedObjectType__c;
        String explicitName = fileLink == null ? '' : fileLink.LinkedObjectName__c;

        if (String.isBlank(explicitType) && String.isBlank(explicitName)) {
            return 'Record : ' + String.valueOf(relatedRecordId);
        }

        return explicitType + ' : ' + (String.isBlank(explicitName) ? 'Unknown Record' : explicitName);
    }

    private String resolveDestinationFolderId(String folderStructure, String rootFolderId, Id userId, String userFolderName, Id recordId, String recordFolderName) {
        if (String.isBlank(folderStructure)) return null;

        if (folderStructure == STRUCTURE_USER) {
            return getOrCreateFolder(rootFolderId, userFolderName, String.valueOf(userId));
        }

        Boolean hasRecord = recordId != null;
        if (!hasRecord) {
            return getOrCreateFolder(rootFolderId, userFolderName, String.valueOf(userId));
        }

        if (folderStructure == STRUCTURE_RECORD) {
            return getOrCreateFolder(rootFolderId, recordFolderName, String.valueOf(recordId));
        }

        if (folderStructure == STRUCTURE_USER_RECORD) {
            String userFolderId = getOrCreateFolder(rootFolderId, userFolderName, String.valueOf(userId));
            if (String.isBlank(userFolderId)) return null;

            return getOrCreateFolder(userFolderId, recordFolderName, String.valueOf(recordId));
        }

        if (folderStructure == STRUCTURE_RECORD_USER) {
            String recordFolderId = getOrCreateFolder(rootFolderId, recordFolderName, String.valueOf(recordId));
            if (String.isBlank(recordFolderId)) return null;

            return getOrCreateFolder(recordFolderId, userFolderName, String.valueOf(userId));
        }

        return null;
    }

    private String getOrCreateFolder(String parentFolderId, String folderName, String uniqueIdValue) {
        if (String.isBlank(parentFolderId)) return null;
        if (String.isBlank(uniqueIdValue)) return null;

        String existingFolderId = findFolderIdByUniqueId(parentFolderId, uniqueIdValue);
        if (!String.isBlank(existingFolderId)) {
            return existingFolderId;
        }

        return createFolder(parentFolderId, folderName, uniqueIdValue);
    }

    private String findFolderIdByUniqueId(String parentFolderId, String uniqueIdValue) {
        String escapedParentId = escapeQueryValue(parentFolderId);
        String escapedUniqueId = escapeQueryValue(uniqueIdValue);

        String query = 'mimeType = \'' + FOLDER_MIME_TYPE + '\' ';
        query += 'and \'' + escapedParentId + '\' in parents ';
        query += 'and trashed = false ';
        query += 'and appProperties has { key=\'' + APP_PROPERTY_RECORD_ID + '\' and value=\'' + escapedUniqueId + '\' }';

        GoogleFileSearchResult searchResult = this.remoteGoogleDrive.files().search()
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

    private String createFolder(String parentFolderId, String folderName, String uniqueIdValue) {
        Map<String, Object> customAttributes = new Map<String, Object>{
            APP_PROPERTY_RECORD_ID => uniqueIdValue
        };

        String entityName = String.isBlank(folderName) ? 'Untitled' : folderName.trim();
        GoogleFileEntity createdFolder = this.remoteGoogleDrive.files().multipartCreate()
            .setFileName(entityName)
            .setMimeType('application/vnd.google-apps.folder')
            .setParentFolders(new List<String>{ parentFolderId })
            .setCustomAttributes(customAttributes)
            .setSupportsAllDrives(true)
            .setBody('')
            .execute();

        return createdFolder == null ? null : createdFolder.id;
    }

    private void registerLatestVersionFolderUpdate(Id localGoogleFileVersionId, String resultingRemoteFileId, String destinationFolderId) {
        if (localGoogleFileVersionId == null) return;
        if (String.isBlank(destinationFolderId)) return;

        GoogleFileVersion__c versionRecord = (GoogleFileVersion__c) GoogleFileVersionSelector.query()
            .withBaseFields()
            .byId(localGoogleFileVersionId)
            .toObject();

        if (versionRecord == null) return;

        GoogleFileVersion__c updatedVersion = new GoogleFileVersion__c(
            Id = versionRecord.Id,
            GoogleDriveFolderId__c = destinationFolderId,
            GoogleDriveFileId__c = resultingRemoteFileId
        );

        uowRef.registerDirty(updatedVersion);
    }

    private String getFirstFolderId(List<String> folderIds) {
        if (folderIds == null || folderIds.isEmpty()) return null;

        for (String folderId : folderIds) {
            if (!String.isBlank(folderId)) return folderId;
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

    private class RemoteFileIds {
        public String googleDriveFileId;
        public String googleWorkspaceFileId;

        public RemoteFileIds(String googleDriveFileId, String googleWorkspaceFileId) {
            this.googleDriveFileId = googleDriveFileId;
            this.googleWorkspaceFileId = googleWorkspaceFileId;
        }
    }
}