import { LightningElement, api, track } from 'lwc';
import { isEmpty, showToast, findIconForRecordType, findRoleForAccessType } from 'c/googleCloudUtils';

import fetchSharingDetails from '@salesforce/apex/GoogleCloudFilesSharingController.fetchSharingDetails';
import createNewSharing from '@salesforce/apex/GoogleCloudFilesSharingController.createNewSharing';
import modifySharingVisibility from '@salesforce/apex/GoogleCloudFilesSharingController.modifyExistingSharingVisibility';
import modifySharingAccess from '@salesforce/apex/GoogleCloudFilesSharingController.modifyExistingSharingAccess';
import deleteSharing from '@salesforce/apex/GoogleCloudFilesSharingController.deleteExistingSharing';

export default class GoogleCloudFileSharing extends LightningElement {
	@api localFileRecordId;

	@track selectFromObjectApiName;
	@track selectForAccessLevel;
	@track selectedShareToRecordId;
	@track sharingDetails;
	@track isLoading = true;

	connectedCallback() {
		this.setDefaultValues();
		this.loadLocalFileSharing();
	}

	handleFromObjectChange(event) {
		this.selectFromObjectApiName = event.detail.value;
	}

	handleAccessLevelChange(event) {
		this.selectForAccessLevel = event.detail.value;
	}

	handleShareRecordChange(event) {
		this.selectedShareToRecordId = event.detail.recordId;
	}

	async handleNewSharingClick(event) {
		this.isLoading = true;

		await createNewSharing({
			localFileRecordId: this.localFileRecordId,
			shareToObjectApiName: this.selectFromObjectApiName,
			shareToRecordId: this.selectedShareToRecordId,
			uiAccessLevel: this.selectForAccessLevel
		}).catch(error => {
			console.error(error);
			showToast(
				this,
				'Unable to Share File',
				'This file couldn’t be shared with this user. If you’re not the owner, please ask the file owner to share it',
				'warning'
			);
		});

		this.loadLocalFileSharing();
		this.setDefaultValues();
	}

	handleSharingRoleChange(event) {
		const row = event.target.closest('[data-target]');
    	const recordId = row?.dataset.target;
		const newRole = event.detail.value;

		modifySharingAccess({
			localFileRecordId: this.localFileRecordId,
			shareToRecordId: recordId,
			uiAccessLevel: newRole
		}).catch(error => {
			showToast(
				this,
				'Unable to Modify Sharing',
				'Unable to update existing sharing. Please try again or contact your System Administrator',
				'warning'
			);
		});

		this.setNewEntityRole(recordId, newRole);
	}

	handleCustomAccessChange(event) {
		const row = event.target.closest('[data-target]');
    	const recordId = row?.dataset.target;
		const isChecked = event.detail.checked;
		const visibility = isChecked ? 'AllUsers' : 'InternalUsers';

		modifySharingVisibility({
			localFileRecordId: this.localFileRecordId,
			shareToRecordId: recordId,
			visibility: visibility
		}).catch(error => {
			showToast(
				this,
				'Unable to Modify Sharing',
				'Unable to update existing sharing. Please try again or contact your System Administrator',
				'warning'
			);
		});

		this.setNewRecordVisibility(recordId, visibility);
	}

	async handleSharingRemoveClick(event) {
		this.isLoading = true;

		const row = event.target.closest('[data-target]');
    	const recordId = row?.dataset.target;
		if (!isEmpty(recordId)) {
			await deleteSharing({ 
				localFileRecordId: this.localFileRecordId,
				shareToRecordId: recordId
			}).catch(error => {
				showToast(
					this,
					'Unable to Delete Sharing',
					'Unable to remove existing sharing. Please try again or contact your System Administrator',
					'warning'
				);
			});
		}

		this.loadLocalFileSharing();
		this.setDefaultValues();
	}

	loadLocalFileSharing() {
		fetchSharingDetails({ localFileRecordId: this.localFileRecordId })
			.then(result => {
				this.sharingDetails = this.normalizeFileSharingDetails(result);
			}).catch(error => {
				showToast(
					this,
					'Unable to retrieve File Version',
					'Please try again later or contact your System Administrator',
					'error'
				);
			}).finally(() => {
				this.isLoading = false;
			});
	}

