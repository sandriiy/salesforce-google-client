public with sharing class GoogleFileCloudFolderJob implements Queueable, Database.AllowsCallouts {
    public class GoogleFileCloudFolderJobException extends Exception {}

    private final GoogleFileRelocationRequestDTO request;

    public GoogleFileCloudFolderJob(GoogleFileRelocationRequestDTO request) {
        this.request = request;
    }

    public void execute(QueueableContext context) {
        if (this.request == null) return;

        IGoogleUnitOfWork uow = new GoogleCloudUnitOfWork(new List<SObjectType>{
            GoogleFile__c.SObjectType,
            GoogleFileVersion__c.SObjectType,
            GoogleFileLink__c.SObjectType
        });

        try {
            Logger.info(
                'Folder Placement Job --> FileId=' + String.valueOf(this.request.localGoogleFileId) +
                ', VersionId=' + String.valueOf(this.request.localGoogleFileVersionId) +
                ', LinkId=' + String.valueOf(this.request.linkLocalGoogleFileId)
            ).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

            new GoogleFileStoreInFolderCommand(uow).placeFile(this.request);
            uow.commitWork(true);
        } catch (Exception ex) {
            Logger.error('Folder Placement Job Failed --> ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
            Logger.saveLog();
            throw new GoogleFileCloudFolderJobException('Unable to place the file into a folder. Please try again or contact your system administrator');
        }
    }
}