public without sharing class GoogleFileAccessCheckCommand {
	public class GoogleFileAccessCheckException extends Exception {}

	private List<GoogleFile__c> inputFiles = new List<GoogleFile__c>();
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

	public List<GoogleFile__c> strip() {
		return accessResolver.resolveAccessibleFiles(inputFiles, targetUserId);
	}
}