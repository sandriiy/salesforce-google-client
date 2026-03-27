public class GoogleSharingInfoDTO {
    @AuraEnabled
	public Id fileId;
	@AuraEnabled
	public User owner;
	@AuraEnabled
	public List<GoogleFile__Share> entitiesSharedTo;
	@AuraEnabled
	public List<GoogleFileLink__c> recordsSharedTo;
}