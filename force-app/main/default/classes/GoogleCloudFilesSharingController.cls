public with sharing class GoogleCloudFilesSharingController {
	@AuraEnabled
    public static GoogleSharingInfoDTO fetchSharingDetails(Id localFileRecordId) {
		GoogleLocalFileService recordService = new GoogleLocalFileService();
        Map<Id,GoogleSharingInfoDTO> sharingInfo = recordService.retrieveSharingDetails()
			.forFile(localFileRecordId)
			.includeAll()
			.fetch();

		return sharingInfo.get(localFileRecordId);
	}

	@AuraEnabled
    public static Id createNewSharing(Id localFileRecordId, String shareToObjectApiName, Id shareToRecordId, String uiAccessLevel) {
		GoogleLocalFileService recordService = new GoogleLocalFileService();
        return recordService.createGoogleFileSharing()
			.forFile(localFileRecordId)
			.shareTo(shareToObjectApiName, shareToRecordId)
			.withUiAccessLevel(uiAccessLevel)
			.apply();
	}

	@AuraEnabled
    public static void modifyExistingSharingAccess(Id localFileRecordId, Id shareToRecordId, String uiAccessLevel) {
		GoogleLocalFileService recordService = new GoogleLocalFileService();
        recordService.modifyGoogleFileSharing()
			.forFile(localFileRecordId)
			.shareTo(shareToRecordId)
			.withUiAccessLevel(uiAccessLevel)
			.apply();
	}

	@AuraEnabled
    public static void modifyExistingSharingVisibility(Id localFileRecordId, Id shareToRecordId, String visibility) {
		GoogleLocalFileService recordService = new GoogleLocalFileService();
        recordService.modifyGoogleFileSharing()
			.forFile(localFileRecordId)
			.shareTo(shareToRecordId)
			.withVisibility(visibility)
			.apply();
	}

	@AuraEnabled
    public static void deleteExistingSharing(Id localFileRecordId, Id shareToRecordId) {
		GoogleLocalFileService recordService = new GoogleLocalFileService();
        recordService.deleteGoogleFileSharing()
			.forFile(localFileRecordId)
			.shareTo(shareToRecordId)
			.apply();
	}

    @AuraEnabled
    public static GoogleFileVersion__c createNewPublicLink(Id localFileVersionId, Datetime expirationDate) {
		GoogleLocalFileVersionService localVersionService = new GoogleLocalFileVersionService();
		List<GoogleFileVersion__c> updatedFiles = localVersionService.applyPublicLinkSharing(localFileVersionId, expirationDate);
		return updatedFiles.isEmpty() ? null : updatedFiles.get(0);
	}

	@AuraEnabled
    public static void deleteExistingPublicLink(Id localFileVersionId) {
		GoogleLocalFileVersionService localVersionService = new GoogleLocalFileVersionService();
		List<GoogleFileVersion__c> updatedFiles = localVersionService.removePublicLinkSharing(localFileVersionId);
	}
}