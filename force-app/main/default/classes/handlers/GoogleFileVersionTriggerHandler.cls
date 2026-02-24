public with sharing class GoogleFileVersionTriggerHandler extends GTriggerHandler {
	private List<GoogleFileVersion__c> newRecords;
	private List<GoogleFileVersion__c> oldRecords;
	private Map<Id, GoogleFileVersion__c> newRecordsMap;
	private Map<Id, GoogleFileVersion__c> oldRecordsMap;

	private GoogleLocalFileVersionLifecycleService lifecycleService;

	public GoogleFileVersionTriggerHandler() {
		super('GoogleFileVersionTriggerHandler');

		this.newRecords = (List<GoogleFileVersion__c>) Trigger.new;
		this.oldRecords = (List<GoogleFileVersion__c>) Trigger.old;
		this.newRecordsMap = (Map<Id, GoogleFileVersion__c>) Trigger.newMap;
		this.oldRecordsMap = (Map<Id, GoogleFileVersion__c>) Trigger.oldMap;

		this.lifecycleService = new GoogleLocalFileVersionLifecycleService();
	}

	public override void afterInsert() {
		this.lifecycleService.applyPreviewStateIfEligible(this.newRecords);
		this.lifecycleService.markAsLatestVersionIfApplicable(this.newRecords, null);
	}

	public override void afterUpdate() {
		this.lifecycleService.syncLatestVersionToMainFile(this.newRecords, this.oldRecordsMap);
	}

	public override void afterDelete() {
		this.lifecycleService.markAsLatestVersionIfApplicable(null, this.oldRecords);
		this.lifecycleService.removeGoogleFiles(this.oldRecords);
	}
}