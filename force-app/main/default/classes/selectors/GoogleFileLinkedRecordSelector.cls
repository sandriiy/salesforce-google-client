public inherited sharing class GoogleFileLinkedRecordSelector {
    public static Map<Id, SObject> selectByIds(Set<Id> recordIds, List<String> fieldApiNames) {
        Map<Id, SObject> recordsById = new Map<Id, SObject>();
        if (recordIds == null || recordIds.isEmpty()) {
            return recordsById;
        }

        List<String> fieldsToSelect = new List<String>{ 'Id' };
        if (fieldApiNames != null && !fieldApiNames.isEmpty()) {
            fieldsToSelect.addAll(fieldApiNames);
        }

        Map<Schema.SObjectType, Set<Id>> sObjectTypeToIds = new Map<Schema.SObjectType, Set<Id>>();
        for (Id recordId : recordIds) {
            Schema.SObjectType objectType = recordId.getSObjectType();
            if (!sObjectTypeToIds.containsKey(objectType)) {
                sObjectTypeToIds.put(objectType, new Set<Id>());
            }
			
            sObjectTypeToIds.get(objectType).add(recordId);
        }

        for (Schema.SObjectType objectType : sObjectTypeToIds.keySet()) {
            String objectApiName = objectType.getDescribe().getName();

			Set<Id> objectRecordIds = sObjectTypeToIds.get(objectType);
            String soql = 'SELECT ' + String.join(fieldsToSelect, ', ') +
                ' FROM ' + objectApiName +
                ' WHERE Id IN :objectRecordIds';

            for (SObject record : Database.query(soql)) {
                recordsById.put((Id) record.get('Id'), record);
            }
        }

        return recordsById;
    }

    public static SObject selectById(Id recordId, List<String> fieldApiNames) {
        if (recordId == null) return null;
        return selectByIds(new Set<Id>{ recordId }, fieldApiNames).get(recordId);
    }

    public static Map<Id, SObject> selectByIds(Set<Id> recordIds) {
        return selectByIds(recordIds, null);
    }
}