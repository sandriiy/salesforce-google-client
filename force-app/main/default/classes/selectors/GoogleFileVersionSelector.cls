public inherited sharing class GoogleFileVersionSelector extends GSOQL implements GSOQL.Selector {
    @TestVisible
    private static final String MOCK_ID = 'GoogleFileVersionSelector';

    public static final List<SObjectField> BASE_FIELDS = new List<SObjectField>{
        GoogleFileVersion__c.Id,
        GoogleFileVersion__c.Name,
        GoogleFileVersion__c.GoogleFileId__c,
		GoogleFileVersion__c.IsLatestFile__c,
        GoogleFileVersion__c.IsPreviewableFile__c,
        GoogleFileVersion__c.Size__c,
        GoogleFileVersion__c.Type__c,
        GoogleFileVersion__c.CreatedDate,
		GoogleFileVersion__c.LastModifiedDate
    };

	public static final List<SObjectField> CONFIDENTIAL_FIELDS = new List<SObjectField>{
        GoogleFileVersion__c.GoogleDriveFileId__c,
        GoogleFileVersion__c.GoogleDocsFileId__c,
		GoogleFileVersion__c.GoogleDriveFolderId__c
	};

    public static final List<SObjectField> SHARING_FIELDS = new List<SObjectField>{
        GoogleFileVersion__c.PublicLink__c,
        GoogleFileVersion__c.PublicLinkExpirationDate__c,
        GoogleFileVersion__c.PublicLinkPermissionId__c
    };
	

    public static GoogleFileVersionSelector query() {
        return new GoogleFileVersionSelector();
    }

    public GoogleFileVersionSelector() {
        super(GoogleFileVersion__c.SObjectType);
        systemMode();
        withoutSharing();
        mockId(MOCK_ID);
    }

    public GoogleFileVersionSelector byParentId(Id recordId) {
        whereAre(Filter.with(GoogleFileVersion__c.GoogleFileId__c).equal(recordId));
        return this;
    }

    public GoogleFileVersionSelector orderByCreatedDesc() {
        orderBy(GoogleFileVersion__c.CreatedDate).sortDesc();
        return this;
    }

    public GoogleFileVersionSelector withBaseFields() {
        with(BASE_FIELDS);
        return this;
    }

	public GoogleFileVersionSelector withAdvancedFields() {
        with(BASE_FIELDS);
		with(SHARING_FIELDS);
		with(CONFIDENTIAL_FIELDS);
        return this;
    }

    public GoogleFileVersionSelector withSharingFields() {
		with(BASE_FIELDS);
        with(SHARING_FIELDS);
        return this;
    }
}