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