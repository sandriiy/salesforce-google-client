import { LightningElement, api, track, wire } from 'lwc';
import { isEmpty, showToast } from 'c/googleCloudUtils';

import retrieveLocalGoogleFileVersionById from '@salesforce/apex/GoogleCloudFilesController.retrieveLocalGoogleFileVersionById';
import createNewPublicLink from '@salesforce/apex/GoogleCloudFilesSharingController.createNewPublicLink';
import deleteExistingPublicLink from '@salesforce/apex/GoogleCloudFilesSharingController.deleteExistingPublicLink';

export default class GoogleCloudFilePublicLink extends LightningElement {
	@api localFileVersionId;

	@track localFileVersionRecord;
    @track expirationOn;
    @track datetime;
	@track publicLink;
	@track isLoading = true;

	connectedCallback() {
		this.loadLocalFileVersion();
	}

	handleExpirationToggle(event) {
		let isEnabled = event.target.checked;
		this.expirationOn = isEnabled;
		this.datetime = undefined;
	}

	handleExpirationDatetime(event) {
		let selectedDateTime = event.target.value;
		this.datetime = selectedDateTime;
	}

	handlePublicLinkCreate(event) {
		if (!this.isValidExpirationDate()) return;

		this.isLoading = true;
		createNewPublicLink({ localFileVersionId: this.localFileVersionId, expirationDate: this.datetime })
			.then(result => {
				this.publicLink = result.PublicLink__c;
				this.expirationOn = isEmpty(this.datetime) ? false : true;
			})
			.catch(error => {
				console.error(error);
				showToast(
					this,
					'Unable to create Public Link',
					'Please try again later or contact your System Administrator',
					'error'
				);
			})
			.finally(() => {
				this.isLoading = false;
			});
	}

	handlePublicLinkDelete(event) {
		this.isLoading = true;
		deleteExistingPublicLink({ localFileVersionId: this.localFileVersionId })
			.then(result => {
				this.clearPublicLinkInfo();
			})
			.catch(error => {
				console.error(error);
				showToast(
					this,
					'Unable to delete Public Link',
					'Please try again later or contact your System Administrator',
					'error'
				);
			})
			.finally(() => {
				this.isLoading = false;
			});
	}

	loadLocalFileVersion() {
		retrieveLocalGoogleFileVersionById({ localGoogleFileVersionId: this.localFileVersionId })
			.then(result => {
				this.localFileVersionRecord = result;
				this.datetime = this.localFileVersionRecord.PublicLinkExpirationDate__c;
				this.publicLink = this.localFileVersionRecord.PublicLink__c;
				this.expirationOn = isEmpty(this.datetime) ? false : true;
			})
			.catch(error => {
				console.error(error);
				showToast(
					this,
					'Unable to retrieve File Version',
					'Please try again later or contact your System Administrator',
					'error'
				);
			})
			.finally(() => {
				this.isLoading = false;
			});
	}

	clearPublicLinkInfo() {
		this.publicLink = undefined;
		this.datetime = undefined;
		this.expirationOn = true;
		this.localFileVersionRecord.PublicLinkExpirationDate__c = null;
		this.localFileVersionRecord.PublicLinkPermissionId__c = null;
		this.localFileVersionRecord.PublicLink__c = null;
	}

	isValidExpirationDate() {
		const input = this.refs.expirationDatetime;
		
		let inputDate = new Date(this.datetime);
		const now = new Date();
		const maxDate = new Date();
		maxDate.setFullYear(maxDate.getFullYear() + 1);

		if (inputDate <= now) {
			input.setCustomValidity('Date/time must be in the future');
        	input.reportValidity(); 

			return false;
		} else if (inputDate > maxDate) {
			input.setCustomValidity('Date/time must not be more than a year');
        	input.reportValidity(); 

			return false;
		}

		input.setCustomValidity('');
        input.reportValidity(); 
		return true;
	}

    get dateTimeDisabled() {
        return !this.expirationOn || this.publicLinkExists;
    }

	get publicLinkExists() {
		return !isEmpty(this.publicLink);
	}
}