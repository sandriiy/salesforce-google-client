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
 * The Flow face of GoogleLocalFileTransferService for uploads. It moves a Salesforce file into Google
 * Drive as an ordinary Google Client file, so previews, summaries and the folder structure all follow.
 */
public with sharing class GoogleFileUploadAction {
	@TestVisible
	private static GoogleLocalFileTransferService transferServiceOverride;

	/**
	 * What the flow supplies. The Salesforce file can be given as a Content Document Id or a Content Version
	 * Id, which is what the standard File Upload screen component provides.
	 */
	public class Input {
		@InvocableVariable(label='Salesforce File ID' description='The Salesforce file to send to Google Drive, as a Content Document ID or a Content Version ID' required=true)
		public Id salesforceFileId;
		@InvocableVariable(label='Record ID' description='The record the file is attached to in Salesforce. Leave blank to keep the file unattached')
		public Id relatedRecordId;
		@InvocableVariable(label='File Name' description='A different name for the file. The original extension is kept')
		public String fileName;
		@InvocableVariable(label='Shown In' description='Where the file appears on the record: "Notes & Attachments" (default), "Uploader" or "File Explorer"')
		public String source;
		@InvocableVariable(label='Remove Salesforce Copy' description='Deletes the Salesforce file once it is in Google Drive. Off by default')
		public Boolean removeSalesforceFile;
	}

	/**
	 * What the flow gets back. A large file comes back with the queued flag set and the Ids empty, because it
	 * finishes uploading after the flow does.
	 */
	public class Output {
		@InvocableVariable(label='Google File ID')
		public Id googleFileId;
		@InvocableVariable(label='Google File Version ID')
		public Id googleFileVersionId;
		@InvocableVariable(label='Google Drive File ID')
		public String googleDriveFileId;
		@InvocableVariable(label='Google Drive Folder ID')
		public String googleDriveFolderId;
		@InvocableVariable(label='File Name')
		public String fileName;
		@InvocableVariable(label='File Size (bytes)')
		public Long fileSize;
		@InvocableVariable(label='Uploads in Background' description='True when the file is large and finishes uploading after the flow, in which case the IDs above are empty')
		public Boolean isQueued;
	}

	/**
	 * Uploads every file the flow supplied, one output per input and in the same order, committing the
	 * records for all of them at once. A file past the configured big file size is queued instead of
	 * being carried through now.
	 *
	 * @param inputs One request per file.
	 * @return One result per request, in the same order.
	 */
	@InvocableMethod(
		label='Upload File to Google Drive'
		description='Sends a Salesforce file to Google Drive and records it as a Google Client file, attached to a record when one is given. Large files finish uploading in the background'
		category='Google Client'
		iconName='slds:standard:file'
		callout=true
	)
	public static List<Output> uploadFiles(List<Input> inputs) {
		List<Output> outputs = new List<Output>();
		if (inputs == null || inputs.isEmpty()) return outputs;

		List<GoogleFileUploadRequestDTO> requests = new List<GoogleFileUploadRequestDTO>();
		for (Input input : inputs) {
			requests.add(toRequest(input));
		}

		for (GoogleFileUploadResultDTO result : resolveTransferService().uploadSalesforceFiles(requests)) {
			outputs.add(toOutput(result));
		}

		return outputs;
	}

	private static GoogleLocalFileTransferService resolveTransferService() {
		return transferServiceOverride != null ? transferServiceOverride : new GoogleLocalFileTransferService();
	}

	private static GoogleFileUploadRequestDTO toRequest(Input input) {
		GoogleFileUploadRequestDTO request = new GoogleFileUploadRequestDTO();
		if (input == null) return request;

		request.salesforceFileId = input.salesforceFileId;
		request.relatedRecordId = input.relatedRecordId;
		request.fileName = input.fileName;
		request.source = input.source;
		request.removeSalesforceFile = input.removeSalesforceFile == true;
		return request;
	}

	private static Output toOutput(GoogleFileUploadResultDTO result) {
		Output output = new Output();
		output.googleFileId = result.googleFileId;
		output.googleFileVersionId = result.googleFileVersionId;
		output.googleDriveFileId = result.googleDriveFileId;
		output.googleDriveFolderId = result.googleDriveFolderId;
		output.fileName = result.fileName;
		output.fileSize = result.fileSize;
		output.isQueued = result.isQueued == true;
		return output;
	}
}
