public inherited sharing class GoogleFileLinkSelector extends GSOQL implements GSOQL.Selector {
	@TestVisible
    private static final String MOCK_ID = 'GoogleFileLinkSelector';

    public static GoogleFileLinkSelector query() {
        return new GoogleFileLinkSelector();
    }

    public GoogleFileLinkSelector() {
        super(GoogleFileLink__c.SObjectType);
        systemMode();
        withoutSharing();
        mockId(MOCK_ID);
    }

	public GoogleFileLinkSelector byParentId(Id recordId) {
        whereAre(Filter.with(GoogleFileLink__c.GoogleFileId__c).equal(recordId));
        return this;
    }

	public GoogleFileLinkSelector byParentIds(List<Id> recordIds) {
        whereAre(Filter.with(GoogleFileLink__c.GoogleFileId__c).isIn(recordIds));
        return this;
    }

	public GoogleFileLinkSelector byParentIds(Set<Id> recordIds) {
        whereAre(Filter.with(GoogleFileLink__c.GoogleFileId__c).isIn(recordIds));
        return this;
    }

	public GoogleFileLinkSelector withBaseFields() {
        with(
            GoogleFileLink__c.Id,
            GoogleFileLink__c.Name,
            GoogleFileLink__c.GoogleFileId__c,
            GoogleFileLink__c.LinkedObjectId__c
        );
        with(
            GoogleFileLink__c.LinkedObjectType__c,
            GoogleFileLink__c.ShareType__c,
            GoogleFileLink__c.Visibility__c
        );

        return this;
    }
}