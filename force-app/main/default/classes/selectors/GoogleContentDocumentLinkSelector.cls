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
 * Reads what a Salesforce file is attached to. Salesforce only answers this object when it is filtered by
 * the file or by the record, so every query here starts from a set of files.
 */
public inherited sharing class GoogleContentDocumentLinkSelector extends GSOQL implements GSOQL.Selector {
	@TestVisible
	private static final String MOCK_ID = 'GoogleContentDocumentLinkSelector';

	/**
	 * The record a file is attached to and the access that attachment grants.
	 */
	public static final List<SObjectField> BASE_FIELDS = new List<SObjectField>{
		ContentDocumentLink.Id,
		ContentDocumentLink.ContentDocumentId,
		ContentDocumentLink.LinkedEntityId,
		ContentDocumentLink.ShareType,
		ContentDocumentLink.Visibility,
		ContentDocumentLink.SystemModstamp
	};

	/**
	 * Starts a query over the attachments of Salesforce files.
	 *
	 * @return A fresh selector to narrow and run.
	 */
	public static GoogleContentDocumentLinkSelector query() {
		return new GoogleContentDocumentLinkSelector();
	}

	public GoogleContentDocumentLinkSelector() {
		super(ContentDocumentLink.SObjectType);
		systemMode();
		withoutSharing();
		mockId(MOCK_ID);
	}

	/**
	 * Keeps the attachments of those Salesforce files.
	 *
	 * @param contentDocumentIds The Salesforce files whose attachments are wanted.
	 * @return This same instance, so the call chains onto toList().
	 */
	public GoogleContentDocumentLinkSelector byContentDocumentIds(Set<Id> contentDocumentIds) {
		whereAre(Filter.with(ContentDocumentLink.ContentDocumentId).isIn(contentDocumentIds));
		return this;
	}

	/**
	 * Selects the record, the access and when the attachment was last changed.
	 *
	 * @return This same instance, so the call chains onto toList().
	 */
	public GoogleContentDocumentLinkSelector withBaseFields() {
		with(BASE_FIELDS);
		return this;
	}

	/**
	 * Oldest attachment first, which is how the record a file was first attached to is told apart from the
	 * ones it was shared to later.
	 *
	 * @return This same instance, so the call chains onto toList().
	 */
	public GoogleContentDocumentLinkSelector orderByOldestFirst() {
		orderBy(ContentDocumentLink.SystemModstamp);
		orderBy(ContentDocumentLink.Id);
		return this;
	}
}
