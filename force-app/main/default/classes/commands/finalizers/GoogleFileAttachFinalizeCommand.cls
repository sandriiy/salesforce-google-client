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

	public GoogleFileAttachFinalizeCommand initiatedBy(Id initiatorUserId) {
		this.initiatorUserId = initiatorUserId;
		return this;
	}

	public GoogleFileAttachFinalizeCommand forFile(Id localGoogleFileId) {
		this.localGoogleFileId = localGoogleFileId;
		return this;
	}

	public GoogleFileAttachFinalizeCommand forLink(Id linkLocalGoogleFileId) {
		this.linkLocalGoogleFileId = linkLocalGoogleFileId;
		return this;
	}

	public GoogleFileAttachFinalizeCommand forRecord(Id relatedRecordId) {
		this.relatedRecordId = relatedRecordId;
		return this;
	}

	public GoogleFileAttachFinalizeCommand onlyIfCreated(Boolean wasCreated) {
		this.wasCreated = wasCreated;
		return this;
	}

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