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
 * Keeps the searchable copy of the label names on the version in step with the label records themselves,
 * on every insert, update, delete and undelete. On an update only the rows whose name or parent really
 * changed are resynced.
 */
public with sharing class GoogleFileVersionLabelTriggerHandler extends GTriggerHandler {
	private static final Set<String> LABEL_NAME_SOURCE_FIELDS = new Set<String>{ 'Name', 'GoogleFileVersionId__c' };

	private List<GoogleFileVersionLabel__c> newRecords;
	private List<GoogleFileVersionLabel__c> oldRecords;
	private Map<Id, GoogleFileVersionLabel__c> oldRecordsMap;

	private GoogleLocalFileVersionLabelService labelService;

	public GoogleFileVersionLabelTriggerHandler() {
		this((IGoogleUnitOfWork) null);
	}

	@TestVisible
	private GoogleFileVersionLabelTriggerHandler(IGoogleUnitOfWork injectedUow) {
		super('GoogleFileVersionLabelTriggerHandler');

		this.newRecords = (List<GoogleFileVersionLabel__c>) Trigger.new;
		this.oldRecords = (List<GoogleFileVersionLabel__c>) Trigger.old;
		this.oldRecordsMap = (Map<Id, GoogleFileVersionLabel__c>) Trigger.oldMap;

		this.labelService = new GoogleLocalFileVersionLabelService(injectedUow);
	}

	public override void afterInsert() {
		this.labelService.syncLabelNames(this.newRecords, null);
	}

	public override void afterUpdate() {
		List<GoogleFileVersionLabel__c> renamedOrMovedLabels = new List<GoogleFileVersionLabel__c>();
		List<GoogleFileVersionLabel__c> previousLabels = new List<GoogleFileVersionLabel__c>();
		for (SObject changedRecord : GTriggerHandler.getChangedRecords(this.newRecords, this.oldRecordsMap, LABEL_NAME_SOURCE_FIELDS)) {
			renamedOrMovedLabels.add((GoogleFileVersionLabel__c) changedRecord);
			previousLabels.add(this.oldRecordsMap.get(changedRecord.Id));
		}

		if (renamedOrMovedLabels.isEmpty()) return;
		this.labelService.syncLabelNames(renamedOrMovedLabels, previousLabels);
	}

	public override void afterDelete() {
		this.labelService.syncLabelNames(null, this.oldRecords);
	}

	public override void afterUndelete() {
		this.labelService.syncLabelNames(this.newRecords, null);
	}
}
