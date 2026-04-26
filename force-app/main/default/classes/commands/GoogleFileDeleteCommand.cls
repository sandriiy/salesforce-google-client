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
public without sharing class GoogleFileDeleteCommand {
	private final IGoogleUnitOfWork uowRef;

	private Id recordId;
	private Boolean hasCloudFilesDeletion;

	public GoogleFileDeleteCommand(IGoogleUnitOfWork uowRef) {
		this.uowRef = uowRef;
	}

	public GoogleFileDeleteCommand setRecordId(Id value) {
		this.recordId = value;
		return this;
	}

	public GoogleFileDeleteCommand setCloudDeletion(Boolean isCloudFilesDeletion) {
		this.hasCloudFilesDeletion = isCloudFilesDeletion;
		return this;
	}

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