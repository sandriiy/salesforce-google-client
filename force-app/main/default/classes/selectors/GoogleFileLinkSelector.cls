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
 * Every query against GoogleFileLink__c starts here. The linked record is held as text rather than a
 * lookup, because a file can be attached to any object, so matching on it means passing an Id as a
 * string.
 */
public inherited sharing class GoogleFileLinkSelector extends GSOQL implements GSOQL.Selector {
	@TestVisible
    private static final String MOCK_ID = 'GoogleFileLinkSelector';

    /**
     * Starts a link query.
     *
     * @return A fresh selector to narrow and run.
     */
    public static GoogleFileLinkSelector query() {
        return new GoogleFileLinkSelector();
    }

    public GoogleFileLinkSelector() {
        super(GoogleFileLink__c.SObjectType);
        systemMode();
        withoutSharing();
        mockId(MOCK_ID);
    }

	/**
	 * Keeps the links of one file.
	 *
	 * @param recordId The GoogleFile__c the links belong to.
	 * @return This same instance, so the call chains onto toList().
	 */
	public GoogleFileLinkSelector byParentId(Id recordId) {
        whereAre(Filter.with(GoogleFileLink__c.GoogleFileId__c).equal(recordId));
        return this;
    }

	/**
	 * Keeps the links of several files at once.
	 *
	 * @param recordIds The files the links belong to.
	 * @return This same instance, so the call chains onto toList().
	 */
	public GoogleFileLinkSelector byParentIds(List<Id> recordIds) {
        whereAre(Filter.with(GoogleFileLink__c.GoogleFileId__c).isIn(recordIds));
        return this;
    }

	/**
	 * Keeps the links of several files at once.
	 *
	 * @param recordIds The files the links belong to.
	 * @return This same instance, so the call chains onto toList().
	 */
	public GoogleFileLinkSelector byParentIds(Set<Id> recordIds) {
        whereAre(Filter.with(GoogleFileLink__c.GoogleFileId__c).isIn(recordIds));
        return this;
    }

	/**
	 * Keeps the links pointing at one Salesforce record, whatever object it is.
	 *
	 * @param recordId The record the files are attached to.
	 * @return This same instance, so the call chains onto toList().
	 */
	public GoogleFileLinkSelector byLinkedObjectId(Id recordId) {
		whereAre(Filter.with(GoogleFileLink__c.LinkedObjectId__c).equal(String.valueOf(recordId)));
		return this;
	}

    /**
     * Selects just enough to work out which component a file belongs on.
     *
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileLinkSelector withPlacementFields() {
        with(
            GoogleFileLink__c.Id,
            GoogleFileLink__c.GoogleFileId__c,
            GoogleFileLink__c.Source__c
        );
		
        return this;
    }

	/**
	 * Selects the fields describing what the link grants and which record it points at.
	 *
	 * @return This same instance, so the call chains onto toList().
	 */
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

	/**
	 * Newest link first, which is how the most recent record a file was attached to is found.
	 *
	 * @return This same instance, so the call chains onto toList().
	 */
	public GoogleFileLinkSelector orderByCreatedDesc() {
        orderBy(GoogleFileLink__c.CreatedDate).sortDesc();
        return this;
    }

	/**
	 * Caps how many rows come back.
	 *
	 * @param n The maximum number of links.
	 * @return This same instance, so the call chains onto toList().
	 */
	public GoogleFileLinkSelector limitTo(Integer n) {
        setLimit(n);
        return this;
    }
}