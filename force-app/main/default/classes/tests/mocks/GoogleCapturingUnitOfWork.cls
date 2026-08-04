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
@IsTest
public class GoogleCapturingUnitOfWork implements IGoogleUnitOfWork {
	public final List<SObject> registeredNew = new List<SObject>();
	public final List<SObject> registeredDirty = new List<SObject>();
	public final List<SObject> registeredDeleted = new List<SObject>();
	public Integer commitCount = 0;

	public void configureDeleteOrder(List<SObjectType> deleteOrder) {}

	public void registerNew(SObject record) {
		if (record != null) registeredNew.add(record);
	}

	public void registerNew(List<SObject> records) {
		if (records == null) return;
		for (SObject record : records) registerNew(record);
	}

	public void registerNew(SObject record, Schema.SObjectField relatedToParentField, SObject relatedToParentRecord) {
		registerNew(record);
	}

	public void registerRelationship(SObject record, Schema.SObjectField relatedToField, SObject relatedTo) {}

	public void registerDirty(SObject record) {
		if (record != null) registeredDirty.add(record);
	}

	public void registerDirty(List<SObject> records) {
		if (records == null) return;
		for (SObject record : records) registerDirty(record);
	}

	public void registerDirty(SObject record, List<Schema.SObjectField> dirtyFields) {
		registerDirty(record);
	}

	public void registerDirty(List<SObject> records, List<Schema.SObjectField> dirtyFields) {
		registerDirty(records);
	}

	public void registerDeleted(SObject record) {
		if (record != null) registeredDeleted.add(record);
	}

	public void registerDeleted(List<SObject> records) {
		if (records == null) return;
		for (SObject record : records) registerDeleted(record);
	}

	public void commitWork(Boolean allOrNone) {
		commitCount++;
	}

	public SObject firstDirty() {
		return registeredDirty.isEmpty() ? null : registeredDirty[0];
	}

	public SObject firstNew() {
		return registeredNew.isEmpty() ? null : registeredNew[0];
	}

	public SObject firstDeleted() {
		return registeredDeleted.isEmpty() ? null : registeredDeleted[0];
	}
}
