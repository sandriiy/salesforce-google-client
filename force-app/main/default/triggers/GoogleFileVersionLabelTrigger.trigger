trigger GoogleFileVersionLabelTrigger on GoogleFileVersionLabel__c (after insert, after update, after delete, after undelete) {
	new GoogleFileVersionLabelTriggerHandler().run();
}