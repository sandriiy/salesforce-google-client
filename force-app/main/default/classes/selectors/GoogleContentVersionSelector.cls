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
 * Reads the Salesforce files that are on their way to Google Drive. The content itself is only selected
 * when you ask for it with withContent(), because a file body counts against the heap and a list of
 * names does not need it.
 */
public inherited sharing class GoogleContentVersionSelector extends GSOQL implements GSOQL.Selector {
	@TestVisible
	private static final String MOCK_ID = 'GoogleContentVersionSelector';

	/**
	 * What is needed to describe a Salesforce file without loading its content.
	 */
	public static final List<SObjectField> BASE_FIELDS = new List<SObjectField>{
		ContentVersion.Id,
		ContentVersion.Title,
		ContentVersion.PathOnClient,
		ContentVersion.FileExtension,
		ContentVersion.ContentSize,
		ContentVersion.ContentDocumentId,
		ContentVersion.IsLatest
	};

	/**
	 * Starts a Salesforce file query.
	 *
	 * @return A fresh selector to narrow and run.
	 */
	public static GoogleContentVersionSelector query() {
		return new GoogleContentVersionSelector();
	}

	public GoogleContentVersionSelector() {
		super(ContentVersion.SObjectType);
		systemMode();
		withoutSharing();
		mockId(MOCK_ID);
	}

	/**
	 * Keeps the versions of those Salesforce files, which is how a Content Document Id is resolved to
	 * something with content on it.
	 *
	 * @param contentDocumentIds The Salesforce files to read.
	 * @return This same instance, so the call chains onto toList().
	 */
	public GoogleContentVersionSelector byContentDocumentIds(Set<Id> contentDocumentIds) {
		whereAre(Filter.with(ContentVersion.ContentDocumentId).isIn(contentDocumentIds));
		return this;
	}

	/**
	 * Keeps only the current version of each Salesforce file.
	 *
	 * @return This same instance, so the call chains onto toList().
	 */
	public GoogleContentVersionSelector byLatest() {
		whereAre(Filter.with(ContentVersion.IsLatest).equal(true));
		return this;
	}

	/**
	 * Selects the name, extension and size without the content.
	 *
	 * @return This same instance, so the call chains onto toList().
	 */
	public GoogleContentVersionSelector withBaseFields() {
		with(BASE_FIELDS);
		return this;
	}

	/**
	 * Adds the file content. Ask for it only for the files you are about to upload, since each one is held
	 * in the heap.
	 *
	 * @return This same instance, so the call chains onto toList().
	 */
	public GoogleContentVersionSelector withContent() {
		with(ContentVersion.VersionData);
		return this;
	}
}
