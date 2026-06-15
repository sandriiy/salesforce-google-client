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
		GoogleFileSharingCommand.RetrieveSharingCommand retrieveSharingCommand = new GoogleFileSharingCommand(uow)
			.retrieveSharing()
			.forFile(localFileRecordId)
			.includeAll();

		requireFileAccess(localFileRecordId, true);

		try {
			Map<Id, GoogleSharingInfoDTO> sharingInfo = retrieveSharingCommand.fetch();
			return sharingInfo.get(localFileRecordId);
		} catch (Exception ex) {
			Logger.error('Retrieve Sharing Details (Local): ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw new GoogleLocalFileSharingException('Unable to retrieve sharing details. Please try again or contact your system administrator');
		}
	}

	public Id createNewSharing(Id localFileRecordId, String shareToObjectApiName, Id shareToRecordId, String uiAccessLevel) {
		GoogleFileSharingCommand.CreateSharingCommand createSharingCommand = new GoogleFileSharingCommand(uow)
			.createSharing()
			.forFile(localFileRecordId)
			.shareTo(shareToObjectApiName, shareToRecordId)
			.withUiAccessLevel(uiAccessLevel);

		requireFileAccess(localFileRecordId, true);

		try {
			return createSharingCommand.apply();
		} catch (Exception ex) {
			Logger.error('Create Google File Sharing (Local/Remote): ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw new GoogleLocalFileSharingException('Unable to share the file. Please use a public group to share the file with this user');
		}
	}

	public void modifyExistingSharingAccess(Id localFileRecordId, Id shareToRecordId, String uiAccessLevel) {
		GoogleFileSharingCommand.ModifySharingCommand modifySharingCommand = new GoogleFileSharingCommand(uow)
			.modifySharing()
			.forFile(localFileRecordId)
			.shareTo(shareToRecordId)
			.withUiAccessLevel(uiAccessLevel);

		requireFileAccess(localFileRecordId, true);

		try {
			modifySharingCommand.apply();
		} catch (Exception ex) {
			Logger.error('Modify Google File Sharing (Local - Access): ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw new GoogleLocalFileSharingException('Unable to update sharing for this file. Please try again or contact your system administrator');
		}
	}

	public void modifyExistingSharingVisibility(Id localFileRecordId, Id shareToRecordId, String visibility) {
		GoogleFileSharingCommand.ModifySharingCommand modifySharingCommand = new GoogleFileSharingCommand(uow)
			.modifySharing()
			.forFile(localFileRecordId)
			.shareTo(shareToRecordId)
			.withVisibility(visibility);

		requireFileAccess(localFileRecordId, true);

		try {
			modifySharingCommand.apply();
		} catch (Exception ex) {
			Logger.error('Modify Google File Sharing (Local - Visibility): ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw new GoogleLocalFileSharingException('Unable to update sharing visibility for this file. Please try again or contact your system administrator');
		}
	}

	public void deleteExistingSharing(Id localFileRecordId, Id shareToRecordId) {
		GoogleFileSharingCommand.DeleteSharingCommand deleteSharingCommand = new GoogleFileSharingCommand(uow)
			.deleteSharing()
			.forFile(localFileRecordId)
			.shareTo(shareToRecordId);

		requireFileAccess(localFileRecordId, true);

		try {
			deleteSharingCommand.apply();
		} catch (Exception ex) {
			Logger.error('Delete Google File Sharing (Local): ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw new GoogleLocalFileSharingException('Unable to remove sharing for this file. Please try again or contact your system administrator');
		}
	}

	public Id attachExistingFileToRecord(Id localFileRecordId, Id relatedRecordId, String source) {
		GoogleFileSharingCommand.CreateSharingCommand createSharingCommand = new GoogleFileSharingCommand(uow)
			.createSharing()
			.forFile(localFileRecordId)
			.shareTo(relatedRecordId == null ? null : relatedRecordId.getSObjectType().getDescribe().getName(), relatedRecordId)
			.withSource(source);

		requireFileAccess(localFileRecordId, true);

		try {
			GoogleFileSharingApplyResultDTO result = createSharingCommand.applyWithResult();

			new GoogleFileAttachFinalizeCommand()
				.initiatedBy(UserInfo.getUserId())
				.forFile(localFileRecordId)
				.forLink(result.recordId)
				.forRecord(relatedRecordId)
				.onlyIfCreated(result.wasCreated)
				.execute();
				
			return result.recordId;
		} catch (Exception ex) {
			Logger.error('Attach Existing Google File To Record (Local): ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw new GoogleLocalFileSharingException('Unable to attach the existing file to this record. Please try again or contact your system administrator');
		}
	}

	public List<GoogleFileLink__c> retrieveLinkedRecords(Id localFileRecordId) {
		GoogleFileLinkSelector selector = GoogleFileLinkSelector.query()
			.withBaseFields()
			.byParentId(localFileRecordId)
			.orderByCreatedDesc();

		requireFileAccess(localFileRecordId, false);

		try {
			List<GoogleFileLink__c> linkedRecords = (List<GoogleFileLink__c>) selector.toList();
			List<GoogleFileLink__c> accessibleLinks = new GoogleFileAccessResolver().resolveReadableRecordLinks(
				linkedRecords,
				UserInfo.getUserId()
			);

			return new GoogleLocalFileLinkEnrichmentService().applyLinkedRecordAttributes(accessibleLinks);
		} catch (Exception ex) {
			Logger.error('Retrieve Linked Records (Local): ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw new GoogleLocalFileSharingException('Unable to retrieve the linked records. Please try again or contact your system administrator');
		}
	}

	private GoogleFile__c requireFileAccess(Id localFileRecordId, Boolean requireEditAccess) {
		List<GoogleFile__c> accessibleFiles = new GoogleFileAccessCheckCommand()
			.forFile(localFileRecordId)
			.forUser(UserInfo.getUserId())
			.strip();

		if (accessibleFiles.isEmpty()) {
			throw new GoogleLocalFileSharingException('You don’t have access to manage this file');
		}

		GoogleFile__c accessibleFile = accessibleFiles[0];
		if (requireEditAccess && accessibleFile.UserAccessLevel__c != 'Edit') {
			throw new GoogleLocalFileSharingException('You don’t have permission to modify this file');
		}

		return accessibleFile;
	}
}