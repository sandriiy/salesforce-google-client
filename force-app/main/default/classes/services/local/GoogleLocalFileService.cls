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
		GoogleFileAccessResolver accessResolver = new GoogleFileAccessResolver();
		try {
			return accessResolver.resolveAccessibleFilesForUser(userId);
		} catch (Exception ex) {
			Logger.error('Retrieve Google File Records (Local): ' + userId + ', message: ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
            Logger.saveLog();
            throw new GoogleLocalFileException('Unable to create the file record. Please try again or contact your system administrator');
		}
	}

	public void ensureGoogleDriveFolderStructure(Id relatedRecordId) {
		if (relatedRecordId == null) return;

		try {
			new GoogleFileFolderStructureCommand().ensureFolder(relatedRecordId);
		} catch (Exception ex) {
			Logger.error('Ensure Google Drive Folder Structure (Local): ' + relatedRecordId + ', message: ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw new GoogleLocalFileException('Unable to create the folder structure. Please try again or contact your system administrator');
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

	public void updateGoogleFileDetails(List<GoogleFileUpdateRequestDTO> requests) {
		if (requests == null || requests.isEmpty()) return;
		
		List<SObject> recordsToUpdate = new List<SObject>();
		for (GoogleFileUpdateRequestDTO request : requests) {
			GoogleFileUpdateCommand updateCommand = new GoogleFileUpdateCommand(request.localGoogleFileRecord, request.localGoogleFileVersionRecord);
			GoogleFileUpdateCommand.GoogleFileUpdateResult updateResult = updateCommand
				.changeFileNameTo(request.fileName)
				.changeFileVersionNameTo(request.fileVersionName)
				.changeFileDescriptionTo(request.fileDescription)
				.build();

			if (updateResult.localGoogleFileToUpdate != null) {
				recordsToUpdate.add(updateResult.localGoogleFileToUpdate);
			}

			if (updateResult.localGoogleFileVersionToUpdate != null) {
				recordsToUpdate.add(updateResult.localGoogleFileVersionToUpdate);
			}
		}

		if (recordsToUpdate.isEmpty()) {
			return;
		} else {
			try {
				uow.registerDirty(recordsToUpdate);
				uow.commitWork(true);
			} catch (DmlException ex) {
				Logger.error('Update Google File Details (Local): ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
				Logger.saveLog();
				throw new GoogleLocalFileException('Unable to update file details. Please try again or contact your system administrator');
			}
		}
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