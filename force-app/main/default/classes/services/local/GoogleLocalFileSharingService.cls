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
public without sharing class GoogleLocalFileSharingService {
	public class GoogleLocalFileSharingException extends Exception {}

	private final IGoogleUnitOfWork uow;

	public GoogleLocalFileSharingService() {
		this.uow = new GoogleCloudUnitOfWork(new List<SObjectType>{
			GoogleFile__c.SObjectType,
			GoogleFileVersion__c.SObjectType,
			GoogleFileLink__c.SObjectType
		});
	}

	public GoogleLocalFileSharingService(IGoogleUnitOfWork injectedUow) {
		this.uow = injectedUow == null
			? new GoogleCloudUnitOfWork(new List<SObjectType>{
				GoogleFile__c.SObjectType,
				GoogleFileVersion__c.SObjectType,
				GoogleFileLink__c.SObjectType
			})
			: injectedUow;
	}

	public GoogleSharingInfoDTO fetchSharingDetails(Id localFileRecordId) {
		try {
			Map<Id, GoogleSharingInfoDTO> sharingInfo = new GoogleFileSharingCommand(uow)
				.retrieveSharing()
				.forFile(localFileRecordId)
				.includeAll()
				.fetch();

			return sharingInfo.get(localFileRecordId);
		} catch (Exception ex) {
			Logger.error('Retrieve Sharing Details (Local): ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw new GoogleLocalFileSharingException('Unable to retrieve sharing details. Please try again or contact your system administrator');
		}
	}

	public Id createNewSharing(Id localFileRecordId, String shareToObjectApiName, Id shareToRecordId, String uiAccessLevel) {
		try {
			return new GoogleFileSharingCommand(uow)
				.createSharing()
				.forFile(localFileRecordId)
				.shareTo(shareToObjectApiName, shareToRecordId)
				.withUiAccessLevel(uiAccessLevel)
				.apply();
		} catch (Exception ex) {
			Logger.error('Create Google File Sharing (Local/Remote): ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw new GoogleLocalFileSharingException('Unable to share the file. Please use a public group to share the file with this user');
		}
	}

	public void modifyExistingSharingAccess(Id localFileRecordId, Id shareToRecordId, String uiAccessLevel) {
		try {
			new GoogleFileSharingCommand(uow)
				.modifySharing()
				.forFile(localFileRecordId)
				.shareTo(shareToRecordId)
				.withUiAccessLevel(uiAccessLevel)
				.apply();
		} catch (Exception ex) {
			Logger.error('Modify Google File Sharing (Local - Access): ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw new GoogleLocalFileSharingException('Unable to update sharing for this file. Please try again or contact your system administrator');
		}
	}

	public void modifyExistingSharingVisibility(Id localFileRecordId, Id shareToRecordId, String visibility) {
		try {
			new GoogleFileSharingCommand(uow)
				.modifySharing()
				.forFile(localFileRecordId)
				.shareTo(shareToRecordId)
				.withVisibility(visibility)
				.apply();
		} catch (Exception ex) {
			Logger.error('Modify Google File Sharing (Local - Visibility): ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw new GoogleLocalFileSharingException('Unable to update sharing visibility for this file. Please try again or contact your system administrator');
		}
	}

	public void deleteExistingSharing(Id localFileRecordId, Id shareToRecordId) {
		try {
			new GoogleFileSharingCommand(uow)
				.deleteSharing()
				.forFile(localFileRecordId)
				.shareTo(shareToRecordId)
				.apply();
		} catch (Exception ex) {
			Logger.error('Delete Google File Sharing (Local): ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw new GoogleLocalFileSharingException('Unable to remove sharing for this file. Please try again or contact your system administrator');
		}
	}
}