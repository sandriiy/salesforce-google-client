import LightningModal from 'lightning/modal';
import { api, track, wire } from 'lwc';
import { isEmpty, showToast } from 'c/googleCloudUtils';

export default class GoogleCloudFileDetailsModal extends LightningModal {
	@api localFileVersionId;
	@api isReadOnlyAccess;
	@api label;

	@track isLoading = true;

	async handleFlowStatusChange(event) {
		if (event.detail.status === 'STARTED') {
			this.isLoading = false;
		} else if (event.detail.status === 'ERROR') {
			this.isLoading = false;
			showToast(
				this,
				'Unable to save File Details',
				'Please try again or contact your System Administrator',
				'error'
			);
		} else if (event.detail.status == 'FINISHED') {
			showToast(
				this,
				'File details saved successfully',
				'',
				'success'
			);

			this.close(true);
		}
	}

	get flowInputVariables() {
		return [
			{
				name: 'fileVersionId',
				type: 'String',
				value: this.localFileVersionId
			},
			{
				name: 'IsReadOnly',
				type: 'Boolean',
				value: this.isReadOnlyAccess
			}
		];
	}
}