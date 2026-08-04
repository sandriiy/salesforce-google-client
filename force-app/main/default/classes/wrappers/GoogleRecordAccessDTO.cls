public class GoogleRecordAccessDTO {
    @AuraEnabled
    public Id recordId { get; set; }

    @AuraEnabled
    public Boolean hasReadAccess { get; set; }

    @AuraEnabled
    public Boolean hasEditAccess { get; set; }

    public GoogleRecordAccessDTO(Id recordId, Boolean hasReadAccess, Boolean hasEditAccess) {
        this.recordId = recordId;
        this.hasReadAccess = hasReadAccess == true;
        this.hasEditAccess = hasEditAccess == true;
    }
}
