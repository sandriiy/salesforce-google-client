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
public with sharing class GoogleFileLinkTriggerHandler extends GTriggerHandler {
    private List<GoogleFileLink__c> newRecords;
	private List<GoogleFileLink__c> oldRecords;
	private Map<Id, GoogleFileLink__c> newRecordsMap;
	private Map<Id, GoogleFileLink__c> oldRecordsMap;

	public GoogleFileLinkTriggerHandler() {
		super('GoogleFileLinkTriggerHandler');

		this.newRecords = (List<GoogleFileLink__c>) Trigger.new;
		this.oldRecords = (List<GoogleFileLink__c>) Trigger.old;
		this.newRecordsMap = (Map<Id, GoogleFileLink__c>) Trigger.newMap;
		this.oldRecordsMap = (Map<Id, GoogleFileLink__c>) Trigger.oldMap;
	}

	public override void beforeInsert() {
		GoogleLocalFileLinkEnrichmentService enrichmentService = new GoogleLocalFileLinkEnrichmentService();
		enrichmentService.applyLinkedRecordAttributes(this.newRecords);
	}
}