import LightningModal from 'lightning/modal';
import { api, track, wire } from 'lwc';
import { isEmpty, showToast } from 'c/googleCloudUtils';

import deleteExistingGoogleFile from '@salesforce/apex/GoogleCloudFilesController.deleteExistingGoogleFile';

export default class GoogleCloudFileDeleteModal extends LightningModal {
	@api label;
	@api localFileRecordId;

	@track isLoading = false;

	handleDeleteCancel(event) {
		this.close('cancel');
	}

	handleDeleteConfirm(event) {
		this.isLoading = true;

		deleteExistingGoogleFile({ recordId: this.localFileRecordId })
			.then(result => {
				showToast(
					this,
					'File Deleted Successfully',
					'',
					'success'
				);

				this.close(true);
			})
			.catch(error => {
				console.error(error);
				showToast(
					this,
					'Unable to delete Existing File',
					'Please try again later or contact your System Administrator',
					'error'
				);
			})
			.finally(() => {
				this.isLoading = false;
			});
	}
}