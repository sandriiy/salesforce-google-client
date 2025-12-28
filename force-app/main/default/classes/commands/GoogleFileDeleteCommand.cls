public without sharing class GoogleFileDeleteCommand {
	private final IGoogleUnitOfWork uowRef;

	private Id recordId;
	private Boolean hasCloudFilesDeletion;

	public GoogleFileDeleteCommand(IGoogleUnitOfWork uowRef) {
		this.uowRef = uowRef;
	}

	public GoogleFileDeleteCommand setRecordId(Id value) {
		this.recordId = value;
		return this;
	}

	public GoogleFileDeleteCommand setCloudDeletion(Boolean isCloudFilesDeletion) {
		this.hasCloudFilesDeletion = isCloudFilesDeletion;
		return this;
	}

	public Boolean save() {
		GoogleFile__c googleFile = buildFileStub(recordId);
		List<GoogleFileVersion__c> localFileVersions = (List<GoogleFileVersion__c>) GoogleFileVersionSelector.query()
			.withAdvancedFields()
			.byParentId(recordId)
			.toList();

		Logger.info('File Delete: ' + recordId);

		uowRef.registerDeleted(googleFile);
		uowRef.commitWork(true);

		enqueueCloudDeletionIfNeeded(localFileVersions);
		return true;
	}

	private GoogleFile__c buildFileStub(Id recordId) {
		return new GoogleFile__c(Id = recordId);
	}

	private void enqueueCloudDeletionIfNeeded(List<GoogleFileVersion__c> localFileVersions) {
		if (hasCloudFilesDeletion == true) {
			System.enqueueJob(new GoogleFileCloudDeleteJob(localFileVersions));
		}
	}
}