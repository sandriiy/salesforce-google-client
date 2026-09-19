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
 * Every query against GoogleFileVersion__c starts here. The Drive Ids are kept out of the base fields on
 * purpose, so a caller has to ask for them with withAdvancedFields() rather than handing them to a
 * screen by accident.
 */
public inherited sharing class GoogleFileVersionSelector extends GSOQL implements GSOQL.Selector {
    @TestVisible
    private static final String MOCK_ID = 'GoogleFileVersionSelector';

    /**
     * The fields every version query brings back. A mocked row missing one of these fails the test it is
     * mocked into, so add a field here and the inline queries in the tests have to follow.
     */
    public static final List<SObjectField> BASE_FIELDS = new List<SObjectField>{
        GoogleFileVersion__c.Id,
        GoogleFileVersion__c.Name,
        GoogleFileVersion__c.GoogleFileId__c,
		GoogleFileVersion__c.IsLatestFile__c,
        GoogleFileVersion__c.IsPreviewableFile__c,
        GoogleFileVersion__c.Size__c,
        GoogleFileVersion__c.GoogleDocsFileSize__c,
        GoogleFileVersion__c.Type__c,
		GoogleFileVersion__c.Summary__c,
		GoogleFileVersion__c.AiLabels__c,
        GoogleFileVersion__c.CreatedDate,
		GoogleFileVersion__c.LastModifiedDate
    };

	/**
	 * The Google Drive coordinates. They are never shown to a user and never offered as a File Explorer
	 * column.
	 */
	public static final List<SObjectField> CONFIDENTIAL_FIELDS = new List<SObjectField>{
        GoogleFileVersion__c.GoogleDriveFileId__c,
        GoogleFileVersion__c.GoogleDocsFileId__c,
		GoogleFileVersion__c.GoogleDriveFolderId__c
	};

    /**
     * The public link state, including the permission Id needed to revoke it.
     */
    public static final List<SObjectField> SHARING_FIELDS = new List<SObjectField>{
        GoogleFileVersion__c.PublicLink__c,
        GoogleFileVersion__c.PublicLinkExpirationDate__c,
        GoogleFileVersion__c.PublicLinkPermissionId__c
    };

    /**
     * Starts a version query.
     *
     * @return A fresh selector to narrow and run.
     */
    public static GoogleFileVersionSelector query() {
        return new GoogleFileVersionSelector();
    }

    public GoogleFileVersionSelector() {
        super(GoogleFileVersion__c.SObjectType);
        systemMode();
        withoutSharing();
        mockId(MOCK_ID);
    }

    /**
     * Keeps the versions of one file.
     *
     * @param recordId The GoogleFile__c the versions belong to.
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileVersionSelector byParentId(Id recordId) {
        whereAre(Filter.with(GoogleFileVersion__c.GoogleFileId__c).equal(recordId));
        return this;
    }

    /**
     * Keeps the versions of several files at once.
     *
     * @param recordIds The files the versions belong to.
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileVersionSelector byParentIds(Set<Id> recordIds) {
        whereAre(Filter.with(GoogleFileVersion__c.GoogleFileId__c).isIn(recordIds));
        return this;
    }

	/**
	 * Keeps only the current version of each file.
	 *
	 * @return This same instance, so the call chains onto toList().
	 */
	public GoogleFileVersionSelector byLatest() {
		whereAre(Filter.with(GoogleFileVersion__c.IsLatestFile__c).equal(true));
		return this;
	}

    /**
     * Newest version first.
     *
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileVersionSelector orderByCreatedDesc() {
        orderBy(GoogleFileVersion__c.CreatedDate).sortDesc();
        return this;
    }

	/**
	 * Caps how many rows come back.
	 *
	 * @param n The maximum number of versions.
	 * @return This same instance, so the call chains onto toList().
	 */
	public GoogleFileVersionSelector limitTo(Integer n) {
		setLimit(n);
		return this;
	}

    /**
     * Selects the fields a list or a card needs.
     *
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileVersionSelector withBaseFields() {
        with(BASE_FIELDS);
        return this;
    }

	/**
	 * Selects everything, the Drive coordinates included, which is what any call reaching Google Drive
	 * needs.
	 *
	 * @return This same instance, so the call chains onto toList().
	 */
	public GoogleFileVersionSelector withAdvancedFields() {
        with(BASE_FIELDS);
		with(SHARING_FIELDS);
		with(CONFIDENTIAL_FIELDS);
        return this;
    }

    /**
     * Selects the base fields plus the public link state.
     *
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileVersionSelector withSharingFields() {
		with(BASE_FIELDS);
        with(SHARING_FIELDS);
        return this;
    }
}