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
	public static List<GoogleFile__c> retrieveAllGoogleFiles() {
		GoogleLocalFileService recordService = new GoogleLocalFileService();
		return recordService.retrieveGoogleFiles(UserInfo.getUserId());
	}

    @AuraEnabled
    public static List<GoogleFile__c> retrieveGoogleFiles(Id relatedRecordId, String source, Integer recordsCount) {
		GoogleFileSelector selector = GoogleFileSelector.query()
			.byRelatedRecordId(relatedRecordId)
			.withBaseFields()
			.withVersionsSubquery()
			.orderByCreatedDesc();

        if (String.isNotBlank(source)) {
			selector.bySource(source);
        }

		if (recordsCount != null && recordsCount != 0) {
			selector.limitTo(recordsCount);
		}

		GoogleLocalFileService recordService = new GoogleLocalFileService();
        return recordService.stripInaccessibleRecords()
			.forFiles(selector.toList())
			.forUser(UserInfo.getUserId())
			.strip();
    }

	@AuraEnabled
    public static GoogleFile__c retrieveLocalGoogleFileById(Id localGoogleFileId) {
        GoogleFile__c localGoogleFile = (GoogleFile__c) GoogleFileSelector.query()
			.byRecordId(localGoogleFileId)
			.withBaseFields()
			.withVersionsSubquery()
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
    public static String retrieveGoogleFileBase64Preview(Id localFileVersionId) { 
		try {
			GoogleLocalFileVersionService localVersionService = new GoogleLocalFileVersionService();
			return localVersionService.exportPreviewBase64BodyIfEligible(localFileVersionId);
		} catch (GoogleLocalFileVersionService.GoogleFileVersionException ex) {
			throw new AuraHandledException(ex.getMessage());
		} catch (Exception ex) {
			Logger.error('Retrieve Google File Preview, Id: ' + localFileVersionId).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.error('Retrieve Google File Preview, Message:' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();

			throw new AuraHandledException('Preview isn’t available for this file. Please download the file instead, or contact your system administrator');
		}
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
			Logger.error('Google Client for Salesforce / Upload Large File, File Name: ' + fileName);
			Logger.error('Google Client for Salesforce / Upload Large File, Total Bytes: ' + String.valueOf(totalBytes));
			Logger.error('Google Client for Salesforce / Upload Large File, Message:' + ex.getMessage());
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
			Logger.error('Google Client for Salesforce / Upload File, File Name: ' + fileName);
			Logger.error('Google Client for Salesforce / Upload File, Message:' + ex.getMessage());
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
			Logger.error('Google Client for Salesforce / Download File, Id: ' + localGoogleFileVersionId);
			Logger.error('Google Client for Salesforce / Download File, Message:' + ex.getMessage());
			Logger.saveLog();

			throw new AuraHandledException('We couldn’t download the file. Please try again, or contact your system administrator');
		}
	}

	@AuraEnabled
	public static String downloadLargeFilePartial(Id localGoogleFileVersionId, Long startByte, Long endByte) {
		try {
			GoogleLocalFileVersionService localVersionService = new GoogleLocalFileVersionService();
			return localVersionService.downloadFileBase64Body(localGoogleFileVersionId, startByte, endByte);
		} catch (Exception ex) {
			Logger.error('Google Client for Salesforce / Download Large File, Id: ' + localGoogleFileVersionId);
			Logger.error('Google Client for Salesforce / Download Large File, End Byte: ' + String.valueOf(endByte));
			Logger.error('Google Client for Salesforce / Download Large File, Message:' + ex.getMessage());
			Logger.saveLog();

			throw new AuraHandledException('We couldn’t download the large file. Please try again, or contact your system administrator');
		}
	}
}