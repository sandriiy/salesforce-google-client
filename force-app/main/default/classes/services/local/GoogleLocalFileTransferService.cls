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
 * Moves files between Salesforce and Google Drive for automation: a Salesforce file up into Drive as a
 * Google Client file, and a Google Client file back down as a Salesforce file. Content travels through
 * the Apex heap here, so a file past the configured big file size is handed to a background job instead
 * of being pushed through in one go.
 */
public without sharing class GoogleLocalFileTransferService {
	public class GoogleLocalFileTransferException extends Exception {}

	private static final String DEFAULT_UPLOAD_SOURCE = 'Notes & Attachments';
	private static final Integer HEAP_BYTES_PER_TRANSFERRED_BYTE = 2;
	private static final Integer HEAP_RESERVE_BYTES = 1048576;
	private static final String FILE_EXTENSION_SEPARATOR = '.';
	private static final String SOURCE_LIST_SEPARATOR = '", "';
	private static final String MISSING_SOURCE_FILE_MESSAGE = 'Provide the Salesforce file to upload as a Content Document Id or a Content Version Id';
	private static final String UNSUPPORTED_SOURCE_FILE_MESSAGE = 'The Salesforce file Id must be a Content Document Id or a Content Version Id';
	private static final String SOURCE_FILE_NOT_FOUND_MESSAGE = 'The Salesforce file could not be found. Check the Id and try again';
	private static final String EMPTY_SOURCE_FILE_MESSAGE = 'The Salesforce file is empty and cannot be uploaded';
	private static final String FILE_TOO_LARGE_MESSAGE = 'This file is too large to be transferred from Salesforce. Upload it through the Google Client components instead';
	private static final String UPLOAD_FAILED_MESSAGE = 'Unable to upload the file to Google Drive. Please try again or contact your system administrator';
	private static final String REMOVE_FAILED_MESSAGE = 'The file was uploaded to Google Drive, but the Salesforce copy could not be removed. Please remove it manually or contact your system administrator';
	private static final String DOWNLOAD_FAILED_MESSAGE = 'Unable to download the file from Google Drive. Please try again or contact your system administrator';
	private static final String DOWNLOAD_TOO_LARGE_MESSAGE = 'The files are too large to download in one run. Download fewer files at a time';
	private static final String SAVE_FAILED_MESSAGE = 'Unable to save the downloaded file in Salesforce. Please try again or contact your system administrator';

	@TestVisible
	private static Map<Id, Blob> sourceContentOverride;

	private final IGoogleUnitOfWork uow;
	private final GoogleMetadataConfigService metadataService;
	private final GoogleLocalFileVersionService versionService;
	private GoogleRemoteFileUploader remoteUploader;

	public GoogleLocalFileTransferService() {
		this(null);
	}

	/**
	 * Builds the service on a unit of work you already have.
	 *
	 * @param injectedUow The unit of work to register on. A null gets one of its own.
	 */
	public GoogleLocalFileTransferService(IGoogleUnitOfWork injectedUow) {
		this.uow = injectedUow == null
			? new GoogleCloudUnitOfWork(GoogleCloudConstants.DEFAULT_WRITE_ORDER)
			: injectedUow;
		this.metadataService = new GoogleMetadataConfigService();
		this.versionService = new GoogleLocalFileVersionService();
	}

	/**
	 * Sends one Salesforce file to Google Drive. A large one comes back with isQueued true and no Ids,
	 * because it finishes in the background.
	 *
	 * @param request The Salesforce file, the record to attach it to and what to call it.
	 * @return What was uploaded, or what was queued.
	 */
	public GoogleFileUploadResultDTO uploadSalesforceFile(GoogleFileUploadRequestDTO request) {
		List<GoogleFileUploadResultDTO> results = uploadSalesforceFiles(new List<GoogleFileUploadRequestDTO>{ request });
		return results.isEmpty() ? null : results[0];
	}

	/**
	 * Sends several Salesforce files to Google Drive, committing the records for all of them at once and
	 * queueing whatever is too large to carry now.
	 *
	 * @param requests One request per Salesforce file.
	 * @return One result per request, in the same order.
	 */
	public List<GoogleFileUploadResultDTO> uploadSalesforceFiles(List<GoogleFileUploadRequestDTO> requests) {
		return transferSalesforceFiles(requests, true);
	}

	/**
	 * Sends one Salesforce file whatever its size, which is what the background job calls once it has a
	 * transaction to itself. Use the ordinary upload from anywhere else.
	 *
	 * @param request The Salesforce file, the record to attach it to and what to call it.
	 * @return What was uploaded.
	 */
	public GoogleFileUploadResultDTO uploadSalesforceFileNow(GoogleFileUploadRequestDTO request) {
		List<GoogleFileUploadResultDTO> results = transferSalesforceFiles(new List<GoogleFileUploadRequestDTO>{ request }, false);
		return results.isEmpty() ? null : results[0];
	}

	/**
	 * Brings one Google Client file back into Salesforce as a Salesforce file.
	 *
	 * @param request The file or version to download, where to attach it and which format to convert to.
	 * @return The new Salesforce file.
	 */
	public GoogleFileDownloadResultDTO downloadToSalesforceFile(GoogleFileDownloadRequestDTO request) {
		List<GoogleFileDownloadResultDTO> results = downloadToSalesforceFiles(new List<GoogleFileDownloadRequestDTO>{ request });
		return results.isEmpty() ? null : results[0];
	}

	/**
	 * Brings several Google Client files back into Salesforce in one transaction. It refuses once the files
	 * together would not fit in the heap, rather than failing halfway with a limit error.
	 *
	 * @param requests One request per file.
	 * @return One result per request, in the same order.
	 */
	public List<GoogleFileDownloadResultDTO> downloadToSalesforceFiles(List<GoogleFileDownloadRequestDTO> requests) {
		List<GoogleFileDownloadResultDTO> results = new List<GoogleFileDownloadResultDTO>();
		if (requests == null || requests.isEmpty()) return results;

		Set<Id> versionIds = new Set<Id>();
		Set<Id> fileIds = new Set<Id>();
		for (GoogleFileDownloadRequestDTO request : requests) {
			if (request == null) continue;
			if (request.googleFileVersionId != null) versionIds.add(request.googleFileVersionId);
			if (request.googleFileId != null) fileIds.add(request.googleFileId);
		}

		Map<Id, GoogleFileVersion__c> versionsByRequestedId = versionService.resolveRequestedVersions(versionIds, fileIds);
		List<ContentVersion> salesforceFiles = new List<ContentVersion>();
		Long reservedBytes = 0;

		for (GoogleFileDownloadRequestDTO request : requests) {
			GoogleFileVersion__c localFileVersion = requireRequestedVersion(versionsByRequestedId, request);
			DownloadedContent content = downloadContent(request, localFileVersion);

			reservedBytes += content.body.size();
			if (!fitsInHeap(reservedBytes)) {
				throw new GoogleLocalFileTransferException(DOWNLOAD_TOO_LARGE_MESSAGE);
			}

			ContentVersion salesforceFile = new ContentVersion(
				Title = stripExtension(content.fileName),
				PathOnClient = content.fileName,
				VersionData = content.body
			);

			if (request.relatedRecordId != null) {
				salesforceFile.FirstPublishLocationId = request.relatedRecordId;
			}

			GoogleFileDownloadResultDTO result = new GoogleFileDownloadResultDTO();
			result.fileName = content.fileName;
			result.fileSize = content.body.size();
			results.add(result);
			salesforceFiles.add(salesforceFile);
		}

		saveSalesforceFiles(salesforceFiles);

		Map<Id, ContentVersion> savedFilesById = loadSavedFiles(salesforceFiles);
		for (Integer index = 0; index < results.size(); index++) {
			ContentVersion savedFile = savedFilesById.get(salesforceFiles[index].Id);
			results[index].contentVersionId = salesforceFiles[index].Id;
			results[index].contentDocumentId = savedFile == null ? null : savedFile.ContentDocumentId;
		}

		return results;
	}

	private List<GoogleFileUploadResultDTO> transferSalesforceFiles(List<GoogleFileUploadRequestDTO> requests, Boolean allowsBackgroundUpload) {
		List<GoogleFileUploadResultDTO> results = new List<GoogleFileUploadResultDTO>();
		if (requests == null || requests.isEmpty()) return results;

		Map<Id, ContentVersion> sourceFilesByRequestedId = loadSourceFiles(requests);
		Map<Id, ContentVersion> sourceFilesByVersionId = new Map<Id, ContentVersion>(sourceFilesByRequestedId.values());
		List<GoogleFileUploadRequestDTO> backgroundRequests = new List<GoogleFileUploadRequestDTO>();
		Set<Id> immediateVersionIds = new Set<Id>();
		Long reservedBytes = 0;

		for (GoogleFileUploadRequestDTO request : requests) {
			ContentVersion sourceFile = requireSourceFile(sourceFilesByRequestedId, request);
			Long fileSize = resolveFileSize(sourceFile);
			if (fileSize <= 0) {
				throw new GoogleLocalFileTransferException(EMPTY_SOURCE_FILE_MESSAGE);
			}

			GoogleFileUploadResultDTO result = new GoogleFileUploadResultDTO();
			result.fileName = resolveFileName(request.fileName, sourceFile);
			result.fileSize = fileSize;
			results.add(result);

			Boolean fitsNow = fitsInHeap(reservedBytes + fileSize);
			if (allowsBackgroundUpload && (fileSize > metadataService.getBigFileSizeInBytes() || !fitsNow)) {
				result.isQueued = true;
				backgroundRequests.add(request);
				continue;
			}

			if (!fitsNow) {
				throw new GoogleLocalFileTransferException(FILE_TOO_LARGE_MESSAGE);
			}

			reservedBytes += fileSize;
			immediateVersionIds.add(sourceFile.Id);
		}

		Map<Id, ContentVersion> contentByVersionId = loadSourceContent(immediateVersionIds, sourceFilesByVersionId);
		List<GoogleFileCreateRequestDTO> createRequests = new List<GoogleFileCreateRequestDTO>();
		List<Integer> createResultIndexes = new List<Integer>();
		List<SObject> salesforceFilesToRemove = new List<SObject>();

		for (Integer index = 0; index < requests.size(); index++) {
			GoogleFileUploadResultDTO result = results[index];
			if (result.isQueued == true) continue;

			GoogleFileUploadRequestDTO request = requests[index];
			ContentVersion sourceFile = contentByVersionId.get(requireSourceFile(sourceFilesByRequestedId, request).Id);
			if (sourceFile == null) {
				throw new GoogleLocalFileTransferException(SOURCE_FILE_NOT_FOUND_MESSAGE);
			}

			createRequests.add(uploadToDrive(request, sourceFile, result));
			createResultIndexes.add(index);
			sourceFile.VersionData = null;

			if (request.removeSalesforceFile == true && sourceFile.ContentDocumentId != null) {
				salesforceFilesToRemove.add(new ContentDocument(Id = sourceFile.ContentDocumentId));
			}
		}

		enqueueBackgroundUploads(backgroundRequests);

		List<GoogleFileInsertCommand.GoogleFileInsertResult> insertResults = new GoogleLocalFileService(uow).createGoogleFileRecords(createRequests);
		for (Integer position = 0; position < insertResults.size(); position++) {
			GoogleFileUploadResultDTO result = results[createResultIndexes[position]];
			result.googleFileId = insertResults[position].getLocalGoogleFileId();
			result.googleFileVersionId = insertResults[position].getLocalGoogleFileVersionId();
		}

		removeSalesforceFiles(salesforceFilesToRemove);
		return results;
	}

	private Map<Id, ContentVersion> loadSourceFiles(List<GoogleFileUploadRequestDTO> requests) {
		Set<Id> contentVersionIds = new Set<Id>();
		Set<Id> contentDocumentIds = new Set<Id>();

		for (GoogleFileUploadRequestDTO request : requests) {
			if (request == null || request.salesforceFileId == null) {
				throw new GoogleLocalFileTransferException(MISSING_SOURCE_FILE_MESSAGE);
			}

			Schema.SObjectType salesforceFileType = request.salesforceFileId.getSObjectType();
			if (salesforceFileType == ContentVersion.SObjectType) {
				contentVersionIds.add(request.salesforceFileId);
			} else if (salesforceFileType == ContentDocument.SObjectType) {
				contentDocumentIds.add(request.salesforceFileId);
			} else {
				throw new GoogleLocalFileTransferException(UNSUPPORTED_SOURCE_FILE_MESSAGE);
			}
		}

		Map<Id, ContentVersion> sourceFilesByRequestedId = new Map<Id, ContentVersion>();

		if (!contentVersionIds.isEmpty()) {
			for (ContentVersion sourceFile : (List<ContentVersion>) GoogleContentVersionSelector.query()
				.withBaseFields()
				.byIds(contentVersionIds)
				.toList()
			) {
				sourceFilesByRequestedId.put(sourceFile.Id, sourceFile);
			}
		}

		if (!contentDocumentIds.isEmpty()) {
			for (ContentVersion sourceFile : (List<ContentVersion>) GoogleContentVersionSelector.query()
				.withBaseFields()
				.byContentDocumentIds(contentDocumentIds)
				.byLatest()
				.toList()
			) {
				sourceFilesByRequestedId.put(sourceFile.ContentDocumentId, sourceFile);
			}
		}

		return sourceFilesByRequestedId;
	}

	private Map<Id, ContentVersion> loadSourceContent(Set<Id> contentVersionIds, Map<Id, ContentVersion> sourceFilesByVersionId) {
		Map<Id, ContentVersion> contentByVersionId = new Map<Id, ContentVersion>();
		if (contentVersionIds.isEmpty()) return contentByVersionId;

		if (sourceContentOverride != null) {
			for (Id contentVersionId : contentVersionIds) {
				ContentVersion sourceFile = sourceFilesByVersionId.get(contentVersionId);
				if (sourceFile == null) continue;

				sourceFile.VersionData = sourceContentOverride.get(contentVersionId);
				contentByVersionId.put(contentVersionId, sourceFile);
			}

			return contentByVersionId;
		}

		return new Map<Id, ContentVersion>((List<ContentVersion>) GoogleContentVersionSelector.query()
			.withBaseFields()
			.withContent()
			.byIds(contentVersionIds)
			.toList());
	}

	private ContentVersion requireSourceFile(Map<Id, ContentVersion> sourceFilesByRequestedId, GoogleFileUploadRequestDTO request) {
		ContentVersion sourceFile = sourceFilesByRequestedId.get(request.salesforceFileId);
		if (sourceFile == null) {
			throw new GoogleLocalFileTransferException(SOURCE_FILE_NOT_FOUND_MESSAGE);
		}

		return sourceFile;
	}

	private GoogleFileCreateRequestDTO uploadToDrive(GoogleFileUploadRequestDTO request, ContentVersion sourceFile, GoogleFileUploadResultDTO result) {
		String mimeType = resolveMimeType(sourceFile);
		String source = resolveSource(request.source);

		GoogleFileEntity uploadedFile;
		try {
			uploadedFile = getRemoteUploader().uploadFileContent(result.fileName, mimeType, sourceFile.VersionData);
		} catch (Exception ex) {
			Logger.error('Upload Salesforce File (Local/Remote): ' + String.valueOf(sourceFile.Id) + ', message: ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw new GoogleLocalFileTransferException(UPLOAD_FAILED_MESSAGE);
		}

		result.googleDriveFileId = uploadedFile.id;
		result.googleDriveFolderId = resolveParentFolderId(uploadedFile);

		GoogleFileCreateRequestDTO createRequest = new GoogleFileCreateRequestDTO();
		createRequest.recordId = request.relatedRecordId;
		createRequest.fileName = result.fileName;
		createRequest.fileType = mimeType;
		createRequest.fileSize = result.fileSize;
		createRequest.googleDriveId = uploadedFile.id;
		createRequest.parentFolderId = result.googleDriveFolderId;
		createRequest.source = source;
		return createRequest;
	}

	private void enqueueBackgroundUploads(List<GoogleFileUploadRequestDTO> backgroundRequests) {
		if (backgroundRequests.isEmpty()) return;

		GQueueableBuilder jobsChainer = GAsync.queueable();
		for (GoogleFileUploadRequestDTO request : backgroundRequests) {
			jobsChainer.chain(new GoogleFileBackgroundUploadJob(request)).deepClone().continueOnJobExecuteFail();
		}

		jobsChainer.enqueue();
		Logger.info('Upload Salesforce Files --> Queued=' + backgroundRequests.size()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
	}

	private void removeSalesforceFiles(List<SObject> salesforceFilesToRemove) {
		if (salesforceFilesToRemove.isEmpty()) return;

		try {
			uow.registerDeleted(salesforceFilesToRemove);
			uow.commitWork(true);
		} catch (Exception ex) {
			Logger.error('Remove Salesforce File After Upload (Local): ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw new GoogleLocalFileTransferException(REMOVE_FAILED_MESSAGE);
		}
	}

	private GoogleFileVersion__c requireRequestedVersion(Map<Id, GoogleFileVersion__c> versionsByRequestedId, GoogleFileDownloadRequestDTO request) {
		try {
			return versionService.requireRequestedVersion(versionsByRequestedId, request == null ? null : request.googleFileVersionId, request == null ? null : request.googleFileId);
		} catch (GoogleLocalFileVersionService.GoogleFileVersionException ex) {
			throw new GoogleLocalFileTransferException(ex.getMessage());
		}
	}

	private DownloadedContent downloadContent(GoogleFileDownloadRequestDTO request, GoogleFileVersion__c localFileVersion) {
		try {
			if (String.isBlank(request.convertTo)) {
				return new DownloadedContent(versionService.downloadFileBody(localFileVersion), resolveDownloadFileName(request.fileName, localFileVersion.Name));
			}

			GoogleFileDownloadAsOptionDTO option = versionService.resolveDownloadAsOption(localFileVersion, request.convertTo);
			return new DownloadedContent(versionService.downloadFileBodyAs(localFileVersion, option.mimeType), resolveDownloadFileName(request.fileName, option.fileName));
		} catch (GoogleLocalFileTransferException ex) {
			throw ex;
		} catch (GoogleLocalFileVersionService.GoogleFileVersionException ex) {
			throw new GoogleLocalFileTransferException(ex.getMessage());
		} catch (Exception ex) {
			Logger.error('Download Google File To Salesforce (Local/Remote): ' + String.valueOf(localFileVersion.Id) + ', message: ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw new GoogleLocalFileTransferException(DOWNLOAD_FAILED_MESSAGE);
		}
	}

	private void saveSalesforceFiles(List<ContentVersion> salesforceFiles) {
		try {
			uow.registerNew(salesforceFiles);
			uow.commitWork(true);
		} catch (Exception ex) {
			Logger.error('Save Downloaded Google File (Local): ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw new GoogleLocalFileTransferException(SAVE_FAILED_MESSAGE);
		}
	}

	private Map<Id, ContentVersion> loadSavedFiles(List<ContentVersion> salesforceFiles) {
		Set<Id> savedFileIds = new Set<Id>();
		for (ContentVersion salesforceFile : salesforceFiles) {
			if (salesforceFile.Id != null) savedFileIds.add(salesforceFile.Id);
		}

		if (savedFileIds.isEmpty()) return new Map<Id, ContentVersion>();

		return new Map<Id, ContentVersion>((List<ContentVersion>) GoogleContentVersionSelector.query()
			.withBaseFields()
			.byIds(savedFileIds)
			.toList());
	}

	private String resolveSource(String requestedSource) {
		if (String.isBlank(requestedSource)) return DEFAULT_UPLOAD_SOURCE;

		List<String> supportedSources = new List<String>();
		for (Schema.PicklistEntry entry : GoogleFile__c.Source__c.getDescribe().getPicklistValues()) {
			if (!entry.isActive()) continue;
			if (entry.getValue().equalsIgnoreCase(requestedSource.trim())) return entry.getValue();
			supportedSources.add(entry.getValue());
		}

		throw new GoogleLocalFileTransferException('The file source must be one of "' + String.join(supportedSources, SOURCE_LIST_SEPARATOR) + '"');
	}

	private String resolveFileName(String requestedFileName, ContentVersion sourceFile) {
		String extension = String.isBlank(sourceFile.FileExtension) ? null : sourceFile.FileExtension.trim().toLowerCase();
		String originalName = String.isNotBlank(sourceFile.PathOnClient) ? sourceFile.PathOnClient : sourceFile.Title;
		return withExtension(String.isNotBlank(requestedFileName) ? requestedFileName : originalName, extension);
	}

	private String resolveDownloadFileName(String requestedFileName, String defaultFileName) {
		String safeDefault = String.isBlank(defaultFileName) ? GoogleCloudConstants.DEFAULT_FILE_NAME : defaultFileName.trim();
		if (String.isBlank(requestedFileName)) return safeDefault;

		String trimmedName = requestedFileName.trim();
		return trimmedName.contains(FILE_EXTENSION_SEPARATOR) ? trimmedName : withExtension(trimmedName, extractExtension(safeDefault));
	}

	private String withExtension(String fileName, String extension) {
		String safeName = String.isBlank(fileName) ? GoogleCloudConstants.DEFAULT_FILE_NAME : fileName.trim();
		if (String.isBlank(extension) || safeName.toLowerCase().endsWith(FILE_EXTENSION_SEPARATOR + extension)) return safeName;
		return safeName + FILE_EXTENSION_SEPARATOR + extension;
	}

	private String extractExtension(String fileName) {
		Integer separatorIndex = fileName.lastIndexOf(FILE_EXTENSION_SEPARATOR);
		if (separatorIndex <= 0 || separatorIndex >= fileName.length() - 1) return null;
		return fileName.substring(separatorIndex + 1).toLowerCase();
	}

	private String stripExtension(String fileName) {
		Integer separatorIndex = fileName.lastIndexOf(FILE_EXTENSION_SEPARATOR);
		return separatorIndex > 0 ? fileName.substring(0, separatorIndex) : fileName;
	}

	private String resolveMimeType(ContentVersion sourceFile) {
		String extension = String.isBlank(sourceFile.FileExtension) ? null : sourceFile.FileExtension.trim().toLowerCase();
		String mimeType = extension == null ? null : GoogleCloudConstants.FILE_EXTENSION_TO_MIME_TYPE.get(extension);
		return String.isBlank(mimeType) ? GoogleCloudConstants.MIME_TYPE_OCTET_STREAM : mimeType;
	}

	private Long resolveFileSize(ContentVersion sourceFile) {
		return sourceFile.ContentSize == null ? 0 : sourceFile.ContentSize;
	}

	private String resolveParentFolderId(GoogleFileEntity uploadedFile) {
		if (uploadedFile.parents != null && !uploadedFile.parents.isEmpty()) {
			return uploadedFile.parents[0];
		}

		return metadataService.getDefaultUploadFolderId();
	}

	private Boolean fitsInHeap(Long transferredBytes) {
		return transferredBytes * HEAP_BYTES_PER_TRANSFERRED_BYTE + HEAP_RESERVE_BYTES <= Limits.getLimitHeapSize() - Limits.getHeapSize();
	}

	private GoogleRemoteFileUploader getRemoteUploader() {
		if (remoteUploader == null) {
			remoteUploader = new GoogleRemoteFileUploader();
		}

		return remoteUploader;
	}

	private class DownloadedContent {
		public final Blob body;
		public final String fileName;

		public DownloadedContent(Blob body, String fileName) {
			if (body == null) {
				throw new GoogleLocalFileTransferException(DOWNLOAD_FAILED_MESSAGE);
			}

			this.body = body;
			this.fileName = fileName;
		}
	}
}
