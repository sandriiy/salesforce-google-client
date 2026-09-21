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
/**
 * Hands a real Google Drive permission to one email address, the only place in the package
 * where access is granted outside Salesforce. The role is always "reader", Drive sends no
 * notification email and the grant lands on the file itself, never its folder. Every Drive call
 * goes through GoogleClientApiProvider, and deciding whether the user may have this at all is
 * the caller's job: GoogleLocalDriveAccessService gates it and nothing in here checks access.
 */
public without sharing class GoogleDriveAccessGrantCommand {
	public class GoogleDriveAccessGrantException extends Exception {}

	private static final Integer MAX_ACCESS_DURATION_DAYS = 365;
	private static final String EXPIRATION_UNSUPPORTED_MARKER = 'cannotSetExpiration';
	private static final String PERMISSION_MISSING_REASON_MARKER = 'notFound';
	private static final String PERMISSION_MISSING_LOCATION_MARKER = 'permissionId';
	private static final String VIEW_ONLY_ROLE = 'reader';
	private static final String INDIVIDUAL_PRINCIPAL_TYPE = 'user';
	private static final String VIEW_LINK_AND_PERMISSIONS_FIELDS = 'webViewLink, permissions(id, type, emailAddress, role, expirationTime, deleted)';

	/**
	 * Why an end date did or did not land on a permission. PermissionMissing means Drive no longer
	 * knows the permission, which is the signal to grant access again rather than give up.
	 */
	public enum EndDateOutcome { Applied, Unsupported, PermissionMissing }

	private final GoogleDrive remoteGoogleDrive;

	public GoogleDriveAccessGrantCommand() {
		this.remoteGoogleDrive = new GoogleClientApiProvider().retrieveGoogleDriveClient();
	}

	/**
	 * Grants the address view access to the Drive file until the given moment, reusing an
	 * individual permission Drive already holds for that address instead of adding a second one.
	 * A permission whose end date has already passed is replaced rather than reused, and so is one
	 * Drive no longer recognises, so access can be granted again after an earlier grant lapsed.
	 * The end date is best effort: some drives refuse expirations outright, and then the grant
	 * survives with no end date rather than failing, which the result reports by leaving
	 * accessEndsOn empty.
	 *
	 * @param remoteFileId The Drive file Id to share, normally GoogleFileVersion__c.GoogleDriveFileId__c.
	 * @param emailAddress The Google account that receives access.
	 * @param accessEndsOn When access should end; must be in the future and at most a year away.
	 * @return The view link, the permission Id to revoke later and whether the address was already shared with.
	 */
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
		Boolean wasAlreadyShared = existingPermission != null;
		String permissionId = wasAlreadyShared ? existingPermission.id : createViewPermission(remoteFileId, emailAddress);

		EndDateOutcome accessEndDateOutcome = applyAccessEndDate(remoteFileId, permissionId, accessEndsOn);
		if (accessEndDateOutcome == EndDateOutcome.PermissionMissing && wasAlreadyShared) {
			permissionId = createViewPermission(remoteFileId, emailAddress);
			wasAlreadyShared = false;
			accessEndDateOutcome = applyAccessEndDate(remoteFileId, permissionId, accessEndsOn);
		}

		return new GrantResult(remoteFile.webViewLink, permissionId, accessEndDateOutcome == EndDateOutcome.Applied ? accessEndsOn : null, wasAlreadyShared);
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
			if (hasExpired(permission.expirationTime)) continue;

			if (permission.emailAddress.trim().equalsIgnoreCase(normalizedEmail)) {
				return permission;
			}
		}

		return null;
	}

	private Boolean hasExpired(String expirationTime) {
		if (String.isBlank(expirationTime)) return false;

		String normalized = expirationTime.trim().replace('T', ' ').removeEnd('Z');
		Integer fractionStart = normalized.indexOf('.');
		if (fractionStart > 0) normalized = normalized.substring(0, fractionStart);

		try {
			return Datetime.valueOfGmt(normalized) <= Datetime.now();
		} catch (Exception ex) {
			return false;
		}
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

	private EndDateOutcome applyAccessEndDate(String remoteFileId, String permissionId, Datetime accessEndsOn) {
		if (String.isBlank(permissionId)) return EndDateOutcome.Unsupported;

		try {
			remoteGoogleDrive.permissions().modify(remoteFileId, permissionId)
				.setSupportsAllDrives(true)
				.setPrincipalRole(VIEW_ONLY_ROLE)
				.setExpirationTime(accessEndsOn.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''))
				.execute();
			return EndDateOutcome.Applied;
		} catch (Exception ex) {
			String failure = ex.getMessage() == null ? '' : ex.getMessage();
			if (failure.contains(EXPIRATION_UNSUPPORTED_MARKER)) return EndDateOutcome.Unsupported;
			if (failure.contains(PERMISSION_MISSING_REASON_MARKER) && failure.contains(PERMISSION_MISSING_LOCATION_MARKER)) return EndDateOutcome.PermissionMissing;

			throw ex;
		}
	}

	/**
	 * What the grant produced, kept so a caller can open the file now and later revoke exactly
	 * the permission that was created.
	 */
	public class GrantResult {
		public final String viewLink;
		/**
		 * The Drive permission Id, whether this call created it or found it already there.
		 */
		public final String permissionId;
		/**
		 * Null when Drive refused to put an end date on the permission.
		 */
		public final Datetime accessEndsOn;
		/**
		 * True when the address already held an individual permission and it was reused as is.
		 */
		public final Boolean wasAlreadyShared;

		/**
		 * Builds the result the way grantViewAccess() reports it.
		 *
		 * @param viewLink The Drive link that opens the file in the browser.
		 * @param permissionId The Drive permission Id that was created or reused.
		 * @param accessEndsOn The applied end date, or null when Drive refused one.
		 * @param wasAlreadyShared Whether an existing individual permission was reused.
		 */
		public GrantResult(String viewLink, String permissionId, Datetime accessEndsOn, Boolean wasAlreadyShared) {
			this.viewLink = viewLink;
			this.permissionId = permissionId;
			this.accessEndsOn = accessEndsOn;
			this.wasAlreadyShared = wasAlreadyShared;
		}
	}
}
