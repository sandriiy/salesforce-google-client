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
 * Uploads one large Salesforce file to Google Drive after the transaction that asked for it has finished.
 * It takes a single file on purpose: the whole content sits in the heap while it is sent, and the version
 * it creates has its own follow up jobs to queue.
 */
public with sharing class GoogleFileBackgroundUploadJob extends GQueueableJob.AllowsCallouts {
	public class GoogleFileBackgroundUploadJobException extends Exception {}

	@TestVisible
	private static Boolean skipExecution = false;

	private final GoogleFileUploadRequestDTO request;

	/**
	 * Builds the job for one file.
	 *
	 * @param request The Salesforce file to upload and where it belongs.
	 */
	public GoogleFileBackgroundUploadJob(GoogleFileUploadRequestDTO request) {
		this.request = request;
	}

	/**
	 * Uploads the file and records it, whatever its size, since the size check already happened before the
	 * job was queued.
	 */
	public override void work() {
		if (skipExecution) return;
		if (this.request == null) return;

		Logger.info('Background Upload Job --> SalesforceFileId=' + String.valueOf(this.request.salesforceFileId) + ', RelatedRecordId=' + String.valueOf(this.request.relatedRecordId)).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

		try {
			GoogleFileUploadResultDTO result = new GoogleLocalFileTransferService().uploadSalesforceFileNow(this.request);
			Logger.info('Background Upload Job --> Uploaded, FileId=' + String.valueOf(result.googleFileId) + ', VersionId=' + String.valueOf(result.googleFileVersionId) + ', GoogleDriveFileId=' + String.valueOf(result.googleDriveFileId)).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
		} catch (Exception ex) {
			Logger.error('Background Upload Job Failed --> SalesforceFileId=' + String.valueOf(this.request.salesforceFileId) + ', Message=' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw new GoogleFileBackgroundUploadJobException('Unable to upload the file to Google Drive. Please try again or contact your system administrator');
		}
	}
}
