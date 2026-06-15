import { api, LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

import retrieveLinkedRecords from '@salesforce/apex/GoogleCloudFilesSharingController.retrieveLinkedRecords';

import { findIconForRecordType, findRoleForAccessType, isEmpty, normalizeError } from 'c/googleCloudUtils';

const DEFAULT_ERROR_MESSAGE = 'Unable to retrieve the linked records.';

export default class GoogleCloudFileLinkedRecords extends NavigationMixin(LightningElement) {
	@api localFileRecordId;

	@track records = [];
	@track errorMessage = '';
	@track isLoading = false;

	connectedCallback() {
		this.loadRecords();
	}

	@api
	async refresh() {
		await this.loadRecords();
	}

	async loadRecords() {
		if (!this.localFileRecordId) {
			this.records = [];
			this.errorMessage = '';
			this.isLoading = false;
			return;
		}

		this.isLoading = true;
		this.errorMessage = '';

		try {
			const result = await retrieveLinkedRecords({ localFileRecordId: this.localFileRecordId });
			this.records = (Array.isArray(result) ? result : []).map(record => ({
				id: record.Id,
				targetId: record.LinkedObjectId__c,
				displayName: record.LinkedObjectName__c || record.LinkedObjectId__c,
				typeLabel: record.LinkedObjectType__c || 'Record',
				iconName: findIconForRecordType(record.LinkedObjectType__c),
				accessLabel: findRoleForAccessType(record.ShareType__c),
				visibilityLabel: record.Visibility__c === 'AllUsers' ? 'All users' : 'Internal users'
			}));
		} catch (error) {
			this.records = [];
			this.errorMessage = normalizeError(error) || DEFAULT_ERROR_MESSAGE;
		} finally {
			this.isLoading = false;
		}
	}

	handleOpenRecord(event) {
		const recordId = event.detail.value;
		if (!recordId) {
			return;
		}

		this[NavigationMixin.Navigate]({
			type: 'standard__recordPage',
			attributes: {
				recordId,
				actionName: 'view'
			}
		});
	}

	get badgeText() {
		return this.hasRecords ? `(${String(this.records.length)})` : '';
	}

	get hasRecords() {
		return this.records.length > 0;
	}

	get hasError() {
		return !isEmpty(this.errorMessage);
	}
}