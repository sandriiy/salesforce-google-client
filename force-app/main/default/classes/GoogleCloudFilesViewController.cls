public with sharing class GoogleCloudFilesViewController {
    @AuraEnabled
    public static GoogleFileHeaderInfoDTO fetchFileHeaderDetails(Id localFileRecordId) {
		GoogleLocalFileService service = new GoogleLocalFileService();

        return service.retrieveGoogleFileHeaderDetails()
            .forFile(localFileRecordId)
            .execute();
	}

	@AuraEnabled(cacheable=true)
    public static List<GoogleFileVersion__c> retrieveLocalGoogleFileVersions(Id localFileRecordId) {
		return (List<GoogleFileVersion__c>) GoogleFileVersionSelector.query()
			.withBaseFields()
			.byParentId(localFileRecordId)
			.orderByCreatedDesc()
			.with('CreatedBy', new List<SObjectField>{ User.Name })
			.toList();
    }
}