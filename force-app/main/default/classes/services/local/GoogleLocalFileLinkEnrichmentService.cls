/**
 * MIT License
 *
 * Copyright (c) 2026 Andrii Sukhetskyi
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
public without sharing class GoogleLocalFileLinkEnrichmentService {
    /**
	 * Enriches the provided Google File Link records by resolving each linked record’s Name field.
	 */
	public List<GoogleFileLink__c> applyLinkedRecordAttributes(List<GoogleFileLink__c> fileLinks) {
        if (fileLinks == null || fileLinks.isEmpty()) return fileLinks;

        Map<String, String> nameFieldByObjectApiName = resolveNameFieldByObjectApiName(fileLinks);
        if (nameFieldByObjectApiName.isEmpty()) return fileLinks;
        
        Map<Id, SObject> linkedRecordsById = loadLinkedRecordsById(fileLinks, nameFieldByObjectApiName);
        populateLinkedObjectNames(fileLinks, linkedRecordsById, nameFieldByObjectApiName);

        return fileLinks;
    }

    private Map<String, String> resolveNameFieldByObjectApiName(List<GoogleFileLink__c> fileLinks) {
        Map<String, String> nameFieldByObjectApiName = new Map<String, String>();

        for (GoogleFileLink__c fileLink : fileLinks) {
            String objectApiName = fileLink.LinkedObjectType__c;
            if (String.isBlank(objectApiName) || nameFieldByObjectApiName.containsKey(objectApiName)) {
                continue;
            }

            Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectApiName);
            if (objectType == null) continue;
            
            Schema.DescribeSObjectResult objectDescribe = objectType.getDescribe();
            Map<String, Schema.SObjectField> fieldsByApiName = objectDescribe.fields.getMap();

            String nameFieldApiName;
            for (Schema.SObjectField fieldToken : fieldsByApiName.values()) {
                Schema.DescribeFieldResult fieldDescribe = fieldToken.getDescribe();
                if (fieldDescribe.isNameField()) {
                    nameFieldApiName = fieldDescribe.getName();
                    break;
                }
            }

            if (!String.isBlank(nameFieldApiName)) {
                nameFieldByObjectApiName.put(objectApiName, nameFieldApiName);
            }
        }

        return nameFieldByObjectApiName;
    }

    private Map<Id, SObject> loadLinkedRecordsById(List<GoogleFileLink__c> fileLinks, Map<String, String> nameFieldByObjectApiName) {
        Map<Id, SObject> linkedRecordsById = new Map<Id, SObject>();
        Map<String, Set<Id>> recordIdsByObjectApiName = new Map<String, Set<Id>>();

        for (GoogleFileLink__c fileLink : fileLinks) {
            String objectApiName = fileLink.LinkedObjectType__c;
            if (String.isBlank(objectApiName) || !nameFieldByObjectApiName.containsKey(objectApiName)) {
                continue;
            }

            Id linkedRecordId = (Id) fileLink.LinkedObjectId__c;
            if (linkedRecordId == null) continue; 

            if (!recordIdsByObjectApiName.containsKey(objectApiName)) {
                recordIdsByObjectApiName.put(objectApiName, new Set<Id>());
            }

            recordIdsByObjectApiName.get(objectApiName).add(linkedRecordId);
        }

        for (String objectApiName : recordIdsByObjectApiName.keySet()) {
            Set<Id> recordIds = recordIdsByObjectApiName.get(objectApiName);
            if (recordIds == null || recordIds.isEmpty()) continue;
            
            String nameFieldApiName = nameFieldByObjectApiName.get(objectApiName);
            Map<Id, SObject> recordsForObject = GoogleFileLinkedRecordSelector.selectByIds(
                recordIds,
                new List<String>{ nameFieldApiName }
            );

            linkedRecordsById.putAll(recordsForObject);
        }

        return linkedRecordsById;
    }

    private void populateLinkedObjectNames(List<GoogleFileLink__c> fileLinks, Map<Id, SObject> linkedRecordsById, Map<String, String> nameFieldByObjectApiName) {
        Integer maxLinkedObjectNameLength = GoogleFileLink__c.LinkedObjectName__c.getDescribe().getLength();

        for (GoogleFileLink__c fileLink : fileLinks) {
            if (!String.isBlank(fileLink.LinkedObjectName__c)) continue;
            
            String objectApiName = fileLink.LinkedObjectType__c;
            if (String.isBlank(objectApiName)) continue;
            
            String nameFieldApiName = nameFieldByObjectApiName.get(objectApiName);
            if (String.isBlank(nameFieldApiName)) continue;

            Id linkedRecordId = (Id) fileLink.LinkedObjectId__c;
            if (linkedRecordId == null) continue;

            SObject linkedRecord = linkedRecordsById.get(linkedRecordId);
            if (linkedRecord == null) continue;
            
            Object rawNameValue = linkedRecord.get(nameFieldApiName);
            if (rawNameValue == null) continue;
            
            String linkedObjectName = String.valueOf(rawNameValue);
            if (linkedObjectName.length() > maxLinkedObjectNameLength) {
                linkedObjectName = linkedObjectName.substring(0, maxLinkedObjectNameLength);
            }

            fileLink.LinkedObjectName__c = linkedObjectName;
        }
    }
}