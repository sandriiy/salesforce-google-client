/**
 * What a user may do with one ordinary Salesforce record, which is what a file linked to that record
 * borrows.
 */
public class GoogleRecordAccessDTO {
    @AuraEnabled
    public Id recordId { get; set; }

    @AuraEnabled
    public Boolean hasReadAccess { get; set; }

    @AuraEnabled
    public Boolean hasEditAccess { get; set; }

    /**
     * Holds the access to one record, treating a null as no access rather than unknown.
     *
     * @param recordId The record in question.
     * @param hasReadAccess Whether the user can read it.
     * @param hasEditAccess Whether the user can change it.
     */
    public GoogleRecordAccessDTO(Id recordId, Boolean hasReadAccess, Boolean hasEditAccess) {
        this.recordId = recordId;
        this.hasReadAccess = hasReadAccess == true;
        this.hasEditAccess = hasEditAccess == true;
    }
}
