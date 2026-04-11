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
public without sharing class GoogleFileInsertCommand {
    public class GoogleFileInsertCommandException extends Exception {}

    private final IGoogleUnitOfWork uowRef;

    private Id relatedRecordId;
    private String fileName;
    private String fileType;
    private Long fileSize;
    private String googleDriveFileId;
    private String googleDriveFolderId;
    private String source;
    private Id existingLocalGoogleFileId;

    public GoogleFileInsertCommand(IGoogleUnitOfWork uowRef) {
        this.uowRef = uowRef;
    }

    public GoogleFileInsertCommand setRecordId(Id value) {
        this.relatedRecordId = value;
        return this;
    }

    public GoogleFileInsertCommand setGoogleDriveId(String value) {
        this.googleDriveFileId = value;
        return this;
    }

    public GoogleFileInsertCommand setFileName(String value) {
        this.fileName = value;
        return this;
    }

    public GoogleFileInsertCommand setFileType(String value) {
        this.fileType = value;
        return this;
    }

    public GoogleFileInsertCommand setFileSize(Long value) {
        this.fileSize = value;
        return this;
    }

    public GoogleFileInsertCommand setParentFolderId(String value) {
        this.googleDriveFolderId = value;
        return this;
    }

    public GoogleFileInsertCommand setSource(String value) {
        this.source = value;
        return this;
    }

    public GoogleFileInsertCommand setLocalGoogleFileId(Id value) {
        this.existingLocalGoogleFileId = value;
        return this;
    }

    public GoogleFileInsertResult save() {
        if (existingLocalGoogleFileId != null) {
            return registerNewVersion();
        }

        return registerNewFile();
    }

    private GoogleFileInsertResult registerNewVersion() {
        GoogleFileVersion__c versionRecord = new GoogleFileVersion__c(
            Name = buildLocalFileName(false),
            Type__c = fileType,
            Size__c = fileSize,
            GoogleFileId__c = existingLocalGoogleFileId,
            GoogleDriveFileId__c = googleDriveFileId,
            GoogleDriveFolderId__c = googleDriveFolderId
        );

        Logger.info('File Insert, Register New Version --> FileId=' + String.valueOf(existingLocalGoogleFileId)).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

        uowRef.registerNew(versionRecord);

        GoogleFileInsertResult result = new GoogleFileInsertResult();
        result.localGoogleFileId = existingLocalGoogleFileId;
        result.localGoogleFileVersionRecord = versionRecord;
        result.isNewFile = false;

        return result;
    }

    private GoogleFileInsertResult registerNewFile() {
        GoogleFile__c fileRecord = new GoogleFile__c(
            Name = buildLocalFileName(true),
            Source__c = source
        );

        GoogleFileVersion__c versionToBind = new GoogleFileVersion__c(
            Name = buildLocalFileName(false),
            Type__c = fileType,
            Size__c = fileSize,
            GoogleDriveFileId__c = googleDriveFileId,
            GoogleDriveFolderId__c = googleDriveFolderId
        );

        Logger.info(
            'File Insert, Register New File --> RemoteFileId=' + String.valueOf(googleDriveFileId) +
            ', UploadFolderId=' + String.valueOf(googleDriveFolderId) +
            ', Source=' + String.valueOf(source) +
            ', RelatedRecordId=' + String.valueOf(relatedRecordId)
        ).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

        uowRef.registerNew(fileRecord);
        uowRef.registerNew(versionToBind, GoogleFileVersion__c.GoogleFileId__c, fileRecord);

        GoogleFileLink__c linkToBind;
        if (shouldCreateLink()) {
            linkToBind = new GoogleFileLink__c(
                LinkedObjectId__c = String.valueOf(relatedRecordId),
                LinkedObjectType__c = relatedRecordId.getSObjectType().getDescribe().getName()
            );

            linkToBind = applyUserBasedChanges(linkToBind);
            uowRef.registerNew(linkToBind, GoogleFileLink__c.GoogleFileId__c, fileRecord);
        }

        GoogleFileInsertResult result = new GoogleFileInsertResult();
        result.localGoogleFileRecord = fileRecord;
        result.localGoogleFileVersionRecord = versionToBind;
        result.localGoogleFileLinkRecord = linkToBind; // null for standalone uploads
        result.isNewFile = true;

        return result;
    }

    private Boolean shouldCreateLink() {
        return relatedRecordId != null;
    }

    private GoogleFileLink__c applyUserBasedChanges(GoogleFileLink__c newLink) {
        User userRow = [SELECT Id, UserType FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];

        newLink.ShareType__c = isInternal(userRow.UserType) ? 'Viewer' : 'InferredFromRecord';
        newLink.Visibility__c = isInternal(userRow.UserType) ? 'InternalUsers' : 'AllUsers';

        return newLink;
    }

    private String buildLocalFileName(Boolean removeExtension) {
        String originalName = String.isBlank(fileName)
            ? GoogleCloudConstants.DEFAULT_FILE_NAME
            : fileName.trim();

        String namePart = originalName;
        String extPart = '';

        Integer lastDot = originalName.lastIndexOf('.');
        if (lastDot > 0 && lastDot < originalName.length() - 1) {
            namePart = originalName.substring(0, lastDot);

            if (!removeExtension) {
                extPart = originalName.substring(lastDot);
            }
        }

        Integer maxTotalLength = 80;
        Integer maxNameLength = maxTotalLength - extPart.length();

        if (maxNameLength < 1) {
            String fallback = GoogleCloudConstants.DEFAULT_FILE_NAME + extPart;
            return fallback.length() > maxTotalLength
                ? fallback.substring(0, maxTotalLength)
                : fallback;
        }

        if (namePart.length() > maxNameLength) {
            namePart = namePart.substring(0, maxNameLength);
        }

        return namePart + extPart;
    }

    private Boolean isInternal(String userType) {
        if (userType == null) return true;

        String t = userType.toLowerCase();
        if (t.contains('guest') || t.contains('portal') || t.contains('partner') || t.contains('customer') || t.contains('csn')) {
            return false;
        }

        return true;
    }

    public class GoogleFileInsertResult {
        public Boolean isNewFile;

        public Id localGoogleFileId;
        public GoogleFile__c localGoogleFileRecord;

        public GoogleFileVersion__c localGoogleFileVersionRecord;
        public GoogleFileLink__c localGoogleFileLinkRecord;

        public Id getLocalGoogleFileId() {
            if (this.localGoogleFileId != null) return this.localGoogleFileId;
            return this.localGoogleFileRecord == null ? null : this.localGoogleFileRecord.Id;
        }

        public Id getLocalGoogleFileVersionId() {
            return this.localGoogleFileVersionRecord == null ? null : this.localGoogleFileVersionRecord.Id;
        }

        public Id getLocalGoogleFileLinkId() {
            return this.localGoogleFileLinkRecord == null ? null : this.localGoogleFileLinkRecord.Id;
        }
    }
}