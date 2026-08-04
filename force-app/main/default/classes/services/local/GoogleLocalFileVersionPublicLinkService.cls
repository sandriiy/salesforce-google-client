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
public without sharing class GoogleLocalFileVersionPublicLinkService {
	public class GoogleFileVersionPublicLinkException extends Exception {}

	private final GoogleMetadataConfigService googleConfig;
	private final GoogleClientApiProvider remoteFileService;
	private final IGoogleUnitOfWork uow;

	public GoogleLocalFileVersionPublicLinkService() {
		this((IGoogleUnitOfWork) null);
	}

	public GoogleLocalFileVersionPublicLinkService(IGoogleUnitOfWork injectedUow) {
		this.googleConfig = new GoogleMetadataConfigService();
		this.remoteFileService = new GoogleClientApiProvider();
		this.uow = injectedUow == null
			? new GoogleCloudUnitOfWork(GoogleCloudConstants.DEFAULT_WRITE_ORDER)
			: injectedUow;
	}

	public List<GoogleFileVersion__c> removePublicLinkSharing(Id localFileVersionId) {
		Logger.info('Remove Public Link Sharing --> ' + localFileVersionId).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

		GoogleFileVersion__c localFileVersion = queryLocalFileVersion(localFileVersionId);
		return deletePublicLink(new List<GoogleFileVersion__c>{ localFileVersion });
	}

	public List<GoogleFileVersion__c> removePublicLinkSharing(Set<Id> localFileVersionIds) {
		if (localFileVersionIds == null || localFileVersionIds.isEmpty()) return new List<GoogleFileVersion__c>();
		Logger.info('Remove Public Link Sharing --> ' + localFileVersionIds).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

		return deletePublicLink(queryLocalFileVersions(localFileVersionIds));
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

	private List<GoogleFileVersion__c> queryLocalFileVersions(Set<Id> localFileVersionIds) {
		return (List<GoogleFileVersion__c>) GoogleFileVersionSelector.query()
			.withAdvancedFields()
			.byIds(localFileVersionIds)
			.toList();
	}

	private List<GoogleFileVersion__c> createAndAssignPublicLink(List<GoogleFileVersion__c> localFileVersions, Datetime expirationDate, Boolean isDomainSkip) {
		if (localFileVersions == null || localFileVersions.isEmpty()) {
			return new List<GoogleFileVersion__c>();
		}

		String googleDomain = this.googleConfig.getGoogleDriveDomain();
		GoogleDrive removeGoogleDrive = this.remoteFileService.retrieveGoogleDriveClient();

		for (GoogleFileVersion__c localFileVersion : localFileVersions) {
			if (localFileVersion == null) continue;

			String googleDriveId = localFileVersion.GoogleDriveFileId__c;
			if (String.isBlank(googleDriveId)) continue;

			GoogleCreatePermissionFileBuilder createPermissionBuild = removeGoogleDrive.permissions().create(googleDriveId)
				.setSupportsAllDrives(true)
				.setPrincipalRole('reader');

			if (String.isNotBlank(googleDomain) && isDomainSkip == false) {
				createPermissionBuild = createPermissionBuild
					.setPrincipalType('domain')
					.setPrincipalDomain(googleDomain);
			} else {
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
			uow.registerDirty(localFileVersions);
			uow.commitWork(true);
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
			uow.registerDirty(localFileVersions);
			uow.commitWork(true);
		} catch (Exception ex) {
			Logger.error('Delete Public Link Failed (Local): ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw new GoogleFileVersionPublicLinkException('Unable to remove a public link. Please try again or contact your administrator');
		}

		return localFileVersions;
	}
}