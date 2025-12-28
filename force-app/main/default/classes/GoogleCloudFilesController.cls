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
		GoogleLocalFileVersionService localVersionService = new GoogleLocalFileVersionService();
		return localVersionService.exportPreviewBase64BodyIfEligible(localFileVersionId);
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
        GoogleLocalFileService recordService = new GoogleLocalFileService();
        return recordService.createGoogleFileRecord()
            .setRecordId(recordId)
            .setFileName(fileName)
            .setFileType(fileType)
            .setFileSize(fileSize)
            .setGoogleDriveId(googleDriveId)
            .setParentFolderId(parentFolderId)
            .setSource(source)
            .save();
    }

	@AuraEnabled
    public static GoogleFile__c saveNewGoogleFileVersion(Id recordId, Id localGoogleFileId, String fileName, String fileType, Long fileSize, String googleDriveId, String parentFolderId, String source) {
		GoogleLocalFileService recordService = new GoogleLocalFileService();
        GoogleFile__c result = recordService.createGoogleFileRecord()
            .setRecordId(recordId)
			.setLocalGoogleFileId(localGoogleFileId)
            .setFileName(fileName)
            .setFileType(fileType)
            .setFileSize(fileSize)
            .setGoogleDriveId(googleDriveId)
            .setParentFolderId(parentFolderId)
            .setSource(source)
            .save();

		return result;
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
        GoogleRemoteFileService removeService = new GoogleRemoteFileService();
		GoogleBigFileEntity remoteBigFileEntity = removeService.uploadBigFilePartial(fileName, chunkToUpload, resumableSessionId, startByte, totalBytes);
		return remoteBigFileEntity;
    }

    @AuraEnabled
    public static GoogleFileEntity uploadFile(String fileName, String contentToUpload) {
		GoogleRemoteFileService removeService = new GoogleRemoteFileService();
		GoogleFileEntity remoteFileEntity = removeService.uploadFile(fileName, contentToUpload);
		return remoteFileEntity;
    }

	@AuraEnabled
	public static String downloadFile(Id localGoogleFileVersionId) {
		GoogleLocalFileVersionService localVersionService = new GoogleLocalFileVersionService();
		return localVersionService.downloadFileBase64Body(localGoogleFileVersionId);
	}

	@AuraEnabled
	public static String downloadLargeFilePartial(Id localGoogleFileVersionId, Long startByte, Long endByte) {
		GoogleLocalFileVersionService localVersionService = new GoogleLocalFileVersionService();
		return localVersionService.downloadFileBase64Body(localGoogleFileVersionId, startByte, endByte);
	}
}