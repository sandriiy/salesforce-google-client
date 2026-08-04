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
public with sharing class GoogleFileVersionTriggerHandler extends GTriggerHandler {
	private List<GoogleFileVersion__c> newRecords;
	private List<GoogleFileVersion__c> oldRecords;
	private Map<Id, GoogleFileVersion__c> newRecordsMap;
	private Map<Id, GoogleFileVersion__c> oldRecordsMap;

	private GoogleLocalFileVersionLifecycleService lifecycleService;

	public GoogleFileVersionTriggerHandler() {
		this((IGoogleUnitOfWork) null);
	}

	@TestVisible
	private GoogleFileVersionTriggerHandler(IGoogleUnitOfWork injectedUow) {
		super('GoogleFileVersionTriggerHandler');

		this.newRecords = (List<GoogleFileVersion__c>) Trigger.new;
		this.oldRecords = (List<GoogleFileVersion__c>) Trigger.old;
		this.newRecordsMap = (Map<Id, GoogleFileVersion__c>) Trigger.newMap;
		this.oldRecordsMap = (Map<Id, GoogleFileVersion__c>) Trigger.oldMap;

		this.lifecycleService = new GoogleLocalFileVersionLifecycleService(injectedUow);
	}

	public override void afterInsert() {
		this.lifecycleService.processFileInsertFinalizer(this.newRecords);
		this.lifecycleService.markAsLatestVersionIfApplicable(this.newRecords, null);
	}

	public override void afterDelete() {
		this.lifecycleService.markAsLatestVersionIfApplicable(null, this.oldRecords);
		this.lifecycleService.removeGoogleFiles(this.oldRecords);
	}
}