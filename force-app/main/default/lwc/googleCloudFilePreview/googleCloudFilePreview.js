import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

import { isEmpty, showToast, normalizeError, getFileIcon, truncateFileName } from 'c/googleCloudUtils';
import { BIG_FILE_SIZE } from 'c/googleCloudDownloadUtils';
import { download, downloadInChunks, createOperationControl, abortOperation, isOperationAbortedError } from 'c/googleCloudDownloadUtils';
import { 
	DEFAULT_PREVIEW_UNAVAILABILITY_MESSAGE, 
	DEFAULT_FAILED_DOWNLOAD_MESSAGE,
	DEFAULT_NO_VERSIONS_MESSAGE,
	DEFAULT_ACCESS_RESTRICTED_MESSAGE,
	DEFAULT_FILE_NAME,
	DEFAULT_FILE_ICON_TYPE 
} from 'c/googleCloudUtils';

import pdfjs from '@salesforce/resourceUrl/GoogleCloudPreviewRender';

import GoogleCloudFilePublicLinkModal from 'c/googleCloudFilePublicLinkModal';
import GoogleCloudFileDetailsModal from 'c/googleCloudFileDetailsModal';
import GoogleCloudFileDeleteModal from 'c/googleCloudFileDeleteModal';
import GoogleCloudFileDownloadAsModal from 'c/googleCloudFileDownloadAsModal';
import GoogleCloudFileUploadModal from 'c/googleCloudUploaderModal';
import GoogleCloudFileSharingModal from 'c/googleCloudFileSharingModal';
import GoogleCloudOpenInDriveModal from 'c/googleCloudOpenInDriveModal';

import { navigateToByAttributes, isExperienceCloudContext } from 'c/googleCloudCrossPlatformUtils';
import { INT_VIEW_FILE_DETAILS_PAGE_NAME, EXT_VIEW_FILE_DETAILS_PAGE_NAME } from 'c/googleCloudCrossPlatformUtils';

import retrieveLocalGoogleFileById from '@salesforce/apex/GoogleCloudFilesController.retrieveLocalGoogleFileById';
import validateFilePreview from '@salesforce/apex/GoogleCloudFilesController.validateFilePreview';
import downloadFileAsPdf from '@salesforce/apex/GoogleCloudFilesController.downloadFileAsPdf';
import canOpenInDrive from '@salesforce/apex/GoogleCloudDriveAccessController.canOpenInDrive';

