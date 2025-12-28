import { LightningElement, api, track, wire } from 'lwc';
import { isEmpty, showToast, formatFileSize } from 'c/googleCloudUtils';
import { refreshApex } from '@salesforce/apex';

import getLocalFileVersions from '@salesforce/apex/GoogleCloudFilesViewController.retrieveLocalGoogleFileVersions';

export default class GoogleCloudFileVersions extends LightningElement {
	@api recordId;

	@track isLoading = false;
	@track wiredFileVersions;
	@track allVersions = [];

	@api async refresh() {
		this.isLoading = true;
		await refreshApex(this.wiredFileVersions);
		this.isLoading = false;
	}

	@wire(getLocalFileVersions, { localFileRecordId: "$recordId" })
	wireFileVersions(result) {
		const { data, error } = result;
		this.wiredFileVersions = result;

		if (data) {
			this.allVersions = this.buildVersionViewModels(data);
			this.notifyLatestFileVersion(data);
		}
	}

	handleVersionClick(event) {
		let previewComponent = this.refs.filePreviewModal;
		let parentContainer = event.target.closest('li[data-id]');
		let parentContainerId = parentContainer.getAttribute('data-id');
		previewComponent.openVersion(this.recordId, parentContainerId);
	}

	buildVersionViewModels(versions) {
		if (!Array.isArray(versions)) {
			return [];
		}

		return versions.map((record, index) => {
			const id = record.Id;
			const size = record.Size__c;
			const type = record.Type__c;

			const createdByName = record.CreatedBy?.Name || 'Unknown';

			const createdDt = record.CreatedDate ? new Date(record.CreatedDate) : null;
			const createdDateLabel = createdDt ? createdDt.toLocaleDateString() : '';
			const createdTimeLabel = createdDt ? createdDt.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }): '';
			const meta = `${createdByName} | ${type} | ${formatFileSize(size)}`;
			const name = `Version ${versions.length - index}`;

			return {
				id,
				name,
				meta,
				createdDateLabel,
				createdTimeLabel,
				hasWarning: !isEmpty(record.PublicLinkPermissionId__c)
			};
		});
	}

	notifyLatestFileVersion(versions) {
		if (!Array.isArray(versions) || versions.length === 0) {
			return;
		}

		const latestVersion = versions.reduce((currentLatest, candidate) => {
			const latestDate = new Date(currentLatest.CreatedDate);
			const candidateDate = new Date(candidate.CreatedDate);
			return candidateDate > latestDate ? candidate : currentLatest;
		}, versions[0]);

		const evt = new CustomEvent('latestversionselected', {
			detail: {
				version: latestVersion
			},
			bubbles: true,
			composed: true
		});

		this.dispatchEvent(evt);
	}
}