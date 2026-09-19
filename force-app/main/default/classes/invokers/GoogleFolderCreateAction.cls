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
 * The Flow face of GoogleLocalFolderService. It creates a folder in Google Drive, or hands back the one a
 * record already owns, so an administrator can put folders in place without code.
 */
public with sharing class GoogleFolderCreateAction {
	/**
	 * What the flow supplies. Give it a name to create a folder, or only a record to get that record's own
	 * folder back.
	 */
	public class Input {
		@InvocableVariable(label='Folder Name' description='Name of the folder to create. Leave blank to get the record’s own Google Drive folder instead, which needs a Record ID and a folder structure with a record folder')
		public String folderName;
		@InvocableVariable(label='Parent Folder ID' description='Google Drive folder the new folder is created in. Leave blank to use the record’s folder when a Record ID is given, or the default upload folder otherwise')
		public String parentFolderId;
		@InvocableVariable(label='Record ID' description='Salesforce record whose Google Drive folder is used as the parent, or returned as is when Folder Name is blank')
		public Id relatedRecordId;
		@InvocableVariable(label='Reuse Existing Folder' description='When a folder with the same name already exists in the parent, return it instead of creating another one. On by default')
		public Boolean reuseExistingFolder;
	}

	/**
	 * What the flow gets back, including a link that opens the folder in Google Drive.
	 */
	public class Output {
		@InvocableVariable(label='Folder ID')
		public String folderId;
		@InvocableVariable(label='Folder Name')
		public String folderName;
		@InvocableVariable(label='Parent Folder ID')
		public String parentFolderId;
		@InvocableVariable(label='Folder URL')
		public String folderUrl;
		@InvocableVariable(label='Was Created' description='False when an existing folder was returned instead of a new one')
		public Boolean wasCreated;
	}

	/**
	 * Creates or finds a folder for every row the flow supplied, one output per input and in the same
	 * order. Anything that goes wrong faults the flow with a message worth showing, so connect a fault
	 * path.
	 *
	 * @param inputs One request per folder.
	 * @return One result per request, in the same order.
	 */
	@InvocableMethod(
		label='Create Folder in Google Drive'
		description='Creates a folder in Google Drive, or returns the one that already exists with that name, and gives back its ID and link'
		category='Google Client'
		iconName='slds:standard:folder'
		callout=true
	)
	public static List<Output> createFolders(List<Input> inputs) {
		List<Output> outputs = new List<Output>();
		if (inputs == null || inputs.isEmpty()) return outputs;

		GoogleLocalFolderService folderService = new GoogleLocalFolderService();
		for (Input input : inputs) {
			outputs.add(toOutput(folderService.createFolder(toRequest(input))));
		}

		return outputs;
	}

	private static GoogleFolderCreateRequestDTO toRequest(Input input) {
		GoogleFolderCreateRequestDTO request = new GoogleFolderCreateRequestDTO();
		if (input == null) return request;

		request.folderName = input.folderName;
		request.parentFolderId = input.parentFolderId;
		request.relatedRecordId = input.relatedRecordId;
		request.reuseExistingFolder = input.reuseExistingFolder != false;
		return request;
	}

	private static Output toOutput(GoogleFolderCreateResultDTO result) {
		Output output = new Output();
		output.folderId = result.folderId;
		output.folderName = result.folderName;
		output.parentFolderId = result.parentFolderId;
		output.folderUrl = result.folderUrl;
		output.wasCreated = result.wasCreated;
		return output;
	}
}
