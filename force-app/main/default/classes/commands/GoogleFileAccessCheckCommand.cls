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
 * Decides which of the given files the user may see and stamps each one with the level
 * they get. Every path that hands a GoogleFile__c to a user goes through here, because
 * sharing on the object itself is never enough for a file that can be linked to any record.
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

	/**
	 * Adds files to the check. An Id is enough; the resolver loads what it needs itself.
	 *
	 * @param files The GoogleFile__c rows to check; null is ignored.
	 * @return This same instance, so the call chains onto forUser() and strip().
	 */
	public GoogleFileAccessCheckCommand forFiles(List<GoogleFile__c> files) {
		if (files != null) inputFiles.addAll(files);
		return this;
	}

	/**
	 * Adds one file to the check.
	 *
	 * @param fileRecord The GoogleFile__c row to check; null is ignored.
	 * @return This same instance, so the call chains onto forUser() and strip().
	 */
	public GoogleFileAccessCheckCommand forFile(GoogleFile__c fileRecord) {
		if (fileRecord != null) inputFiles.add(fileRecord);
		return this;
	}

	/**
	 * Adds one file to the check by Id, for callers that have not queried the row and do not
	 * need to.
	 *
	 * @param fileRecordId The GoogleFile__c Id to check; null is ignored.
	 * @return This same instance, so the call chains onto forUser() and strip().
	 */
	public GoogleFileAccessCheckCommand forFile(Id fileRecordId) {
		if (fileRecordId != null) {
			inputFiles.add(new GoogleFile__c(Id = fileRecordId));
		}
		return this;
	}

	/**
	 * Sets the user whose access is resolved. Leave it unset to resolve for the running user.
	 *
	 * @param userId The User Id to resolve access for.
	 * @return This same instance, so the call chains onto strip().
	 */
	public GoogleFileAccessCheckCommand forUser(Id userId) {
		this.targetUserId = userId;
		return this;
	}

	/**
	 * Restricts the check to the links of one record, so a file that is linked to several
	 * records only counts the access paths the caller is actually looking at.
	 *
	 * @param links The GoogleFileLink__c rows of the record being viewed.
	 * @return This same instance, so the call chains onto forFile() and forUser().
	 */
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

	/**
	 * Runs the resolution and returns only the files the user may see, each stamped with
	 * UserAccessLevel__c set to "View" or "Edit". Files with no access are dropped, not nulled,
	 * so the result can be shorter than the input, and it keeps the input order.
	 *
	 * @return The accessible files, in the order they were added.
	 */
	public List<GoogleFile__c> strip() {
		return accessResolver.resolveAccessibleFiles(inputFiles, targetUserId, scopedRecordLinks);
	}
}