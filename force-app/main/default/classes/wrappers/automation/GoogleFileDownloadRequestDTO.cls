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
 * What GoogleLocalFileTransferService needs to bring a Google Client file back into Salesforce. Name
 * either a version or a file, and a file takes its current version.
 */
public class GoogleFileDownloadRequestDTO {
	public Id googleFileVersionId;
	public Id googleFileId;
	/**
	 * The record the new Salesforce file is attached to. Leave it out to keep it unattached.
	 */
	public Id relatedRecordId;
	/**
	 * A different name for the Salesforce file. Without an extension the original one is kept.
	 */
	public String fileName;
	/**
	 * The format to convert to, as a file extension such as "pdf" or "docx". Blank downloads the file as it
	 * was uploaded.
	 */
	public String convertTo;
}
