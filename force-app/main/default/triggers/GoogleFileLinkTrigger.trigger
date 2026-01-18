trigger GoogleFileLinkTrigger on GoogleFileLink__c (before insert, after insert, before update, after update, after delete) {
	new GoogleFileLinkTriggerHandler().run();
}