public inherited sharing class GoogleFileSelector extends GSOQL implements GSOQL.Selector {
    @TestVisible
    private static final String MOCK_ID = 'GoogleFileSelector';

    public static final List<SObjectField> BASE_FIELDS = new List<SObjectField>{
        GoogleFile__c.Id,
        GoogleFile__c.CreatedDate,
        GoogleFile__c.LastModifiedDate,
        GoogleFile__c.Source__c
    };

    public static final List<SObjectField> DETAIL_FIELDS = new List<SObjectField>{
        GoogleFile__c.Name,
        GoogleFile__c.Description__c,
        GoogleFile__c.OwnerId,
        GoogleFile__c.CreatedById
    };
	

    public static GoogleFileSelector query() {
        return new GoogleFileSelector();
    }

    public GoogleFileSelector() {
        super(GoogleFile__c.SObjectType);
        systemMode();
        withoutSharing();
        mockId(MOCK_ID);
    }

    public GoogleFileSelector byRecordId(Id recordId) {
        whereAre(Filter.with(GoogleFile__c.Id).equal(recordId));
        return this;
    }

	public GoogleFileSelector byRecordIds(List<Id> recordIds) {
        whereAre(Filter.with(GoogleFile__c.Id).equal(recordIds));
        return this;
    }

    public GoogleFileSelector byRelatedRecordId(Id relatedId) {
        whereAre(
            GSOQL.Filter.id().isIn(
                GSOQL.InnerJoin.of(GoogleFileLink__c.SObjectType)
                    .with(GoogleFileLink__c.GoogleFileId__c)
                    .whereAre(
                        GSOQL.Filter.with(GoogleFileLink__c.LinkedObjectId__c).equal(relatedId)
                    )
            )
        );

        return this;
    }

    public GoogleFileSelector bySource(String source) {
        whereAre(Filter.with(GoogleFile__c.Source__c).equal(source));
        return this;
    }

    public GoogleFileSelector withSpecificFields(List<String> fields) {
        with(String.join(fields, ','));
        return this;
    }

    public GoogleFileSelector withBaseFields() {
        with(BASE_FIELDS);
        return this;
    }

    public GoogleFileSelector withAllFields() {
        with(BASE_FIELDS);
		with(DETAIL_FIELDS);
        return this;
    }

    public GoogleFileSelector withVersionsSubquery() {
        GSOQL.SubQuery versions = GSOQL.SubQuery.of('GoogleFileVersions__r')
            .with(GoogleFileVersionSelector.BASE_FIELDS)
            .with('CreatedBy', new List<SObjectField>{ User.Name })
            .orderBy(GoogleFileVersion__c.CreatedDate).sortDesc();

        with(versions);
        return this;
    }

    public GoogleFileSelector withLatestVersionSubquery() {
        GSOQL.SubQuery latestVersion = GSOQL.SubQuery.of('GoogleFileVersions__r')
            .with(GoogleFileVersionSelector.BASE_FIELDS)
            .with('CreatedBy', new List<SObjectField>{ User.Name })
            .orderBy(GoogleFileVersion__c.CreatedDate).sortDesc()
            .setLimit(1);

        with(latestVersion);
        return this;
    }

    public GoogleFileSelector orderByCreatedDesc() {
        orderBy(GoogleFile__c.CreatedDate).sortDesc();
        return this;
    }

    public GoogleFileSelector limitTo(Integer n) {
        setLimit(n);
        return this;
    }
}