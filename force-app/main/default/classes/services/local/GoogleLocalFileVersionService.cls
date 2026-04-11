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
public without sharing class GoogleLocalFileVersionService {
	public class GoogleFileVersionException extends Exception {}
	public enum AccessLevel { View, Edit }

	private final GoogleMetadataConfigService googleConfig;
	private final GoogleClientApiProvider remoteFileService;

	public GoogleLocalFileVersionService() {
		this.googleConfig = new GoogleMetadataConfigService();
		this.remoteFileService = new GoogleClientApiProvider();
	}

	public GoogleFilePreviewAction validatePreviewEligible(Id localFileVersionId) {
		GoogleFileVersion__c localFileVersion = queryLocalFileVersion(localFileVersionId);
		return assertPreviewEligible(localFileVersion); // Method will throw exception if not eligible
	}

	public String downloadFileBase64BodyAsPdf(Id localFileVersionId) {
		GoogleFileVersion__c localFileVersion = queryLocalFileVersion(localFileVersionId);
		GoogleFileEntity fileResult = exportOrDownloadAsPdf(localFileVersion);
		return EncodingUtil.base64Encode(fileResult.bodyAsBlob);
	}

	public String downloadFileBase64Body(Id localFileVersionId) {
		GoogleFileVersion__c localFileVersion = queryLocalFileVersion(localFileVersionId);

		GoogleDrive removeGoogleDrive = this.remoteFileService.retrieveGoogleDriveClient();
		GoogleFileEntity remoteFileEntity = removeGoogleDrive.files().retrieve().download(localFileVersion.GoogleDriveFileId__c)
			.setFileDownloadType(GoogleDownloadFileBuilder.DownloadType.CONTENT)
			.setSearchOnAllDrives(true)
			.execute();

		return EncodingUtil.base64Encode(remoteFileEntity.bodyAsBlob);
	}

	public String downloadFileBase64Body(Id localFileVersionId, Long startByte, Long endByte) {
		GoogleFileVersion__c localFileVersion = queryLocalFileVersion(localFileVersionId);

		GoogleDrive removeGoogleDrive = this.remoteFileService.retrieveGoogleDriveClient();
		GoogleFileEntity remoteFileEntity = removeGoogleDrive.files().retrieve().download(localFileVersion.GoogleDriveFileId__c)
			.setFileDownloadType(GoogleDownloadFileBuilder.DownloadType.CONTENT)
			.setPartialRange(startByte, endByte)
			.setSearchOnAllDrives(true)
			.execute();

		return EncodingUtil.base64Encode(remoteFileEntity.bodyAsBlob);
	}

	private GoogleFileVersion__c queryLocalFileVersion(Id localFileVersionId) {
		return (GoogleFileVersion__c) GoogleFileVersionSelector.query()
			.withAdvancedFields()
			.byId(localFileVersionId)
			.toObject();
	}

	private GoogleFileEntity exportOrDownloadAsPdf(GoogleFileVersion__c localFileVersion) {
		GoogleDrive removeGoogleDrive = this.remoteFileService.retrieveGoogleDriveClient();

		if (localFileVersion.Type__c == 'application/pdf') {
			return removeGoogleDrive.files().retrieve().download(localFileVersion.GoogleDriveFileId__c)
				.setFileDownloadType(GoogleDownloadFileBuilder.DownloadType.CONTENT)
				.setSearchOnAllDrives(true)
				.execute();
		}

		return removeGoogleDrive.files().retrieve().export(localFileVersion.GoogleDocsFileId__c)
			.setMimeType('application/pdf')
			.setSearchOnAllDrives(true)
			.execute();
	}

	private GoogleFilePreviewAction assertPreviewEligible(GoogleFileVersion__c localFileVersion) {
		if (this.googleConfig.isPreviewDisabled() || localFileVersion == null) {
			throw new GoogleFileVersionException('Preview Unavailable. Please download it to open');
		}

		if (localFileVersion.Type__c == 'application/pdf') {
			return GoogleFilePreviewAction.DIRECT;
		}

		if (localFileVersion.Size__c > this.googleConfig.getBigFileSizeInBytes()) {
			throw new GoogleFileVersionException('Oops! This file is too large to preview. Please download it to open');
		} else if (isVersionPreviewDocInProgress(localFileVersion)) {
			throw new GoogleFileVersionException('Preview is being prepared. Please try again shortly or download the file');
		} else if (isVersionPreviewDocUnavailable(localFileVersion)) {
			throw new GoogleFileVersionException('Preview unavailable for the selected file type. Please download the file to open');
		}

		return GoogleFilePreviewAction.CONVERT;
	}

	private Boolean isVersionPreviewDocInProgress(GoogleFileVersion__c fileVersion) {
		return (
			fileVersion.IsPreviewableFile__c &&
			String.isBlank(fileVersion.GoogleDocsFileId__c) &&
			fileVersion.Type__c != 'application/pdf'
		);
	}

	private Boolean isVersionPreviewDocUnavailable(GoogleFileVersion__c fileVersion) {
		return (
			!fileVersion.IsPreviewableFile__c
		);
	}
}