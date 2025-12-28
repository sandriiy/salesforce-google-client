trigger GoogleFileVersionTrigger on GoogleFileVersion__c (before insert, after insert, before update, after update, after delete) {
	new GoogleFileVersionTriggerHandler().run();
}