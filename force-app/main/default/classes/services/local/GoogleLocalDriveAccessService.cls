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
public without sharing class GoogleLocalDriveAccessService {
	public class GoogleLocalDriveAccessException extends Exception {}

	private static final Integer VIEW_ACCESS_DURATION_DAYS = 7;
	private static final String UNAVAILABLE_MESSAGE = 'You can’t open this file in Google Drive';
	private static final String FAILED_MESSAGE = 'We couldn’t open this file in Google Drive. Your Salesforce email may not match a Google account. Please try again or contact your system administrator';
	private static final String MISSING_REMOTE_FILE_MESSAGE = 'This file isn’t available in Google Drive yet. Please try again in a few moments';

	private final GoogleMetadataConfigService googleConfig;
	private final GoogleFileAccessResolver accessResolver;

	public GoogleLocalDriveAccessService() {
		this.googleConfig = new GoogleMetadataConfigService();
		this.accessResolver = new GoogleFileAccessResolver();
	}

	public Boolean canOpenInDrive(Id localFileRecordId) {
		if (localFileRecordId == null) return false;
		if (!googleConfig.isOpenInDriveEnabled()) return false;

		User actingUser = queryActingUser(UserInfo.getUserId());
		if (actingUser == null || !accessResolver.isInternalUser(actingUser.UserType)) return false;

		return findOwnedFile(localFileRecordId, UserInfo.getUserId()) != null;
	}

	public GoogleDriveAccessDTO openInDrive(Id localFileRecordId, Id localFileVersionId) {
		Logger.info('Open In Drive Request --> FileId=' + String.valueOf(localFileRecordId) + ', VersionId=' + String.valueOf(localFileVersionId)).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

		if (!googleConfig.isOpenInDriveEnabled()) {
			throw new GoogleLocalDriveAccessException(UNAVAILABLE_MESSAGE);
		}

		Id actingUserId = UserInfo.getUserId();
		User actingUser = queryActingUser(actingUserId);

		if (actingUser == null || !accessResolver.isInternalUser(actingUser.UserType)) {
			throw new GoogleLocalDriveAccessException(UNAVAILABLE_MESSAGE);
		}

		GoogleFile__c ownedFile = findOwnedFile(localFileRecordId, actingUserId);
		if (ownedFile == null) {
			throw new GoogleLocalDriveAccessException(UNAVAILABLE_MESSAGE);
		}

		GoogleFileVersion__c targetVersion = findVersionOfFile(localFileVersionId, localFileRecordId);
		if (targetVersion == null) {
			throw new GoogleLocalDriveAccessException(UNAVAILABLE_MESSAGE);
		}

		if (String.isBlank(targetVersion.GoogleDriveFileId__c)) {
			throw new GoogleLocalDriveAccessException(MISSING_REMOTE_FILE_MESSAGE);
		}

		if (String.isBlank(actingUser.Email)) {
			throw new GoogleLocalDriveAccessException(FAILED_MESSAGE);
		}

		Datetime accessEndsOn = Datetime.now().addDays(VIEW_ACCESS_DURATION_DAYS);

		GoogleDriveAccessGrantCommand.GrantResult grantResult;

		try {
			grantResult = new GoogleDriveAccessGrantCommand()
				.grantViewAccess(targetVersion.GoogleDriveFileId__c, actingUser.Email, accessEndsOn);
		} catch (Exception ex) {
			Logger.error('Open In Drive Failed (Local): ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw new GoogleLocalDriveAccessException(FAILED_MESSAGE);
		}

		Logger.info('Open In Drive Grant --> FileId=' + String.valueOf(localFileRecordId) + ', VersionId=' + String.valueOf(targetVersion.Id) + ', GoogleDriveFileId=' + targetVersion.GoogleDriveFileId__c + ', Grantee=' + actingUser.Email + ', PermissionId=' + grantResult.permissionId + ', Expires=' + String.valueOf(grantResult.accessEndsOn) + ', WasAlreadyShared=' + String.valueOf(grantResult.wasAlreadyShared)).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
		Logger.saveLog();

		return new GoogleDriveAccessDTO(grantResult.viewLink, grantResult.accessEndsOn, grantResult.wasAlreadyShared);
	}

	private User queryActingUser(Id actingUserId) {
		return (User) GoogleUserSelector.query()
			.withTypeFields()
			.withContactFields()
			.byUserId(actingUserId)
			.toObject();
	}

	private GoogleFile__c findOwnedFile(Id localFileRecordId, Id actingUserId) {
		return (GoogleFile__c) GoogleFileSelector.query()
			.withSpecificFields(new List<String>{ 'Id', 'OwnerId' })
			.byOwner(actingUserId)
			.byId(localFileRecordId)
			.toObject();
	}

	private GoogleFileVersion__c findVersionOfFile(Id localFileVersionId, Id localFileRecordId) {
		GoogleFileVersion__c versionRecord = (GoogleFileVersion__c) GoogleFileVersionSelector.query()
			.withAdvancedFields()
			.byId(localFileVersionId)
			.toObject();

		if (versionRecord == null) return null;
		return versionRecord.GoogleFileId__c == localFileRecordId ? versionRecord : null;
	}
}
