import { api, track } from 'lwc';
import LightningModal from 'lightning/modal';

export default class GoogleCloudExistingFileAttachModal extends LightningModal {
	@api label;
	@api recordId;
	@api remainingSlots;
	@api source;

	@track hasChanges = false;
	latestAttachmentDetail;

	handleFileAttached(event) {
		this.hasChanges = true;
		this.latestAttachmentDetail = event.detail;
		this.close({
			hasChanges: true,
			detail: event.detail
		});
	}

	handleClose() {
		this.close({
			hasChanges: this.hasChanges,
			detail: this.latestAttachmentDetail
		});
	}
}