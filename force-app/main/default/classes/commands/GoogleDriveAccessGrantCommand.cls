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
public without sharing class GoogleDriveAccessGrantCommand {
	public class GoogleDriveAccessGrantException extends Exception {}

	private static final Integer MAX_ACCESS_DURATION_DAYS = 365;
	private static final String EXPIRATION_UNSUPPORTED_MARKER = 'cannotSetExpiration';
	private static final String VIEW_ONLY_ROLE = 'reader';
	private static final String INDIVIDUAL_PRINCIPAL_TYPE = 'user';
	private static final String VIEW_LINK_AND_PERMISSIONS_FIELDS = 'webViewLink, permissions(id, type, emailAddress, role, expirationTime, deleted)';

	private final GoogleDrive remoteGoogleDrive;

	public GoogleDriveAccessGrantCommand() {
		this.remoteGoogleDrive = new GoogleClientApiProvider().retrieveGoogleDriveClient();
	}

	public GrantResult grantViewAccess(String remoteFileId, String emailAddress, Datetime accessEndsOn) {
		if (String.isBlank(remoteFileId)) {
			throw new GoogleDriveAccessGrantException('Remote File Id must not be blank');
		}

		if (String.isBlank(emailAddress)) {
			throw new GoogleDriveAccessGrantException('Email Address must not be blank');
		}

		if (accessEndsOn == null || accessEndsOn <= Datetime.now()) {
			throw new GoogleDriveAccessGrantException('Access End Date must be in the future');
		}
		
		if (accessEndsOn > Datetime.now().addDays(MAX_ACCESS_DURATION_DAYS)) {
			throw new GoogleDriveAccessGrantException('Access End Date must be within ' + MAX_ACCESS_DURATION_DAYS + ' days');
		}

		GoogleFileEntity remoteFile = retrieveViewLinkAndPermissions(remoteFileId);
		if (remoteFile == null) {
			throw new GoogleDriveAccessGrantException('Remote file was not found in Google Drive');
		}

		GoogleFileEntity.Permission existingPermission = findIndividualPermission(remoteFile.permissions, emailAddress);
		String permissionId = existingPermission == null
			? createViewPermission(remoteFileId, emailAddress)
			: existingPermission.id;

		Boolean isEndDateApplied = applyAccessEndDate(remoteFileId, permissionId, accessEndsOn);
		return new GrantResult(remoteFile.webViewLink, permissionId, isEndDateApplied ? accessEndsOn : null, existingPermission != null);
	}

	private GoogleFileEntity retrieveViewLinkAndPermissions(String remoteFileId) {
		return remoteGoogleDrive.files().retrieve().download(remoteFileId)
			.setFileDownloadType(GoogleDownloadFileBuilder.DownloadType.METADATA)
			.setSearchOnAllDrives(true)
			.setFields(VIEW_LINK_AND_PERMISSIONS_FIELDS)
			.execute();
	}

	private GoogleFileEntity.Permission findIndividualPermission(List<GoogleFileEntity.Permission> permissions, String emailAddress) {
		if (permissions == null || permissions.isEmpty()) return null;

		String normalizedEmail = emailAddress.trim();
		for (GoogleFileEntity.Permission permission : permissions) {
			if (permission == null || permission.deleted == true) continue;
			if (permission.type != INDIVIDUAL_PRINCIPAL_TYPE) continue;
			if (String.isBlank(permission.emailAddress)) continue;

			if (permission.emailAddress.trim().equalsIgnoreCase(normalizedEmail)) {
				return permission;
			}
		}

		return null;
	}

	private String createViewPermission(String remoteFileId, String emailAddress) {
		GooglePermissionEntity newPermission = remoteGoogleDrive.permissions().create(remoteFileId)
			.setSupportsAllDrives(true)
			.setPrincipalType(INDIVIDUAL_PRINCIPAL_TYPE)
			.setPrincipalRole(VIEW_ONLY_ROLE)
			.setPrincipalEmailAddress(emailAddress)
			.setSendNotificationEmail(false)
			.execute();

		if (newPermission == null || String.isBlank(newPermission.id)) {
			throw new GoogleDriveAccessGrantException('Google Drive did not return a permission for ' + emailAddress);
		}

		return newPermission.id;
	}

	private Boolean applyAccessEndDate(String remoteFileId, String permissionId, Datetime accessEndsOn) {
		if (String.isBlank(permissionId)) return false;

		try {
			remoteGoogleDrive.permissions().modify(remoteFileId, permissionId)
				.setSupportsAllDrives(true)
				.setPrincipalRole(VIEW_ONLY_ROLE)
				.setExpirationTime(accessEndsOn.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''))
				.execute();
			return true;
		} catch (Exception ex) {
			if (ex.getMessage() != null && ex.getMessage().contains(EXPIRATION_UNSUPPORTED_MARKER)) {
				return false;
			}
			throw ex;
		}
	}

	public class GrantResult {
		public final String viewLink;
		public final String permissionId;
		public final Datetime accessEndsOn;
		public final Boolean wasAlreadyShared;

		public GrantResult(String viewLink, String permissionId, Datetime accessEndsOn, Boolean wasAlreadyShared) {
			this.viewLink = viewLink;
			this.permissionId = permissionId;
			this.accessEndsOn = accessEndsOn;
			this.wasAlreadyShared = wasAlreadyShared;
		}
	}
}
