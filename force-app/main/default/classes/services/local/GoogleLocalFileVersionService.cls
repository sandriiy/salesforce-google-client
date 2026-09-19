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
 * Everything that reads the content of a file version out of Google Drive: previews, downloads,
 * conversions to another format and plain text. It reaches Drive directly and never writes, so there is
 * no unit of work here.
 */
public without sharing class GoogleLocalFileVersionService {
	public class GoogleFileVersionException extends Exception {}
	/**
	 * Kept for callers that already reference it. Access itself is resolved by GoogleFileAccessResolver.
	 */
	public enum AccessLevel { View, Edit }

	private final GoogleMetadataConfigService googleConfig;
	private final GoogleClientApiProvider remoteFileService;

	public GoogleLocalFileVersionService() {
		this.googleConfig = new GoogleMetadataConfigService();
		this.remoteFileService = new GoogleClientApiProvider();
	}

	/**
	 * Says how a version should be previewed, or throws with the reason it cannot be. A document is judged
	 * by the size of its Workspace copy rather than the upload, since that copy is usually far smaller.
	 *
	 * @param localFileVersionId The version being opened.
	 * @return DIRECT for something the browser renders itself, CONVERT for the Workspace copy.
	 */
	public GoogleFilePreviewAction validatePreviewEligible(Id localFileVersionId) {
		GoogleFileVersion__c localFileVersion = queryLocalFileVersion(localFileVersionId);
		return assertPreviewEligible(localFileVersion); // Method will throw exception if not eligible
	}

	/**
	 * Downloads the version as a PDF, encoded for a Lightning component.
	 *
	 * @param localFileVersionId The version to download.
	 * @return The PDF as base64.
	 */
	public String downloadFileBase64BodyAsPdf(Id localFileVersionId) {
		return EncodingUtil.base64Encode(downloadFileBodyAsPdf(localFileVersionId));
	}

	/**
	 * Downloads the version as a PDF, which is the shape to use from Apex.
	 *
	 * @param localFileVersionId The version to download.
	 * @return The PDF content.
	 */
	public Blob downloadFileBodyAsPdf(Id localFileVersionId) {
		GoogleFileVersion__c localFileVersion = queryLocalFileVersion(localFileVersionId);
		Logger.info('File Download As PDF --> VersionId=' + String.valueOf(localFileVersionId) + ', GoogleDriveFileId=' + String.valueOf(localFileVersion == null ? null : localFileVersion.GoogleDriveFileId__c)).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
		try {
			GoogleFileEntity fileResult = exportOrDownloadAsPdf(localFileVersion);
			return fileResult.bodyAsBlob;
		} catch (Exception ex) {
			Logger.error('File Download As PDF Failed --> VersionId=' + String.valueOf(localFileVersionId) + ', Message=' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw ex;
		}
	}

	/**
	 * Lists the formats this version can be downloaded in, which depends on whether it has a Workspace copy
	 * and whether that copy is a document or a spreadsheet.
	 *
	 * @param localFileVersionId The version being downloaded.
	 * @return The available formats, empty when only the original can be had.
	 */
	public List<GoogleFileDownloadAsOptionDTO> retrieveDownloadAsOptions(Id localFileVersionId) {
		GoogleFileVersion__c localFileVersion = queryLocalFileVersion(localFileVersionId);
		return buildDownloadAsOptions(localFileVersion);
	}

	/**
	 * Downloads the version in another format, encoded for a Lightning component.
	 *
	 * @param localFileVersionId The version to download.
	 * @param exportMimeType A MIME type from the Download As options.
	 * @return The converted content as base64.
	 */
	public String downloadFileBase64BodyAs(Id localFileVersionId, String exportMimeType) {
		return EncodingUtil.base64Encode(downloadFileBodyAs(localFileVersionId, exportMimeType));
	}

	/**
	 * Downloads the version in another format.
	 *
	 * @param localFileVersionId The version to download.
	 * @param exportMimeType A MIME type from the Download As options.
	 * @return The converted content.
	 */
	public Blob downloadFileBodyAs(Id localFileVersionId, String exportMimeType) {
		return downloadFileBodyAs(queryLocalFileVersion(localFileVersionId), exportMimeType);
	}

	/**
	 * Downloads a version you already loaded in another format, which saves a query when several files are
	 * being converted in one go.
	 *
	 * @param localFileVersion The version loaded with its confidential fields.
	 * @param exportMimeType A MIME type from the Download As options.
	 * @return The converted content.
	 */
	public Blob downloadFileBodyAs(GoogleFileVersion__c localFileVersion, String exportMimeType) {
		Logger.info('File Download As --> VersionId=' + String.valueOf(localFileVersion == null ? null : localFileVersion.Id) + ', ExportMimeType=' + exportMimeType + ', GoogleDocsFileId=' + String.valueOf(localFileVersion == null ? null : localFileVersion.GoogleDocsFileId__c)
		).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

		try {
			GoogleFileEntity fileResult = exportGoogleWorkspaceFile(localFileVersion, assertSupportedDownloadAsMimeType(localFileVersion, exportMimeType));
			return fileResult.bodyAsBlob;
		} catch (Exception ex) {
			Logger.error('File Download As Failed --> VersionId=' + String.valueOf(localFileVersion == null ? null : localFileVersion.Id) + ', Message=' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw ex;
		}
	}

	/**
	 * Downloads the file as it was uploaded, encoded for a Lightning component.
	 *
	 * @param localFileVersionId The version to download.
	 * @return The original content as base64.
	 */
	public String downloadFileBase64Body(Id localFileVersionId) {
		return EncodingUtil.base64Encode(downloadFileBody(localFileVersionId));
	}

	/**
	 * Downloads the file as it was uploaded.
	 *
	 * @param localFileVersionId The version to download.
	 * @return The original content.
	 */
	public Blob downloadFileBody(Id localFileVersionId) {
		return downloadFileBody(queryLocalFileVersion(localFileVersionId));
	}

	/**
	 * Downloads a version you already loaded, which saves a query when several files are being downloaded
	 * in one go.
	 *
	 * @param localFileVersion The version loaded with its confidential fields.
	 * @return The original content.
	 */
	public Blob downloadFileBody(GoogleFileVersion__c localFileVersion) {
		Logger.info('File Download --> VersionId=' + String.valueOf(localFileVersion == null ? null : localFileVersion.Id) + ', GoogleDriveFileId=' + String.valueOf(localFileVersion == null ? null : localFileVersion.GoogleDriveFileId__c)).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
		try {
			GoogleDrive removeGoogleDrive = this.remoteFileService.retrieveGoogleDriveClient();
			GoogleFileEntity remoteFileEntity = removeGoogleDrive.files().retrieve().download(localFileVersion.GoogleDriveFileId__c)
				.setFileDownloadType(GoogleDownloadFileBuilder.DownloadType.CONTENT)
				.setSearchOnAllDrives(true)
				.execute();
			return remoteFileEntity.bodyAsBlob;
		} catch (Exception ex) {
			Logger.error('File Download Failed --> VersionId=' + String.valueOf(localFileVersion == null ? null : localFileVersion.Id) + ', Message=' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw ex;
		}
	}

	/**
	 * Turns a file extension into the Download As option behind it, so a caller can ask for "pdf" without
	 * knowing the MIME type. A format this file cannot be converted to is refused rather than guessed at.
	 *
	 * @param localFileVersion The version being converted.
	 * @param fileExtension The wanted extension, with or without the dot, in any case.
	 * @return The matching option, carrying the MIME type and the file name to use.
	 */
	public GoogleFileDownloadAsOptionDTO resolveDownloadAsOption(GoogleFileVersion__c localFileVersion, String fileExtension) {
		String normalizedExtension = String.isBlank(fileExtension) ? null : fileExtension.trim().removeStart('.').toLowerCase();
		if (normalizedExtension != null) {
			for (GoogleFileDownloadAsOptionDTO option : buildDownloadAsOptions(localFileVersion)) {
				if (option.fileExtension == normalizedExtension) return option;
			}
		}

		throw new GoogleFileVersionException('The selected download format is unavailable for this file');
	}

	/**
	 * Reads the content of one file as plain text.
	 *
	 * @param request The file or version to read and how much text to return.
	 * @return The text, how much of it there is and whether it was cut short.
	 */
	public GoogleFileTextExtractResultDTO extractText(GoogleFileTextExtractRequestDTO request) {
		List<GoogleFileTextExtractResultDTO> results = extractText(new List<GoogleFileTextExtractRequestDTO>{ request });
		return results.isEmpty() ? null : results[0];
	}

	/**
	 * Reads several files as plain text, looking all the versions up in one query first. A file whose
	 * Workspace copy is still being prepared is refused with a message saying so rather than returning
	 * nothing, since the two are easy to confuse.
	 *
	 * @param requests One request per file or version.
	 * @return One result per request, in the same order.
	 */
	public List<GoogleFileTextExtractResultDTO> extractText(List<GoogleFileTextExtractRequestDTO> requests) {
		List<GoogleFileTextExtractResultDTO> results = new List<GoogleFileTextExtractResultDTO>();
		if (requests == null || requests.isEmpty()) return results;

		Set<Id> versionIds = new Set<Id>();
		Set<Id> fileIds = new Set<Id>();
		for (GoogleFileTextExtractRequestDTO request : requests) {
			if (request == null) continue;
			if (request.googleFileVersionId != null) versionIds.add(request.googleFileVersionId);
			if (request.googleFileId != null) fileIds.add(request.googleFileId);
		}

		Map<Id, GoogleFileVersion__c> versionsByRequestedId = resolveRequestedVersions(versionIds, fileIds);
		GoogleFileTextExportCommand exportCommand = new GoogleFileTextExportCommand(this.remoteFileService);

		for (GoogleFileTextExtractRequestDTO request : requests) {
			GoogleFileVersion__c localFileVersion = requireRequestedVersion(versionsByRequestedId, request == null ? null : request.googleFileVersionId, request == null ? null : request.googleFileId);
			if (!exportCommand.supportsTextExtraction(localFileVersion)) {
				throw new GoogleFileVersionException('Text is not available for this file. The preview copy may still be preparing, or the file type is not supported');
			}

			Logger.info('File Text Extract --> VersionId=' + String.valueOf(localFileVersion.Id) + ', GoogleDocsFileId=' + String.valueOf(localFileVersion.GoogleDocsFileId__c)).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

			String text;
			try {
				text = exportCommand.extractPlainText(localFileVersion);
			} catch (Exception ex) {
				Logger.error('File Text Extract Failed --> VersionId=' + String.valueOf(localFileVersion.Id) + ', Message=' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
				Logger.saveLog();
				throw new GoogleFileVersionException('Unable to read the file content. Please try again or contact your system administrator');
			}

			results.add(buildTextExtractResult(localFileVersion, text == null ? '' : text, request.maxCharacters));
		}

		return results;
	}

	/**
	 * Loads versions asked for by their own Id and files asked for by theirs, in one go, keyed by whatever
	 * was asked for.
	 *
	 * @param versionIds The versions wanted by their own Id.
	 * @param fileIds The files whose latest version is wanted.
	 * @return The versions with their confidential fields, keyed by the Id they were requested with.
	 */
	public Map<Id, GoogleFileVersion__c> resolveRequestedVersions(Set<Id> versionIds, Set<Id> fileIds) {
		return new GoogleFileVersionContextResolver().resolveVersionsByIdOrFileId(versionIds, fileIds);
	}

	/**
	 * Picks one version out of what resolveRequestedVersions() loaded, preferring the version Id when both
	 * are given, and throws with a readable message when there is nothing to pick.
	 *
	 * @param versionsByRequestedId What resolveRequestedVersions() returned.
	 * @param localFileVersionId The version asked for, or null.
	 * @param localFileId The file asked for, or null.
	 * @return The version to work with.
	 */
	public GoogleFileVersion__c requireRequestedVersion(Map<Id, GoogleFileVersion__c> versionsByRequestedId, Id localFileVersionId, Id localFileId) {
		if (localFileVersionId == null && localFileId == null) {
			throw new GoogleFileVersionException('Provide a Google File Id or a Google File Version Id');
		}

		GoogleFileVersion__c localFileVersion = versionsByRequestedId == null
			? null
			: versionsByRequestedId.get(localFileVersionId != null ? localFileVersionId : localFileId);

		if (localFileVersion == null) {
			throw new GoogleFileVersionException('The file could not be found. Check the Id and try again');
		}

		return localFileVersion;
	}

	/**
	 * Downloads a slice of the file, which is how a large file reaches the browser without ever sitting in
	 * the Apex heap whole.
	 *
	 * @param localFileVersionId The version to download.
	 * @param startByte The first byte of the slice.
	 * @param endByte The last byte of the slice.
	 * @return That slice as base64.
	 */
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

	private GoogleFileTextExtractResultDTO buildTextExtractResult(GoogleFileVersion__c localFileVersion, String text, Integer maxCharacters) {
		GoogleFileTextExtractResultDTO result = new GoogleFileTextExtractResultDTO();
		result.googleFileVersionId = localFileVersion.Id;
		result.fileName = localFileVersion.Name;
		result.isTruncated = maxCharacters != null && maxCharacters > 0 && text.length() > maxCharacters;
		result.text = result.isTruncated ? text.substring(0, maxCharacters) : text;
		result.characterCount = result.text.length();
		return result;
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

		if (GoogleCloudConstants.DIRECT_PREVIEW_MIME_TYPES.contains(localFileVersion.Type__c)) {
			return GoogleFilePreviewAction.DIRECT;
		}

		if (resolvePreviewSizeInBytes(localFileVersion) > this.googleConfig.getBigFileSizeInBytes()) {
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

	private Decimal resolvePreviewSizeInBytes(GoogleFileVersion__c fileVersion) {
		return fileVersion.GoogleDocsFileSize__c != null
			? fileVersion.GoogleDocsFileSize__c
			: fileVersion.Size__c;
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