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
 * Renames a file and its version and changes the description, keeping the original extension and
 * the 80 character limit on the name. It registers the changes and leaves the commit to the service.
 */
public without sharing class GoogleFileUpdateCommand {
    /**
     * What the command registered. A field is null when that record needed no change, which is how the
     * service knows whether committing is worth it.
     */
    public class GoogleFileUpdateResult {
        public GoogleFile__c localGoogleFileToUpdate;
        public GoogleFileVersion__c localGoogleFileVersionToUpdate;
    }

    private static final Integer MAX_FILE_NAME_LENGTH = 80;

    private final IGoogleUnitOfWork uowRef;
    private final GoogleFile__c localGoogleFileRecord;
    private final GoogleFileVersion__c localGoogleFileVersionRecord;
    private String fileName;
    private String fileVersionName;
    private String fileDescription;

    /**
     * Builds the command around the records being edited. Both records must carry their current Name,
     * because the command compares against it and keeps the extension it finds there.
     *
     * @param uowRef The unit of work the updates are registered on.
     * @param localGoogleFileRecord The file being renamed.
     * @param localGoogleFileVersionRecord The version being renamed.
     */
    public GoogleFileUpdateCommand(IGoogleUnitOfWork uowRef, GoogleFile__c localGoogleFileRecord, GoogleFileVersion__c localGoogleFileVersionRecord) {
        this.uowRef = uowRef;
        this.localGoogleFileRecord = localGoogleFileRecord;
        this.localGoogleFileVersionRecord = localGoogleFileVersionRecord;
    }

    /**
     * Sets the new file name. The extension of the current name is kept whatever you pass.
     *
     * @param value The new name, with or without the extension.
     * @return This same instance, so the call chains onto build().
     */
    public GoogleFileUpdateCommand changeFileNameTo(String value) {
        this.fileName = value;
        return this;
    }

    /**
     * Sets the new version name, which is the name users see on the version row.
     *
     * @param value The new version name, with or without the extension.
     * @return This same instance, so the call chains onto build().
     */
    public GoogleFileUpdateCommand changeFileVersionNameTo(String value) {
        this.fileVersionName = value;
        return this;
    }

    /**
     * Sets the new description. A blank value clears it.
     *
     * @param value The new description.
     * @return This same instance, so the call chains onto build().
     */
    public GoogleFileUpdateCommand changeFileDescriptionTo(String value) {
        this.fileDescription = value;
        return this;
    }

    /**
     * Works out what actually changed and registers only those records on the unit of work.
     *
     * @return The records that were registered, with a null for anything that did not need updating.
     */
    public GoogleFileUpdateResult build() {
        Logger.info('File Update --> FileId=' + String.valueOf(localGoogleFileRecord.Id) + ', VersionId=' + String.valueOf(localGoogleFileVersionRecord.Id) + ', NewFileName=' + String.valueOf(fileName) + ', NewVersionName=' + String.valueOf(fileVersionName) + ', NewDescription=' + String.valueOf(fileDescription)).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
        GoogleFileUpdateResult result = new GoogleFileUpdateResult();
        result.localGoogleFileToUpdate = buildFileUpdate();
        result.localGoogleFileVersionToUpdate = buildFileVersionUpdate();

        if (result.localGoogleFileToUpdate != null) uowRef.registerDirty(result.localGoogleFileToUpdate);
        if (result.localGoogleFileVersionToUpdate != null) uowRef.registerDirty(result.localGoogleFileVersionToUpdate);

        return result;
    }

    private GoogleFile__c buildFileUpdate() {
        String normalizedFileName = normalizeFileName(fileName, localGoogleFileRecord.Name);
        String normalizedFileDescription = normalizeDescription(fileDescription);

        Boolean isFileNameChanged = localGoogleFileRecord.Name != normalizedFileName;
        Boolean isFileDescriptionChanged = localGoogleFileRecord.Description__c != normalizedFileDescription;

        if (!isFileNameChanged && !isFileDescriptionChanged) {
            return null;
        }

        GoogleFile__c fileToUpdate = new GoogleFile__c(Id = localGoogleFileRecord.Id);

        if (isFileNameChanged) {
            fileToUpdate.Name = normalizedFileName;
        }

        if (isFileDescriptionChanged) {
            fileToUpdate.Description__c = normalizedFileDescription;
        }

        return fileToUpdate;
    }

    private GoogleFileVersion__c buildFileVersionUpdate() {
        String normalizedFileVersionName = normalizeFileName(fileVersionName, localGoogleFileVersionRecord.Name);

        if (localGoogleFileVersionRecord.Name == normalizedFileVersionName) {
            return null;
        }

        return new GoogleFileVersion__c(
            Id = localGoogleFileVersionRecord.Id,
            Name = normalizedFileVersionName
        );
    }

    private String normalizeFileName(String newValue, String originalValue) {
        String originalExtension = extractExtension(originalValue);
        String normalizedBaseName = String.isBlank(newValue)
            ? GoogleCloudConstants.DEFAULT_FILE_NAME
            : newValue.trim();

        if (!String.isBlank(originalExtension)) {
            if (normalizedBaseName.toLowerCase().endsWith(originalExtension.toLowerCase())) {
                normalizedBaseName = normalizedBaseName.substring(
                    0,
                    normalizedBaseName.length() - originalExtension.length()
                );
            } else {
                Integer lastDotIndex = normalizedBaseName.lastIndexOf('.');
                if (lastDotIndex >= 0) {
                    normalizedBaseName = normalizedBaseName.substring(0, lastDotIndex);
                }
            }
        }

        while (normalizedBaseName.endsWith('.')) {
            normalizedBaseName = normalizedBaseName.substring(0, normalizedBaseName.length() - 1);
        }

        if (String.isBlank(normalizedBaseName)) {
            normalizedBaseName = GoogleCloudConstants.DEFAULT_FILE_NAME;
        }

        Integer maxBaseNameLength = MAX_FILE_NAME_LENGTH - originalExtension.length();
        if (maxBaseNameLength < 1) {
            String fallbackName = GoogleCloudConstants.DEFAULT_FILE_NAME + originalExtension;
            return fallbackName.length() > MAX_FILE_NAME_LENGTH
                ? fallbackName.substring(0, MAX_FILE_NAME_LENGTH)
                : fallbackName;
        }

        if (normalizedBaseName.length() > maxBaseNameLength) {
            normalizedBaseName = normalizedBaseName.substring(0, maxBaseNameLength);
        }

        return normalizedBaseName + originalExtension;
    }

    private String extractExtension(String fileNameValue) {
        if (String.isBlank(fileNameValue)) {
            return '';
        }

        Integer lastDotIndex = fileNameValue.lastIndexOf('.');
        if (lastDotIndex <= 0 || lastDotIndex >= fileNameValue.length() - 1) {
            return '';
        }

        return fileNameValue.substring(lastDotIndex);
    }

    private String normalizeDescription(String value) {
        return String.isBlank(value) ? null : value;
    }
}