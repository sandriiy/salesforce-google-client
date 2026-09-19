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
 * The Flow face of GoogleLocalFileTransferService for downloads. It brings a Google Client file back into
 * Salesforce as a Salesforce file, which is what an email or a record attachment needs.
 */
public with sharing class GoogleFileDownloadAction {
	@TestVisible
	private static GoogleLocalFileTransferService transferServiceOverride;

	/**
	 * What the flow supplies. Name either a version or a file, and a file takes its current version.
	 */
	public class Input {
		@InvocableVariable(label='Google File Version ID' description='The exact file version to download. Leave blank to download the latest version of the Google File')
		public Id googleFileVersionId;
		@InvocableVariable(label='Google File ID' description='The Google File whose latest version is downloaded when no version is given')
		public Id googleFileId;
		@InvocableVariable(label='Attach To Record ID' description='The Salesforce record the downloaded file is attached to. Leave blank to keep it unattached')
		public Id relatedRecordId;
		@InvocableVariable(label='File Name' description='A different name for the Salesforce file. The extension is kept when none is given')
		public String fileName;
		@InvocableVariable(label='Convert To' description='Optional format for documents and spreadsheets that have a preview copy, as a file extension such as pdf, docx, txt, xlsx or csv')
		public String convertTo;
	}

	/**
	 * The Salesforce file that was created.
	 */
	public class Output {
		@InvocableVariable(label='Content Version ID')
		public Id contentVersionId;
		@InvocableVariable(label='Content Document ID')
		public Id contentDocumentId;
		@InvocableVariable(label='File Name')
		public String fileName;
		@InvocableVariable(label='File Size (bytes)')
		public Long fileSize;
	}

	/**
	 * Downloads every file the flow supplied and saves them in one transaction, one output per input and
	 * in the same order. Asking for more than fits in memory faults the flow rather than failing part
	 * way, so download fewer files at a time.
	 *
	 * @param inputs One request per file.
	 * @return One result per request, in the same order.
	 */
	@InvocableMethod(
		label='Download File from Google Drive'
		description='Downloads a Google Client file from Google Drive and saves it as a Salesforce file, attached to a record or converted to another format when asked'
		category='Google Client'
		iconName='slds:standard:document'
		callout=true
	)
	public static List<Output> downloadFiles(List<Input> inputs) {
		List<Output> outputs = new List<Output>();
		if (inputs == null || inputs.isEmpty()) return outputs;

		List<GoogleFileDownloadRequestDTO> requests = new List<GoogleFileDownloadRequestDTO>();
		for (Input input : inputs) {
			requests.add(toRequest(input));
		}

		for (GoogleFileDownloadResultDTO result : resolveTransferService().downloadToSalesforceFiles(requests)) {
			outputs.add(toOutput(result));
		}

		return outputs;
	}

	private static GoogleLocalFileTransferService resolveTransferService() {
		return transferServiceOverride != null ? transferServiceOverride : new GoogleLocalFileTransferService();
	}

	private static GoogleFileDownloadRequestDTO toRequest(Input input) {
		GoogleFileDownloadRequestDTO request = new GoogleFileDownloadRequestDTO();
		if (input == null) return request;

		request.googleFileVersionId = input.googleFileVersionId;
		request.googleFileId = input.googleFileId;
		request.relatedRecordId = input.relatedRecordId;
		request.fileName = input.fileName;
		request.convertTo = input.convertTo;
		return request;
	}

	private static Output toOutput(GoogleFileDownloadResultDTO result) {
		Output output = new Output();
		output.contentVersionId = result.contentVersionId;
		output.contentDocumentId = result.contentDocumentId;
		output.fileName = result.fileName;
		output.fileSize = result.fileSize;
		return output;
	}
}
