public without sharing class GoogleLocalFileLinkService {
    public List<GoogleFileLink__c> applyLinkedRecordAttributes(List<GoogleFileLink__c> newFileLinks) {
		if (newFileLinks == null || newFileLinks.isEmpty()) {
            return newFileLinks;
        }

        Set<String> linkedObjectApiNames = collectLinkedObjectApiNames(newFileLinks);
        Map<String, String> nameFieldByObjectApiName = getNameFieldByObjectApiName(linkedObjectApiNames);
		if (nameFieldByObjectApiName.isEmpty()) return newFileLinks; 

        Map<Id, SObject> linkedRecordsById = loadLinkedRecords(newFileLinks, nameFieldByObjectApiName);
		populateLinkedObjectNames(newFileLinks, linkedRecordsById, nameFieldByObjectApiName);

        return newFileLinks;
    }

    private Set<String> collectLinkedObjectApiNames(List<GoogleFileLink__c> fileLinks) {
        Set<String> objectApiNames = new Set<String>();

        for (GoogleFileLink__c fileLink : fileLinks) {
            if (!String.isBlank(fileLink.LinkedObjectType__c)) {
                objectApiNames.add(fileLink.LinkedObjectType__c);
            }
        }

        return objectApiNames;
    }

    private Map<String, String> getNameFieldByObjectApiName(Set<String> objectApiNames) {
        Map<String, String> nameFieldByObjectApiName = new Map<String, String>();

        if (objectApiNames == null || objectApiNames.isEmpty()) {
            return nameFieldByObjectApiName;
        }

        List<FieldDefinition> nameFieldDefinitions = [
            SELECT QualifiedApiName,
                   EntityDefinition.QualifiedApiName
            FROM FieldDefinition
            WHERE EntityDefinition.QualifiedApiName IN :objectApiNames
            AND IsNameField = TRUE
        ];

        for (FieldDefinition fieldDef : nameFieldDefinitions) {
            String entityApiName = fieldDef.EntityDefinition.QualifiedApiName;
            String fieldApiName = fieldDef.QualifiedApiName;
            nameFieldByObjectApiName.put(entityApiName, fieldApiName);
        }

        return nameFieldByObjectApiName;
    }

    private Map<Id, SObject> loadLinkedRecords(List<GoogleFileLink__c> fileLinks, Map<String, String> nameFieldByObjectApiName) {
        Map<Id, SObject> linkedRecordsById = new Map<Id, SObject>();

        Map<String, Set<Id>> objectApiNameToIds = new Map<String, Set<Id>>();
        for (GoogleFileLink__c fileLink : fileLinks) {
            String objectApiName = fileLink.LinkedObjectType__c;
            String linkedRecordId = fileLink.LinkedObjectId__c;

            if (String.isBlank(objectApiName) || String.isBlank(linkedRecordId)) {
                continue;
            }

            if (!nameFieldByObjectApiName.containsKey(objectApiName)) {
                continue;
            }

            if (!objectApiNameToIds.containsKey(objectApiName)) {
                objectApiNameToIds.put(objectApiName, new Set<Id>());
            }

            objectApiNameToIds.get(objectApiName).add(linkedRecordId);
        }

        for (String objectApiName : objectApiNameToIds.keySet()) {
            Set<Id> recordIds = objectApiNameToIds.get(objectApiName);
            if (recordIds.isEmpty()) {
                continue;
            }

            String nameFieldApiName = nameFieldByObjectApiName.get(objectApiName);
            List<String> fieldsToQuery = new List<String>{ nameFieldApiName };

            Map<Id, SObject> recordsForObject = GoogleFileLinkedRecordSelector.selectByIds(recordIds, fieldsToQuery);
            linkedRecordsById.putAll(recordsForObject);
        }

        return linkedRecordsById;
    }

    private void populateLinkedObjectNames(List<GoogleFileLink__c> fileLinks, Map<Id, SObject> linkedRecordsById, Map<String, String> nameFieldByObjectApiName) {
        for (GoogleFileLink__c fileLink : fileLinks) {
            if (!String.isBlank(fileLink.LinkedObjectName__c)) {
                continue;
            }

            String objectApiName = fileLink.LinkedObjectType__c;
            String linkedRecordId = fileLink.LinkedObjectId__c;

            if (String.isBlank(objectApiName) || String.isBlank(linkedRecordId)) {
                continue;
            }

            if (!nameFieldByObjectApiName.containsKey(objectApiName)) {
                continue;
            }

            SObject linkedRecord = linkedRecordsById.get(linkedRecordId);
            if (linkedRecord == null) {
                continue;
            }

            String nameFieldApiName = nameFieldByObjectApiName.get(objectApiName);
            Object rawValue = linkedRecord.get(nameFieldApiName);

            if (rawValue == null) {
                continue;
            }

            String nameValue = String.valueOf(rawValue);

            if (nameValue != null && nameValue.length() > 255) {
                nameValue = nameValue.substring(0, 255);
            }

            fileLink.LinkedObjectName__c = nameValue;
        }
    }
}