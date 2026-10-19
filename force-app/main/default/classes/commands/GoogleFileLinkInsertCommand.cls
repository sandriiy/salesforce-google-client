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
 * Registers the links that attach an existing file to further records, the way Attach Existing File does,
 * without asking whether the running user may do so: the caller has already decided that, which is what
 * lets a migration link a file on its owner's behalf. Nothing is inserted here. The rows go on the unit of
 * work and the service that owns it commits; a Drive shortcut for each link is the caller's business too,
 * through GoogleFileAttachFinalizeCommand, once the links have Ids.
 */
public without sharing class GoogleFileLinkInsertCommand {
	public class GoogleFileLinkInsertCommandException extends Exception {}

	private static final String MISSING_FILE_MESSAGE = 'The file to attach is required';

	private final IGoogleUnitOfWork uowRef;
	private final GoogleFileLinkDefaultsResolver linkDefaultsResolver;

	private Id localGoogleFileId;
	private List<Id> relatedRecordIds = new List<Id>();
	private String source;
	private String shareType;
	private String visibility;

	/**
	 * @param uowRef The unit of work the links are registered on; the caller commits it.
	 */
	public GoogleFileLinkInsertCommand(IGoogleUnitOfWork uowRef) {
		this.uowRef = uowRef;
		this.linkDefaultsResolver = new GoogleFileLinkDefaultsResolver();
	}

	/**
	 * Sets the file being attached.
	 *
	 * @param value The existing GoogleFile__c.
	 * @return This same instance, so the setters chain onto save().
	 */
	public GoogleFileLinkInsertCommand forFile(Id value) {
		this.localGoogleFileId = value;
		return this;
	}

	/**
	 * Sets the records the file is attached to. A record given twice is linked once; a null is ignored.
	 *
	 * @param values The records, any object.
	 * @return This same instance, so the setters chain onto save().
	 */
	public GoogleFileLinkInsertCommand toRecords(List<Id> values) {
		this.relatedRecordIds = values == null ? new List<Id>() : values;
		return this;
	}

	/**
	 * Sets where the links show up on their records, using a value of the Source picklist.
	 *
	 * @param value The source to stamp on each link.
	 * @return This same instance, so the setters chain onto save().
	 */
	public GoogleFileLinkInsertCommand withSource(String value) {
		this.source = value;
		return this;
	}

	/**
	 * Sets the access every link grants. Leave it unset and the running user's default applies.
	 *
	 * @param value "Viewer", "Collaborator", "InferredFromRecord" or "None".
	 * @return This same instance, so the setters chain onto save().
	 */
	public GoogleFileLinkInsertCommand withShareType(String value) {
		this.shareType = value;
		return this;
	}

	/**
	 * Sets who every link is visible to. Leave it unset and the running user's default applies.
	 *
	 * @param value "InternalUsers" or "AllUsers".
	 * @return This same instance, so the setters chain onto save().
	 */
	public GoogleFileLinkInsertCommand withVisibility(String value) {
		this.visibility = value;
		return this;
	}

	/**
	 * Registers one additional link per distinct record and hands them back before they have Ids. Read the
	 * Ids only after the unit of work has committed.
	 *
	 * @return The registered links, in the order the records were given.
	 */
	public List<GoogleFileLink__c> save() {
		if (localGoogleFileId == null) {
			throw new GoogleFileLinkInsertCommandException(MISSING_FILE_MESSAGE);
		}

		List<GoogleFileLink__c> linkRecords = new List<GoogleFileLink__c>();
		Set<Id> linkedRecordIds = new Set<Id>();

		for (Id relatedRecordId : relatedRecordIds) {
			if (relatedRecordId == null || linkedRecordIds.contains(relatedRecordId)) continue;
			linkedRecordIds.add(relatedRecordId);

			GoogleFileLink__c linkRecord = new GoogleFileLink__c(
				IsAdditionalLink__c = true,
				GoogleFileId__c = localGoogleFileId,
				LinkedObjectId__c = String.valueOf(relatedRecordId),
				LinkedObjectType__c = relatedRecordId.getSObjectType().getDescribe().getName(),
				Source__c = source,
				ShareType__c = shareType,
				Visibility__c = visibility
			);

			linkRecords.add(linkDefaultsResolver.applyDefaultValues(linkRecord));
		}

		if (linkRecords.isEmpty()) return linkRecords;

		Logger.info('File Link Insert, Register Additional Links --> FileId=' + String.valueOf(localGoogleFileId) + ', Records=' + linkRecords.size()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

		uowRef.registerNew(linkRecords);
		return linkRecords;
	}
}
