import LightningModal from 'lightning/modal';
import { api } from 'lwc';

import { DEFAULT_FAILED_DOWNLOAD_MESSAGE, normalizeError, showToast } from 'c/googleCloudUtils';
import { downloadAs } from 'c/googleCloudDownloadUtils';

import retrieveDownloadAsOptions from '@salesforce/apex/GoogleCloudFilesController.retrieveDownloadAsOptions';

const MODAL_FILE_NAME_MAX_LENGTH = 40;

export default class GoogleCloudFileDownloadAsModal extends LightningModal {
	@api label = 'Download file as';
	@api fileName;
	@api localFileVersionId;

	isLoading = false;
	selectedMimeType;
	downloadOptions = [];

	async connectedCallback() {
		await this.initializeDownloadOptions();
	}

	handleSelectionChange(event) {
		this.selectedMimeType = event.detail.value;
	}

	handleCancel() {
		this.close(false);
	}

	async handleDownload() {
		if (!this.selectedOption || !this.localFileVersionId) {
			return;
		}

		this.isLoading = true;

		try {
			await downloadAs(this.localFileVersionId, {
				exportMimeType: this.selectedOption.mimeType,
				fileName: this.selectedOption.fileName,
				mimeType: this.selectedOption.mimeType
			});

			this.close(true);
		} catch (error) {
			showToast(
				this,
				'Unable to download File Version',
				DEFAULT_FAILED_DOWNLOAD_MESSAGE,
				'error'
			);
		} finally {
			this.isLoading = false;
		}
	}

	async initializeDownloadOptions() {
		if (!this.localFileVersionId) {
			return;
		}

		this.isLoading = true;

		try {
			const downloadOptions = await retrieveDownloadAsOptions({ localGoogleFileVersionId: this.localFileVersionId });
			this.downloadOptions = Array.isArray(downloadOptions) ? downloadOptions : [];
			this.selectedMimeType = this.downloadOptions.length > 0 ? this.downloadOptions[0].mimeType : null;
		} catch (error) {
			showToast(
				this,
				'Unable to load download formats',
				normalizeError(error),
				'error'
			);
		} finally {
			this.isLoading = false;
		}
	}

	get radioOptions() {
		return this.downloadOptions.map((option) => ({
			label: option.label,
			value: option.mimeType
		}));
	}

	get selectedOption() {
		return this.downloadOptions.find((option) => option.mimeType === this.selectedMimeType) || null;
	}

	get isDownloadDisabled() {
		return !this.selectedOption;
	}

	get hasDownloadOptions() {
		return this.downloadOptions.length > 0;
	}

	get modalLabel() {
		if (this.fileName) {
			return `Download ${this.fileName} as`;
		}

		return this.label || 'Download file as';
	}
}