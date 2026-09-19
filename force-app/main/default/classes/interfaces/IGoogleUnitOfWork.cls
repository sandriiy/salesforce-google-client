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
/**
 * The transaction every write in this package goes through. Work is registered here and nothing happens
 * until commitWork(), so a service can gather changes from several commands and save them once. Implement
 * it to capture what a command would have written, which is how the tests assert on records that are
 * never inserted.
 */
public interface IGoogleUnitOfWork {
    /**
     * Sets the order deletes run in. Without this they run in the reverse of the insert order.
     *
     * @param deleteOrder The object types in the order they should be deleted.
     */
    void configureDeleteOrder(List<SObjectType> deleteOrder);
    /**
     * Queues one record for insert.
     *
     * @param record The record to insert.
     */
    void registerNew(SObject record);
    /**
     * Queues several records for insert.
     *
     * @param records The records to insert.
     */
    void registerNew(List<SObject> records);
    /**
     * Queues a record whose parent has no Id yet, and fills the lookup in once the parent is inserted. This
     * is how a file, its version and its link are saved in one go.
     *
     * @param record The child record to insert.
     * @param relatedToParentField The lookup on the child pointing at the parent.
     * @param relatedToParentRecord The parent, which is queued for insert too.
     */
    void registerNew(SObject record, Schema.SObjectField relatedToParentField, SObject relatedToParentRecord);
    /**
     * Points one queued record at another without queueing anything new.
     *
     * @param record The record whose lookup is being filled.
     * @param relatedToField The lookup field.
     * @param relatedTo The record it should point at.
     */
    void registerRelationship(SObject record, Schema.SObjectField relatedToField, SObject relatedTo);
    /**
     * Queues one record for update. It needs an Id.
     *
     * @param record The record to update.
     */
    void registerDirty(SObject record);
    /**
     * Queues several records for update.
     *
     * @param records The records to update.
     */
    void registerDirty(List<SObject> records);
    /**
     * Queues an update of only the fields you name, which keeps a partly loaded record from overwriting the
     * fields it never read.
     *
     * @param record The record holding the new values.
     * @param dirtyFields The fields to write.
     */
    void registerDirty(SObject record, List<Schema.SObjectField> dirtyFields);
    /**
     * Queues an update of only the fields you name, across several records.
     *
     * @param records The records holding the new values.
     * @param dirtyFields The fields to write.
     */
    void registerDirty(List<SObject> records, List<Schema.SObjectField> dirtyFields);
    /**
     * Queues one record for delete. It needs an Id.
     *
     * @param record The record to delete.
     */
    void registerDeleted(SObject record);
    /**
     * Queues several records for delete.
     *
     * @param records The records to delete.
     */
    void registerDeleted(List<SObject> records);
    /**
     * Runs everything that was registered, in the configured order, wrapped in a savepoint so a failure
     * leaves nothing behind.
     *
     * @param allOrNone True to fail the whole transaction on the first error.
     */
    void commitWork(Boolean allOrNone);
}