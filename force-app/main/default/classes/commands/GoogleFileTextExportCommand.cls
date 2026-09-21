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
 * Reads the text of a file out of Google Drive, either from the Google Workspace copy Google Client
 * prepares for previews or straight from the upload when it is already text. Both the AI commands and
 * the text extraction service read through here, so there is one answer to what a file says.
 */
public without sharing class GoogleFileTextExportCommand {
	private final GoogleClientApiProvider googleApiProvider;

	public GoogleFileTextExportCommand() {
		this(new GoogleClientApiProvider());
	}

	/**
	 * Builds the command on an existing provider, which is how a caller that already holds one avoids
	 * resolving a second access token in the same transaction.
	 *
	 * @param googleApiProvider The provider to reach Drive through. A null falls back to a new one.
	 */
	public GoogleFileTextExportCommand(GoogleClientApiProvider googleApiProvider) {
		this.googleApiProvider = googleApiProvider == null ? new GoogleClientApiProvider() : googleApiProvider;
	}

	/**
	 * Says whether this version can be read as text at all. A freshly uploaded document answers false
	 * until its Workspace copy exists, so ask before exporting rather than treating a blank as empty.
	 *
	 * @param localFileVersion The version to check, loaded with the confidential fields.
	 * @return True when there is a Workspace copy or the upload itself is plain text.
	 */
	public Boolean supportsTextExtraction(GoogleFileVersion__c localFileVersion) {
		return localFileVersion != null
			&& (String.isNotBlank(localFileVersion.GoogleDocsFileId__c) || supportsRawText(localFileVersion));
	}

	/**
	 * Gives back the whole file content as plain text, preferring the Workspace copy and falling back to
	 * the raw bytes for text, CSV, TSV and Markdown uploads.
	 *
	 * @param localFileVersion The version to read, loaded with the confidential fields.
	 * @return The text, or null when the file cannot be read as text.
	 */
	public String extractPlainText(GoogleFileVersion__c localFileVersion) {
		if (localFileVersion == null) return null;

		if (String.isNotBlank(localFileVersion.GoogleDocsFileId__c)) {
			return exportWorkspaceCopy(localFileVersion, GoogleCloudConstants.MIME_TYPE_TEXT);
		}

		if (!supportsRawText(localFileVersion)) return null;

		GoogleFileEntity result = googleApiProvider.retrieveGoogleDriveClient().files().retrieve().download(localFileVersion.GoogleDriveFileId__c)
			.setFileDownloadType(GoogleDownloadFileBuilder.DownloadType.CONTENT)
			.setSearchOnAllDrives(true)
			.execute();

		return toText(result);
	}

	/**
	 * Exports the Workspace copy in the format you ask for, which is how the AI commands get text and
	 * how Download As gets any other format.
	 *
	 * @param localFileVersion The version whose Workspace copy is exported.
	 * @param exportMimeType The MIME type Google exports to.
	 * @return The exported content as text, or null when there is no Workspace copy.
	 */
	public String exportWorkspaceCopy(GoogleFileVersion__c localFileVersion, String exportMimeType) {
		if (localFileVersion == null || String.isBlank(localFileVersion.GoogleDocsFileId__c)) return null;

		GoogleFileEntity result = googleApiProvider.retrieveGoogleDriveClient().files().retrieve().export(localFileVersion.GoogleDocsFileId__c)
			.setMimeType(exportMimeType)
			.setSearchOnAllDrives(true)
			.execute();

		return toText(result);
	}

	private Boolean supportsRawText(GoogleFileVersion__c localFileVersion) {
		return String.isNotBlank(localFileVersion.GoogleDriveFileId__c)
			&& GoogleCloudConstants.PLAIN_TEXT_MIME_TYPES.contains(localFileVersion.Type__c);
	}

	private String toText(GoogleFileEntity result) {
		return result == null || result.bodyAsBlob == null
			? null
			: result.bodyAsBlob.toString();
	}
}
