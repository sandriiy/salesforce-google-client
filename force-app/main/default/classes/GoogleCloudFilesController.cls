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
public with sharing class GoogleCloudFilesController {
	@AuraEnabled
	public static String fetchFileAccess(Id localGoogleFileId) {
		GoogleLocalFileService recordService = new GoogleLocalFileService();
        List<GoogleFile__c> localFiles = recordService.stripInaccessibleRecords()
			.forFile(localGoogleFileId)
			.forUser(UserInfo.getUserId())
			.strip();

		return localFiles.isEmpty()
			? null
			: localFiles.get(0).UserAccessLevel__c;
	}

	@AuraEnabled
    public static String validateFilePreview(Id localFileVersionId) {
		try {
			GoogleLocalFileVersionService localVersionService = new GoogleLocalFileVersionService();
			GoogleFilePreviewAction previewAction = localVersionService.validatePreviewEligible(localFileVersionId);
			return previewAction.toString();
		} catch (GoogleLocalFileVersionService.GoogleFileVersionException ex) {
			throw new AuraHandledException(ex.getMessage());
		} catch (Exception ex) {
			Logger.error('Validate File Preview, Id: ' + localFileVersionId).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.error('Validate File Preview, Message:' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();

			throw new AuraHandledException('Preview isn’t available for this file. Please download the file instead, or contact your system administrator');
		}
	}

	/**
	 * Deprecated. Use retrieveFileExplorerFiles() instead.
	 */
	@AuraEnabled
	public static List<GoogleFile__c> retrieveAllGoogleFiles() {
		GoogleLocalFileService recordService = new GoogleLocalFileService();
		return recordService.retrieveGoogleFiles(UserInfo.getUserId());
	}

	@AuraEnabled
	public static GoogleFileExplorerResultDTO retrieveFileExplorerFiles() {
		GoogleLocalFileService recordService = new GoogleLocalFileService();
		return recordService.retrieveFileExplorerFiles(UserInfo.getUserId());
	}

	@AuraEnabled
	public static GoogleFileExplorerResultDTO retrieveAllGoogleFilesPage(String sortField, String sortDirection, String searchTerm, String cursor, Integer pageSize, String bucket) {
		GoogleLocalFileService recordService = new GoogleLocalFileService();
		return recordService.retrieveGoogleFilesPage(
			GoogleFileExplorerPageRequestDTO.of(sortField, sortDirection, searchTerm, cursor, pageSize, bucket)
		);
	}

	@AuraEnabled(cacheable=true)
	public static List<GoogleFileColumnDTO> retrieveFileExplorerColumns() {
		return new GoogleFileExplorerColumnResolver().resolveColumns();
	}

	@AuraEnabled
	public static List<GoogleFile__c> retrieveAttachableOwnedGoogleFiles(Id relatedRecordId) {
		GoogleLocalFileService recordService = new GoogleLocalFileService();
		return recordService.retrieveAttachableOwnedFiles(relatedRecordId);
	}

    @AuraEnabled
    public static List<GoogleFile__c> retrieveGoogleFiles(Id relatedRecordId, String source, Integer recordsCount) {
		GoogleLocalFileService recordService = new GoogleLocalFileService();
		return recordService.retrieveGoogleFilesForRelatedRecord(relatedRecordId, source, recordsCount);
    }

	@AuraEnabled
    public static GoogleFile__c retrieveLocalGoogleFileById(Id localGoogleFileId) {
		GoogleFile__c localGoogleFile = (GoogleFile__c) GoogleFileSelector.query()
			.withBaseFields()
			.withVersionsSubquery()
			.byId(localGoogleFileId)
			.toObject();

		if (localGoogleFile != null) {
			GoogleLocalFileService recordService = new GoogleLocalFileService();
			List<GoogleFile__c> stripedFiles = recordService.stripInaccessibleRecords()
				.forFile(localGoogleFile)
				.forUser(UserInfo.getUserId())
				.strip();

			if (!stripedFiles.isEmpty()) {
				return stripedFiles.get(0);
			}
		}

		throw new AuraHandledException('You don’t have access to view this file. Please verify your permissions and try again');
    }

	@AuraEnabled
    public static GoogleFileVersion__c retrieveLocalGoogleFileVersionById(Id localGoogleFileVersionId) {
		return (GoogleFileVersion__c) GoogleFileVersionSelector.query()
			.withSharingFields()
			.byId(localGoogleFileVersionId)
			.toObject();
    }

	@AuraEnabled
    public static List<GoogleFile__c> retrieveGoogleFilesWithoutLimit(Id relatedRecordId, String source) {
        return retrieveGoogleFiles(relatedRecordId, source, null);
    }

	@AuraEnabled(cacheable=true)
    public static List<GoogleFile__c> retrieveGoogleFilesWithLimit(Id relatedRecordId, String source, Integer recordsCount) {
        return retrieveGoogleFiles(relatedRecordId, source, recordsCount);
    }

	@AuraEnabled
	public static void ensureGoogleDriveFolderStructure(Id relatedRecordId) {
		try {
			GoogleLocalFileService recordService = new GoogleLocalFileService();
			recordService.ensureGoogleDriveFolderStructure(relatedRecordId);
		} catch (Exception ex) {
			Logger.error('Ensure Google Drive Folder Structure, Record Id: ' + relatedRecordId).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.error('Ensure Google Drive Folder Structure, Message: ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
		}
	}

    @AuraEnabled
    public static GoogleFile__c saveNewGoogleFile(Id recordId, String fileName, String fileType, Long fileSize, String googleDriveId, String parentFolderId, String source) {
        GoogleFileCreateRequestDTO request = new GoogleFileCreateRequestDTO();
		request.recordId = recordId;
		request.fileName = fileName;
		request.fileType = fileType;
		request.fileSize = fileSize;
		request.googleDriveId = googleDriveId;
		request.parentFolderId = parentFolderId;
		request.source = source;

		GoogleLocalFileService recordService = new GoogleLocalFileService();
		return recordService.createGoogleFileRecord(request);
    }

	@AuraEnabled
    public static GoogleFile__c saveNewGoogleFileVersion(Id recordId, Id localGoogleFileId, String fileName, String fileType, Long fileSize, String googleDriveId, String parentFolderId, String source) {
		GoogleFileCreateRequestDTO request = new GoogleFileCreateRequestDTO();
		request.recordId = recordId;
		request.localGoogleFileId = localGoogleFileId;
		request.fileName = fileName;
		request.fileType = fileType;
		request.fileSize = fileSize;
		request.googleDriveId = googleDriveId;
		request.parentFolderId = parentFolderId;
		request.source = source;

		GoogleLocalFileService recordService = new GoogleLocalFileService();
		return recordService.createGoogleFileRecord(request);
    }

	@AuraEnabled
    public static void deleteExistingGoogleFile(Id recordId) {
        GoogleLocalFileService recordService = new GoogleLocalFileService();
        recordService.deleteGoogleFileRecord()
            .setRecordId(recordId)
			.setCloudDeletion(true)
            .save();
    }

    @AuraEnabled
    public static GoogleBigFileEntity uploadLargeFilePartial(String fileName, String chunkToUpload, String resumableSessionId, Long startByte, Long totalBytes) {
		try {
			GoogleBigFileEntity remoteBigFileEntity = new GoogleRemoteFileUploader().uploadBigFilePartial(fileName, chunkToUpload, resumableSessionId, startByte, totalBytes);
			return remoteBigFileEntity;
		} catch (Exception ex) {
			Logger.error('Upload Large File, File Name: ' + fileName).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.error('Upload Large File, Total Bytes: ' + String.valueOf(totalBytes)).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.error('Upload Large File, Message: ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();

			throw new AuraHandledException('We couldn’t upload the large file. Please try again, or contact your system administrator');
		}
    }

    @AuraEnabled
    public static GoogleFileEntity uploadFile(String fileName, String contentToUpload) {
		try {
			GoogleFileEntity remoteFileEntity = new GoogleRemoteFileUploader().uploadFile(fileName, contentToUpload);
			return remoteFileEntity;
		} catch (Exception ex) {
			Logger.error('Upload File, File Name: ' + fileName).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.error('Upload File, Message: ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();

			throw new AuraHandledException('We couldn’t upload the file. Please try again, or contact your system administrator');
		}
    }

	@AuraEnabled
	public static String downloadFile(Id localGoogleFileVersionId) {
		try {
			GoogleLocalFileVersionService localVersionService = new GoogleLocalFileVersionService();
			return localVersionService.downloadFileBase64Body(localGoogleFileVersionId);
		} catch (Exception ex) {
			Logger.error('Download File, Id: ' + localGoogleFileVersionId).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.error('Download File, Message: ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();

			throw new AuraHandledException('We couldn’t download the file. Please try again, or contact your system administrator');
		}
	}

	@AuraEnabled
	public static String downloadFileAsPdf(Id localGoogleFileVersionId) {
		try {
			GoogleLocalFileVersionService localVersionService = new GoogleLocalFileVersionService();
			return localVersionService.downloadFileBase64BodyAsPdf(localGoogleFileVersionId);
		} catch (Exception ex) {
			Logger.error('Download File as PDF, Id: ' + localGoogleFileVersionId).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.error('Download File as PDF, Message: ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();

			throw new AuraHandledException('We couldn’t download the file. Please try again, or contact your system administrator');
		}
	}

	@AuraEnabled
	public static List<GoogleFileDownloadAsOptionDTO> retrieveDownloadAsOptions(Id localGoogleFileVersionId) {
		try {
			GoogleLocalFileVersionService localVersionService = new GoogleLocalFileVersionService();
			return localVersionService.retrieveDownloadAsOptions(localGoogleFileVersionId);
		} catch (Exception ex) {
			Logger.error('Retrieve Download As Options, Id: ' + localGoogleFileVersionId).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.error('Retrieve Download As Options, Message: ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();

			return new List<GoogleFileDownloadAsOptionDTO>();
		}
	}

	@AuraEnabled
	public static String downloadFileAs(Id localGoogleFileVersionId, String exportMimeType) {
		try {
			GoogleLocalFileVersionService localVersionService = new GoogleLocalFileVersionService();
			return localVersionService.downloadFileBase64BodyAs(localGoogleFileVersionId, exportMimeType);
		} catch (Exception ex) {
			Logger.error('Download File As, Id: ' + localGoogleFileVersionId).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.error('Download File As, Export Mime Type: ' + exportMimeType).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.error('Download File As, Message: ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();

			throw new AuraHandledException('We couldn’t download the file in the selected format. Please try again, or contact your system administrator');
		}
	}

	@AuraEnabled
	public static String downloadLargeFilePartial(Id localGoogleFileVersionId, Long startByte, Long endByte) {
		try {
			GoogleLocalFileVersionService localVersionService = new GoogleLocalFileVersionService();
			return localVersionService.downloadFileBase64Body(localGoogleFileVersionId, startByte, endByte);
		} catch (Exception ex) {
			Logger.error('Download Large File, Id: ' + localGoogleFileVersionId).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.error('Download Large File, End Byte: ' + String.valueOf(endByte)).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.error('Download Large File, Message: ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();

			throw new AuraHandledException('We couldn’t download the large file. Please try again, or contact your system administrator');
		}
	}
}