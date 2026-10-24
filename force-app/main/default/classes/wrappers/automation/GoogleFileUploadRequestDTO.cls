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
 * What GoogleLocalFileTransferService needs to move a Salesforce file into Google Drive. The result is an
 * ordinary Google Client file, so previews, summaries and the folder structure all follow as usual.
 */
public class GoogleFileUploadRequestDTO {
	/**
	 * The Salesforce file to send, given either as a Content Document Id or a Content Version Id.
	 */
	public Id salesforceFileId;
	/**
	 * The record to attach it to. Leave it out and the file belongs to nobody in particular.
	 */
	public Id relatedRecordId;
	/**
	 * A different name for the file. The original extension is kept whatever you pass.
	 */
	public String fileName;
	/**
	 * Where the file shows up on the record, using a value of the Source picklist. Blank means Notes and
	 * Attachments.
	 */
	public String source;
	/**
	 * Whether the Salesforce copy is deleted once the file is safely in Drive, which is how a flow frees
	 * Salesforce storage.
	 */
	public Boolean removeSalesforceFile = false;
	/**
	 * Where the link to the record shows up, using a value of the Source picklist, when that differs from
	 * source. Blank means the same place as source.
	 */
	public String linkSource;
	/**
	 * Who owns the resulting file. Blank means the running user, as for any upload.
	 */
	public Id ownerId;
	/**
	 * The access the record links grant, "Viewer", "Collaborator", "InferredFromRecord" or "None". Blank
	 * means the default for the running user.
	 */
	public String shareType;
	/**
	 * Who the record links are visible to, "InternalUsers" or "AllUsers". Blank means the default for the
	 * running user.
	 */
	public String visibility;
	/**
	 * Further records the file is attached to on top of relatedRecordId, with the same access as the first
	 * link. They are linked once the file exists, the way Attach Existing File does it, shortcuts included.
	 */
	public List<Id> additionalRecordIds;
	/**
	 * True to leave out the AI summary and label for the files committed with this one, keeping the preview
	 * copy and the folder placement. Off by default, which is what every upload does.
	 */
	public Boolean skipIntelligence = false;
}
