public with sharing class GoogleCloudFilesSharingController {
	@AuraEnabled
	public static GoogleSharingInfoDTO fetchSharingDetails(Id localFileRecordId) {
		GoogleLocalFileSharingService sharingService = new GoogleLocalFileSharingService();
		return sharingService.fetchSharingDetails(localFileRecordId);
	}

	@AuraEnabled
	public static Id createNewSharing(Id localFileRecordId, String shareToObjectApiName, Id shareToRecordId, String uiAccessLevel) {
		GoogleLocalFileSharingService sharingService = new GoogleLocalFileSharingService();
		return sharingService.createNewSharing(localFileRecordId, shareToObjectApiName, shareToRecordId, uiAccessLevel);
	}

	@AuraEnabled
	public static void modifyExistingSharingAccess(Id localFileRecordId, Id shareToRecordId, String uiAccessLevel) {
		GoogleLocalFileSharingService sharingService = new GoogleLocalFileSharingService();
		sharingService.modifyExistingSharingAccess(localFileRecordId, shareToRecordId, uiAccessLevel);
	}

	@AuraEnabled
	public static void modifyExistingSharingVisibility(Id localFileRecordId, Id shareToRecordId, String visibility) {
		GoogleLocalFileSharingService sharingService = new GoogleLocalFileSharingService();
		sharingService.modifyExistingSharingVisibility(localFileRecordId, shareToRecordId, visibility);
	}

	@AuraEnabled
	public static void deleteExistingSharing(Id localFileRecordId, Id shareToRecordId) {
		GoogleLocalFileSharingService sharingService = new GoogleLocalFileSharingService();
		sharingService.deleteExistingSharing(localFileRecordId, shareToRecordId);
	}

    @AuraEnabled
    public static GoogleFileVersion__c createNewPublicLink(Id localFileVersionId, Datetime expirationDate, Boolean isDomainSkip) {
		GoogleLocalFileVersionPublicLinkService localPublicLinkService = new GoogleLocalFileVersionPublicLinkService();
		List<GoogleFileVersion__c> updatedFiles = localPublicLinkService.applyPublicLinkSharing(localFileVersionId, expirationDate, isDomainSkip);
		return updatedFiles.isEmpty() ? null : updatedFiles.get(0);
	}

	@AuraEnabled
    public static void deleteExistingPublicLink(Id localFileVersionId) {
		GoogleLocalFileVersionPublicLinkService localPublicLinkService = new GoogleLocalFileVersionPublicLinkService();
		localPublicLinkService.removePublicLinkSharing(localFileVersionId);
	}

	@AuraEnabled(cacheable=true)
    public static Boolean isPublicLinkDomain() {
		GoogleMetadataConfigService googleConfig = new GoogleMetadataConfigService();
		String googleDomain = googleConfig.getGoogleDriveDomain();
		return String.isNotBlank(googleDomain);
	}
}