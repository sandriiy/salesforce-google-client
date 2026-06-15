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
public with sharing class GoogleLocalFileVersionLifecycleService {
    public class GoogleFileVersionLifecycleException extends Exception {}

    private final GoogleMetadataConfigService googleConfig;
    private final GoogleFileVersionContextResolver versionContextResolver;
    private final IGoogleUnitOfWork uow;

    public GoogleLocalFileVersionLifecycleService() {
        this.googleConfig = new GoogleMetadataConfigService();
        this.versionContextResolver = new GoogleFileVersionContextResolver();
        this.uow = new GoogleCloudUnitOfWork(new List<SObjectType>{
            GoogleFile__c.SObjectType,
            GoogleFileVersion__c.SObjectType
        });
    }

    public GoogleLocalFileVersionLifecycleService(IGoogleUnitOfWork injectedUow) {
        this.googleConfig = new GoogleMetadataConfigService();
        this.versionContextResolver = new GoogleFileVersionContextResolver();
        this.uow = injectedUow == null
            ? new GoogleCloudUnitOfWork(new List<SObjectType>{
                GoogleFile__c.SObjectType,
                GoogleFileVersion__c.SObjectType
            })
            : injectedUow;
    }

	public void processFileInsertFinalizer(List<GoogleFileVersion__c> newFileVersions) {
		new GoogleFileInsertFinalizeCommand(this.googleConfig, this.versionContextResolver).execute(newFileVersions);
	}

    public void markAsLatestVersionIfApplicable(List<GoogleFileVersion__c> newFileVersions, List<GoogleFileVersion__c> oldFileVersions) {
        Set<Id> parentFileIds = this.versionContextResolver.collectParentFileIds(newFileVersions, oldFileVersions);
        if (parentFileIds.isEmpty()) return;

        Logger.info('Mark As Latest Version If Applicable --> ' + joinIds(parentFileIds)).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

        List<GoogleFile__c> parentFiles = (List<GoogleFile__c>) GoogleFileSelector.query()
            .withVersionsSubquery()
            .byIds(parentFileIds)
            .toList();

        List<GoogleFileVersion__c> latestVersionsToUpdate = buildLatestFlagUpdates(parentFiles);
        if (latestVersionsToUpdate.isEmpty()) return;

        commitUpdatesWithBypass('GoogleFileVersionTriggerHandler', latestVersionsToUpdate);
    }

	public void removeGoogleFiles(List<GoogleFileVersion__c> localFileVersions) {
		System.enqueueJob(new GoogleFileCloudDeleteJob(localFileVersions));
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
