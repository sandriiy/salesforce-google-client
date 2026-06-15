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
public without sharing class GoogleFileAccessCheckCommand {
	public class GoogleFileAccessCheckException extends Exception {}

	private List<GoogleFile__c> inputFiles = new List<GoogleFile__c>();
	private List<GoogleFileLink__c> scopedRecordLinks;
	private Id targetUserId;
	private final GoogleFileAccessResolver accessResolver;

	public GoogleFileAccessCheckCommand() {
		this.accessResolver = new GoogleFileAccessResolver();
	}

	public GoogleFileAccessCheckCommand forFiles(List<GoogleFile__c> files) {
		if (files != null) inputFiles.addAll(files);
		return this;
	}

	public GoogleFileAccessCheckCommand forFile(GoogleFile__c fileRecord) {
		if (fileRecord != null) inputFiles.add(fileRecord);
		return this;
	}

	public GoogleFileAccessCheckCommand forFile(Id fileRecordId) {
		if (fileRecordId != null) {
			inputFiles.add(new GoogleFile__c(Id = fileRecordId));
		}
		return this;
	}

	public GoogleFileAccessCheckCommand forUser(Id userId) {
		this.targetUserId = userId;
		return this;
	}

	public GoogleFileAccessCheckCommand forRecordLinks(List<GoogleFileLink__c> links) {
		if (links == null) {
			return this;
		}

		if (scopedRecordLinks == null) {
			scopedRecordLinks = new List<GoogleFileLink__c>();
		}

		scopedRecordLinks.addAll(links);
		return this;
	}

	public List<GoogleFile__c> strip() {
		return accessResolver.resolveAccessibleFiles(inputFiles, targetUserId, scopedRecordLinks);
	}
}