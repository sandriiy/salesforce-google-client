public with sharing class GoogleLocalFileVersionLifecycleService {
    public class GoogleFileVersionLifecycleException extends Exception {}

    private final GoogleMetadataConfigService googleConfig;
    private final IGoogleUnitOfWork uow;

    public GoogleLocalFileVersionLifecycleService() {
        this.googleConfig = new GoogleMetadataConfigService();
        this.uow = new GoogleCloudUnitOfWork(new List<SObjectType>{
            GoogleFile__c.SObjectType,
            GoogleFileVersion__c.SObjectType
        });
    }

    public GoogleLocalFileVersionLifecycleService(IGoogleUnitOfWork injectedUow) {
        this.googleConfig = new GoogleMetadataConfigService();
        this.uow = injectedUow == null
            ? new GoogleCloudUnitOfWork(new List<SObjectType>{
                GoogleFile__c.SObjectType,
                GoogleFileVersion__c.SObjectType
            })
            : injectedUow;
    }

    public void syncLatestVersionToMainFile(List<GoogleFileVersion__c> newFileVersions, Map<Id, GoogleFileVersion__c> oldFileVersions) {
        List<GoogleFileVersion__c> versionsToSync = resolveVersionsToSync(newFileVersions, oldFileVersions);
        if (versionsToSync.isEmpty()) return;

        Set<Id> parentFileIds = collectParentFileIds(versionsToSync);
        if (parentFileIds.isEmpty()) return;

        Logger.info('Sync Latest Version To Main File --> ' + joinIds(parentFileIds)).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

        Map<Id, GoogleFile__c> parentFilesById = (Map<Id, GoogleFile__c>) GoogleFileSelector.query()
            .byRecordIds(new List<Id>(parentFileIds))
            .withAllFields()
            .toMap();

        List<GoogleFile__c> localFilesToUpdate = buildParentFileDescriptionUpdates(versionsToSync, parentFilesById);
        if (localFilesToUpdate.isEmpty()) return;

        commitUpdatesWithBypass('GoogleFileTriggerHandler', localFilesToUpdate);
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

        Logger.info('Mark As Latest Version If Applicable --> ' + joinIds(parentFileIds)).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

        List<GoogleFile__c> parentFiles = (List<GoogleFile__c>) GoogleFileSelector.query()
            .byRecordIds(new List<Id>(parentFileIds))
            .withVersionsSubquery()
            .toList();

        List<GoogleFileVersion__c> latestVersionsToUpdate = buildLatestFlagUpdates(parentFiles);
        if (latestVersionsToUpdate.isEmpty()) return;

        commitUpdatesWithBypass('GoogleFileVersionTriggerHandler', latestVersionsToUpdate);
    }

	public void removeGoogleFiles(List<GoogleFileVersion__c> localFileVersions) {
		System.enqueueJob(new GoogleFileCloudDeleteJob(localFileVersions));
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

            if (isVersionPreviewDocRequired(newFileVersion)) {
                previewableFileVersionIds.add(newFileVersion.Id);
            }
        }

        return previewableFileVersionIds;
    }

    private Boolean isVersionPreviewDocRequired(GoogleFileVersion__c fileVersion) {
        return (
            fileVersion.IsPreviewableFile__c &&
            fileVersion.Type__c != 'application/pdf' &&
            !String.isBlank(fileVersion.GoogleDriveFileId__c) &&
            String.isBlank(fileVersion.GoogleDocsFileId__c)
        );
    }

    private void commitUpdatesWithBypass(String handlerNameToBypass, List<SObject> recordsToUpdate) {
        if (recordsToUpdate == null || recordsToUpdate.isEmpty()) return;

        for (SObject recordToUpdate : recordsToUpdate) {
            if (recordToUpdate != null) {
                uow.registerDirty(recordToUpdate);
            }
        }

        GTriggerHandler.setBypass(handlerNameToBypass, true);
        try {
            uow.commitWork(true);
        } catch (Exception ex) {
            Logger.error('Update File(s)/Version(s) Failed (Local): ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
            Logger.saveLog();
            throw new GoogleFileVersionLifecycleException('Unable to update the record(s). Please try again or contact your administrator');
        } finally {
            GTriggerHandler.clearAllBypasses();
        }
    }

    private static String joinIds(Set<Id> recordIds) {
        if (recordIds == null || recordIds.isEmpty()) return '';

        List<String> idValues = new List<String>();
        for (Id recordId : recordIds) {
            if (recordId != null) {
                idValues.add(String.valueOf(recordId));
            }
        }

        return String.join(idValues, ', ');
    }
}
