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
public without sharing class GoogleFileStoreInFolderCommand {
	public class GoogleFileStoreInFolderCommandException extends Exception {}

    private GoogleDrive remoteGoogleDrive;
    private GoogleMetadataConfigService metadataService;
    private GoogleFileFolderStructureCommand folderStructureCommand;
    private final IGoogleUnitOfWork uowRef;

    public GoogleFileStoreInFolderCommand(IGoogleUnitOfWork uowRef) {
        this.remoteGoogleDrive = new GoogleClientApiProvider().retrieveGoogleDriveClient();
        this.metadataService = new GoogleMetadataConfigService();
        this.folderStructureCommand = new GoogleFileFolderStructureCommand();
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
        String primaryRootFolderId = getFirstFolderId(uploadParentFolderIds);

        RemoteFileIds remoteFileIds = loadRemoteFileIds(request.localGoogleFileVersionId);

        Logger.info(
            'Folder Placement Job --> RemoteIds' +
            ', GoogleDriveFileId=' + String.valueOf(remoteFileIds == null ? null : remoteFileIds.googleDriveFileId) +
            ', GoogleWorkspaceFileId=' + String.valueOf(remoteFileIds == null ? null : remoteFileIds.googleWorkspaceFileId) +
            ', StoredGoogleDriveFolderId=' + String.valueOf(remoteFileIds == null ? null : remoteFileIds.currentGoogleDriveFolderId)
        ).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

        if (remoteFileIds == null || String.isBlank(remoteFileIds.googleDriveFileId)) {
            Logger.error('Folder Placement Job Failed --> Remote GoogleDriveFileId is blank' + ', VersionId=' + String.valueOf(request.localGoogleFileVersionId)).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			return;
        }

        String effectiveRootFolderId = resolveEffectiveRootFolderId(remoteFileIds, primaryRootFolderId);
        if (String.isBlank(effectiveRootFolderId)) return;

        Id relatedRecordId = loadRelatedRecordId(request);
        String destinationFolderId = folderStructureCommand.findExistingFolder(effectiveRootFolderId, request.initiatorUserId, relatedRecordId);
        if (String.isBlank(destinationFolderId)) {
            destinationFolderId = folderStructureCommand.ensureFolder(effectiveRootFolderId, request.initiatorUserId, relatedRecordId);
        }
		
        if (String.isBlank(destinationFolderId)) return;

        List<String> foldersToDetach = new List<String>{effectiveRootFolderId};

        Logger.info(
            'Folder Placement Job --> Move' +
            ', SourceFileId=' + String.valueOf(remoteFileIds.googleDriveFileId) +
            ', EffectiveRootFolderId=' + String.valueOf(effectiveRootFolderId) +
            ', DestinationFolderId=' + String.valueOf(destinationFolderId) +
            ', RemoveParents=' + String.valueOf(foldersToDetach)
        ).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

        GoogleFileEntity movedFile;
        try {
            movedFile = this.remoteGoogleDrive.files().modify().metadata(remoteFileIds.googleDriveFileId)
                .addParentFolders(new List<String>{destinationFolderId})
                .removeParentFolders(foldersToDetach)
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
            moveRemoteFile(remoteFileIds.googleWorkspaceFileId, foldersToDetach, destinationFolderId);
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
            versionRecord.GoogleDocsFileId__c,
            versionRecord.GoogleDriveFolderId__c
        );
    }

    private Id loadRelatedRecordId(GoogleFileRelocationRequestDTO request) {
        if (request == null || request.linkLocalGoogleFileId == null) return null;

        GoogleFileLink__c fileLink = (GoogleFileLink__c) GoogleFileLinkSelector.query()
            .withBaseFields()
            .byId(request.linkLocalGoogleFileId)
            .toObject();

        return fileLink == null || String.isBlank(fileLink.LinkedObjectId__c)
            ? null
            : (Id) fileLink.LinkedObjectId__c;
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

    private String resolveEffectiveRootFolderId(RemoteFileIds remoteFileIds, String primaryRootFolderId) {
        if (remoteFileIds != null && String.isNotBlank(remoteFileIds.currentGoogleDriveFolderId)) {
            return remoteFileIds.currentGoogleDriveFolderId;
        }

        String parentFromDrive = fetchCurrentParentFromDrive(remoteFileIds == null ? null : remoteFileIds.googleDriveFileId);
        if (String.isNotBlank(parentFromDrive)) {
            Logger.info(
                'Folder Placement Job --> Effective root resolved via Drive lookup' +
                ', SourceFileId=' + String.valueOf(remoteFileIds.googleDriveFileId) +
                ', EffectiveRootFolderId=' + parentFromDrive
            ).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
            return parentFromDrive;
        }

        return primaryRootFolderId;
    }

    private String fetchCurrentParentFromDrive(String googleDriveFileId) {
        if (String.isBlank(googleDriveFileId)) return null;

        try {
            GoogleFileEntity currentFile = this.remoteGoogleDrive.files().retrieve().download(googleDriveFileId)
                .setFileDownloadType(GoogleDownloadFileBuilder.DownloadType.METADATA)
                .setSearchOnAllDrives(true)
                .setFields('id, parents')
                .execute();

            if (currentFile == null || currentFile.parents == null) return null;

            for (String parent : currentFile.parents) {
                if (String.isNotBlank(parent)) return parent;
            }
        } catch (Exception ex) {
            Logger.info(
                'Folder Placement Job --> Drive parent lookup failed' +
                ', SourceFileId=' + String.valueOf(googleDriveFileId) +
                ', Error=' + ex.getMessage()
            ).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
        }

        return null;
    }

    private class RemoteFileIds {
        public String googleDriveFileId;
        public String googleWorkspaceFileId;
        public String currentGoogleDriveFolderId;

        public RemoteFileIds(String googleDriveFileId, String googleWorkspaceFileId, String currentGoogleDriveFolderId) {
            this.googleDriveFileId = googleDriveFileId;
            this.googleWorkspaceFileId = googleWorkspaceFileId;
            this.currentGoogleDriveFolderId = currentGoogleDriveFolderId;
        }
    }
}