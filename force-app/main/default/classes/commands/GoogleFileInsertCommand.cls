public without sharing class GoogleFileInsertCommand {
	private final String DEFAULT_FILE_NAME = 'Untitled';
	private final IGoogleUnitOfWork uowRef;

	private Id relatedRecordId;
	private String fileName;
	private String fileType;
	private Long fileSize;
	private String googleDriveFileId;
	private String googleDriveFolderId;
	private String source;
	private Id existingLocalGoogleFileId;

	public GoogleFileInsertCommand(IGoogleUnitOfWork uowRef) {
		this.uowRef = uowRef;
	}

	public GoogleFileInsertCommand setRecordId(Id value) {
		this.relatedRecordId = value;
		return this;
	}

	public GoogleFileInsertCommand setGoogleDriveId(String value) {
		this.googleDriveFileId = value;
		return this;
	}

	public GoogleFileInsertCommand setFileName(String value) {
		this.fileName = value;
		return this;
	}

	public GoogleFileInsertCommand setFileType(String value) {
		this.fileType = value;
		return this;
	}

	public GoogleFileInsertCommand setFileSize(Long value) {
		this.fileSize = value;
		return this;
	}

	public GoogleFileInsertCommand setParentFolderId(String value) {
		this.googleDriveFolderId = value;
		return this;
	}

	public GoogleFileInsertCommand setSource(String value) {
		this.source = value;
		return this;
	}

	public GoogleFileInsertCommand setLocalGoogleFileId(Id value) {
		this.existingLocalGoogleFileId = value;
		return this;
	}

	public GoogleFile__c save() {
		if (existingLocalGoogleFileId != null) {
			return saveNewVersion();
		} else {
			return saveNewFile();
		}
	}

	private GoogleFile__c saveNewVersion() {
		GoogleFileVersion__c versionRecord = new GoogleFileVersion__c(
			Name = buildLocalFileName(false),
			Type__c = fileType,
			Size__c = fileSize,
			GoogleFileId__c = existingLocalGoogleFileId,
			GoogleDriveFileId__c = googleDriveFileId,
			GoogleDriveFolderId__c = googleDriveFolderId
		);

		Logger.info('File Insert, New Version for: ' + existingLocalGoogleFileId);

		uowRef.registerNew(versionRecord);
		uowRef.commitWork(true);

		return (GoogleFile__c) GoogleFileSelector.query()
			.byRecordId(existingLocalGoogleFileId)
			.withLatestVersionSubquery()
			.withBaseFields()
			.toObject();
	}

	private GoogleFile__c saveNewFile() {
		GoogleFile__c fileRecord = new GoogleFile__c(
			Name = buildLocalFileName(true),
			Source__c = source
		);

		GoogleFileVersion__c versionToBind = new GoogleFileVersion__c(
			Name = buildLocalFileName(false),
			Type__c = fileType,
			Size__c = fileSize,
			GoogleDriveFileId__c = googleDriveFileId,
			GoogleDriveFolderId__c = googleDriveFolderId
		);

		GoogleFileLink__c linkToBind = new GoogleFileLink__c(
			LinkedObjectId__c = String.valueOf(relatedRecordId),
			LinkedObjectType__c = relatedRecordId.getSObjectType().getDescribe().getName()
		);

		linkToBind = applyUserBasedChanges(linkToBind);

		Logger.info('File Insert, New File with Remote: Google ID: ' + googleDriveFileId + '; Folder ID: ' + googleDriveFolderId);
		Logger.info('Known File Source: ' + source);

		uowRef.registerNew(fileRecord);
		uowRef.registerNew(versionToBind, GoogleFileVersion__c.GoogleFileId__c, fileRecord);
		uowRef.registerNew(linkToBind, GoogleFileLink__c.GoogleFileId__c, fileRecord);
		uowRef.commitWork(true);

		return (GoogleFile__c) GoogleFileSelector.query()
			.byRecordId(fileRecord.Id)
			.withLatestVersionSubquery()
			.withBaseFields()
			.toObject();
	}

	private GoogleFileLink__c applyUserBasedChanges(GoogleFileLink__c newLink) {
		User userRow = [SELECT Id, UserType FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];

		newLink.ShareType__c = isInternal(userRow.UserType) ? 'Viewer' : 'InferredFromRecord';
		newLink.Visibility__c = isInternal(userRow.UserType) ? 'InternalUsers' : 'AllUsers';

		return newLink;
	}

	private String buildLocalFileName(Boolean removeExtension) {
		String originalName = String.isBlank(fileName)
			? DEFAULT_FILE_NAME
			: fileName.trim();

		String namePart = originalName;
		String extPart = '';

		Integer lastDot = originalName.lastIndexOf('.');
		if (lastDot > 0 && lastDot < originalName.length() - 1) {
			namePart = originalName.substring(0, lastDot);

			if (!removeExtension) {
				extPart = originalName.substring(lastDot);
			}
		}

		Integer maxTotalLength = 80;
		Integer maxNameLength = maxTotalLength - extPart.length();

		if (maxNameLength < 1) {
			String fallback = DEFAULT_FILE_NAME + extPart;
			return fallback.length() > maxTotalLength
				? fallback.substring(0, maxTotalLength)
				: fallback;
		}

		if (namePart.length() > maxNameLength) {
			namePart = namePart.substring(0, maxNameLength);
		}

		return namePart + extPart;
	}

	private Boolean isInternal(String userType) {
		if (userType == null) return true;

		String t = userType.toLowerCase();
		if (t.contains('guest') || t.contains('portal') || t.contains('partner') || t.contains('customer') || t.contains('csn')) {
			return false;
		}

		return true;
	}
}