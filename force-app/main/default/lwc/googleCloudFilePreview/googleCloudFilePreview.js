import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

import { isEmpty, showToast, normalizeError, getFileIcon } from 'c/googleCloudUtils';
import { BIG_FILE_SIZE } from 'c/googleCloudDownloadUtils';
import { download, downloadInChunks } from 'c/googleCloudDownloadUtils';
import { 
	DEFAULT_PREVIEW_UNAVAILABILITY_MESSAGE, 
	DEFAULT_FAILED_DOWNLOAD_MESSAGE,
	DEFAULT_ACCESS_RESTRICTED_MESSAGE,
	DEFAULT_FILE_NAME,
	DEFAULT_FILE_ICON_TYPE 
} from 'c/googleCloudUtils';

import pdfjs from '@salesforce/resourceUrl/GoogleCloudPreviewRender';

import GoogleCloudFilePublicLinkModal from 'c/googleCloudFilePublicLinkModal';
import GoogleCloudFileDetailsModal from 'c/googleCloudFileDetailsModal';
import GoogleCloudFileDeleteModal from 'c/googleCloudFileDeleteModal';
import GoogleCloudFileUploadModal from 'c/googleCloudUploaderModal';
import GoogleCloudFileSharingModal from 'c/googleCloudFileSharingModal';

import { navigateToByAttributes, isExperienceCloudContext } from 'c/googleCloudCrossPlatformUtils';
import { INT_VIEW_FILE_DETAILS_PAGE_NAME, EXT_VIEW_FILE_DETAILS_PAGE_NAME } from 'c/googleCloudCrossPlatformUtils';

import retrieveLocalGoogleFileById from '@salesforce/apex/GoogleCloudFilesController.retrieveLocalGoogleFileById';
import retrieveRemoteGoogleFilePreview from '@salesforce/apex/GoogleCloudFilesController.retrieveGoogleFileBase64Preview';

export default class GoogleCloudFilePreview extends NavigationMixin(LightningElement) {
	@api localGoogleRecordId;
	@api localGoogleRecord;
	@api localVersionRecordId; // optional, specified for older versions
	@api localLatestVersionRecord;

	@track accessLevel;
	@track unavailablePreviewMessage = DEFAULT_PREVIEW_UNAVAILABILITY_MESSAGE;
	@track isUnavailablePreview = false;
	@track isExperienceSite = false;
	@track isOldVersion = false;
	@track isLoading = true;
	@track isOpen = false;

	@api async open(localGoogleDriveId) {
		this.initialization();
		this.localGoogleRecordId = JSON.parse(JSON.stringify(localGoogleDriveId));
		this.isOpen = true;

		await this.resolveFilePreview();
	}

	@api async openVersion(localGoogleDriveId, localGoogleVersionId) {
		this.initialization();
		this.localGoogleRecordId = JSON.parse(JSON.stringify(localGoogleDriveId));
		this.localVersionRecordId = JSON.parse(JSON.stringify(localGoogleVersionId));
		
		this.isOldVersion = true;
		this.isOpen = true;

		await this.resolveFilePreview();
	}

	@api async refresh() {
		this.isLoading = true;
		this.resetAllStyles();
		await this.resolveFilePreview();
		this.isLoading = false;
	}

	@api async refreshMetadata() {
		this.isLoading = true;

		try {
			await this.getLocalGoogleDriveFile();
			this.localLatestVersionRecord = this.getLatestFileVersion(this.localGoogleRecord);
		} catch (e) {
			this.unavailablePreviewMessage = normalizeError(e);
			this.isUnavailablePreview = true;
			this.applyPdfStageHiddenStyles();
		}

		this.isLoading = false;
	}

	@api async uploadNewVersion(inputFiles, uploadSource) {
		if(this.denyOperationIfReadOnly()) return;
		if(this.denyOperationIfOldVersion()) return;
		if(this.denyOperationIfMultipleFiles(inputFiles)) return;

		await GoogleCloudFileUploadModal.open({
			recordId: this.localGoogleRecordId,
			localGoogleRecordId: this.localGoogleRecordId,
			uploadSource: uploadSource,
			size: 'small',
			inputFiles: inputFiles
		});

		this.refresh();
	}

	@api close() {
		this.resolvePreviewClosing();
		this.isOpen = false; 
	}

	connectedCallback() {
		this.isExperienceSite = isExperienceCloudContext();
	}

