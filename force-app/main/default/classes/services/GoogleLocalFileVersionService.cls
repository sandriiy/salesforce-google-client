public without sharing class GoogleLocalFileVersionService {
	public class GoogleFileVersionException extends Exception {}

	private final GoogleMetadataConfigService googleConfig;
	private final GoogleRemoteFileService remoteFileService;

	public GoogleLocalFileVersionService() {
		this.googleConfig = new GoogleMetadataConfigService();
		this.remoteFileService = new GoogleRemoteFileService();
	}

	public void syncLatestVersionToMainFile(List<GoogleFileVersion__c> newFileVersions, Map<Id, GoogleFileVersion__c> oldFileVersions) {
		List<GoogleFileVersion__c> versionsToSync = resolveVersionsToSync(newFileVersions, oldFileVersions);
		if (versionsToSync.isEmpty()) return;

		Set<Id> parentFileIds = collectParentFileIds(versionsToSync);
		if (parentFileIds.isEmpty()) return;

		Logger.info('Sync Latest Version To Main File --> ' + String.join(parentFileIds, ', '));

		Map<Id, GoogleFile__c> parentFilesById = (Map<Id, GoogleFile__c>) GoogleFileSelector.query()
			.byRecordIds(new List<Id>(parentFileIds))
			.withAllFields()
			.toMap();

		List<GoogleFile__c> localFilesToUpdate = buildParentFileDescriptionUpdates(versionsToSync, parentFilesById);
		
		if (localFilesToUpdate.isEmpty()) return;
		updateWithBypass('GoogleFileTriggerHandler', localFilesToUpdate);
	}

    public void applyPreviewStateIfEligible(List<GoogleFileVersion__c> newFileVersions) {
		if (newFileVersions == null || newFileVersions.isEmpty()) return;
		if (this.googleConfig.isPreviewDisabled()) return;

		Set<Id> previewableFileVersionIds = collectPreviewableVersionIds(newFileVersions);
		if (previewableFileVersionIds.isEmpty()) return;

		System.enqueueJob(new GoogleFileVersionPreviewJob(previewableFileVersionIds));
	}

	public void markAsLatestVersionIfApplicable(List<GoogleFileVersion__c> newFileVersions, List<GoogleFileVersion__c> oldFileVersions) {
		Set<Id> parentFileIds = collectParentFileIds(newFileVersions, oldFileVersions);
		if (parentFileIds.isEmpty()) return;

		Logger.info('Mark As Latest Version If Applicable --> ' + String.join(parentFileIds, ', '));

		List<GoogleFile__c> parentFiles = (List<GoogleFile__c>) GoogleFileSelector.query()
			.byRecordIds(new List<Id>(parentFileIds))
			.withVersionsSubquery()
			.toList();

		List<GoogleFileVersion__c> latestVersionsToUpdate = buildLatestFlagUpdates(parentFiles);
		if (latestVersionsToUpdate.isEmpty()) return;

		updateWithBypass('GoogleFileVersionTriggerHandler', latestVersionsToUpdate);
	}

	public String exportPreviewBase64BodyIfEligible(Id localFileVersionId) {
		GoogleFileVersion__c localFileVersion = queryLocalFileVersion(localFileVersionId);

		assertPreviewEligible(localFileVersion);

		GoogleFileEntity fileResult = exportOrDownloadAsPdf(localFileVersion);
		return EncodingUtil.base64Encode(fileResult.bodyAsBlob);
	}

	public String downloadFileBase64Body(Id localFileVersionId) {
		GoogleFileVersion__c localFileVersion = queryLocalFileVersion(localFileVersionId);

		GoogleFileEntity remoteFileEntity = this.remoteFileService.downloadFile(localFileVersion.GoogleDriveFileId__c);
		return EncodingUtil.base64Encode(remoteFileEntity.bodyAsBlob);
	}

	public String downloadFileBase64Body(Id localFileVersionId, Long startByte, Long endByte) {
		GoogleFileVersion__c localFileVersion = queryLocalFileVersion(localFileVersionId);

		GoogleFileEntity remoteFileEntity = this.remoteFileService.downloadFile(localFileVersion.GoogleDriveFileId__c, startByte, endByte);
		return EncodingUtil.base64Encode(remoteFileEntity.bodyAsBlob);
	}

	public void removeGoogleFiles(List<GoogleFileVersion__c> localFileVersions) {
		System.enqueueJob(new GoogleFileCloudDeleteJob(localFileVersions));
	}

	public List<GoogleFileVersion__c> removePublicLinkSharing(Id localFileVersionId) {
		Logger.info('Remove Public Link Sharing --> ' + localFileVersionId);

		GoogleFileVersion__c localFileVersion = queryLocalFileVersion(localFileVersionId);
		return deletePublicLink(new List<GoogleFileVersion__c>{ localFileVersion });
	}

	public List<GoogleFileVersion__c> applyPublicLinkSharing(Id localFileVersionId) {
		return applyPublicLinkSharing(localFileVersionId, null);
	}

	public List<GoogleFileVersion__c> applyPublicLinkSharing(Id localFileVersionId, Datetime expirationDate) {
		Logger.info('Apply Public Link Sharing --> ' + localFileVersionId);

		GoogleFileVersion__c localFileVersion = queryLocalFileVersion(localFileVersionId);
		return createAndAssignPublicLink(new List<GoogleFileVersion__c>{ localFileVersion }, expirationDate);
	}

	private List<GoogleFileVersion__c> resolveVersionsToSync(List<GoogleFileVersion__c> newFileVersions, Map<Id, GoogleFileVersion__c> oldFileVersions) {
		if (newFileVersions == null || newFileVersions.isEmpty()) {
			return new List<GoogleFileVersion__c>();
		}

		if (oldFileVersions != null && !oldFileVersions.isEmpty()) {
			return GTriggerHandler.getChangedRecords(newFileVersions, oldFileVersions, new Set<String>{ 'Description__c' });
		}

		return newFileVersions;
	}

	private Set<Id> collectParentFileIds(List<GoogleFileVersion__c> fileVersions) {
		Set<Id> parentFileIds = new Set<Id>();
		if (fileVersions == null) return parentFileIds;

		for (GoogleFileVersion__c fileVersion : fileVersions) {
			if (fileVersion != null && fileVersion.GoogleFileId__c != null) {
				parentFileIds.add(fileVersion.GoogleFileId__c);
			}
		}

		return parentFileIds;
	}

	private Set<Id> collectParentFileIds(List<GoogleFileVersion__c> newFileVersions, List<GoogleFileVersion__c> oldFileVersions) {
		Set<Id> parentFileIds = new Set<Id>();

		parentFileIds.addAll(collectParentFileIds(newFileVersions));
		parentFileIds.addAll(collectParentFileIds(oldFileVersions));

		return parentFileIds;
	}

	private List<GoogleFile__c> buildParentFileDescriptionUpdates(List<GoogleFileVersion__c> versionsToSync, Map<Id, GoogleFile__c> parentFilesById) {
		List<GoogleFile__c> localFilesToUpdate = new List<GoogleFile__c>();
		Set<Id> parentFilesAlreadyAdded = new Set<Id>();

		for (GoogleFileVersion__c fileVersion : versionsToSync) {
			if (fileVersion == null || fileVersion.GoogleFileId__c == null) continue;
			if (!fileVersion.IsLatestFile__c) continue;

			GoogleFile__c parentFile = parentFilesById.get(fileVersion.GoogleFileId__c);
			if (parentFile == null) continue;

			if (parentFile.Description__c == fileVersion.Description__c) continue;
			if (parentFilesAlreadyAdded.contains(parentFile.Id)) continue;

			localFilesToUpdate.add(new GoogleFile__c(
				Id = parentFile.Id,
				Description__c = fileVersion.Description__c
			));

			parentFilesAlreadyAdded.add(parentFile.Id);
		}

		return localFilesToUpdate;
	}

	private List<GoogleFileVersion__c> buildLatestFlagUpdates(List<GoogleFile__c> parentFiles) {
		List<GoogleFileVersion__c> latestVersionsToUpdate = new List<GoogleFileVersion__c>();

		for (GoogleFile__c parentFile : parentFiles) {
			List<GoogleFileVersion__c> fileVersions = parentFile.GoogleFileVersions__r;
			if (fileVersions == null || fileVersions.isEmpty()) continue;

			for (Integer index = 0; index < fileVersions.size(); index++) {
				GoogleFileVersion__c fileVersion = fileVersions[index];
				Boolean shouldBeLatest = (index == 0);

				if (fileVersion.IsLatestFile__c != shouldBeLatest) {
					latestVersionsToUpdate.add(new GoogleFileVersion__c(
						Id = fileVersion.Id,
						IsLatestFile__c = shouldBeLatest
					));
				}
			}
		}

		return latestVersionsToUpdate;
	}

	private Set<Id> collectPreviewableVersionIds(List<GoogleFileVersion__c> newFileVersions) {
		Set<Id> previewableFileVersionIds = new Set<Id>();

		for (GoogleFileVersion__c newFileVersion : newFileVersions) {
			if (newFileVersion == null || newFileVersion.Id == null) continue;

			if (this.isVersionPreviewDocRequired(newFileVersion)) {
				previewableFileVersionIds.add(newFileVersion.Id);
			}
		}

		return previewableFileVersionIds;
	}

	private GoogleFileVersion__c queryLocalFileVersion(Id localFileVersionId) {
		return (GoogleFileVersion__c) GoogleFileVersionSelector.query()
			.withAdvancedFields()
			.byId(localFileVersionId)
			.toObject();
	}

	private GoogleFileEntity exportOrDownloadAsPdf(GoogleFileVersion__c localFileVersion) {
		if (localFileVersion.Type__c == 'application/pdf') {
			return this.remoteFileService.downloadFile(localFileVersion.GoogleDriveFileId__c);
		}

		return this.remoteFileService.exportGoogleDocFileAsPdf(localFileVersion.GoogleDocsFileId__c);
	}

	private void updateWithBypass(String handlerNameToBypass, List<SObject> recordsToUpdate) {
		GTriggerHandler.setBypass(handlerNameToBypass, true);
		try {
			update recordsToUpdate;
		} catch (Exception ex) {
			Logger.error('Update File(s)/Version(s) Failed (Local): ' + ex.getMessage());
			Logger.saveLog();
			throw new GoogleFileVersionException('Unable to update the record(s). Please try again or contact your administrator');
		} finally {
			GTriggerHandler.clearAllBypasses();
		}
	}

	private List<GoogleFileVersion__c> createAndAssignPublicLink(List<GoogleFileVersion__c> localFileVersions, Datetime expirationDate) {
		for (GoogleFileVersion__c localFileVersion : localFileVersions) {
			String googleDriveId = localFileVersion.GoogleDriveFileId__c;

			GooglePermissionEntity newPermission = this.remoteFileService.createFilePublicLink(googleDriveId);
			GoogleFileEntity fileDetails = this.remoteFileService.exportGoogleFileDetails(googleDriveId);

			localFileVersion.PublicLink__c = fileDetails.webViewLink;
			localFileVersion.PublicLinkExpirationDate__c = expirationDate;
			localFileVersion.PublicLinkPermissionId__c = newPermission.id;
			localFileVersion.PublicLinkStatus__c = 'Active';
		}

		try {
			update localFileVersions;
		} catch (Exception ex) {
			Logger.error('Created & Assign Public Link Failed (Local): ' + ex.getMessage());
			Logger.saveLog();
			throw new GoogleFileVersionException('Unable to create a public link. Please try again or contact your administrator');
		}

		return localFileVersions;
	}

	private void assertPreviewEligible(GoogleFileVersion__c localFileVersion) {
		if (this.googleConfig.isPreviewDisabled()) {
			throw new GoogleFileVersionException('Preview Unavailable. Please download it to open');
		}

		if (localFileVersion.Size__c > this.googleConfig.getBigFileSizeInBytes()) {
			throw new GoogleFileVersionException('Oops! This file is too large to preview. Please download it to open');
		} else if (this.isVersionPreviewDocInProgress(localFileVersion)) {
			throw new GoogleFileVersionException('Preview is being prepared. Please try again shortly or download the file');
		} else if (this.isVersionPreviewDocUnavailable(localFileVersion)) {
			throw new GoogleFileVersionException('Preview unavailable for the selected file type. Please download the file to open');
		}
	}

	private List<GoogleFileVersion__c> deletePublicLink(List<GoogleFileVersion__c> localFileVersions) {
		for (GoogleFileVersion__c localFileVersion : localFileVersions) {
			String googleDriveId = localFileVersion.GoogleDriveFileId__c;
			String publicPermissionId = localFileVersion.PublicLinkPermissionId__c;

			if (String.isNotBlank(googleDriveId) && String.isNotBlank(publicPermissionId)) {
				this.remoteFileService.removeFilePublicLink(googleDriveId, publicPermissionId);
				localFileVersion.PublicLink__c = null;
				localFileVersion.PublicLinkExpirationDate__c = null;
				localFileVersion.PublicLinkPermissionId__c = null;
				localFileVersion.PublicLinkStatus__c = 'None';
			}
		}

		try {
			update localFileVersions;
		} catch (Exception ex) {
			Logger.error('Delete Public Link Failed (Local): ' + ex.getMessage());
			Logger.saveLog();
			throw new GoogleFileVersionException('Unable to remove a public link. Please try again or contact your administrator');
		}

		return localFileVersions;
	}

	private Boolean isVersionPreviewDocRequired(GoogleFileVersion__c fileVersion) {
		return (
			fileVersion.IsPreviewableFile__c &&
			fileVersion.Type__c != 'application/pdf' &&
			!String.isBlank(fileVersion.GoogleDriveFileId__c) &&
			String.isBlank(fileVersion.GoogleDocsFileId__c)
		);
	}

	private Boolean isVersionPreviewDocInProgress(GoogleFileVersion__c fileVersion) {
		return (
			fileVersion.IsPreviewableFile__c &&
			String.isBlank(fileVersion.GoogleDocsFileId__c) &&
			fileVersion.Type__c != 'application/pdf'
		);
	}

	private Boolean isVersionPreviewDocUnavailable(GoogleFileVersion__c fileVersion) {
		return (
			!fileVersion.IsPreviewableFile__c
		);
	}
}