const PREVIEW_SLOW_THRESHOLD_MS = 5000;
const PREVIEW_RENDERER_PDF = 'pdf';
const PREVIEW_RENDERER_IMAGE = 'image';
const IMAGE_MIME_TYPE_PREFIX = 'image/';

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
	@track isPreviewTakingTooLong = false;
	@track isIntelligenceAvailable = false;
	@track isIntelligencePanelOpen = false;
	@track isOpenInDriveAvailable = false;

	previewOperation;
	previewBlobUrl;
	previewRenderer = PREVIEW_RENDERER_PDF;

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
		const currentVersionId = this.intelligenceVersionId;

		try {
			await this.getLocalGoogleDriveFile();
			this.localLatestVersionRecord = this.getLatestFileVersion(this.localGoogleRecord);

			if (currentVersionId === this.intelligenceVersionId) {
				await this.refs.fileIntelligence?.refresh?.();
			}
		} catch (e) {
			this.unavailablePreviewMessage = normalizeError(e);
			this.isUnavailablePreview = true;
			this.cleanupPreviewBlobUrl();
			this.resetAllStyles();
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
		this.abortPreviewOperation(false, false);
		this.cleanupPreviewBlobUrl();
		this.resolvePreviewClosing();
		this.isOpen = false; 
	}

	connectedCallback() {
		this.isExperienceSite = isExperienceCloudContext();
	}

	initialization() {
		this.abortPreviewOperation(false, false);
		this.cleanupPreviewBlobUrl();
		this.isUnavailablePreview = false;
		this.isLoading = true;
		this.isPreviewTakingTooLong = false;
		this.localGoogleRecordId = undefined;
		this.localGoogleRecord = undefined;
		this.localLatestVersionRecord = undefined;
		this.isIntelligenceAvailable = false;
		this.isIntelligencePanelOpen = false;
		this.resetAllStyles();
	}

	handlePreviewAbort(event) {
		this.abortPreviewOperation();
	}

	handlePreviewModalClose(event) {
		this.close();
	}

	handleIntelligenceStateChange(event) {
		this.isIntelligenceAvailable = event.detail?.isEligible === true;
		this.isIntelligencePanelOpen = event.detail?.isOpen === true;
	}

	async handleFileDownload(event) {
		this.isLoading = true;
		await this.downloadFile();
		this.isLoading = false;
	}

	async handleDownloadAs(event) {
		if (!this.isDownloadAsAvailable || !this.localLatestVersionRecord?.Id) {
			return;
		}

		await GoogleCloudFileDownloadAsModal.open({
			size: 'small',
			label: `Download ${truncateFileName(this.fileName)} as`,
			fileName: this.fileName,
			localFileVersionId: this.localLatestVersionRecord.Id
		});
	}

	async handleOpenInDrive(event) {
		const targetVersionId = this.openInDriveVersionId;
		if (!this.isOpenInDriveAvailable || !targetVersionId) {
			return;
		}

		await GoogleCloudOpenInDriveModal.open({
			size: 'small',
			label: 'Open in Google Drive',
			fileName: this.fileName,
			localGoogleFileId: this.localGoogleRecordId,
			localGoogleFileVersionId: targetVersionId
		});
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
            localFileVersionId: this.localLatestVersionRecord.Id,
			isReadOnlyAccess: this.isReadMode
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
		const previewOperation = this.startPreviewOperation();

		try {
			await this.getLocalGoogleDriveFile();
			this.assertPreviewOperationActive(previewOperation);

			this.localLatestVersionRecord = this.getLatestFileVersion(this.localGoogleRecord);
			this.assertPreviewOperationActive(previewOperation);

			await this.getGoogleFileBlob(this.localLatestVersionRecord.Id, previewOperation);
			this.assertPreviewOperationActive(previewOperation);
		} catch (e) {
			if (isOperationAbortedError(e) || !this.isPreviewOperationActive(previewOperation)) {
				return;
			}

			this.unavailablePreviewMessage = normalizeError(e);
			this.isUnavailablePreview = true;
			this.cleanupPreviewBlobUrl();
			this.resetAllStyles();
		} finally {
			if (this.previewOperation === previewOperation) {
				this.finishPreviewOperation(previewOperation);
				this.isLoading = false;
			}
		}
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

		await this.resolveOpenInDriveAvailability();
	}

	async resolveOpenInDriveAvailability() {
		try {
			this.isOpenInDriveAvailable = await canOpenInDrive({ localGoogleFileId: this.localGoogleRecordId }) === true;
		} catch (e) {
			this.isOpenInDriveAvailable = false;
		}
	}

	async getGoogleFileBlob(localGoogleVersionId, previewOperation) {
		// Will throw if preview is not eligible
		const previewAction = await validateFilePreview({ localFileVersionId: localGoogleVersionId });
		this.assertPreviewOperationActive(previewOperation);
		const previewRenderer = this.resolvePreviewRenderer(previewAction);

		let previewBlob;
		if (previewAction === 'DIRECT') {
			previewBlob = await this.downloadFile({
				downloadImmediately: false,
				returnBlob: true,
				operationControl: previewOperation
			});

			this.assertPreviewOperationActive(previewOperation);
		} else if (previewAction === 'CONVERT') {
			const base64 = await downloadFileAsPdf({ localGoogleFileVersionId: localGoogleVersionId });
			this.assertPreviewOperationActive(previewOperation);

			if (isEmpty(base64)) {
				this.cleanupPreviewBlobUrl();
				this.isUnavailablePreview = true;
				this.resetAllStyles();
				return;
			}

			previewBlob = this.base64ToBlob(base64, 'application/pdf');
		}

		if (!previewBlob || previewBlob.size === 0) {
			this.cleanupPreviewBlobUrl();
			this.isUnavailablePreview = true;
			this.resetAllStyles();
		} else {
			const blobUrl = URL.createObjectURL(previewBlob);

			if (!this.isPreviewOperationActive(previewOperation)) {
				URL.revokeObjectURL(blobUrl);
				this.assertPreviewOperationActive(previewOperation);
			}

			this.renderPreview(blobUrl, previewRenderer);
			this.applyMainStageStyles(previewRenderer);
		}
	}

	async downloadFile({
		downloadImmediately = true,
		returnBase64 = false,
		returnBlob = false,
		operationControl = null
	} = {}) {
		let googleVersion = this.localLatestVersionRecord;

		try {
			if (googleVersion.Size__c <= BIG_FILE_SIZE) {
				return await download(googleVersion.Id, {
					fileName: googleVersion.Name,
					mimeType: googleVersion.Type__c,
					returnBase64,
					returnBlob,
					control: operationControl
				});
			} else {
				return await downloadInChunks(googleVersion.Id, {
					size: googleVersion.Size__c,
					fileName: googleVersion.Name,
					mimeType: googleVersion.Type__c,
					returnBase64,
					returnBlob,
					control: operationControl,
					onError: () => {
						showToast(
							this,
							'Unable to download File Version',
							DEFAULT_FAILED_DOWNLOAD_MESSAGE,
							'error'
						);
					}
				});
			}
		} catch (error) {
			if (isOperationAbortedError(error)) {
				throw error;
			}

			showToast(
				this,
				'Unable to download File Version',
				DEFAULT_FAILED_DOWNLOAD_MESSAGE,
				'error'
			);
		}

		if (downloadImmediately) {
			return;
		}
	}

	getLatestFileVersion(record) {
		if (!record || !Array.isArray(record.GoogleFileVersions__r) || record.GoogleFileVersions__r.length === 0) {
			showToast(
				this,
				'Unable to find File Version',
				DEFAULT_NO_VERSIONS_MESSAGE,
				'error'
			);
		} else {
			if (this.isOldVersion === true) {
				const found = record.GoogleFileVersions__r.find(
					(v) => v.Id === this.localVersionRecordId
				);

				if (found) return found;
			}

			return record.GoogleFileVersions__r[0];
		}
	}

	resolvePreviewRenderer(previewAction) {
		if (previewAction === 'DIRECT' && this.isImageMimeType(this.localLatestVersionRecord?.Type__c)) {
			return PREVIEW_RENDERER_IMAGE;
		}

		return PREVIEW_RENDERER_PDF;
	}

	isImageMimeType(mimeType) {
		return typeof mimeType === 'string' && mimeType.toLowerCase().startsWith(IMAGE_MIME_TYPE_PREFIX);
	}

	renderPreview(blobUrl, previewRenderer) {
		this.cleanupPreviewBlobUrl();
		this.previewBlobUrl = blobUrl;
		this.previewRenderer = previewRenderer;

		if (previewRenderer === PREVIEW_RENDERER_IMAGE) {
			return;
		}

		const iframe = this.template.querySelector('.pdfjs-iframe');
		if (!iframe) {
			return;
		}

		const viewerUrl = `${pdfjs}/web/viewer.html?file=${encodeURIComponent(blobUrl)}`;
		iframe.src = viewerUrl;
	}

	applyMainStageStyles(previewRenderer) {
        const docBlock = this.template.querySelector('.doc');
        if (docBlock) {
			docBlock.style.backgroundColor = previewRenderer === PREVIEW_RENDERER_IMAGE
				? '#111111'
				: '#FFFFFF';
        }
    }

	applyPdfStageHiddenStyles() {
		const docBlock = this.template.querySelector('.doc');

		if (docBlock) {
			docBlock.style.backgroundColor = '';
		}
	}

	resetAllStyles() {
		const docBlock = this.template.querySelector('.doc');

		if (docBlock) {
			docBlock.style.backgroundColor = '';
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

	startPreviewOperation() {
		this.abortPreviewOperation(false, false);
		this.cleanupPreviewBlobUrl();

		const previewOperation = createOperationControl();
		previewOperation.slowTimerId = setTimeout(() => {
			if (!this.isPreviewOperationActive(previewOperation)) {
				return;
			}

			this.isPreviewTakingTooLong = true;
		}, PREVIEW_SLOW_THRESHOLD_MS);

		this.previewOperation = previewOperation;
		this.isPreviewTakingTooLong = false;

		return previewOperation;
	}

	finishPreviewOperation(previewOperation) {
		if (!previewOperation) {
			return;
		}

		if (previewOperation.slowTimerId) {
			clearTimeout(previewOperation.slowTimerId);
			previewOperation.slowTimerId = undefined;
		}

		if (this.previewOperation === previewOperation) {
			this.previewOperation = undefined;
			this.isPreviewTakingTooLong = false;
		}
	}

	abortPreviewOperation(showUnavailablePreview = true, stopLoading = true) {
		if (this.previewOperation) {
			abortOperation(this.previewOperation);
			this.finishPreviewOperation(this.previewOperation);

			if (showUnavailablePreview) {
				this.cleanupPreviewBlobUrl();
				this.isUnavailablePreview = true;
				this.applyPdfStageHiddenStyles();
			}
		}

		if (stopLoading) {
			this.isLoading = false;
		}
	}

	isPreviewOperationActive(previewOperation) {
		return this.previewOperation === previewOperation && previewOperation?.isAborted !== true;
	}

	assertPreviewOperationActive(previewOperation) {
		if (!this.isPreviewOperationActive(previewOperation)) {
			const error = new Error('Preview aborted');
			error.name = 'GoogleCloudDownloadAbortError';
			throw error;
		}
	}

	base64ToBlob(base64, mimeType) {
		const binaryString = window.atob(base64);
		const bytes = new Uint8Array(binaryString.length);

		for (let i = 0; i < binaryString.length; i++) {
			bytes[i] = binaryString.charCodeAt(i);
		}

		return new Blob([bytes], { type: mimeType });
	}

	cleanupPreviewBlobUrl() {
		const iframe = this.template.querySelector('.pdfjs-iframe');
		if (iframe) {
			iframe.src = 'about:blank';
		}

		if (this.previewBlobUrl) {
			URL.revokeObjectURL(this.previewBlobUrl);
			this.previewBlobUrl = undefined;
		}
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

	get hasPreviewContent() {
		return !this.isUnavailablePreview && !isEmpty(this.previewBlobUrl);
	}

	get isImagePreview() {
		return this.previewRenderer === PREVIEW_RENDERER_IMAGE;
	}

	get pdfContentClass() {
		return this.hasPreviewContent && !this.isImagePreview
			? 'content'
			: 'content content--hidden';
	}

	get imageContentClass() {
		return this.hasPreviewContent && this.isImagePreview
			? 'content image-content'
			: 'content image-content content--hidden';
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

	get openInDriveVersionId() {
		return this.localVersionRecordId || this.localLatestVersionRecord?.Id;
	}

	get isOpenInDriveVisible() {
		return this.isOpenInDriveAvailable === true && !!this.openInDriveVersionId;
	}

	get isDownloadAsAvailable() {
		return this.isLoading !== true 
			&& this.isUnavailablePreview !== true
			&& this.localLatestVersionRecord?.IsPreviewableFile__c === true
			&& this.localLatestVersionRecord?.Size__c != null
			&& this.localLatestVersionRecord.Size__c <= BIG_FILE_SIZE;
	}

	get stageClass() {
		return this.isIntelligencePanelOpen
			? 'stage stage--with-sidebar'
			: 'stage';
	}

	get docClass() {
		return this.isIntelligencePanelOpen
			? 'doc doc--with-sidebar'
			: 'doc';
	}

	get intelligenceRailClass() {
		return this.isIntelligencePanelOpen
			? 'intelligence-rail intelligence-rail--expanded'
			: this.isIntelligenceAvailable
				? 'intelligence-rail intelligence-rail--collapsed'
				: 'intelligence-rail intelligence-rail--hidden';
	}

	get intelligenceVersionId() {
		return this.localLatestVersionRecord?.Id;
	}

	get viewDetailsReferenceName() {
		return this.isExperienceSite
			? EXT_VIEW_FILE_DETAILS_PAGE_NAME
			: INT_VIEW_FILE_DETAILS_PAGE_NAME;
	}
}