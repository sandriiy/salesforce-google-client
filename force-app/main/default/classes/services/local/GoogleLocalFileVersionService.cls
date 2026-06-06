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
		Logger.info('File Download As PDF --> VersionId=' + String.valueOf(localFileVersionId) + ', GoogleDriveFileId=' + String.valueOf(localFileVersion == null ? null : localFileVersion.GoogleDriveFileId__c)).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
		try {
			GoogleFileEntity fileResult = exportOrDownloadAsPdf(localFileVersion);
			return EncodingUtil.base64Encode(fileResult.bodyAsBlob);
		} catch (Exception ex) {
			Logger.error('File Download As PDF Failed --> VersionId=' + String.valueOf(localFileVersionId) + ', Message=' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw ex;
		}
	}

	public List<GoogleFileDownloadAsOptionDTO> retrieveDownloadAsOptions(Id localFileVersionId) {
		GoogleFileVersion__c localFileVersion = queryLocalFileVersion(localFileVersionId);
		return buildDownloadAsOptions(localFileVersion);
	}

	public String downloadFileBase64BodyAs(Id localFileVersionId, String exportMimeType) {
		GoogleFileVersion__c localFileVersion = queryLocalFileVersion(localFileVersionId);
		Logger.info('File Download As --> VersionId=' + localFileVersionId + ', ExportMimeType=' + exportMimeType + ', GoogleDocsFileId=' + localFileVersion.GoogleDocsFileId__c
		).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

		try {
			GoogleFileEntity fileResult = exportGoogleWorkspaceFile(localFileVersion, assertSupportedDownloadAsMimeType(localFileVersion, exportMimeType));
			return EncodingUtil.base64Encode(fileResult.bodyAsBlob);
		} catch (Exception ex) {
			Logger.error('File Download As Failed --> VersionId=' + String.valueOf(localFileVersionId) + ', Message=' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw ex;
		}
	}

	public String downloadFileBase64Body(Id localFileVersionId) {
		GoogleFileVersion__c localFileVersion = queryLocalFileVersion(localFileVersionId);
		Logger.info('File Download --> VersionId=' + String.valueOf(localFileVersionId) + ', GoogleDriveFileId=' + String.valueOf(localFileVersion == null ? null : localFileVersion.GoogleDriveFileId__c)).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
		try {
			GoogleDrive removeGoogleDrive = this.remoteFileService.retrieveGoogleDriveClient();
			GoogleFileEntity remoteFileEntity = removeGoogleDrive.files().retrieve().download(localFileVersion.GoogleDriveFileId__c)
				.setFileDownloadType(GoogleDownloadFileBuilder.DownloadType.CONTENT)
				.setSearchOnAllDrives(true)
				.execute();
			return EncodingUtil.base64Encode(remoteFileEntity.bodyAsBlob);
		} catch (Exception ex) {
			Logger.error('File Download Failed --> VersionId=' + String.valueOf(localFileVersionId) + ', Message=' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw ex;
		}
	}

	public String downloadFileBase64Body(Id localFileVersionId, Long startByte, Long endByte) {
		GoogleFileVersion__c localFileVersion = queryLocalFileVersion(localFileVersionId);
		Logger.info('File Download Partial --> VersionId=' + String.valueOf(localFileVersionId) + ', StartByte=' + String.valueOf(startByte) + ', EndByte=' + String.valueOf(endByte)).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
		try {
			GoogleDrive removeGoogleDrive = this.remoteFileService.retrieveGoogleDriveClient();
			GoogleFileEntity remoteFileEntity = removeGoogleDrive.files().retrieve().download(localFileVersion.GoogleDriveFileId__c)
				.setFileDownloadType(GoogleDownloadFileBuilder.DownloadType.CONTENT)
				.setPartialRange(startByte, endByte)
				.setSearchOnAllDrives(true)
				.execute();
			return EncodingUtil.base64Encode(remoteFileEntity.bodyAsBlob);
		} catch (Exception ex) {
			Logger.error('File Download Partial Failed --> VersionId=' + String.valueOf(localFileVersionId) + ', Message=' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw ex;
		}
	}

	private GoogleFileVersion__c queryLocalFileVersion(Id localFileVersionId) {
		return (GoogleFileVersion__c) GoogleFileVersionSelector.query()
			.withAdvancedFields()
			.byId(localFileVersionId)
			.toObject();
	}

	private GoogleFileEntity exportOrDownloadAsPdf(GoogleFileVersion__c localFileVersion) {
		GoogleDrive removeGoogleDrive = this.remoteFileService.retrieveGoogleDriveClient();

		if (localFileVersion.Type__c == GoogleCloudConstants.MIME_TYPE_PDF) {
			return removeGoogleDrive.files().retrieve().download(localFileVersion.GoogleDriveFileId__c)
				.setFileDownloadType(GoogleDownloadFileBuilder.DownloadType.CONTENT)
				.setSearchOnAllDrives(true)
				.execute();
		}

		return exportGoogleWorkspaceFile(localFileVersion, GoogleCloudConstants.MIME_TYPE_PDF);
	}

	private GoogleFilePreviewAction assertPreviewEligible(GoogleFileVersion__c localFileVersion) {
		if (this.googleConfig.isPreviewDisabled() || localFileVersion == null) {
			throw new GoogleFileVersionException('Preview Unavailable. Please download it to open');
		}

		if (localFileVersion.Type__c == GoogleCloudConstants.MIME_TYPE_PDF) {
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
			fileVersion.Type__c != GoogleCloudConstants.MIME_TYPE_PDF
		);
	}

	private Boolean isVersionPreviewDocUnavailable(GoogleFileVersion__c fileVersion) {
		return (
			!fileVersion.IsPreviewableFile__c
		);
	}

	private List<GoogleFileDownloadAsOptionDTO> buildDownloadAsOptions(GoogleFileVersion__c localFileVersion) {
		String workspaceType = resolveGoogleWorkspaceType(localFileVersion);
		List<GoogleFileDownloadAsOptionDTO> downloadAsTypes = GoogleCloudConstants.GOOGLE_WORKSPACE_DOWNLOAD_AS_TYPES.get(workspaceType);
		if (!isDownloadAsSupported(localFileVersion) || downloadAsTypes == null || downloadAsTypes.isEmpty()) {
			return new List<GoogleFileDownloadAsOptionDTO>();
		}

		List<GoogleFileDownloadAsOptionDTO> options = new List<GoogleFileDownloadAsOptionDTO>();
		for (GoogleFileDownloadAsOptionDTO downloadAsType : downloadAsTypes) {
			options.add(createDownloadAsOption(downloadAsType, localFileVersion.Name));
		}

		return options;
	}

	private GoogleFileDownloadAsOptionDTO createDownloadAsOption(GoogleFileDownloadAsOptionDTO downloadAsType, String originalFileName) {
		GoogleFileDownloadAsOptionDTO option = new GoogleFileDownloadAsOptionDTO(
			downloadAsType.label,
			downloadAsType.mimeType,
			downloadAsType.fileExtension
		);

		option.fileName = buildDownloadAsFileName(originalFileName, downloadAsType.fileExtension);
		return option;
	}

	private String buildDownloadAsFileName(String originalFileName, String fileExtension) {
		String fileName = String.isNotBlank(originalFileName)
			? originalFileName.trim()
			: GoogleCloudConstants.DEFAULT_FILE_NAME;
		Integer extensionSeparator = fileName.lastIndexOf('.');
		String baseFileName = extensionSeparator > 0
			? fileName.substring(0, extensionSeparator)
			: fileName;

		return baseFileName + '.' + fileExtension;
	}

	private Boolean isDownloadAsSupported(GoogleFileVersion__c localFileVersion) {
		return localFileVersion != null
			&& localFileVersion.Size__c != null
			&& localFileVersion.Size__c <= this.googleConfig.getBigFileSizeInBytes()
			&& localFileVersion.IsPreviewableFile__c
			&& !this.googleConfig.isPreviewDisabled()
			&& String.isNotBlank(localFileVersion.GoogleDocsFileId__c)
			&& String.isNotBlank(resolveGoogleWorkspaceType(localFileVersion));
	}

	private String resolveGoogleWorkspaceType(GoogleFileVersion__c localFileVersion) {
		return localFileVersion == null
			? null
			: GoogleCloudConstants.FILE_EXTENSION_TO_PREVIEW_TYPE.get(localFileVersion.Type__c);
	}

	private String assertSupportedDownloadAsMimeType(GoogleFileVersion__c localFileVersion, String exportMimeType) {
		if (String.isBlank(exportMimeType)) {
			throw new GoogleFileVersionException('The selected download format is unavailable for this file');
		}

		String workspaceType = resolveGoogleWorkspaceType(localFileVersion);
		List<GoogleFileDownloadAsOptionDTO> downloadAsTypes = GoogleCloudConstants.GOOGLE_WORKSPACE_DOWNLOAD_AS_TYPES.get(workspaceType);
		if (downloadAsTypes == null || downloadAsTypes.isEmpty()) {
			throw new GoogleFileVersionException('The selected download format is unavailable for this file');
		}

		for (GoogleFileDownloadAsOptionDTO option : downloadAsTypes) {
			if (option.mimeType == exportMimeType) {
				return exportMimeType;
			}
		}

		throw new GoogleFileVersionException('The selected download format is unavailable for this file');
	}

	private GoogleFileEntity exportGoogleWorkspaceFile(GoogleFileVersion__c localFileVersion, String exportMimeType) {
		GoogleDrive removeGoogleDrive = this.remoteFileService.retrieveGoogleDriveClient();
		return removeGoogleDrive.files().retrieve().export(localFileVersion.GoogleDocsFileId__c)
			.setMimeType(exportMimeType)
			.setSearchOnAllDrives(true)
			.execute();
	}
}