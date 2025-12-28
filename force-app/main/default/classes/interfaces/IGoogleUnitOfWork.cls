public interface IGoogleUnitOfWork {
    void registerNew(SObject record);
    void registerNew(List<SObject> records);
    void registerNew(SObject record, Schema.SObjectField relatedToParentField, SObject relatedToParentRecord);
    void registerRelationship(SObject record, Schema.SObjectField relatedToField, SObject relatedTo);
    void registerDirty(SObject record);
    void registerDirty(List<SObject> records);
    void registerDirty(SObject record, List<Schema.SObjectField> dirtyFields);
    void registerDirty(List<SObject> records, List<Schema.SObjectField> dirtyFields);
    void registerDeleted(SObject record);
    void registerDeleted(List<SObject> records);
    void commitWork(Boolean allOrNone);
}