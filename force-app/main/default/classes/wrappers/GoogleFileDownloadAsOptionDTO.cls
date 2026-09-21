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
 * One format a file can be downloaded in, with the file name already worked out so the caller does not
 * have to swap the extension itself.
 */
public with sharing class GoogleFileDownloadAsOptionDTO {
	@AuraEnabled
	public String label;
	@AuraEnabled
	public String mimeType;
	@AuraEnabled
	public String fileExtension;
	@AuraEnabled
	public String fileName;

	public GoogleFileDownloadAsOptionDTO() {}
	/**
	 * Holds one download format.
	 *
	 * @param label What the menu shows.
	 * @param mimeType What Google exports to.
	 * @param fileExtension The extension the downloaded file gets.
	 */
	public GoogleFileDownloadAsOptionDTO(String label, String mimeType, String fileExtension) {
		this.label = label;
		this.mimeType = mimeType;
		this.fileExtension = fileExtension;
	}
}