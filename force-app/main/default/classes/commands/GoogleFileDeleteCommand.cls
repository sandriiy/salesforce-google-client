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
 * Deletes a GoogleFile__c and, when asked, the Drive files behind every one of its versions.
 * Together with GoogleFileSharingCommand this is the deliberate exception to the rule that
 * commands never commit: save() commits the unit of work itself, because the Drive deletion is
 * a queueable that may only be enqueued once the Salesforce delete has gone through. Nothing
 * in here checks who may delete the file; the caller settles that first.
 */
public without sharing class GoogleFileDeleteCommand {
	private final IGoogleUnitOfWork uowRef;

	private Id recordId;
	private Boolean hasCloudFilesDeletion;

	/**
	 * @param uowRef The unit of work the delete is registered on and committed through; do not
	 * queue other work on it expecting to commit later.
	 */
	public GoogleFileDeleteCommand(IGoogleUnitOfWork uowRef) {
		this.uowRef = uowRef;
	}

	/**
	 * Sets the GoogleFile__c to delete.
	 *
	 * @param value The file record Id.
	 * @return This same instance, so the call chains onto setCloudDeletion() and save().
	 */
	public GoogleFileDeleteCommand setRecordId(Id value) {
		this.recordId = value;
		return this;
	}

	/**
	 * Chooses whether the Drive files of every version are deleted too, through
	 * GoogleFileCloudDeleteJob after the commit. Leave it off to keep the content in Drive and
	 * drop only the Salesforce records.
	 *
	 * @param isCloudFilesDeletion True to delete the Drive content as well.
	 * @return This same instance, so the call chains onto save().
	 */
	public GoogleFileDeleteCommand setCloudDeletion(Boolean isCloudFilesDeletion) {
		this.hasCloudFilesDeletion = isCloudFilesDeletion;
		return this;
	}

	/**
	 * Deletes the file record, commits, and then enqueues the Drive deletion when it was asked
	 * for. Versions, links, labels and shares go with the file through the master-detail
	 * cascade, which is why the versions are read before the delete: the job needs their Drive
	 * Ids after the rows are gone.
	 *
	 * @return Always true; a failure surfaces as an exception, not as false.
	 */
	public Boolean save() {
		GoogleFile__c googleFile = buildFileStub(recordId);
		List<GoogleFileVersion__c> localFileVersions = (List<GoogleFileVersion__c>) GoogleFileVersionSelector.query()
			.withAdvancedFields()
			.byParentId(recordId)
			.toList();

		Logger.info('File Delete: ' + recordId).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

		uowRef.registerDeleted(googleFile);
		uowRef.commitWork(true);

		enqueueCloudDeletionIfNeeded(localFileVersions);
		return true;
	}

	private GoogleFile__c buildFileStub(Id recordId) {
		return new GoogleFile__c(Id = recordId);
	}

	private void enqueueCloudDeletionIfNeeded(List<GoogleFileVersion__c> localFileVersions) {
		if (hasCloudFilesDeletion == true) {
			System.enqueueJob(new GoogleFileCloudDeleteJob(localFileVersions));
		}
	}
}