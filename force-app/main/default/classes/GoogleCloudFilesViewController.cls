public with sharing class GoogleCloudFilesViewController {
    @AuraEnabled
    public static GoogleFileHeaderInfoDTO fetchFileHeaderDetails(Id localFileRecordId) {
		assertFileReadable(localFileRecordId);

		GoogleLocalFileService service = new GoogleLocalFileService();

        return service.retrieveGoogleFileHeaderDetails()
            .forFile(localFileRecordId)
            .execute();
	}

	@AuraEnabled(cacheable=true)
    public static List<GoogleFileVersion__c> retrieveLocalGoogleFileVersions(Id localFileRecordId) {
		assertFileReadable(localFileRecordId);

		return (List<GoogleFileVersion__c>) GoogleFileVersionSelector.query()
			.withBaseFields()
			.byParentId(localFileRecordId)
			.orderByCreatedDesc()
			.with('CreatedBy', new List<SObjectField>{ User.Name })
			.toList();
    }

	private static void assertFileReadable(Id localFileRecordId) {
		if (localFileRecordId == null) return;
		
		GoogleLocalFileService service = new GoogleLocalFileService();
		List<GoogleFile__c> accessibleFiles = service.stripInaccessibleRecords()
			.forFile(localFileRecordId)
			.forUser(UserInfo.getUserId())
			.strip();

		if (accessibleFiles.isEmpty()) {
			throw new AuraHandledException('You don’t have access to view this file. Please verify your permissions and try again');
		}
	}
}