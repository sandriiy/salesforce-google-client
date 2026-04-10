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