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
 * What GoogleLocalFolderService.createFolder() needs. Give it a name to create a folder, or only a record
 * to get that record's own Google Drive folder back.
 */
public class GoogleFolderCreateRequestDTO {
	/**
	 * The folder to create. Leave it blank, with a record, to get the record folder instead.
	 */
	public String folderName;
	/**
	 * Where the folder goes. Blank falls back to the record folder, then to the default upload folder.
	 */
	public String parentFolderId;
	/**
	 * The Salesforce record the folder belongs to or sits under.
	 */
	public Id relatedRecordId;
	/**
	 * Whether a folder with the same name in the same parent is adopted instead of a second one being made.
	 */
	public Boolean reuseExistingFolder = true;
}
