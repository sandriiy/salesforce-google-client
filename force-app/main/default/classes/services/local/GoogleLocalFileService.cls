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
 * The way in for everything about files themselves: listing them, creating them, renaming them and
 * deleting them. This is the layer your own Apex should call rather than the commands underneath, since
 * it owns the unit of work and the single commit, turns failures into something a user can read, and
 * leaves the detail in the log.
 */
public without sharing class GoogleLocalFileService {
    public class GoogleLocalFileException extends Exception {}

    private final IGoogleUnitOfWork uow;

    public GoogleLocalFileService() {
        this.uow = new GoogleCloudUnitOfWork(GoogleCloudConstants.DEFAULT_WRITE_ORDER);
    }

    /**
     * Builds the service on a unit of work you already have, which is how several services commit together
     * in one transaction.
     *
     * @param injectedUow The unit of work to register on. A null gets one of its own.
     */
    public GoogleLocalFileService(IGoogleUnitOfWork injectedUow) {
        this.uow = injectedUow == null
            ? new GoogleCloudUnitOfWork(GoogleCloudConstants.DEFAULT_WRITE_ORDER)
            : injectedUow;
    }

    /**
     * Starts a read of the compact header shown at the top of the File Details page.
     *
     * @return The command to point at a file with forFile().
     */
    public GoogleFilePageDetailsCommand.RetrieveHeaderCommand retrieveGoogleFileHeaderDetails() {
        try {
            return new GoogleFilePageDetailsCommand().retrieveHeader();
        } catch (Exception ex) {
            Logger.error('Retrieve Page Details Header (Local): ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
            Logger.saveLog();
            throw new GoogleLocalFileException('Unable to retrieve file details. Please try again or contact your system administrator');
        }
    }
	
	/**
	 * Deprecated. Use retrieveFileExplorerFiles(Id) instead.
	 */
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

	/**
	 * Reads the first page of File Explorer for a user.
	 *
	 * @param userId Whose files to list.
	 * @return The first page, with the cursor for the next one.
	 */
	public GoogleFileExplorerResultDTO retrieveFileExplorerFiles(Id userId) {
		return retrieveGoogleFilesPage(GoogleFileExplorerPageRequestDTO.firstPage(), userId);
	}

	/**
	 * Reads one page of files for the running user.
	 *
	 * @param request What to sort, search and page by.
	 * @return The page, with the cursor for the next one when there is more.
	 */
	public GoogleFileExplorerResultDTO retrieveGoogleFilesPage(GoogleFileExplorerPageRequestDTO request) {
		return retrieveGoogleFilesPage(request, UserInfo.getUserId());
	}

	/**
	 * Reads one page of files for a given user. This is where the File Explorer request is translated into
	 * the neutral criteria the access layer works with, so paging stays free of anything about that screen.
	 *
	 * @param request What to sort, search and page by.
	 * @param userId Whose files to list.
	 * @return The page, with the cursor for the next one when there is more.
	 */
	public GoogleFileExplorerResultDTO retrieveGoogleFilesPage(GoogleFileExplorerPageRequestDTO request, Id userId) {
		GoogleFileAccessResolver accessResolver = new GoogleFileAccessResolver();
		try {
			GoogleFileAccessResolver.FilePage page = accessResolver.resolveFilePage(buildPageCriteria(request), userId);

			String nextCursor = (page.hasMore && page.cursorRow != null) ? request.encodeCursorFrom(page.cursorRow) : null;
			Boolean isPrivileged = accessResolver.privilegedFloor() != null;
			return new GoogleFileExplorerResultDTO(page.records, page.hasMore, isPrivileged, nextCursor);
		} catch (Exception ex) {
			Logger.error('Retrieve Google File Page (Local): ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw new GoogleLocalFileException('Unable to retrieve files. Please try again or contact your system administrator');
		}
	}

	private GoogleFileAccessResolver.FilePageCriteria buildPageCriteria(GoogleFileExplorerPageRequestDTO request) {
		GoogleFileAccessResolver.FilePageCriteria criteria = new GoogleFileAccessResolver.FilePageCriteria();
		criteria.pageSize = request.effectivePageSize();
		criteria.sortPath = request.sortPath();
		if (String.isNotBlank(request.sortDirection)) criteria.sortDirection = request.sortDirection;
		criteria.searchTerm = request.searchTerm;
		criteria.cursorValue = request.decodedCursorValue();
		criteria.cursorId = request.cursorId();
		criteria.ownerScope = resolveOwnershipScope(request.bucket);
		criteria.additionalVersionFields = new GoogleFileExplorerColumnResolver().resolveAdditionalVersionFields();
		return criteria;
	}

	private GoogleFileAccessResolver.OwnershipScope resolveOwnershipScope(String bucket) {
		if (GoogleCloudConstants.FILE_EXPLORER_BUCKET_OWNED.equals(bucket)) return GoogleFileAccessResolver.OwnershipScope.OwnedByUser;
		if (GoogleCloudConstants.FILE_EXPLORER_BUCKET_SHARED.equals(bucket)) return GoogleFileAccessResolver.OwnershipScope.NotOwnedByUser;
		return GoogleFileAccessResolver.OwnershipScope.AnyOwner;
	}

	/**
	 * Creates the Google Drive folders a record needs before files start arriving, which is what lets an
	 * upload resolve its folder while the bytes are still moving.
	 *
	 * @param relatedRecordId The record whose folders should exist.
	 */
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

	/**
	 * Lists the files attached to a record for one place in the UI, already filtered to what the running
	 * user may see.
	 *
	 * @param relatedRecordId The record whose files are wanted.
	 * @param source The component asking, such as "Notes & Attachments". Blank means every file.
	 * @param recordsCount How many to return at most. Null or zero means all of them.
	 * @return The accessible files, each stamped with UserAccessLevel__c.
	 */
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

	/**
	 * Lists the running user's own files that are not on this record yet, which is what Attach Existing
	 * File offers. Only owned files qualify, because attaching a file to a record grants access to it.
	 *
	 * @param relatedRecordId The record the file would be attached to.
	 * @return The files that can still be attached there.
	 */
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

	/**
	 * Records several uploaded files in one transaction and one commit, which is what automation needs when
	 * it moves a batch of files at once.
	 *
	 * @param requests One request per uploaded file.
	 * @return The created records in the same order, carrying their new Ids.
	 */
	public List<GoogleFileInsertCommand.GoogleFileInsertResult> createGoogleFileRecords(List<GoogleFileCreateRequestDTO> requests) {
		List<GoogleFileInsertCommand.GoogleFileInsertResult> insertResults = new List<GoogleFileInsertCommand.GoogleFileInsertResult>();
		if (requests == null || requests.isEmpty()) return insertResults;

		try {
			for (GoogleFileCreateRequestDTO request : requests) {
				insertResults.add(buildInsertCommand(request).save());
			}

			uow.commitWork(true);
		} catch (Exception ex) {
			Logger.error('Create Google File Records (Local): ' + requests.size() + ' file(s), message: ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw new GoogleLocalFileException('Unable to create the file record. Please try again or contact your system administrator');
		}

		return insertResults;
	}

    /**
     * Records one uploaded file and hands back what the caller may see of it. A file the caller cannot reach
     * comes back null, which only happens when it was uploaded on somebody else's behalf.
     *
     * @param request The uploaded file and the record it belongs to.
     * @return The new file with its current version, or null when the caller cannot see it.
     */
    public GoogleFile__c createGoogleFileRecord(GoogleFileCreateRequestDTO request) {
		GoogleFileInsertCommand.GoogleFileInsertResult insertResult;
		try {
			insertResult = buildInsertCommand(request).save();
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

	private GoogleFileInsertCommand buildInsertCommand(GoogleFileCreateRequestDTO request) {
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

		return insertCommand;
	}

	/**
	 * Renames files and versions and changes descriptions, committing once for the whole batch and doing
	 * nothing at all when none of them really changed.
	 *
	 * @param requests The records to change and what to change them to.
	 */
	public void updateGoogleFileDetails(List<GoogleFileUpdateRequestDTO> requests) {
		if (requests == null || requests.isEmpty()) return;
		
		Boolean hasUpdates = false;
		for (GoogleFileUpdateRequestDTO request : requests) {
			GoogleFileUpdateCommand updateCommand = new GoogleFileUpdateCommand(uow, request.localGoogleFileRecord, request.localGoogleFileVersionRecord);
			GoogleFileUpdateCommand.GoogleFileUpdateResult updateResult = updateCommand
				.changeFileNameTo(request.fileName)
				.changeFileVersionNameTo(request.fileVersionName)
				.changeFileDescriptionTo(request.fileDescription)
				.build();

			if (updateResult.localGoogleFileToUpdate != null || updateResult.localGoogleFileVersionToUpdate != null) {
				hasUpdates = true;
			}
		}

		if (!hasUpdates) return;

		try {
			uow.commitWork(true);
		} catch (Exception ex) {
			Logger.error('Update Google File Details (Local): ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw new GoogleLocalFileException('Unable to update file details. Please try again or contact your system administrator');
		}
	}

    /**
     * Starts a delete.
     *
     * @return The command to point at a file and decide whether Google Drive loses its copy too.
     */
    public GoogleFileDeleteCommand deleteGoogleFileRecord() {
        try {
            return new GoogleFileDeleteCommand(uow);
        } catch (Exception ex) {
            Logger.error('Delete Google File Record (Local/Remote): ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
            Logger.saveLog();
            throw new GoogleLocalFileException('Unable to delete the file. Please try again or contact your system administrator');
        }
    }

    /**
     * Starts an access check. Any path of your own that returns files to a user ends with this, or the files
     * leak.
     *
     * @return The command to fill in with files and a user.
     */
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