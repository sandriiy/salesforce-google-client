public without sharing class GoogleFileShortcutPlacementCommand {
	public class GoogleFileShortcutPlacementCommandException extends Exception {}

	private static final String SHORTCUT_MIME_TYPE = 'application/vnd.google-apps.shortcut';

	private final GoogleDrive remoteGoogleDrive;
	private final GoogleFileFolderStructureCommand folderStructureCommand;
	private final GoogleMetadataConfigService metadataService;
	
	private Id initiatorUserId;
	private Id localGoogleFileId;
	private Id linkLocalGoogleFileId;

	public GoogleFileShortcutPlacementCommand() {
		this.remoteGoogleDrive = new GoogleClientApiProvider().retrieveGoogleDriveClient();
		this.folderStructureCommand = new GoogleFileFolderStructureCommand();
		this.metadataService = new GoogleMetadataConfigService();
	}

	public GoogleFileShortcutPlacementCommand initiatedBy(Id initiatorUserId) {
		this.initiatorUserId = initiatorUserId;
		return this;
	}

	public GoogleFileShortcutPlacementCommand forFile(Id localGoogleFileId) {
		this.localGoogleFileId = localGoogleFileId;
		return this;
	}

	public GoogleFileShortcutPlacementCommand forLink(Id linkLocalGoogleFileId) {
		this.linkLocalGoogleFileId = linkLocalGoogleFileId;
		return this;
	}

	public void execute() {
		if (!metadataService.requiresRecordFolder()) return;

		GoogleFileLink__c fileLink = loadFileLink(linkLocalGoogleFileId);
		Id relatedRecordId = resolveRelatedRecordId(fileLink);
		if (relatedRecordId == null) return;

		GoogleFileVersion__c latestVersion = loadLatestVersion(localGoogleFileId);
		if (latestVersion == null) {
			Logger.error('Shortcut Placement Job Failed --> latest GoogleFileVersion__c not found, FileId=' + String.valueOf(localGoogleFileId)).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			throw new GoogleFileShortcutPlacementCommandException('Shortcut Placement Job Failed, latest Google File Version not found');
		}

		String destinationFolderId = folderStructureCommand.ensureFolder(initiatorUserId, relatedRecordId);
		if (String.isBlank(destinationFolderId)) return;

		Logger.info(
			'Shortcut Placement Job --> Create' +
			', SourceFileId=' + String.valueOf(latestVersion.GoogleDriveFileId__c) +
			', DestinationFolderId=' + String.valueOf(destinationFolderId) +
			', LinkId=' + String.valueOf(linkLocalGoogleFileId)
		).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

		try {
			GoogleFileEntity createdShortcut = remoteGoogleDrive.files().multipartCreate()
				.setFileName(latestVersion.Name)
				.setMimeType(SHORTCUT_MIME_TYPE)
				.setParentFolders(new List<String>{ destinationFolderId })
				.setShortcutTarget(latestVersion.GoogleDriveFileId__c)
				.setSupportsAllDrives(true)
				.execute();

			Logger.info(
				'Shortcut Placement Job --> Created' +
				', ShortcutId=' + String.valueOf(createdShortcut == null ? null : createdShortcut.id) +
				', SourceFileId=' + String.valueOf(latestVersion.GoogleDriveFileId__c)
			).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
		} catch (Exception ex) {
			Logger.error(
				'Shortcut Placement Job Failed --> Create failed' +
				', SourceFileId=' + String.valueOf(latestVersion.GoogleDriveFileId__c) +
				', DestinationFolderId=' + String.valueOf(destinationFolderId) +
				', Error=' + ex.getMessage()
			).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

			throw new GoogleFileShortcutPlacementCommandException('Shortcut Placement Job Failed, remote shortcut create failed');
		}
	}

	private GoogleFileLink__c loadFileLink(Id linkLocalGoogleFileId) {
		if (linkLocalGoogleFileId == null) return null;

		return (GoogleFileLink__c) GoogleFileLinkSelector.query()
			.withBaseFields()
			.byId(linkLocalGoogleFileId)
			.toObject();
	}

	private Id resolveRelatedRecordId(GoogleFileLink__c fileLink) {
		if (fileLink == null || String.isBlank(fileLink.LinkedObjectId__c)) return null;

		try {
			return (Id) fileLink.LinkedObjectId__c;
		} catch (Exception ex) {
			Logger.error('Shortcut Placement Job Failed --> invalid LinkedObjectId__c, LinkId=' + String.valueOf(fileLink.Id)).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			return null;
		}
	}

	private GoogleFileVersion__c loadLatestVersion(Id localGoogleFileId) {
		if (localGoogleFileId == null) return null;

		return (GoogleFileVersion__c) GoogleFileVersionSelector.query()
			.withAdvancedFields()
			.byParentId(localGoogleFileId)
			.byLatest()
			.orderByCreatedDesc()
			.limitTo(1)
			.toObject();
	}
}