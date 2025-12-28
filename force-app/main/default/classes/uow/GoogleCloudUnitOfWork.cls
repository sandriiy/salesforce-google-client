public class GoogleCloudUnitOfWork implements IGoogleUnitOfWork {
    public class UnitOfWorkException extends Exception {}

    private final List<SObjectType> writeOrder;

    private final List<SObject> pendingInserts = new List<SObject>();
    private final List<SObject> pendingUpdates = new List<SObject>();
    private final List<SObject> pendingDeletes = new List<SObject>();
    private final List<RelationshipBinding> bindings = new List<RelationshipBinding>();

    private List<SObjectType> deleteOrder;
    private final List<SObject> pendingSparseUpdates = new List<SObject>();


    public GoogleCloudUnitOfWork(List<SObjectType> writeOrder) {
        this.writeOrder = (writeOrder == null) ? new List<SObjectType>() : new List<SObjectType>(writeOrder);
    }

    public void configureDeleteOrder(List<SObjectType> deleteOrder) {
        this.deleteOrder = (deleteOrder == null) ? null : new List<SObjectType>(deleteOrder);
    }

    public void registerNew(SObject record) {
        if (record != null) pendingInserts.add(record);
    }

    public void registerNew(List<SObject> records) {
        if (records == null) return;
        for (SObject record : records) if (record != null) pendingInserts.add(record);
    }

    public void registerNew(SObject record, Schema.SObjectField relatedToParentField, SObject relatedToParentRecord) {
        if (record == null) return;
        pendingInserts.add(record);
        if (relatedToParentField != null && relatedToParentRecord != null) {
            bindings.add(new RelationshipBinding(record, relatedToParentField, relatedToParentRecord));
        }
    }

    public void registerRelationship(SObject record, Schema.SObjectField relatedToField, SObject relatedTo) {
        if (record == null || relatedToField == null || relatedTo == null) return;
        bindings.add(new RelationshipBinding(record, relatedToField, relatedTo));
    }

    public void registerDirty(SObject record) {
        if (record == null) return;
        if ((Id)record.get('Id') == null) throw new UnitOfWorkException('registerDirty requires a record with an Id');
        pendingUpdates.add(record);
    }

    public void registerDirty(List<SObject> records) {
        if (records == null) return;
        for (SObject record : records) if (record != null) registerDirty(record);
    }

    public void registerDirty(SObject record, List<Schema.SObjectField> dirtyFields) {
        if (record == null) return;
        if ((Id)record.get('Id') == null) throw new UnitOfWorkException('registerDirty requires a record with an Id');
        if (dirtyFields == null || dirtyFields.isEmpty()) {
            pendingUpdates.add(record);
            return;
        }
        pendingSparseUpdates.add(buildSparseUpdate(record, dirtyFields));
    }

    public void registerDirty(List<SObject> records, List<Schema.SObjectField> dirtyFields) {
        if (records == null) return;
        for (SObject record : records) if (record != null) registerDirty(record, dirtyFields);
    }

    public void registerDeleted(SObject record) {
        if (record == null) return;
        if ((Id)record.get('Id') == null) throw new UnitOfWorkException('registerDeleted requires a record with an Id');
        pendingDeletes.add(record);
    }

    public void registerDeleted(List<SObject> records) {
        if (records == null) return;
        for (SObject record : records) if (record != null) registerDeleted(record);
    }

    public void commitWork(Boolean allOrNone) {
        Savepoint sp = Database.setSavepoint();
        try {
            processWave(pendingInserts, allOrNone, 'insert');
            processWave(pendingUpdates, allOrNone, 'update');
            if (!pendingSparseUpdates.isEmpty()) processWave(pendingSparseUpdates, allOrNone, 'update');
            processDeletes(allOrNone);

            pendingInserts.clear();
            pendingUpdates.clear();
            pendingSparseUpdates.clear();
            pendingDeletes.clear();
            bindings.clear();
        } catch (Exception e) {
            Database.rollback(sp);
            throw (e instanceof UnitOfWorkException)
                ? (UnitOfWorkException)e
                : new UnitOfWorkException(e.getMessage());
        }
    }

    private SObject buildSparseUpdate(SObject sourceWithValues, List<Schema.SObjectField> dirtyFields) {
        SObjectType sType = sourceWithValues.getSObjectType();
        SObject sparse = sType.newSObject();
        sparse.put('Id', sourceWithValues.get('Id'));
        for (Schema.SObjectField fieldRef : dirtyFields) {
            String fieldName = String.valueOf(fieldRef);
            sparse.put(fieldRef, sourceWithValues.get(fieldName));
        }
        return sparse;
    }

    private void processWave(List<SObject> pool, Boolean allOrNone, String dmlVerb) {
        if (pool.isEmpty()) return;

        List<SObject> remaining = new List<SObject>(pool);
        Integer guard = 0;

        while (!remaining.isEmpty()) {
            for (SObject record : remaining) applyResolvedBindings(record);

            List<SObject> readyRecords = new List<SObject>();
            for (SObject record : remaining) if (dependenciesSatisfied(record)) readyRecords.add(record);

            if (readyRecords.isEmpty()) {
                Set<String> typesStuck = new Set<String>();
                for (SObject r : remaining) typesStuck.add(r.getSObjectType().getDescribe().getName());
                throw new UnitOfWorkException('UnitOfWork could not resolve dependencies for ' + dmlVerb +
                                              '. Pending types: ' + String.join(typesStuck, ', '));
            }

            Map<SObjectType, List<SObject>> buckets = new Map<SObjectType, List<SObject>>();
            for (SObject record : readyRecords) {
                SObjectType typeKey = record.getSObjectType();
                if (!buckets.containsKey(typeKey)) buckets.put(typeKey, new List<SObject>());
                buckets.get(typeKey).add(record);
            }

            Set<SObjectType> processedTypes = new Set<SObjectType>();

            for (SObjectType preferredType : writeOrder) {
                if (buckets.containsKey(preferredType)) {
                    doDmlAndCheck(buckets.get(preferredType), allOrNone, dmlVerb);
                    processedTypes.add(preferredType);
                }
            }
            for (SObjectType otherType : buckets.keySet()) {
                if (!processedTypes.contains(otherType)) {
                    doDmlAndCheck(buckets.get(otherType), allOrNone, dmlVerb);
                }
            }

            List<SObject> nextRemaining = new List<SObject>();
            for (SObject r : remaining) if (!readyRecords.contains(r)) nextRemaining.add(r);
            remaining = nextRemaining;

            guard++;
            if (guard > pool.size() + 5) {
                throw new UnitOfWorkException('UnitOfWork exceeded safety iterations for ' + dmlVerb + '.');
            }
        }
    }

    private void doDmlAndCheck(List<SObject> batch, Boolean allOrNone, String dmlVerb) {
        if (batch.isEmpty()) return;

        if (allOrNone) {
            if (dmlVerb == 'insert') { Database.insert(batch, true);  return; }
            if (dmlVerb == 'update') { Database.update(batch, true);  return; }
            throw new UnitOfWorkException('Unsupported DML verb: ' + dmlVerb);
        } else {
            Database.SaveResult[] results;
            if (dmlVerb == 'insert')      results = Database.insert(batch, false);
            else if (dmlVerb == 'update') results = Database.update(batch, false);
            else throw new UnitOfWorkException('Unsupported DML verb: ' + dmlVerb);

            List<String> errors = new List<String>();
            for (Database.SaveResult sr : results) {
                if (!sr.isSuccess()) for (Database.Error err : sr.getErrors()) {
                    errors.add(err.getStatusCode() + ': ' + err.getMessage());
                }
            }
            if (!errors.isEmpty()) throw new UnitOfWorkException(String.join(errors, ' | '));
        }
    }

    private void processDeletes(Boolean allOrNone) {
        if (pendingDeletes.isEmpty()) return;

        Map<SObjectType, List<SObject>> buckets = new Map<SObjectType, List<SObject>>();
        for (SObject record : pendingDeletes) {
            SObjectType typeKey = record.getSObjectType();
            if (!buckets.containsKey(typeKey)) buckets.put(typeKey, new List<SObject>());
            buckets.get(typeKey).add(record);
        }

        List<SObjectType> orderToUse = new List<SObjectType>();
        if (deleteOrder != null && !deleteOrder.isEmpty()) {
            orderToUse.addAll(deleteOrder);
        } else if (!writeOrder.isEmpty()) {
            orderToUse.addAll(reverse(writeOrder));
        }

        Set<SObjectType> processedTypes = new Set<SObjectType>();

        for (SObjectType typeKey : orderToUse) {
            if (buckets.containsKey(typeKey)) {
                doDeleteAndCheck(buckets.get(typeKey), allOrNone);
                processedTypes.add(typeKey);
            }
        }
        for (SObjectType typeKey : buckets.keySet()) {
            if (!processedTypes.contains(typeKey)) {
                doDeleteAndCheck(buckets.get(typeKey), allOrNone);
            }
        }
    }

    private void doDeleteAndCheck(List<SObject> batch, Boolean allOrNone) {
        if (batch.isEmpty()) return;

        if (allOrNone) {
            Database.delete(batch, true);
        } else {
            Database.DeleteResult[] results = Database.delete(batch, false);
            List<String> errors = new List<String>();
            for (Database.DeleteResult dr : results) {
                if (!dr.isSuccess()) for (Database.Error err : dr.getErrors()) {
                    errors.add(err.getStatusCode() + ': ' + err.getMessage());
                }
            }
            if (!errors.isEmpty()) throw new UnitOfWorkException(String.join(errors, ' | '));
        }
    }

    private List<SObjectType> reverse(List<SObjectType> sourceList) {
        List<SObjectType> reversed = new List<SObjectType>();
        if (sourceList == null) return reversed;
        for (Integer i = sourceList.size() - 1; i >= 0; i--) reversed.add(sourceList[i]);
        return reversed;
    }

    private Boolean dependenciesSatisfied(SObject childRecord) {
        for (RelationshipBinding binding : bindings) {
            if (binding.childRecord == childRecord && (Id)binding.parentRecord.get('Id') == null) return false;
        }
        return true;
    }

    private void applyResolvedBindings(SObject childRecord) {
        for (RelationshipBinding binding : bindings) {
            if (binding.childRecord == childRecord) {
                Id parentId = (Id)binding.parentRecord.get('Id');
                if (parentId != null) childRecord.put(binding.lookupField, parentId);
            }
        }
    }

    private class RelationshipBinding {
        SObject childRecord;
        Schema.SObjectField lookupField;
        SObject parentRecord;
        RelationshipBinding(SObject childRecord, Schema.SObjectField lookupField, SObject parentRecord) {
            this.childRecord  = childRecord;
            this.lookupField  = lookupField;
            this.parentRecord = parentRecord;
        }
    }
}