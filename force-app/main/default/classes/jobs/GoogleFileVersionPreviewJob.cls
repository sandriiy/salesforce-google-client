public with sharing class GoogleFileVersionPreviewJob implements Queueable, Database.AllowsCallouts {
	public class GoogleFilePreviewJobException extends Exception {}

    private final Set<Id> versionIds;
    public GoogleFileVersionPreviewJob(Set<Id> versionIds) {
        this.versionIds = versionIds == null 
			? new Set<Id>()
			: new Set<Id>(versionIds);
    }

    public void execute(QueueableContext qc) {
		Logger.info('Queueable Job to generate Google Docs previews for: ' + String.join(versionIds, ', ')).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
        if (versionIds.isEmpty()) return;

		List<GoogleFileVersion__c> localFileVersions = (List<GoogleFileVersion__c>) GoogleFileVersionSelector.query()
			.withAdvancedFields()
			.byIds(versionIds)
			.toList();

        List<GoogleFileVersion__c> toUpdate = new List<GoogleFileVersion__c>();
        for (GoogleFileVersion__c localFileVersion : localFileVersions) {
            if (String.isNotBlank(localFileVersion.GoogleDocsFileId__c)) continue;

			GoogleDriveApiProvider remoteFileService = new GoogleDriveApiProvider();
			GoogleDrive removeGoogleDrive = remoteFileService.retrieveGoogleDriveClient();
			GoogleFileEntity clonedFile = removeGoogleDrive.files().clone(localFileVersion.GoogleDriveFileId__c)
				.setFields('id')
				.setFileName(localFileVersion.Name)
				.setSupportsAllDrives(true)
				.setMimeType('application/vnd.google-apps.document')
				.execute();

			localFileVersion.GoogleDocsFileId__c  = clonedFile.id;
			toUpdate.add(localFileVersion);
        }

        if (!toUpdate.isEmpty()) {
			GTriggerHandler.setBypass('GoogleFileVersionTriggerHandler', true);
			try {
				update toUpdate;
			} catch (Exception ex) {
				Logger.error('Google File Version update failed (Local): ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
				Logger.saveLog();
			} finally {
				GTriggerHandler.clearAllBypasses();
			}
        }
    }
}
