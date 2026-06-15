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
public with sharing class GoogleFileVersionPreviewJob extends GQueueableJob.AllowsCallouts {
	public class GoogleFilePreviewJobException extends Exception {}

	@TestVisible
	private static Boolean skipExecution = false;

    private final Set<Id> versionIds;
    public GoogleFileVersionPreviewJob(Set<Id> versionIds) {
        this.versionIds = versionIds == null
			? new Set<Id>()
			: new Set<Id>(versionIds);
    }

	public override void work() {
		if (skipExecution) return;
		if (versionIds.isEmpty()) return;

		Logger.info('Queueable Job to generate Google Workspace previews for: ' + String.join(versionIds, ', ')).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

		List<GoogleFileVersion__c> localFileVersions = (List<GoogleFileVersion__c>) GoogleFileVersionSelector.query()
			.withAdvancedFields()
			.byIds(versionIds)
			.toList();

		IGoogleUnitOfWork uow = new GoogleCloudUnitOfWork(new List<SObjectType>{
			GoogleFileVersion__c.SObjectType
		});

        for (GoogleFileVersion__c localFileVersion : localFileVersions) {
            if (String.isNotBlank(localFileVersion.GoogleDocsFileId__c)) continue;

			String targetGoogleWorkspaceType = GoogleCloudConstants.FILE_EXTENSION_TO_PREVIEW_TYPE.get(localFileVersion.Type__c);
			if (String.isBlank(targetGoogleWorkspaceType)) continue;

			GoogleClientApiProvider remoteFileService = new GoogleClientApiProvider();
			GoogleDrive removeGoogleDrive = remoteFileService.retrieveGoogleDriveClient();
			GoogleFileEntity clonedFile = removeGoogleDrive.files().clone(localFileVersion.GoogleDriveFileId__c)
				.setFields('id')
				.setFileName(localFileVersion.Name)
				.setSupportsAllDrives(true)
				.setMimeType(targetGoogleWorkspaceType)
				.execute();

			String generatedPreviewFileId = clonedFile.id;
			uow.registerDirty(new GoogleFileVersion__c(
				Id = localFileVersion.Id,
				GoogleDocsFileId__c = generatedPreviewFileId
			));
        }

		try {
			GTriggerHandler.setBypass('GoogleFileVersionTriggerHandler', true);
			uow.commitWork(true);
		} catch (Exception ex) {
			Logger.error('Google File Version update failed (Local): ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
		} finally {
			GTriggerHandler.clearAllBypasses();
		}
    }
}