public with sharing class GoogleFileVersionTriggerHandler extends GTriggerHandler {
	private List<GoogleFileVersion__c> newRecords;
	private List<GoogleFileVersion__c> oldRecords;
	private Map<Id, GoogleFileVersion__c> newRecordsMap;
	private Map<Id, GoogleFileVersion__c> oldRecordsMap;

	private GoogleLocalFileVersionService fileVersionService;

	public GoogleFileVersionTriggerHandler() {
		super('GoogleFileVersionTriggerHandler');

		this.newRecords = (List<GoogleFileVersion__c>) Trigger.new;
		this.oldRecords = (List<GoogleFileVersion__c>) Trigger.old;
		this.newRecordsMap = (Map<Id, GoogleFileVersion__c>) Trigger.newMap;
		this.oldRecordsMap = (Map<Id, GoogleFileVersion__c>) Trigger.oldMap;

		this.fileVersionService = new GoogleLocalFileVersionService();
	}

	public override void afterInsert() {
		this.fileVersionService.applyPreviewStateIfEligible(this.newRecords);
		this.fileVersionService.markAsLatestVersionIfApplicable(this.newRecords, null);
	}

	public override void afterUpdate() {
		this.fileVersionService.syncLatestVersionToMainFile(this.newRecords, this.oldRecordsMap);
	}

	public override void afterDelete() {
		this.fileVersionService.removeGoogleFiles(this.oldRecords);
		this.fileVersionService.markAsLatestVersionIfApplicable(null, this.oldRecords);
	}
}