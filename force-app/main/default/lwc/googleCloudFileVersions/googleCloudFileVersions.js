import { LightningElement, api, track, wire } from 'lwc';
import { isEmpty, formatFileSize, getFileIcon } from 'c/googleCloudUtils';
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
		const { data } = result;
		this.wiredFileVersions = result;

		if (data) {
			this.allVersions = this.buildVersionViewModels(data);
			this.notifyLatestFileVersion(data);
		}
	}

	handleVersionClick(event) {
		this.refs.filePreviewModal.openVersion(this.recordId, event.detail.value);
	}

	buildVersionViewModels(versions) {
		if (!Array.isArray(versions)) {
			return [];
		}

		return versions.map((record, index) => {
			const id = record.Id;
			const size = record.Size__c;
			const fileName = record.Name || 'Untitled';

			const createdDt = record.CreatedDate ? new Date(record.CreatedDate) : null;
			const createdDateLabel = createdDt ? createdDt.toLocaleDateString() : '';
			const sizeLabel = formatFileSize(size);
			const name = `Version ${versions.length - index}`;

			return {
				id,
				name,
				fileName,
				iconName: getFileIcon(fileName),
				createdDateLabel,
				sizeLabel,
				warningMessage: !isEmpty(record.PublicLinkPermissionId__c)
					? 'This version contains a public link. For security, consider removing it'
					: '',
				detailVariant: !isEmpty(record.PublicLinkPermissionId__c) ? 'warning' : 'default'
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

	get badgeText() {
		return this.allVersions ? `(${String(this.allVersions.length)})` : '';
	}
}