	initialization() {
		this.isUnavailablePreview = false;
		this.isLoading = true;
		this.localGoogleRecordId = undefined;
		this.localGoogleRecord = undefined;
		this.localLatestVersionRecord = undefined;
		this.resetAllStyles();
	}

	handlePreviewModalClose(event) {
		this.close();
	}

	async handleFileDownload(event) {
		await this.downloadFile();
	}

	async handleFileSharing(event) {
		if (this.denyOperationIfReadOnly()) return;

		await GoogleCloudFileSharingModal.open({
            size: 'small',
            label: `Share ${this.fileName}`,
            localFileRecordId: this.localGoogleRecordId
        });
	}

	async handleFilePublicLink(event) {
		if (this.denyOperationIfReadOnly()) return;

		await GoogleCloudFilePublicLinkModal.open({
            size: 'small',
            label: 'Create public link',
            localFileVersionId: this.localLatestVersionRecord.Id
        });
	}

	handleGoogleFileOpen(event) {
		navigateToByAttributes(
			this.viewDetailsReferenceName,
			{ c__recordId: this.localGoogleRecordId}
		);
	}

	async handleFileDetailsEdit(event) {
		if (this.denyOperationIfReadOnly()) return;
		if (this.denyOperationIfOldVersion()) return;

		let isEdited = await GoogleCloudFileDetailsModal.open({
            size: 'small',
            label: `Edit ${this.fileName}`,
            localFileVersionId: this.localLatestVersionRecord.Id
        });

		if (isEdited) {
			this.refreshMetadata();
			this.dispatchEvent(new CustomEvent('filechange'));
		}
	}

	async handleFileDelete(event) {
		if (this.denyOperationIfReadOnly()) return;
		if (this.denyOperationIfOldVersion()) return;

		let isDeleted = await GoogleCloudFileDeleteModal.open({
            size: 'small',
            label: `Delete ${this.fileName}`,
            localFileRecordId: this.localGoogleRecordId
        });

        if (isDeleted) {
			const eventDetail = { 
				localGoogleRecordId: this.localGoogleRecordId,
				localGoogleVersionId: this.localLatestVersionRecord
			};

			this.dispatchEvent(new CustomEvent('filedeleted', { detail: eventDetail }));
			this.close();
		}
	}

	handleNewVersionUpload(event) {
		if (this.denyOperationIfReadOnly()) return;
		if (this.denyOperationIfOldVersion()) return;

		const eventDetail = { localGoogleRecordId: this.localGoogleRecordId };
		this.dispatchEvent(new CustomEvent('newversionrequest', { detail: eventDetail }));
	}

	async resolveFilePreview() {
		try {
			await this.getLocalGoogleDriveFile();
			this.localLatestVersionRecord = this.getLatestFileVersion(this.localGoogleRecord);
			await this.getGoogleFileBlob(this.localLatestVersionRecord.Id);
		} catch (e) {
			this.unavailablePreviewMessage = normalizeError(e);
			this.isUnavailablePreview = true;
			this.applyPdfStageHiddenStyles();
		}

		this.isLoading = false;
	}

	resolvePreviewClosing() {
		const eventDetail = { 
			localGoogleRecordId: this.localGoogleRecordId,
			localGoogleVersionId: this.localLatestVersionRecord
		};

		this.dispatchEvent(new CustomEvent('previewclosed', { detail: eventDetail }));
	}

	async getLocalGoogleDriveFile() {
		this.localGoogleRecord = await retrieveLocalGoogleFileById({ localGoogleFileId: this.localGoogleRecordId });
		this.accessLevel = this.localGoogleRecord.UserAccessLevel__c || 'View';
	}

	async getGoogleFileBlob(localGoogleVersionId) {
		const base64 = await retrieveRemoteGoogleFilePreview({
			localFileVersionId: localGoogleVersionId,
		});

		if (isEmpty(base64)) {
			this.isUnavailablePreview = true;
			this.applyPdfStageHiddenStyles();
		} else {
			const binaryString = window.atob(base64);
			const bytes = new Uint8Array(binaryString.length);
			for (let i = 0; i < binaryString.length; i++) {
				bytes[i] = binaryString.charCodeAt(i);
			}

			const blob = new Blob([bytes], { type: 'application/pdf' });
			const blobUrl = URL.createObjectURL(blob);
			this.renderViewer(blobUrl);
			this.applyMainStageStyles();
		}
	}

