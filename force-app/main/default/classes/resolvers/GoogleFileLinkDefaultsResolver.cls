public without sharing class GoogleFileLinkDefaultsResolver {
	public GoogleFileLink__c applyDefaultValues(GoogleFileLink__c linkRecord) {
		if (linkRecord == null) return null;

		User currentUser = loadCurrentUser();
		Boolean isInternalUser = isInternalUserType(currentUser == null ? null : currentUser.UserType);

		linkRecord.ShareType__c = isInternalUser ? 'Viewer' : 'InferredFromRecord';
		linkRecord.Visibility__c = isInternalUser ? 'InternalUsers' : 'AllUsers';
		return linkRecord;
	}

	private User loadCurrentUser() {
		List<User> users = [
			SELECT Id, UserType
			FROM User
			WHERE Id = :UserInfo.getUserId()
			LIMIT 1
		];

		return users.isEmpty() ? null : users[0];
	}

	private Boolean isInternalUserType(String userType) {
		if (userType == null) return true;

		String normalized = userType.toLowerCase();
		if (normalized.contains('guest') ||
			normalized.contains('portal') ||
			normalized.contains('partner') ||
			normalized.contains('customer') ||
			normalized.contains('csn')) {
			return false;
		}

		return true;
	}
}