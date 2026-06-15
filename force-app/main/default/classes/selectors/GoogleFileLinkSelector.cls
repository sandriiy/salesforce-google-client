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
public inherited sharing class GoogleFileLinkSelector extends GSOQL implements GSOQL.Selector {
	@TestVisible
    private static final String MOCK_ID = 'GoogleFileLinkSelector';

    public static GoogleFileLinkSelector query() {
        return new GoogleFileLinkSelector();
    }

    public GoogleFileLinkSelector() {
        super(GoogleFileLink__c.SObjectType);
        systemMode();
        withoutSharing();
        mockId(MOCK_ID);
    }

	public GoogleFileLinkSelector byParentId(Id recordId) {
        whereAre(Filter.with(GoogleFileLink__c.GoogleFileId__c).equal(recordId));
        return this;
    }

	public GoogleFileLinkSelector byParentIds(List<Id> recordIds) {
        whereAre(Filter.with(GoogleFileLink__c.GoogleFileId__c).isIn(recordIds));
        return this;
    }

	public GoogleFileLinkSelector byParentIds(Set<Id> recordIds) {
        whereAre(Filter.with(GoogleFileLink__c.GoogleFileId__c).isIn(recordIds));
        return this;
    }

	public GoogleFileLinkSelector byLinkedObjectId(Id recordId) {
		whereAre(Filter.with(GoogleFileLink__c.LinkedObjectId__c).equal(String.valueOf(recordId)));
		return this;
	}

    public GoogleFileLinkSelector withPlacementFields() {
        with(
            GoogleFileLink__c.Id,
            GoogleFileLink__c.GoogleFileId__c,
            GoogleFileLink__c.Source__c
        );
		
        return this;
    }

	public GoogleFileLinkSelector withBaseFields() {
        with(
            GoogleFileLink__c.Id,
            GoogleFileLink__c.Name,
            GoogleFileLink__c.GoogleFileId__c,
            GoogleFileLink__c.LinkedObjectId__c
        );
        with(
			GoogleFileLink__c.LinkedObjectName__c,
            GoogleFileLink__c.LinkedObjectType__c,
            GoogleFileLink__c.ShareType__c,
            GoogleFileLink__c.Visibility__c
        );

        return this;
    }

	public GoogleFileLinkSelector orderByCreatedDesc() {
        orderBy(GoogleFileLink__c.CreatedDate).sortDesc();
        return this;
    }

	public GoogleFileLinkSelector limitTo(Integer n) {
        setLimit(n);
        return this;
    }
}