	async downloadFile() {
		let googleVersion = this.localLatestVersionRecord;
		try {
			if (googleVersion.Size__c <= BIG_FILE_SIZE) {
				this.isLoading = true;

				await download(googleVersion.Id, {
					fileName: googleVersion.Name,
					mimeType: googleVersion.Type__c
				});

				this.isLoading = false;
			} else {
				this.isLoading = true;

				await downloadInChunks(googleVersion.Id, {
					size: googleVersion.Size__c,
					fileName: googleVersion.Name,
					mimeType: googleVersion.Type__c,
					onError: (err) => {
						throw new Error(err?.message || err);
					}
				});

				this.isLoading = false;
			}
		} catch (error) {
			showToast(
				this,
				'Unable to download File Version',
				DEFAULT_FAILED_DOWNLOAD_MESSAGE,
				'error'
			);
		}
	}

	getLatestFileVersion(record) {
		if (!record || !Array.isArray(record.GoogleFileVersions__r) || record.GoogleFileVersions__r.length === 0) {
			throw new Error('No versions were found for this file. Please verify that the file still exists');
		}

		if (this.isOldVersion === true) {
			const found = record.GoogleFileVersions__r.find(
				(v) => v.Id === this.localVersionRecordId
			);

			if (found) return found;
		}

		return record.GoogleFileVersions__r[0];
	}

	renderViewer(blobUrl) {
        const iframe = this.template.querySelector('.pdfjs-iframe');

        // Compose the viewer.html URL with the Blob URL as the file param
        const viewerUrl = `${pdfjs}/web/viewer.html?file=${encodeURIComponent(blobUrl)}`;
        iframe.src = viewerUrl;
    }

	applyMainStageStyles() {
        const docBlock = this.template.querySelector('.doc');
        if (docBlock) {
            docBlock.style.backgroundColor = '#FFFFFF';
        }
    }

	applyPdfStageHiddenStyles() {
		const docBlock = this.template.querySelector('.doc');
		const pdfFrame = this.template.querySelector('.content');

		if (docBlock) {
			docBlock.style.backgroundColor = '';
		}

		if (pdfFrame) {
			pdfFrame.style.display = 'none';
		}
	}

	resetAllStyles() {
		const docBlock = this.template.querySelector('.doc');
		const pdfFrame = this.template.querySelector('.content');

		if (docBlock) {
			docBlock.style.backgroundColor = '';
		}

		if (pdfFrame) {
			pdfFrame.style.display = '';
		}
	}

	denyOperationIfMultipleFiles(inputFiles) {
		const fileCount = inputFiles?.length ?? 0;

		if (fileCount > 1) {
			showToast(
				this,
				'Multiple Files Not Supported',
				'This operation supports only a single file. Please select one file and try again',
				'warning'
			);

			return true;
		}

		return false;
	}

	denyOperationIfReadOnly() {
		if (this.isReadMode) {
			showToast(
				this,
				'Access to the operation is prohibited',
				DEFAULT_ACCESS_RESTRICTED_MESSAGE,
				'warning'
			);

			return true;
		}

		return false;
	}

	denyOperationIfOldVersion() {
		if (this.isOldVersion) {
			showToast(
				this,
				'Access to the operation is prohibited',
				DEFAULT_ACCESS_RESTRICTED_MESSAGE,
				'warning'
			);

			return true;
		}

		return false;
	}

	get isOldOrReadMode() {
		return this.isReadMode || this.isOldVersion === true;
	}

	get isReadMode() {
		return this.accessLevel === 'Edit'
			? false
			: true;
	}

	get readModeStyles() {
		return this.isReadMode === true
			? 'opacity: 0.2;'
			: '';
	}

	get fileName() {
		if (!this.localLatestVersionRecord || isEmpty(this.localLatestVersionRecord.Name)) {
			return DEFAULT_FILE_NAME;
		}

		return this.localLatestVersionRecord.Name;
	}

	get fileType() {
		if (!this.localLatestVersionRecord || isEmpty(this.localLatestVersionRecord.Name)) {
			return DEFAULT_FILE_ICON_TYPE;
		}

		return getFileIcon(this.localLatestVersionRecord.Name);
	}

	get viewDetailsReferenceName() {
		return this.isExperienceSite
			? EXT_VIEW_FILE_DETAILS_PAGE_NAME
			: INT_VIEW_FILE_DETAILS_PAGE_NAME;
	}
}
