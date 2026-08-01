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
			GoogleFileLink__c.SObjectType,
			GoogleFileVersion__c.SObjectType
        });
    }

    public GoogleLocalFileService(IGoogleUnitOfWork injectedUow) {
        this.uow = injectedUow == null
            ? new GoogleCloudUnitOfWork(new List<SObjectType>{
                GoogleFile__c.SObjectType,
				GoogleFileLink__c.SObjectType,
				GoogleFileVersion__c.SObjectType
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
	
	public GoogleFileExplorerResultDTO retrieveGoogleFiles(Id userId) {
		if (new GoogleFileAccessResolver().privilegedFloor() != null) {
			return retrieveGoogleFilesPage(GoogleFileExplorerPageRequestDTO.firstPage());
		}

		GoogleFileAccessResolver accessResolver = new GoogleFileAccessResolver();
		try {
			List<String> additionalVersionFields = new GoogleFileExplorerColumnResolver().resolveAdditionalVersionFields();
			List<GoogleFile__c> files = accessResolver.resolveAccessibleFilesForUser(userId, additionalVersionFields);

			Boolean hasMore = files.size() > GoogleCloudConstants.EXPLORER_STANDARD_LIMIT;
			while (files.size() > GoogleCloudConstants.EXPLORER_STANDARD_LIMIT) {
				files.remove(files.size() - 1);
			}

			return new GoogleFileExplorerResultDTO(files, hasMore, false, null);
		} catch (Exception ex) {
			Logger.error('Retrieve Google File Records (Local): ' + userId + ', message: ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
            Logger.saveLog();
            throw new GoogleLocalFileException('Unable to create the file record. Please try again or contact your system administrator');
		}
	}

	public GoogleFileExplorerResultDTO retrieveGoogleFilesPage(GoogleFileExplorerPageRequestDTO request) {
		GoogleFileAccessResolver accessResolver = new GoogleFileAccessResolver();
		try {
			List<String> additionalVersionFields = new GoogleFileExplorerColumnResolver().resolveAdditionalVersionFields();
			List<GoogleFile__c> page = accessResolver.resolveFilePage(request, additionalVersionFields);

			Boolean hasMore = page.size() > request.effectivePageSize();
			if (hasMore) page.remove(page.size() - 1);

			String nextCursor = (hasMore && !page.isEmpty()) ? request.encodeCursorFrom(page.get(page.size() - 1)) : null;
			return new GoogleFileExplorerResultDTO(page, hasMore, true, nextCursor);
		} catch (Exception ex) {
			Logger.error('Retrieve Google File Page (Local): ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw new GoogleLocalFileException('Unable to retrieve files. Please try again or contact your system administrator');
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

	public List<GoogleFile__c> retrieveGoogleFilesForRelatedRecord(Id relatedRecordId, String source, Integer recordsCount) {
		if (relatedRecordId == null) return new List<GoogleFile__c>();

		try {
			List<GoogleFileLink__c> resolvedLinks = new GoogleFileLinkPlacementResolver().resolveLinks(relatedRecordId, source);
			Set<Id> resolvedFileIds = new Set<Id>();

			for (GoogleFileLink__c linkRecord : resolvedLinks) {
				if (linkRecord.GoogleFileId__c != null) {
					resolvedFileIds.add(linkRecord.GoogleFileId__c);
				}
			}

			if (resolvedFileIds.isEmpty()) return new List<GoogleFile__c>();

			GoogleFileSelector selector = GoogleFileSelector.query()
				.withBaseFields()
				.withVersionsSubquery()
				.orderByCreatedDesc();

			if (recordsCount != null && recordsCount != 0) {
				selector.limitTo(recordsCount);
			}

			return stripInaccessibleRecords()
				.forFiles(selector.byIds(resolvedFileIds).toList())
				.forRecordLinks(resolvedLinks)
				.forUser(UserInfo.getUserId())
				.strip();
		} catch (Exception ex) {
			Logger.error('Retrieve Google File Records By Related Record (Local): ' + String.valueOf(relatedRecordId) + ', source: ' + String.valueOf(source) + ', message: ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw new GoogleLocalFileException('Unable to retrieve the requested files. Please try again or contact your system administrator');
		}
	}

	public List<GoogleFile__c> retrieveAttachableOwnedFiles(Id relatedRecordId) {
		if (relatedRecordId == null) return new List<GoogleFile__c>();
		
		try {
			Set<Id> alreadyLinkedFileIds = new Set<Id>();
			for (GoogleFileLink__c existingLink : (List<GoogleFileLink__c>) GoogleFileLinkSelector.query().withBaseFields().byLinkedObjectId(relatedRecordId).toList()) {
				if (existingLink.GoogleFileId__c != null) {
					alreadyLinkedFileIds.add(existingLink.GoogleFileId__c);
				}
			}

			List<GoogleFile__c> ownedFiles = (List<GoogleFile__c>) GoogleFileSelector.query()
				.byOwner(UserInfo.getUserId())
				.withAllFields()
				.withLatestVersionSubquery()
				.orderByCreatedDesc()
				.toList();

			List<GoogleFile__c> attachableFiles = new List<GoogleFile__c>();
			for (GoogleFile__c ownedFile : ownedFiles) {
				if (ownedFile == null || ownedFile.Id == null || alreadyLinkedFileIds.contains(ownedFile.Id)) {
					continue;
				}

				ownedFile.UserAccessLevel__c = 'Edit';
				attachableFiles.add(ownedFile);
			}

			return attachableFiles;
		} catch (Exception ex) {
			Logger.error('Retrieve Attachable Google Files (Local): ' + String.valueOf(relatedRecordId) + ', message: ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw new GoogleLocalFileException('Unable to retrieve the available files. Please try again or contact your system administrator');
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

		GoogleFile__c createdFile = (GoogleFile__c) GoogleFileSelector.query()
			.withLatestVersionSubquery()
			.withBaseFields()
			.byId(insertResult.getLocalGoogleFileId())
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

}