	normalizeFileSharingDetails(fileSharings) {
		const idPrefix = (id) => (id || '').substring(0, 3);
		const isUser = (id) => idPrefix(id) === '005';
		const isGroup = (id) => idPrefix(id) === '00G';

		const owner = {
			Id: fileSharings?.owner?.Id,
			Name: fileSharings?.owner?.Name || 'Owner',
		};

		const principals = (fileSharings?.entitiesSharedTo || []).map(s => {
			const kind = isUser(s.UserOrGroupId) ? 'User' : (isGroup(s.UserOrGroupId) ? 'Group' : 'Principal');
			return {
				Id: s.Id,
				targetId: s.UserOrGroupId,
				displayName: s.UserOrGroup?.Name || s.UserOrGroupId,
				kindLabel: kind,
				icon: isUser(s.UserOrGroupId) ? 'standard:user' : 'standard:groups',
				role: findRoleForAccessType(s.AccessLevel)
			};
		});

		const recordLinks = (fileSharings?.recordsSharedTo || []).map(r => ({
			Id: r.Id,
			displayName: r.LinkedObjectId__c,
			targetId: r.LinkedObjectId__c,
			kindLabel: r.LinkedObjectType__c || 'Record',
			customerAccess: r.Visibility__c === 'AllUsers' ? true : false,
			icon: findIconForRecordType(r.LinkedObjectType__c),
			role: findRoleForAccessType(r.ShareType__c)
		}));

		return { owner, principals, recordLinks };
	}

	setDefaultValues() {
		this.selectFromObjectApiName = 'User';
		this.selectForAccessLevel = 'Viewer';
		this.selectedShareToRecordId = undefined;
	}

	setNewRecordVisibility(targetId, newVisibility) {
		const updatedDetails = { ...this.sharingDetails };
		if (Array.isArray(updatedDetails.recordLinks)) {
			updatedDetails.recordLinks = updatedDetails.recordLinks.map(link => {
				if (link.targetId === targetId) {
					return {
						...link,
						customerAccess: newVisibility === 'AllUsers' ? true : false,
					};
				}
				return link;
			});
		}

		this.sharingDetails = updatedDetails;
	}

	setNewEntityRole(targetId, newRole) {
		const updatedDetails = { ...this.sharingDetails };
		if (Array.isArray(updatedDetails.principals)) {
			updatedDetails.principals = updatedDetails.principals.map(principal => {
				if (principal.targetId === targetId) {
					return {
						...principal,
						role: newRole
					};
				}
				return principal;
			});
		}

		if (Array.isArray(updatedDetails.recordLinks)) {
			updatedDetails.recordLinks = updatedDetails.recordLinks.map(link => {
				if (link.targetId === targetId) {
					return {
						...link,
						role: newRole
					};
				}
				return link;
			});
		}

		this.sharingDetails = updatedDetails;
	}

	get readyToShare() {
		return (
			!isEmpty(this.localFileRecordId) &&
			!isEmpty(this.selectFromObjectApiName) &&
			!isEmpty(this.selectForAccessLevel) &&
			!isEmpty(this.selectedShareToRecordId)
		);
	}

	get shareToOptions() {
        return [
            { label: 'Users', value: 'User' },
            { label: 'Groups', value: 'Group' },
        ];
    }

	get shareRoleOptions() {
		return [
			{ label: 'Viewer', value: 'Viewer' },
			{ label: 'Collaborator', value: 'Collaborator' }
		];
	}

	get shareRecordOptions() {
		return [
			{ label: 'Viewer', value: 'Viewer' },
			{ label: 'Set by Record', value: 'InferredFromRecord' }
		];
	}

	get ownerRoleOptions() {
		return [
			{ label: 'Owner', value: 'Owner' }
		];
	}

	get selectFromObjectPlaceholder() {
		if (this.selectFromObjectApiName === 'User') {
			return 'Search Users...';
		} else {
			return 'Search Groups..';
		}
	}

	get selectFromObjectFilters() {
		if (this.selectFromObjectApiName === 'User') {
			return {
				criteria: [
					{
						fieldPath: 'IsActive',
						operator: 'eq',
						value: true
					},
					{
						fieldPath: 'Id',
						operator: 'nin',
						value: this.userIdsToExclude
					}
				],
				filterLogic: '1 AND 2'
			};
		} else {
			return {
				criteria: [
					{
						fieldPath: 'Type',
						operator: 'in',
						value: ['Regular', 'Queue']
					},
					{
						fieldPath: 'Id',
						operator: 'nin',
						value: this.groupIdsToExclude
					}
				],
				filterLogic: '1 AND 2'
			};
		}
	}

	get userIdsToExclude() {
		const ids = new Set();

		if (this.sharingDetails?.owner?.Id) {
			ids.add(this.sharingDetails.owner.Id);
		}

		if (Array.isArray(this.sharingDetails?.principals)) {
			this.sharingDetails.principals.forEach(p => {
				if (p.kindLabel === 'User' && p.targetId) {
					ids.add(p.targetId);
				}
			});
		}

		return [...ids];
	}

	get groupIdsToExclude() {
		const ids = new Set();

		if (Array.isArray(this.sharingDetails?.principals)) {
			this.sharingDetails.principals.forEach(p => {
				if (p.kindLabel === 'Group' && p.targetId) {
					ids.add(p.targetId);
				}
			});
		}

		return [...ids];
	}
}