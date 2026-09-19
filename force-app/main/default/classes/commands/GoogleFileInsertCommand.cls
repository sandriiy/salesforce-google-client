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
 * Registers the Salesforce side of an upload once the bytes are already in Drive: a new
 * GoogleFile__c with its first version and the link to the record, or just a new version when
 * the upload belongs to an existing file. Nothing is inserted here. The rows go on the unit of
 * work and the service that owns it commits, in the package write order that puts the link
 * before the version so the version trigger can find the record folder.
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

    /**
     * @param uowRef The unit of work the rows are registered on; the caller commits it.
     */
    public GoogleFileInsertCommand(IGoogleUnitOfWork uowRef) {
        this.uowRef = uowRef;
    }

    /**
     * Sets the record the file is linked to. Leave it unset for a standalone upload, which
     * creates the file with no link at all.
     *
     * @param value The Id of the record the file belongs to; any object.
     * @return This same instance, so the setters chain onto save().
     */
    public GoogleFileInsertCommand setRecordId(Id value) {
        this.relatedRecordId = value;
        return this;
    }

    /**
     * Sets the Drive Id of the uploaded content, stored on the version.
     *
     * @param value The Drive file Id.
     * @return This same instance, so the setters chain onto save().
     */
    public GoogleFileInsertCommand setGoogleDriveId(String value) {
        this.googleDriveFileId = value;
        return this;
    }

    /**
     * Sets the uploaded file name. The file record gets it without the extension, the version
     * keeps the extension, and both are trimmed to fit the Name field.
     *
     * @param value The original file name; blank falls back to the default name.
     * @return This same instance, so the setters chain onto save().
     */
    public GoogleFileInsertCommand setFileName(String value) {
        this.fileName = value;
        return this;
    }

    /**
     * Sets the MIME type of the uploaded content.
     *
     * @param value The MIME type as the browser or Drive reported it.
     * @return This same instance, so the setters chain onto save().
     */
    public GoogleFileInsertCommand setFileType(String value) {
        this.fileType = value;
        return this;
    }

    /**
     * Sets the size of the uploaded content in bytes.
     *
     * @param value The size in bytes.
     * @return This same instance, so the setters chain onto save().
     */
    public GoogleFileInsertCommand setFileSize(Long value) {
        this.fileSize = value;
        return this;
    }

    /**
     * Sets the Drive folder the content was uploaded into, before any record-folder placement
     * moves it.
     *
     * @param value The Drive folder Id.
     * @return This same instance, so the setters chain onto save().
     */
    public GoogleFileInsertCommand setParentFolderId(String value) {
        this.googleDriveFolderId = value;
        return this;
    }

    /**
     * Sets where the upload came from, stored on the file and on its link.
     *
     * @param value The source label, for example the component or flow that uploaded the file.
     * @return This same instance, so the setters chain onto save().
     */
    public GoogleFileInsertCommand setSource(String value) {
        this.source = value;
        return this;
    }

    /**
     * Points the upload at an existing GoogleFile__c, so save() registers a new version of that
     * file instead of a new file. The record Id and source are then ignored.
     *
     * @param value The existing file record Id.
     * @return This same instance, so the setters chain onto save().
     */
    public GoogleFileInsertCommand setLocalGoogleFileId(Id value) {
        this.existingLocalGoogleFileId = value;
        return this;
    }

    /**
     * Registers the rows and hands them back before they have Ids. Read the Ids only after the
     * unit of work has committed.
     *
     * @return The registered file, version and link, or the version alone when it was added to
     * an existing file.
     */
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
                LinkedObjectType__c = relatedRecordId.getSObjectType().getDescribe().getName(),
                Source__c = source
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
		return new GoogleFileLinkDefaultsResolver().applyDefaultValues(newLink);
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

    /**
     * The rows save() registered. They are the very instances the unit of work inserts, so
     * their Ids appear on them after the commit without a query.
     */
    public class GoogleFileInsertResult {
        /**
         * True when a new GoogleFile__c was registered, false when only a version was added.
         */
        public Boolean isNewFile;

        /**
         * Set only for a new version of an existing file; getLocalGoogleFileId() covers both cases.
         */
        public Id localGoogleFileId;
        /**
         * Null for a new version of an existing file.
         */
        public GoogleFile__c localGoogleFileRecord;

        public GoogleFileVersion__c localGoogleFileVersionRecord;
        /**
         * Null for a standalone upload and for a new version of an existing file.
         */
        public GoogleFileLink__c localGoogleFileLinkRecord;

        /**
         * Returns the file Id whichever branch save() took.
         *
         * @return The existing file Id, the new record's Id once committed, or null before that.
         */
        public Id getLocalGoogleFileId() {
            if (this.localGoogleFileId != null) return this.localGoogleFileId;
            return this.localGoogleFileRecord == null ? null : this.localGoogleFileRecord.Id;
        }

        /**
         * @return The version Id once committed, or null before that.
         */
        public Id getLocalGoogleFileVersionId() {
            return this.localGoogleFileVersionRecord == null ? null : this.localGoogleFileVersionRecord.Id;
        }

        /**
         * @return The link Id once committed, or null when no link was registered.
         */
        public Id getLocalGoogleFileLinkId() {
            return this.localGoogleFileLinkRecord == null ? null : this.localGoogleFileLinkRecord.Id;
        }
    }
}