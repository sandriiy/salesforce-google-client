public without sharing class GoogleLocalFileVersionPublicLinkService {
	public class GoogleFileVersionPublicLinkException extends Exception {}

	private final GoogleMetadataConfigService googleConfig;
	private final GoogleDriveApiProvider remoteFileService;

	public GoogleLocalFileVersionPublicLinkService() {
		this.googleConfig = new GoogleMetadataConfigService();
		this.remoteFileService = new GoogleDriveApiProvider();
	}

	public List<GoogleFileVersion__c> removePublicLinkSharing(Id localFileVersionId) {
		Logger.info('Remove Public Link Sharing --> ' + localFileVersionId).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

		GoogleFileVersion__c localFileVersion = queryLocalFileVersion(localFileVersionId);
		return deletePublicLink(new List<GoogleFileVersion__c>{ localFileVersion });
	}

	public List<GoogleFileVersion__c> applyPublicLinkSharing(Id localFileVersionId) {
		return applyPublicLinkSharing(localFileVersionId, null);
	}

	public List<GoogleFileVersion__c> applyPublicLinkSharing(Id localFileVersionId, Datetime expirationDate) {
		return applyPublicLinkSharing(localFileVersionId, expirationDate, false);
	}

	public List<GoogleFileVersion__c> applyPublicLinkSharing(Id localFileVersionId, Datetime expirationDate, Boolean isDomainSkip) {
		Logger.info('Apply Public Link Sharing --> ' + localFileVersionId).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

		GoogleFileVersion__c localFileVersion = queryLocalFileVersion(localFileVersionId);
		return createAndAssignPublicLink(new List<GoogleFileVersion__c>{ localFileVersion }, expirationDate, isDomainSkip);
	}

	private GoogleFileVersion__c queryLocalFileVersion(Id localFileVersionId) {
		return (GoogleFileVersion__c) GoogleFileVersionSelector.query()
			.withAdvancedFields()
			.byId(localFileVersionId)
			.toObject();
	}

	private List<GoogleFileVersion__c> createAndAssignPublicLink(List<GoogleFileVersion__c> localFileVersions, Datetime expirationDate, Boolean isDomainSkip) {
		if (localFileVersions == null || localFileVersions.isEmpty()) {
			return new List<GoogleFileVersion__c>();
		}

		String googleDomain = this.googleConfig.getGoogleDriveDomain();
		System.debug(googleDomain);
		System.debug(isDomainSkip);
		GoogleDrive removeGoogleDrive = this.remoteFileService.retrieveGoogleDriveClient();

		for (GoogleFileVersion__c localFileVersion : localFileVersions) {
			if (localFileVersion == null) continue;

			String googleDriveId = localFileVersion.GoogleDriveFileId__c;
			if (String.isBlank(googleDriveId)) continue;

			GoogleCreatePermissionFileBuilder createPermissionBuild = removeGoogleDrive.permissions().create(googleDriveId)
				.setSupportsAllDrives(true)
				.setPrincipalRole('reader');

			if (String.isNotBlank(googleDomain) && isDomainSkip == false) {
				System.debug('here');
				createPermissionBuild = createPermissionBuild
					.setPrincipalType('domain')
					.setPrincipalDomain(googleDomain);
			} else {
				System.debug('here2');
				createPermissionBuild = createPermissionBuild
					.setPrincipalType('anyone');
			}

			GooglePermissionEntity newPermission = createPermissionBuild.execute();
			GoogleFileEntity fileDetails = removeGoogleDrive.files().retrieve().download(googleDriveId)
				.setFileDownloadType(GoogleDownloadFileBuilder.DownloadType.METADATA)
				.setSearchOnAllDrives(true)
				.setFields('webViewLink, webContentLink')
				.execute();

			localFileVersion.PublicLink__c = fileDetails == null ? null : fileDetails.webViewLink;
			localFileVersion.PublicLinkExpirationDate__c = expirationDate;
			localFileVersion.PublicLinkPermissionId__c = newPermission == null ? null : newPermission.id;
			localFileVersion.PublicLinkStatus__c = 'Active';
		}

		try {
			update localFileVersions;
		} catch (Exception ex) {
			Logger.error('Created & Assign Public Link Failed (Local): ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw new GoogleFileVersionPublicLinkException('Unable to create a public link. Please try again or contact your administrator');
		}

		return localFileVersions;
	}

	private List<GoogleFileVersion__c> deletePublicLink(List<GoogleFileVersion__c> localFileVersions) {
		if (localFileVersions == null || localFileVersions.isEmpty()) {
			return new List<GoogleFileVersion__c>();
		}

		GoogleDrive removeGoogleDrive = this.remoteFileService.retrieveGoogleDriveClient();

		for (GoogleFileVersion__c localFileVersion : localFileVersions) {
			if (localFileVersion == null) continue;

			String googleDriveId = localFileVersion.GoogleDriveFileId__c;
			String publicPermissionId = localFileVersion.PublicLinkPermissionId__c;

			if (String.isBlank(googleDriveId) || String.isBlank(publicPermissionId)) {
				continue;
			}

			removeGoogleDrive.permissions().remove(googleDriveId, publicPermissionId)
				.setSupportsAllDrives(true)
				.execute();

			localFileVersion.PublicLink__c = null;
			localFileVersion.PublicLinkExpirationDate__c = null;
			localFileVersion.PublicLinkPermissionId__c = null;
			localFileVersion.PublicLinkStatus__c = 'None';
		}

		try {
			update localFileVersions;
		} catch (Exception ex) {
			Logger.error('Delete Public Link Failed (Local): ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw new GoogleFileVersionPublicLinkException('Unable to remove a public link. Please try again or contact your administrator');
		}

		return localFileVersions;
	}
}