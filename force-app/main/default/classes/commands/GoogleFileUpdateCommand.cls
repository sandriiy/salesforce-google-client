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
public without sharing class GoogleFileUpdateCommand {
    public class GoogleFileUpdateResult {
        public GoogleFile__c localGoogleFileToUpdate;
        public GoogleFileVersion__c localGoogleFileVersionToUpdate;
    }

    private static final Integer MAX_FILE_NAME_LENGTH = 80;

    private final GoogleFile__c localGoogleFileRecord;
    private final GoogleFileVersion__c localGoogleFileVersionRecord;
    private String fileName;
    private String fileVersionName;
    private String fileDescription;

    public GoogleFileUpdateCommand(GoogleFile__c localGoogleFileRecord, GoogleFileVersion__c localGoogleFileVersionRecord) {
        this.localGoogleFileRecord = localGoogleFileRecord;
        this.localGoogleFileVersionRecord = localGoogleFileVersionRecord;
    }

    public GoogleFileUpdateCommand changeFileNameTo(String value) {
        this.fileName = value;
        return this;
    }

    public GoogleFileUpdateCommand changeFileVersionNameTo(String value) {
        this.fileVersionName = value;
        return this;
    }

    public GoogleFileUpdateCommand changeFileDescriptionTo(String value) {
        this.fileDescription = value;
        return this;
    }

    public GoogleFileUpdateResult build() {
        Logger.info('File Update --> FileId=' + String.valueOf(localGoogleFileRecord.Id) + ', VersionId=' + String.valueOf(localGoogleFileVersionRecord.Id) + ', NewFileName=' + String.valueOf(fileName) + ', NewVersionName=' + String.valueOf(fileVersionName) + ', NewDescription=' + String.valueOf(fileDescription)).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
        GoogleFileUpdateResult result = new GoogleFileUpdateResult();
        result.localGoogleFileToUpdate = buildFileUpdate();
        result.localGoogleFileVersionToUpdate = buildFileVersionUpdate();
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