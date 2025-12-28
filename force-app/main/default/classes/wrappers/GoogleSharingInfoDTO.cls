public class GoogleSharingInfoDTO {
    @AuraEnabled public Id fileId { get; set; }
	@AuraEnabled public User owner { get; set; }
	@AuraEnabled public List<GoogleFile__Share> entitiesSharedTo { get; set; }
	@AuraEnabled public List<GoogleFileLink__c> recordsSharedTo { get; set; }
}