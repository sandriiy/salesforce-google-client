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
 * Queues the Drive shortcut after a file has been attached to another record. It only does so when the
 * link was really created and the configured structure keeps record folders, so attaching a file twice
 * does not leave two shortcuts behind.
 */
public with sharing class GoogleFileAttachFinalizeCommand {
	private final GoogleMetadataConfigService googleConfig;
	private Id initiatorUserId;
	private Id localGoogleFileId;
	private Id linkLocalGoogleFileId;
	private Id relatedRecordId;
	private Boolean wasCreated;

	public GoogleFileAttachFinalizeCommand() {
		this(new GoogleMetadataConfigService());
	}

	@TestVisible
	private GoogleFileAttachFinalizeCommand(GoogleMetadataConfigService googleConfig) {
		this.googleConfig = googleConfig == null ? new GoogleMetadataConfigService() : googleConfig;
	}

	/**
	 * Sets the user who attached the file, since the job runs later and cannot ask.
	 *
	 * @param initiatorUserId The user who attached the file.
	 * @return This same instance, so the call chains onto execute().
	 */
	public GoogleFileAttachFinalizeCommand initiatedBy(Id initiatorUserId) {
		this.initiatorUserId = initiatorUserId;
		return this;
	}

	/**
	 * Sets the file that was attached.
	 *
	 * @param localGoogleFileId The GoogleFile__c being attached.
	 * @return This same instance, so the call chains onto execute().
	 */
	public GoogleFileAttachFinalizeCommand forFile(Id localGoogleFileId) {
		this.localGoogleFileId = localGoogleFileId;
		return this;
	}

	/**
	 * Sets the link that was created, which is where the destination record comes from.
	 *
	 * @param linkLocalGoogleFileId The new GoogleFileLink__c.
	 * @return This same instance, so the call chains onto execute().
	 */
	public GoogleFileAttachFinalizeCommand forLink(Id linkLocalGoogleFileId) {
		this.linkLocalGoogleFileId = linkLocalGoogleFileId;
		return this;
	}

	/**
	 * Sets the record the file was attached to.
	 *
	 * @param relatedRecordId The record that now reaches the file.
	 * @return This same instance, so the call chains onto execute().
	 */
	public GoogleFileAttachFinalizeCommand forRecord(Id relatedRecordId) {
		this.relatedRecordId = relatedRecordId;
		return this;
	}

	/**
	 * Tells the command whether the attach actually created a link. Pass what the sharing command returned
	 * and nothing happens for a file that was already on that record.
	 *
	 * @param wasCreated True when the link is new.
	 * @return This same instance, so the call chains onto execute().
	 */
	public GoogleFileAttachFinalizeCommand onlyIfCreated(Boolean wasCreated) {
		this.wasCreated = wasCreated;
		return this;
	}

	/**
	 * Queues the shortcut job when everything is in place, and quietly does nothing when it is not.
	 */
	public void execute() {
		if (wasCreated != true) return;
		if (initiatorUserId == null || localGoogleFileId == null || linkLocalGoogleFileId == null || relatedRecordId == null) return;
		if (!googleConfig.requiresRecordFolder()) return;

		GAsync.queueable()
			.chain(new GoogleFileCloudShortcutJob(initiatorUserId, localGoogleFileId, linkLocalGoogleFileId))
			.deepClone()
			.enqueue();
	}
}