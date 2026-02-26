public without sharing class GoogleFileAccessibilityCommand {
	private Id targetUserId;
	private final GoogleFileAccessResolver accessResolver;

	public GoogleFileAccessibilityCommand() {
		this.accessResolver = new GoogleFileAccessResolver();
	}

	public GoogleFileAccessibilityCommand forUser(Id userId) {
		this.targetUserId = userId;
		return this;
	}

	public List<GoogleFile__c> fetch() {
		return accessResolver.resolveAccessibleFilesForUser(targetUserId);
	}
}