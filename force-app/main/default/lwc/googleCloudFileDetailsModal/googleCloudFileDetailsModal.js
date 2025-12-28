import LightningModal from 'lightning/modal';
import { api, track, wire } from 'lwc';
import { isEmpty, showToast } from 'c/googleCloudUtils';

export default class GoogleCloudFileDetailsModal extends LightningModal {
	@api localFileVersionId;
	@api label;

	@track isLoading = true;
	@track originalExtension;

	handleFormSubmit(event) {
		this.isLoading = true;
		let form = this.refs.form;
		this.validateFileExtension();
		form.submit();
	}

	handleFormCancel(event) {
		this.close(false);
	}

	handleFormSuccess(event) {
		showToast(
			this,
			'File details saved successfully',
			'',
			'success'
		);

		this.close(true);
	}

	handleFormError(event) {
		showToast(
			this,
			'Unable to save File Details',
			'Please try again or contact your System Administrator',
			'error'
		);
	}

	handleFormLoad(event) {
		this.isLoading = false;
		this.extractFileExtension(event);
	}

	extractFileExtension(event) {
		const record = event.detail.records?.[this.localFileVersionId];
        const originalName = record?.fields?.Name?.value;

		if (originalName) {
			const lastDotIndex = originalName.lastIndexOf('.');
			if (lastDotIndex <= 0 || lastDotIndex === originalName.length - 1) {
				return null;
			}

        	this.originalExtension = originalName.substring(lastDotIndex + 1);
		}
	}

	validateFileExtension() {
		const nameInput = this.template.querySelector(
            'lightning-input-field[data-field="Name"]'
        );

        if (nameInput) {
			let currentName = (nameInput.value || '').trim();

			if (currentName && this.originalExtension) {
				const lastDot = currentName.lastIndexOf('.');

				let baseName;
				if (lastDot > 0) {
					baseName = currentName.substring(0, lastDot);
				} else {
					baseName = currentName;
				}

				nameInput.value = `${baseName}.${this.originalExtension}`;
			} else {
				nameInput.value = `Untitled.${this.originalExtension}`;
			}
		}
	}
}