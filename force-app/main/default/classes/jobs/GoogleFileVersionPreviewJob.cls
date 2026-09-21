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
 * Makes the Google Workspace copy of each new file, which is what previews, Download As, summaries and
 * labeling all read. It runs as a job because the clone is a Drive callout and a callout cannot follow
 * uncommitted DML in the same transaction.
 */
public with sharing class GoogleFileVersionPreviewJob extends GQueueableJob.AllowsCallouts {
	public class GoogleFilePreviewJobException extends Exception {}

	@TestVisible
	private static Boolean skipExecution = false;

    private final Set<Id> versionIds;
    /**
     * Builds the job for a set of versions.
     *
     * @param versionIds The versions needing a Workspace copy.
     */
    public GoogleFileVersionPreviewJob(Set<Id> versionIds) {
        this.versionIds = versionIds == null
			? new Set<Id>()
			: new Set<Id>(versionIds);
    }

	/**
	 * Clones each version in Drive, stores the copy Id, and queues the size measurement afterwards. The size
	 * is measured later on purpose, since Drive reports a placeholder until it has finished converting.
	 */
	public override void work() {
		if (skipExecution) return;
		if (versionIds.isEmpty()) return;

		Logger.info('Queueable Job to generate Google Workspace previews for: ' + String.join(versionIds, ', ')).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

		List<GoogleFileVersion__c> localFileVersions = (List<GoogleFileVersion__c>) GoogleFileVersionSelector.query()
			.withAdvancedFields()
			.byIds(versionIds)
			.toList();

		IGoogleUnitOfWork uow = new GoogleCloudUnitOfWork(GoogleCloudConstants.DEFAULT_WRITE_ORDER);
		Set<Id> generatedPreviewVersionIds = new Set<Id>();

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
			
			generatedPreviewVersionIds.add(localFileVersion.Id);
        }

		try {
			GTriggerHandler.setBypass('GoogleFileVersionTriggerHandler', true);
			uow.commitWork(true);
		} catch (Exception ex) {
			Logger.error('Google File Version update failed (Local): ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			return;
		} finally {
			GTriggerHandler.clearAllBypasses();
		}

		GoogleFileVersionPreviewSizeJob.schedule(generatedPreviewVersionIds);
    }
}