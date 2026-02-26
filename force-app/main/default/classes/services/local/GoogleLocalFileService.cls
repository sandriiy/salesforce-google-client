public without sharing class GoogleLocalFileService {
    public class GoogleLocalFileException extends Exception {}

    private final IGoogleUnitOfWork uow;

    public GoogleLocalFileService() {
        this.uow = new GoogleCloudUnitOfWork(new List<SObjectType>{
            GoogleFile__c.SObjectType,
            GoogleFileVersion__c.SObjectType,
            GoogleFileLink__c.SObjectType
        });
    }

    public GoogleLocalFileService(IGoogleUnitOfWork injectedUow) {
        this.uow = injectedUow == null
            ? new GoogleCloudUnitOfWork(new List<SObjectType>{
                GoogleFile__c.SObjectType,
                GoogleFileVersion__c.SObjectType,
                GoogleFileLink__c.SObjectType
            })
            : injectedUow;
    }

    public GoogleFilePageDetailsCommand.RetrieveHeaderCommand retrieveGoogleFileHeaderDetails() {
        try {
            return new GoogleFilePageDetailsCommand().retrieveHeader();
        } catch (Exception ex) {
            Logger.error('Retrieve Page Details Header (Local): ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
            Logger.saveLog();
            throw new GoogleLocalFileException('Unable to retrieve file details. Please try again or contact your system administrator');
        }
    }
	
	public List<GoogleFile__c> retrieveGoogleFiles(Id userId) {
		GoogleFileAccessibilityCommand accesibilityCommands = new GoogleFileAccessibilityCommand();
		try {
			return accesibilityCommands.forUser(userId).fetch();
		} catch (Exception ex) {
			Logger.error('Retrieve Google File Records (Local): ' + userId + ', message: ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
            Logger.saveLog();
            throw new GoogleLocalFileException('Unable to create the file record. Please try again or contact your system administrator');
		}
	}

    public GoogleFile__c createGoogleFileRecord(GoogleFileCreateRequestDTO request) {
		GoogleFileInsertCommand insertCommand = new GoogleFileInsertCommand(uow)
			.setRecordId(request.recordId)
			.setFileName(request.fileName)
			.setFileType(request.fileType)
			.setFileSize(request.fileSize)
			.setGoogleDriveId(request.googleDriveId)
			.setParentFolderId(request.parentFolderId)
			.setSource(request.source);

		if (request.localGoogleFileId != null) {
			insertCommand = insertCommand.setLocalGoogleFileId(request.localGoogleFileId);
		}

		GoogleFileInsertCommand.GoogleFileInsertResult insertResult;
		try {
			insertResult = insertCommand.save();
			uow.commitWork(true);
		} catch (Exception ex) {
			Logger.error('Create Google File Record (Local): ' + request.googleDriveId + ', message: ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw new GoogleLocalFileException('Unable to create the file record. Please try again or contact your system administrator');
		}

		queueGoogleFileFolderStructuring(insertResult);

		GoogleFile__c createdFile = (GoogleFile__c) GoogleFileSelector.query()
			.byRecordId(insertResult.getLocalGoogleFileId())
			.withLatestVersionSubquery()
			.withBaseFields()
			.toObject();

		if (createdFile != null) {
			List<GoogleFile__c> localFiles = stripInaccessibleRecords()
				.forFile(createdFile)
				.forUser(UserInfo.getUserId())
				.strip();

			return localFiles.isEmpty() ? null : localFiles.get(0);
		}

		return null;
	}

    public GoogleFileDeleteCommand deleteGoogleFileRecord() {
        try {
            return new GoogleFileDeleteCommand(uow);
        } catch (Exception ex) {
            Logger.error('Delete Google File Record (Local/Remote): ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
            Logger.saveLog();
            throw new GoogleLocalFileException('Unable to delete the file. Please try again or contact your system administrator');
        }
    }

    public GoogleFileAccessCheckCommand stripInaccessibleRecords() {
        try {
            return new GoogleFileAccessCheckCommand();
        } catch (Exception ex) {
            Logger.error('Strip Inaccessible Records (Local/Security): ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
            Logger.saveLog();
            throw new GoogleLocalFileException('Unable to verify access to the requested files due to security restrictions. Please try again or contact your system administrator');
        }
    }

	@TestVisible
	private void queueGoogleFileFolderStructuring(GoogleFileInsertCommand.GoogleFileInsertResult insertResult) {
		if (Test.isRunningTest()) return;
		
		Id localGoogleFileId = insertResult == null ? null : insertResult.getLocalGoogleFileId();
        Id localGoogleFileVersionId = insertResult == null ? null : insertResult.getLocalGoogleFileVersionId();

        Id localGoogleFileLinkId = insertResult == null ? null : insertResult.getLocalGoogleFileLinkId();
        if (localGoogleFileLinkId == null && localGoogleFileId != null) {
            localGoogleFileLinkId = GoogleFileLinkSelector.query()
				.withBaseFields()
				.byParentId(localGoogleFileId)
				.orderByCreatedDesc()
				.limitTo(1)
				.toId();
        }

        if (localGoogleFileId != null && localGoogleFileVersionId != null) {
            GoogleFileRelocationRequestDTO relocationRequest = new GoogleFileRelocationRequestDTO(
                UserInfo.getUserId(),
                localGoogleFileId,
                localGoogleFileVersionId,
                localGoogleFileLinkId
            );

			Integer delayInMinutes = 1;
            System.enqueueJob(new GoogleFileCloudFolderJob(relocationRequest), delayInMinutes);
        }
	}
}