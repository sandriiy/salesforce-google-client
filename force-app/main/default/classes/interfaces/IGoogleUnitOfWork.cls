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
public interface IGoogleUnitOfWork {
    void configureDeleteOrder(List<SObjectType> deleteOrder);
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