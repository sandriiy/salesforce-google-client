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
public without sharing class GoogleFileSharingCommand {
	public class GoogleFileSharingException extends Exception {}

	private final IGoogleUnitOfWork uowRef;
	private final SharingSupport support;

	public GoogleFileSharingCommand(IGoogleUnitOfWork uowRef) {
		this.uowRef = uowRef;
		this.support = new SharingSupport();
	}

	public RetrieveSharingCommand retrieveSharing() {
		return new RetrieveSharingCommand(support);
	}

	public CreateSharingCommand createSharing() {
		return new CreateSharingCommand(uowRef, support);
	}

	public DeleteSharingCommand deleteSharing() {
		return new DeleteSharingCommand(uowRef, support);
	}

	public ModifySharingCommand modifySharing() {
		return new ModifySharingCommand(uowRef, support);
	}

	private class SharingSupport {
		private final GoogleFileLinkDefaultsResolver linkDefaultsResolver = new GoogleFileLinkDefaultsResolver();

		public void validateCommonIds(Id localFileRecordId, Id shareToRecordId) {
			if (localFileRecordId == null) {
				throw new GoogleFileSharingException('File Record Id must not be null');
			}
			if (shareToRecordId == null) {
				throw new GoogleFileSharingException('Share to Record Id must not be null');
			}
		}

		public String mapUiAccessLevelToShareAccess(String uiAccessLevel) {
			if (String.isBlank(uiAccessLevel)) {
				throw new GoogleFileSharingException('Access level must not be blank');
			}

			String normalized = uiAccessLevel.trim().toLowerCase();

			if (normalized == 'viewer') {
				return 'Read';
			}
			if (normalized == 'collaborator') {
				return 'Edit';
			}

			throw new GoogleFileSharingException('Unsupported AccessLevel: ' + uiAccessLevel);
		}

		public void validateLinkShareType(String shareType) {
			String normalized = shareType == null ? null : shareType.trim();

			if (String.isBlank(normalized)) {
				throw new GoogleFileSharingException('ShareType must not be blank when provided');
			}
		}

		public void validateLinkVisibility(String visibility) {
			String normalized = visibility == null ? null : visibility.trim();

			if (String.isBlank(normalized)) {
				throw new GoogleFileSharingException('Visibility must not be blank when provided');
			}
		}

		public GoogleFile__Share buildShareRecord(Id localFileRecordId, Id shareToRecordId, String shareAccessLevel) {
			GoogleFile__Share shareRecord = new GoogleFile__Share();
			shareRecord.ParentId = localFileRecordId;
			shareRecord.UserOrGroupId = shareToRecordId;
			shareRecord.AccessLevel = shareAccessLevel;
			shareRecord.RowCause = Schema.GoogleFile__Share.RowCause.Manual;
			return shareRecord;
		}

		public List<GoogleFile__Share> findUserOrGroupShares(Id localFileRecordId, Id shareToRecordId) {
			return (List<GoogleFile__Share>) GoogleFileShareSelector.query()
				.withBaseFields()
				.byParentId(localFileRecordId)
				.byPrincipalId(shareToRecordId)
				.toList();
		}

		public List<GoogleFileLink__c> findRecordLinks(Id localFileRecordId, Id linkedRecordId) {
			return (List<GoogleFileLink__c>) GoogleFileLinkSelector.query()
				.withBaseFields()
				.byParentId(localFileRecordId)
				.byLinkedObjectId(linkedRecordId)
				.toList();
		}

		public void validateRecordLinkCreation(Id localFileRecordId, Id linkedRecordId, Id actingUserId) {
			if (findOwnedFile(localFileRecordId, actingUserId) == null) {
				throw new GoogleFileSharingException('Only owned files can be attached to records');
			}

			if (!hasReadableRecordAccess(linkedRecordId, actingUserId)) {
				throw new GoogleFileSharingException('You don’t have access to attach this file to the selected record');
			}
		}

		public GoogleFileLink__c buildRecordLink(Id localFileRecordId, Id linkedRecordId, String linkedObjectType, String source) {
			GoogleFileLink__c linkRecord = new GoogleFileLink__c(
				IsAdditionalLink__c = true,
				GoogleFileId__c = localFileRecordId,
				LinkedObjectId__c = String.valueOf(linkedRecordId),
				LinkedObjectType__c = resolveLinkedObjectType(linkedRecordId, linkedObjectType)
			);

			linkRecord.Source__c = source.trim();
			return linkDefaultsResolver.applyDefaultValues(linkRecord);
		}

		private String resolveLinkedObjectType(Id linkedRecordId, String linkedObjectType) {
			if (String.isNotBlank(linkedObjectType)) {
				return linkedObjectType.trim();
			}

			return linkedRecordId.getSObjectType().getDescribe().getName();
		}

		private GoogleFile__c findOwnedFile(Id localFileRecordId, Id ownerId) {
			return (GoogleFile__c) GoogleFileSelector.query()
				.withSpecificFields(new List<String>{ 'Id', 'OwnerId' })
				.byOwner(ownerId)
				.byId(localFileRecordId)
				.toObject();
		}

		private Boolean hasReadableRecordAccess(Id linkedRecordId, Id actingUserId) {
			if (linkedRecordId == null) {
				return false;
			}

			return new GoogleRecordAccessResolver().hasReadAccess(actingUserId, linkedRecordId);
		}

		public Boolean isUserOrGroup(Id shareToRecordId) {
			Schema.SObjectType shareToType = shareToRecordId.getSObjectType();
			return shareToType == User.SObjectType || shareToType == Group.SObjectType;
		}

		public void validateUiAccessLevel(String uiAccessLevel, String message) {
			if (String.isBlank(uiAccessLevel)) {
				throw new GoogleFileSharingException(message);
			}
		}

		public void validateLinkInputs(String uiAccessLevel, String linkVisibility) {
			if (!String.isBlank(uiAccessLevel)) {
				validateLinkShareType(uiAccessLevel);
			}

			if (!String.isBlank(linkVisibility)) {
				validateLinkVisibility(linkVisibility);
			}
		}
	}

	public class RetrieveSharingCommand {
		private final SharingSupport support;

		private final Set<Id> fileIds = new Set<Id>();
		private Boolean wantOwner = false;
		private Boolean wantGroupsAndUsers = false;
		private Boolean wantRecords = false;

		public RetrieveSharingCommand(SharingSupport support) {
			this.support = support;
		}

		public RetrieveSharingCommand forFile(Id fileId) {
			if (fileId != null) {
				this.fileIds.add(fileId);
			}

			return this;
		}

		public RetrieveSharingCommand forFiles(Set<Id> fileIds) {
			if (fileIds != null) {
				this.fileIds.addAll(fileIds);
			}

			return this;
		}

		public RetrieveSharingCommand includeOwner(Boolean include) {
			this.wantOwner = include;
			return this;
		}

		public RetrieveSharingCommand includeUsersAndGroups(Boolean include) {
			this.wantGroupsAndUsers = include;
			return this;
		}

		public RetrieveSharingCommand includeRecords(Boolean include) {
			this.wantRecords = include;
			return this;
		}

		public RetrieveSharingCommand includeAll() {
			this.wantOwner = true;
			this.wantGroupsAndUsers = true;
			this.wantRecords = true;
			return this;
		}

		public RetrieveSharingCommand includeNone() {
			this.wantOwner = false;
			this.wantGroupsAndUsers = false;
			this.wantRecords = false;
			return this;
		}

		public Map<Id, GoogleSharingInfoDTO> fetch() {
			if (fileIds.isEmpty()) {
				return new Map<Id, GoogleSharingInfoDTO>();
			}

			List<GoogleFile__c> localFiles = GoogleFileSelector.query()
				.withAllFields()
				.withLatestVersionSubquery()
				.byIds(fileIds)
				.toList();

			Map<Id, GoogleSharingInfoDTO> sharingInfoByFileId = new Map<Id, GoogleSharingInfoDTO>();

			for (GoogleFile__c localFile : localFiles) {
				GoogleSharingInfoDTO fileSharingInfo = new GoogleSharingInfoDTO();
				fileSharingInfo.fileId = localFile.Id;
				fileSharingInfo.owner = getFileOwner(localFile);
				fileSharingInfo.entitiesSharedTo = getFileEntitiesSharedTo(localFile);
				fileSharingInfo.recordsSharedTo = getFileRecordsSharedTo(localFile);
				sharingInfoByFileId.put(localFile.Id, fileSharingInfo);
			}

			return sharingInfoByFileId;
		}

		private User getFileOwner(GoogleFile__c localFile) {
			if (!wantOwner || localFile.OwnerId == null) {
				return null;
			}

			List<User> owner = (List<User>) GoogleUserSelector.query()
				.withContactFields()
				.byUserId(localFile.OwnerId)
				.limitTo(1)
				.toList();

			return owner.isEmpty() ? null : owner[0];
		}

		private List<GoogleFile__Share> getFileEntitiesSharedTo(GoogleFile__c localFile) {
			if (!wantGroupsAndUsers) {
				return new List<GoogleFile__Share>();
			}

			return (List<GoogleFile__Share>) GoogleFileShareSelector.query()
				.withPrincipalName()
				.byParentId(localFile.Id)
				.excludingPrincipalId(localFile.OwnerId)
				.toList();
		}

		private List<GoogleFileLink__c> getFileRecordsSharedTo(GoogleFile__c localFile) {
			if (!wantRecords) {
				return new List<GoogleFileLink__c>();
			}

			return (List<GoogleFileLink__c>) GoogleFileLinkSelector.query()
				.withBaseFields()
				.byParentId(localFile.Id)
				.toList();
		}
	}

	public class CreateSharingCommand {
		private final IGoogleUnitOfWork uowRef;
		private final SharingSupport support;

		private Id localFileRecordId;
		private String linkedObjectType;
		private String uiAccessLevel;
		private String source;
		private Id shareToRecordId;

		public CreateSharingCommand(IGoogleUnitOfWork uowRef, SharingSupport support) {
			this.uowRef = uowRef;
			this.support = support;
		}

		public CreateSharingCommand forFile(Id localFileRecordId) {
			this.localFileRecordId = localFileRecordId;
			return this;
		}

		public CreateSharingCommand shareTo(String linkedObjectType, Id shareToRecordId) {
			this.linkedObjectType = linkedObjectType;
			this.shareToRecordId = shareToRecordId;
			return this;
		}

		public CreateSharingCommand forUser(Id userId) {
			this.shareToRecordId = userId;
			return this;
		}

		public CreateSharingCommand forGroup(Id groupId) {
			this.shareToRecordId = groupId;
			return this;
		}

		public CreateSharingCommand withUiAccessLevel(String uiAccessLevel) {
			this.uiAccessLevel = uiAccessLevel;
			return this;
		}

		public CreateSharingCommand withSource(String source) {
			this.source = source;
			return this;
		}

		public Id apply() {
			return applyWithResult().recordId;
		}

		public GoogleFileSharingApplyResultDTO applyWithResult() {
			support.validateCommonIds(localFileRecordId, shareToRecordId);

			if (support.isUserOrGroup(shareToRecordId)) {
				return createUserOrGroupSharing();
			}

			return createRecordLink();
		}

		public void validateCreation() {
			support.validateCommonIds(localFileRecordId, shareToRecordId);

			if (support.isUserOrGroup(shareToRecordId)) {
				support.mapUiAccessLevelToShareAccess(uiAccessLevel);
				return;
			}

			support.validateRecordLinkCreation(localFileRecordId, shareToRecordId, UserInfo.getUserId());
		}

		private GoogleFileSharingApplyResultDTO createUserOrGroupSharing() {
			String shareAccessLevel = support.mapUiAccessLevelToShareAccess(uiAccessLevel);
			GoogleFile__Share shareRecord = support.buildShareRecord(
				localFileRecordId,
				shareToRecordId,
				shareAccessLevel
			);

			Logger.info('File Sharing Create: File ID: ' + localFileRecordId + '; Share To: ' + shareToRecordId + '; Access: ' + shareAccessLevel).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

			uowRef.registerNew(shareRecord);
			uowRef.commitWork(true);

			return new GoogleFileSharingApplyResultDTO(shareRecord.Id, true);
		}

		private GoogleFileSharingApplyResultDTO createRecordLink() {
			support.validateRecordLinkCreation(localFileRecordId, shareToRecordId, UserInfo.getUserId());

			List<GoogleFileLink__c> existingLinks = support.findRecordLinks(localFileRecordId, shareToRecordId);
			if (!existingLinks.isEmpty()) {
				return new GoogleFileSharingApplyResultDTO(existingLinks[0].Id, false);
			}

			GoogleFileLink__c linkRecord = support.buildRecordLink(localFileRecordId, shareToRecordId, linkedObjectType, source);
			Logger.info('File Sharing Create (Record Link): File ID: ' + localFileRecordId + '; Share To: ' + shareToRecordId + '; ShareType: ' + linkRecord.ShareType__c + '; Visibility: ' + linkRecord.Visibility__c).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

			uowRef.registerNew(linkRecord);
			uowRef.commitWork(true);
			return new GoogleFileSharingApplyResultDTO(linkRecord.Id, true);
		}
	}

	public class DeleteSharingCommand {
		private final IGoogleUnitOfWork uowRef;
		private final SharingSupport support;

		private Id localFileRecordId;
		private Id shareToRecordId;

		public DeleteSharingCommand(IGoogleUnitOfWork uowRef, SharingSupport support) {
			this.uowRef = uowRef;
			this.support = support;
		}

		public DeleteSharingCommand forFile(Id localFileRecordId) {
			this.localFileRecordId = localFileRecordId;
			return this;
		}

		public DeleteSharingCommand shareTo(Id shareToRecordId) {
			this.shareToRecordId = shareToRecordId;
			return this;
		}

		public void apply() {
			support.validateCommonIds(localFileRecordId, shareToRecordId);

			Boolean isUserOrGroupTarget = support.isUserOrGroup(shareToRecordId);

			Logger.info('File Sharing Delete: File ID: ' + localFileRecordId + '; Share To: ' + shareToRecordId + '; Target Type: ' + (isUserOrGroupTarget ? 'UserOrGroup' : 'Record')).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

			if (isUserOrGroupTarget) {
				deleteUserOrGroupSharing();
			} else {
				deleteRecordLinkSharing();
			}

			uowRef.commitWork(true);
		}

		private void deleteUserOrGroupSharing() {
			List<GoogleFile__Share> sharesToDelete = support.findUserOrGroupShares(localFileRecordId, shareToRecordId);
			if (sharesToDelete.isEmpty()) {
				throw new GoogleFileSharingException('No matching user/group share found for this sharing');
			}

			for (GoogleFile__Share shareRecord : sharesToDelete) {
				uowRef.registerDeleted(shareRecord);
			}
		}

		private void deleteRecordLinkSharing() {
			List<GoogleFileLink__c> linksToDelete = support.findRecordLinks(localFileRecordId, shareToRecordId);
			if (linksToDelete.isEmpty()) {
				throw new GoogleFileSharingException('No matching record link found for this sharing');
			}

			for (GoogleFileLink__c linkRecord : linksToDelete) {
				uowRef.registerDeleted(linkRecord);
			}
		}
	}

	public class ModifySharingCommand {
		private final IGoogleUnitOfWork uowRef;
		private final SharingSupport support;

		private Id localFileRecordId;
		private Id shareToRecordId;

		private String uiAccessLevel;
		private String linkVisibility;

		public ModifySharingCommand(IGoogleUnitOfWork uowRef, SharingSupport support) {
			this.uowRef = uowRef;
			this.support = support;
		}

		public ModifySharingCommand forFile(Id localFileRecordId) {
			this.localFileRecordId = localFileRecordId;
			return this;
		}

		public ModifySharingCommand shareTo(Id shareToRecordId) {
			this.shareToRecordId = shareToRecordId;
			return this;
		}

		public ModifySharingCommand withUiAccessLevel(String uiAccessLevel) {
			this.uiAccessLevel = uiAccessLevel;
			return this;
		}

		public ModifySharingCommand withVisibility(String linkVisibility) {
			this.linkVisibility = linkVisibility;
			return this;
		}

		public void apply() {
			support.validateCommonIds(localFileRecordId, shareToRecordId);

			Boolean isUserOrGroupTarget = support.isUserOrGroup(shareToRecordId);

			Logger.info('File Sharing Modify: File ID: ' + localFileRecordId + '; Share To: ' + shareToRecordId + '; Target Type: ' + (isUserOrGroupTarget ? 'UserOrGroup' : 'Record')).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

			if (isUserOrGroupTarget) {
				applyUserOrGroupModification();
			} else {
				applyRecordLinkModification();
			}
		}

		private void applyUserOrGroupModification() {
			support.validateUiAccessLevel(uiAccessLevel, 'Access level is required for modifying user/group shares.');

			List<GoogleFile__Share> sharesToModify = support.findUserOrGroupShares(localFileRecordId, shareToRecordId);
			if (sharesToModify.isEmpty()) {
				throw new GoogleFileSharingException('Matching user/group share not found');
			}

			String mappedAccessLevel = support.mapUiAccessLevelToShareAccess(uiAccessLevel);

			Logger.info('File Sharing Modify (User/Group): File ID: ' + localFileRecordId + '; Share To: ' + shareToRecordId + '; Access: ' + mappedAccessLevel).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

			for (GoogleFile__Share shareRecord : sharesToModify) {
				shareRecord.AccessLevel = mappedAccessLevel;
				uowRef.registerDirty(shareRecord);
			}

			uowRef.commitWork(true);
		}

		private void applyRecordLinkModification() {
			if (String.isBlank(uiAccessLevel) && String.isBlank(linkVisibility)) {
				throw new GoogleFileSharingException(
					'Provide at least access level or visibility for modifying record links'
				);
			}

			List<GoogleFileLink__c> linksToModify = support.findRecordLinks(localFileRecordId, shareToRecordId);
			if (linksToModify.isEmpty()) {
				throw new GoogleFileSharingException('Matching GoogleFileLink__c not found');
			}

			support.validateLinkInputs(uiAccessLevel, linkVisibility);

			Logger.info('File Sharing Modify (Record Link): File ID: ' + localFileRecordId + '; Share To: ' + shareToRecordId +
				(String.isBlank(uiAccessLevel) ? '' : '; ShareType: ' + uiAccessLevel) +
				(String.isBlank(linkVisibility) ? '' : '; Visibility: ' + linkVisibility)
			).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

			for (GoogleFileLink__c linkRecord : linksToModify) {
				applyLinkUpdates(linkRecord, uiAccessLevel, linkVisibility);
				uowRef.registerDirty(linkRecord);
			}

			uowRef.commitWork(true);
		}

		private void applyLinkUpdates(GoogleFileLink__c linkRecord, String uiAccessLevel, String linkVisibility) {
			if (!String.isBlank(uiAccessLevel)) {
				linkRecord.ShareType__c = uiAccessLevel;
			}
			if (!String.isBlank(linkVisibility)) {
				linkRecord.Visibility__c = linkVisibility;
			}
		}
	}
}