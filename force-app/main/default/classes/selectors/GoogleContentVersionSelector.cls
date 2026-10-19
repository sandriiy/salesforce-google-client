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
	 * What the migration needs to judge a Salesforce file and keep its owner, without the content.
	 */
	public static final List<SObjectField> MIGRATION_FIELDS = new List<SObjectField>{
		ContentVersion.Id,
		ContentVersion.Title,
		ContentVersion.FileExtension,
		ContentVersion.FileType,
		ContentVersion.ContentSize,
		ContentVersion.ContentLocation,
		ContentVersion.ContentDocumentId,
		ContentVersion.OwnerId,
		ContentVersion.CreatedDate,
		ContentVersion.IsLatest
	};

	private static final String STORED_IN_SALESFORCE_LOCATION = 'S';
	private static final String ENHANCED_NOTE_FILE_TYPE = 'SNOTE';

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

	/**
	 * Selects what the migration judges a Salesforce file by, the owner it keeps and when it was created.
	 *
	 * @return This same instance, so the call chains onto toList().
	 */
	public GoogleContentVersionSelector withMigrationFields() {
		with(MIGRATION_FIELDS);
		return this;
	}

	/**
	 * Adds the owner's name and whether they are still active, which decides whether a copy of the file can
	 * keep that owner.
	 *
	 * @return This same instance, so the call chains onto toList().
	 */
	public GoogleContentVersionSelector withOwnerDetails() {
		with('Owner.Name, Owner.IsActive');
		return this;
	}

	/**
	 * Keeps the Salesforce files whose content lives in Salesforce, leaving out files that only point at an
	 * external system and so have no bytes to copy.
	 *
	 * @return This same instance, so the call chains onto toList().
	 */
	public GoogleContentVersionSelector byStoredInSalesforce() {
		whereAre(Filter.with(ContentVersion.ContentLocation).equal(STORED_IN_SALESFORCE_LOCATION));
		return this;
	}

	/**
	 * Leaves out enhanced notes, which are not files.
	 *
	 * @return This same instance, so the call chains onto toList().
	 */
	public GoogleContentVersionSelector excludingEnhancedNotes() {
		whereAre(Filter.with(ContentVersion.FileType).notEqual(ENHANCED_NOTE_FILE_TYPE));
		return this;
	}

	/**
	 * Keeps the Salesforce files up to a size. The size is bound as an integer, which is the type Salesforce
	 * gives the content size column and the only type a cursor accepts for it.
	 *
	 * @param maxSizeBytes The largest content size to include, in bytes.
	 * @return This same instance, so the call chains onto toList().
	 */
	public GoogleContentVersionSelector byMaxSize(Long maxSizeBytes) {
		whereAre(Filter.with(ContentVersion.ContentSize).lessOrEqual(maxSizeBytes.intValue()));
		return this;
	}

	/**
	 * Narrows by a condition written in SOQL, the way an administrator describes which files to migrate.
	 * It is wrapped in parentheses and joined to the package's own conditions with AND, so it can only
	 * narrow the result and never widen it.
	 *
	 * @param condition A WHERE condition on ContentVersion, without the WHERE keyword. Blank changes nothing.
	 * @return This same instance, so the call chains onto toList().
	 */
	public GoogleContentVersionSelector byCondition(String condition) {
		if (String.isBlank(condition)) return this;

		whereAre('(' + condition.trim() + ')');
		return this;
	}

	/**
	 * Oldest first and then by Id, which keeps the order stable while a migration walks the files.
	 *
	 * @return This same instance, so the call chains onto toList().
	 */
	public GoogleContentVersionSelector orderByCreatedThenId() {
		orderBy(ContentVersion.CreatedDate);
		orderBy(ContentVersion.Id);
		return this;
	}

	/**
	 * Opens an Apex cursor over the query instead of running it, for a walk over more files than one
	 * transaction can hold.
	 *
	 * @return The cursor, positioned before the first row.
	 */
	public Database.Cursor toCursor() {
		String query = toString();
		return Database.getCursorWithBinds(query, binding(), AccessLevel.SYSTEM_MODE);
	}
}
