public with sharing class GoogleFileLinkTriggerHandler extends GTriggerHandler {
    private List<GoogleFileLink__c> newRecords;
	private List<GoogleFileLink__c> oldRecords;
	private Map<Id, GoogleFileLink__c> newRecordsMap;
	private Map<Id, GoogleFileLink__c> oldRecordsMap;

	private GoogleLocalFileLinkService fileLinkService;

	public GoogleFileLinkTriggerHandler() {
		super('GoogleFileLinkTriggerHandler');

		this.newRecords = (List<GoogleFileLink__c>) Trigger.new;
		this.oldRecords = (List<GoogleFileLink__c>) Trigger.old;
		this.newRecordsMap = (Map<Id, GoogleFileLink__c>) Trigger.newMap;
		this.oldRecordsMap = (Map<Id, GoogleFileLink__c>) Trigger.oldMap;

		this.fileLinkService = new GoogleLocalFileLinkService();
	}

	public override void beforeInsert() {
		this.fileLinkService.applyLinkedRecordAttributes(this.newRecords);
	}
}