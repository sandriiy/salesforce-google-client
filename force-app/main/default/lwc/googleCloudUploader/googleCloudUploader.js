import { LightningElement, api, track, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { saveGoogleFileLocally, uploadInChunks, upload, prefetchUploadFolderStructure } from 'c/googleCloudUploadUtils';
import { DEFAULT_OOPS_MESSAGE, DEFAULT_FILE_UPLOAD_FAILURE, DEFAULT_FAILED_RETRIEVE_MESSAGE, DEFAULT_FILE_NOT_ALLOWED_MESSAGE } from 'c/googleCloudUtils';
import hasGoogleClientUserAccess from '@salesforce/customPermission/GoogleClientUserAccess';
import { isEmpty, isPermissionMissing, showToast, normalizeAllowedTypes, formatExistingLocalFiles, createNewFilePlaceholder, extractFileExtension, resolveTransferLimits, createBulkSelection, resolveRecordNameFields, resolveRecordNameValue } from 'c/googleCloudUtils';
import {
	downloadMany,
	resolveBulkDownloadRefusal,
	resolveBulkArchiveName,
	resolveBulkDownloadOutcome,
	resolveBulkDownloadFailure,
	createOperationControl,
	abortOperation,
	BULK_DOWNLOAD_FAILED_TITLE
} from 'c/googleCloudDownloadUtils';
import { FlowAttributeChangeEvent } from 'lightning/flowSupport';

import GoogleCloudFileDeleteModal from 'c/googleCloudFileDeleteModal';
import GoogleCloudExistingFileAttachModal from 'c/googleCloudExistingFileAttachModal';
import retrieveGoogleFiles from '@salesforce/apex/GoogleCloudFilesController.retrieveGoogleFiles';

const UPLOAD_SOURCE = 'Uploader';
const RECORD_NAME_WAIT_MS = 3000;
const FILE_CARD_CLASS = 'file-card slds-m-horizontal_small slds-theme_default slds-rounded_medium';
export default class GoogleCloudUploader extends LightningElement {
    @api recordId;
    @api supportedFileExtensions;
    @api maximumSizeMb;
    @api allowMultipleFiles;
	@api maxFileCount;

	@track isAccessible = hasGoogleClientUserAccess === true;
	@track isNewFileVersionUpload = false;
	@track isDropzoneActive = false;
	@track isLoading = true;
    @track files = [];

	apexRetryHandlers = new Map();
	selection = createBulkSelection();
	isBulkDownloadInProgress = false;
	isBulkDownloadStopping = false;
	isBulkDownloadAbandoned = false;
	bulkDownloadProgress;
	bulkDownloadControl;
	recordNameLookupId;
	recordNameObjectApiName;
	recordNameFields;
	recordNameFieldsRecordId;
	recordName;
	recordNameLookup;
	settleRecordNameLookupPromise;

	@wire(getRecord, { recordId: '$recordNameLookupId', layoutTypes: ['Compact'] })
	wiredRecordForName({ data, error }) {
		if (data) {
			this.recordNameObjectApiName = data.apiName;
		} else if (error) {
			this.settleRecordNameLookup(null);
		}
	}

	@wire(getObjectInfo, { objectApiName: '$recordNameObjectApiName' })
	wiredObjectInfoForName({ data, error }) {
		if (data) {
			const nameFields = resolveRecordNameFields(data).map((nameField) => `${data.apiName}.${nameField}`);
			if (isEmpty(nameFields)) {
				this.settleRecordNameLookup(null);
				return;
			}

			this.recordNameFields = nameFields;
			this.recordNameFieldsRecordId = this.recordNameLookupId;
		} else if (error) {
			this.settleRecordNameLookup(null);
		}
	}

	@wire(getRecord, { recordId: '$recordNameFieldsRecordId', fields: '$recordNameFields' })
	wiredRecordName({ data, error }) {
		if (data) {
			this.settleRecordNameLookup(resolveRecordNameValue(data, this.recordNameFields));
		} else if (error) {
			this.settleRecordNameLookup(null);
		}
	}

	connectedCallback() {
		resolveTransferLimits();
		this.loadFiles();
	}

	disconnectedCallback() {
		if (this.bulkDownloadControl) {
			this.isBulkDownloadAbandoned = true;
			abortOperation(this.bulkDownloadControl);
		}
	}

    async handleFileSelected(event) {
		const selectedFiles = [...(event.target.files || [])];
		await this.processSelectedFiles(selectedFiles);
	}

	async processSelectedFiles(selectedFiles) {
		const allowedFiles = this.retrieveAllowedFiles(selectedFiles);
		let isNotAllowed = this.validateAllowedFileAmount(allowedFiles);
		if (isNotAllowed) return;
        
        if (!isEmpty(allowedFiles)) {
			if (this.isNewFileVersionUpload === true) {
				let previewComponent = this.refs.filePreviewModal;
				await previewComponent.uploadNewVersion(allowedFiles, UPLOAD_SOURCE);
				this.isNewFileVersionUpload = false;
				this.handleFilesRefresh();
			} else {
				prefetchUploadFolderStructure(this.recordId);

				allowedFiles.forEach(allowedFile => this.handleFileUpload(allowedFile));
			}
        }
    }

	handleDropZoneDragEnter(event) {
		this.updateDropzoneState(event, true);
	}

	handleDropZoneDragOver(event) {
		this.updateDropzoneState(event, true);
	}

	handleDropZoneDragLeave(event) {
		event.preventDefault();
		event.stopPropagation();

		const nextTarget = event.relatedTarget;
		if (nextTarget && event.currentTarget.contains(nextTarget)) {
			return;
		}

		this.isDropzoneActive = false;
	}

	async handleDropZoneDrop(event) {
		event.preventDefault();
		event.stopPropagation();
		this.isDropzoneActive = false;

		const droppedFiles = [...(event.dataTransfer?.files || [])];
		await this.processSelectedFiles(droppedFiles);
	}

	updateDropzoneState(event, isActive) {
		event.preventDefault();
		event.stopPropagation();
		this.isDropzoneActive = isActive;
	}

	handleFileReset(event) {
		const input = event.target;
		input.value = null;
	}

    async handleFileUpload(selectedFile) {
		let newFilePlaceholder = createNewFilePlaceholder(selectedFile);
		this.files.unshift(newFilePlaceholder);

		const transferLimits = await resolveTransferLimits();
		if (selectedFile.size > transferLimits.uploadChunkBytes) {
			this.uploadLargeFile(newFilePlaceholder, selectedFile);
		} else {
			this.uploadSmallFile(newFilePlaceholder, selectedFile);
		}
	}

    uploadLargeFile(newFilePlaceholder, selectedFile) {
		uploadInChunks(newFilePlaceholder.id, selectedFile, {
			onProgress: (uploadedId, parentFolderId, id, progress) => {
				const fileIndex = this.files.findIndex(file => file.id === id);
				const file = this.files[fileIndex];

				if (progress < 100) {
					this.files[fileIndex] = { ...file, progress: String(progress) };
				} else {
					this.files[fileIndex] = { ...file, parentFolderId: parentFolderId, id: uploadedId };
					this.saveGoogleFileLocally(this.files[fileIndex]);
					this.showFileToast();
				}
			}
		}).catch(error => {
			this.handleLargeUploadFailure(error, newFilePlaceholder);
		});
	}

	handleLargeUploadFailure(error, filePlaceholder) {
		if (error?.canRetryThroughApex) {
			this.apexRetryHandlers.set(filePlaceholder.id, error.retryThroughApex);

			const fileIndex = this.files.findIndex(file => file.id === filePlaceholder.id);
			if (fileIndex !== -1) {
				this.files[fileIndex] = { ...this.files[fileIndex], canRetryThroughApex: true };
			}

			return;
		}

		this.removeFileById(filePlaceholder.id);

		showToast(
			this,
			DEFAULT_OOPS_MESSAGE,
			DEFAULT_FILE_UPLOAD_FAILURE,
			'error'
		);
	}

	handleRetryThroughApex(event) {
		event.stopPropagation();

		const parentContainer = event.target.closest('article[data-id]');
		const filePlaceholderId = parentContainer.getAttribute('data-id');

		const retryThroughApex = this.apexRetryHandlers.get(filePlaceholderId);
		this.apexRetryHandlers.delete(filePlaceholderId);
		if (!retryThroughApex) return;

		const fileIndex = this.files.findIndex(file => file.id === filePlaceholderId);
		if (fileIndex !== -1) {
			this.files[fileIndex] = { ...this.files[fileIndex], canRetryThroughApex: false, progress: '0' };
		}

		retryThroughApex().catch(() => {
			this.removeFileById(filePlaceholderId);

			showToast(
				this,
				DEFAULT_OOPS_MESSAGE,
				DEFAULT_FILE_UPLOAD_FAILURE,
				'error'
			);
		});
	}

	handleDiscardFailedUpload(event) {
		event.stopPropagation();

		const parentContainer = event.target.closest('article[data-id]');
		const filePlaceholderId = parentContainer.getAttribute('data-id');

		this.apexRetryHandlers.delete(filePlaceholderId);
		this.removeFileById(filePlaceholderId);
	}

    uploadSmallFile(newFilePlaceholder, selectedFile) {
		upload(newFilePlaceholder.id, selectedFile, {
			onSuccess: (uploadedId, parentFolderId, id) => {
				const fileIndex = this.files.findIndex(file => file.id === id);
				const file = this.files[fileIndex];

				this.files[fileIndex] = {
					...file, 
					parentFolderId: parentFolderId, 
					id: uploadedId 
				};

				this.saveGoogleFileLocally(this.files[fileIndex]);
				this.showFileToast();
			}
		}).catch(error => {
			this.removeFileById(newFilePlaceholder.id);

			showToast(
				this,
				DEFAULT_OOPS_MESSAGE,
				DEFAULT_FILE_UPLOAD_FAILURE,
				'error'
			);
		});
	}

	handleFilePreview(event) {
		const fileId = event.currentTarget?.dataset?.id;
		const fileIndex = this.files?.findIndex?.(file => file?.id === fileId) ?? -1;
		const fileProgress = this.files?.[fileIndex]?.progress;
		const fileLocalId = this.files?.[fileIndex]?.localId;
		if (this.isFileLocked(fileLocalId)) return;

		if (fileProgress == null && fileLocalId != null) {
			let previewComponent = this.refs.filePreviewModal;
			previewComponent.open(fileLocalId);
		} else {
			showToast(
				this,
				'Preview Unavailable',
				'The upload isn’t complete yet. Please try again in a moment',
				'info'
			);
		}
	}

	handleNewVersionRequest(event) {
		let openFileVersionId = event.detail.localGoogleRecordId;
		if (!isEmpty(openFileVersionId)) {
			this.isNewFileVersionUpload = true;
			this.openFileSelection();
		}
	}

	async handleFilesRefresh(event) {
		this.isLoading = true;
		await this.loadFiles();
		this.isLoading = false;
	}

	async handleAttachExistingFile() {
		if (isEmpty(this.recordId)) {
			return;
		}

		const modalResult = await GoogleCloudExistingFileAttachModal.open({
			size: 'medium',
			label: 'Attach Existing Files',
			recordId: this.recordId,
			source: UPLOAD_SOURCE
		});

		if (!modalResult?.hasChanges) {
			return;
		}

		await this.handleFilesRefresh();

		this.dispatchEvent(new CustomEvent('fileattached', {
			detail: {
				...(modalResult.detail || {}),
				numberOfFiles: this.files?.length ?? 0
			}
		}));
		this.dispatchEvent(new FlowAttributeChangeEvent('files', this.files));
	}

	handleAttachExistingLinkClick(event) {
		event.preventDefault();
		event.stopPropagation();
		this.handleAttachExistingFile();
	}

	async handleFileReplace(event) {
		let parentContainer = event.target.closest('article[data-id]');
		let parentContainerId = parentContainer.getAttribute('data-id');
		const fileIndex = this.files?.findIndex?.(file => file?.id === parentContainerId) ?? -1;
		const fileLocalId = this.files?.[fileIndex]?.localId;

		if (!isEmpty(fileLocalId)) {
			let previewComponent = this.refs.filePreviewModal;
			previewComponent.open(fileLocalId);

			this.isNewFileVersionUpload = true;
			this.openFileSelection();

			this.dispatchEvent(new FlowAttributeChangeEvent('files', this.files));
		}
	}

	async handleFileDelete(event) {
		event.stopPropagation();

		let parentContainer = event.target.closest('article[data-id]');
		let parentContainerId = parentContainer.getAttribute('data-id');
		const fileIndex = this.files?.findIndex?.(file => file?.id === parentContainerId) ?? -1;
		const localFile = this.files?.[fileIndex];

		let isDeleted = await GoogleCloudFileDeleteModal.open({
            size: 'small',
            label: `Delete ${localFile.name}`,
            localFileRecordId: localFile.localId
        });

		if (isDeleted) {
			const eventDetail = { 
				fileName: localFile.name,
				fileId: localFile.localId,
				numberOfFiles: this.files?.length ?? 0
			};

			this.dispatchEvent(new CustomEvent('filedeleted', { detail: eventDetail }));
			this.handleFilesRefresh();

			this.dispatchEvent(new FlowAttributeChangeEvent('files', this.files));
		}
	}
	
	handlePreviewCloseReset(event) {
		this.isNewFileVersionUpload = false;
		if (event.detail?.isIntelligenceUpdated === true) {
			this.handleFilesRefresh();
		}
	}

	handleFileSelectionChange(event) {
		const fileId = event.target.dataset.id;
		if (isEmpty(fileId)) return;

		this.updateSelection(event.target.checked
			? this.selection.select([fileId])
			: this.selection.deselect([fileId]));
	}

	handleSelectionClear() {
		this.updateSelection(this.selection.clear());
	}

	handleSelectionClick(event) {
		event.stopPropagation();
	}

	async handleBulkDownload() {
		if (this.isBulkDownloadInProgress) return;

		const selectedFiles = this.selection.pick(this.files, 'localId');
		const refusal = resolveBulkDownloadRefusal(selectedFiles);
		if (refusal) {
			showToast(this, BULK_DOWNLOAD_FAILED_TITLE, refusal, 'warning');
			return;
		}

		const control = createOperationControl();
		this.bulkDownloadControl = control;
		this.isBulkDownloadInProgress = true;
		this.isBulkDownloadStopping = false;
		this.isBulkDownloadAbandoned = false;
		this.bulkDownloadProgress = { current: 0, total: selectedFiles.length, percent: 0 };

		try {
			const recordName = await this.waitForRecordName();
			const result = await downloadMany(selectedFiles, {
				zipName: (includedCount) => resolveBulkArchiveName(recordName, includedCount),
				control,
				onProgress: (progress) => {
					this.bulkDownloadProgress = progress;
				}
			});

			this.reportBulkDownloadResult(result);
		} catch (error) {
			if (!this.isBulkDownloadAbandoned) {
				this.showBulkDownloadToast(resolveBulkDownloadFailure(error));
			}
		} finally {
			this.isBulkDownloadInProgress = false;
			this.isBulkDownloadStopping = false;
			this.isBulkDownloadAbandoned = false;
			this.bulkDownloadProgress = undefined;
			this.bulkDownloadControl = null;
		}
	}

	handleBulkDownloadStop() {
		this.isBulkDownloadStopping = true;
		abortOperation(this.bulkDownloadControl);
	}

	reportBulkDownloadResult(result) {
		this.showBulkDownloadToast(resolveBulkDownloadOutcome(result));
		this.updateSelection(this.selection.deselect(result.downloaded.map((file) => file.localId)));
	}

	showBulkDownloadToast({ title, message, variant, mode }) {
		showToast(this, title, message, variant, mode);
	}

	updateSelection(nextSelection) {
		this.selection = nextSelection;
		if (!nextSelection.isEmpty) {
			this.startRecordNameLookup();
		}
	}

	startRecordNameLookup() {
		if (this.recordNameLookup || isEmpty(this.recordId)) return;

		this.recordNameLookup = new Promise((resolve) => {
			this.settleRecordNameLookupPromise = resolve;
		});
		this.recordNameLookupId = this.recordId;
	}

	settleRecordNameLookup(recordName) {
		this.recordName = recordName;

		if (this.settleRecordNameLookupPromise) {
			this.settleRecordNameLookupPromise(recordName);
			this.settleRecordNameLookupPromise = null;
		}
	}

	async waitForRecordName() {
		if (!this.settleRecordNameLookupPromise) {
			return this.recordName;
		}

		let waitTimer;
		const timeLimit = new Promise((resolve) => {
			waitTimer = setTimeout(resolve, RECORD_NAME_WAIT_MS);
		});

		await Promise.race([this.recordNameLookup, timeLimit]);
		clearTimeout(waitTimer);

		return this.recordName;
	}

	isFileLocked(localId) {
		return this.isBulkDownloadInProgress && !isEmpty(localId) && this.selection.has(localId);
	}

	retrieveAllowedFiles(selectedFiles) {
		if (isEmpty(selectedFiles)) return [];

		let allowedFiles = [];
		let areNotAllowedFiles = false;

		selectedFiles.forEach(selectedFile => {
			if (this.isFileAllowed(selectedFile)) {
				allowedFiles.push(selectedFile);
			} else {
				areNotAllowedFiles = true;
			}
		});

		if (areNotAllowedFiles) {
			showToast(
				this,
				DEFAULT_OOPS_MESSAGE,
				DEFAULT_FILE_NOT_ALLOWED_MESSAGE,
				'warning'
			);
		}

		return allowedFiles;
	}

    isFileAllowed(selectedFile) {
        let typeOk = true;
        if (this.supportedFileExtensions && this.supportedFileExtensions.trim().length) {
            const allowed = new Set(
                this.supportedFileExtensions
                    .split(',')
                    .map(ext => ext.trim().toLowerCase())
                    .filter(Boolean)
            );

            const fileExt = extractFileExtension(selectedFile.name);
            typeOk = allowed.has(fileExt);
        }

        let sizeOk = true;
        if (this.maximumSizeMb && this.maximumSizeMb > 0) {
            const sizeInMB = selectedFile.size / (1024 * 1024);
            sizeOk = sizeInMB <= this.maximumSizeMb;
        }

        return typeOk && sizeOk;
    }

	validateAllowedFileAmount(newFiles) {
		if (isEmpty(this.maxFileCount) || this.isNewFileVersionUpload === true) return false;

		const existingCount = Array.isArray(this.files) ? this.files.length : 0;
		const newCount = newFiles.length;
		const totalCount = existingCount + newCount;
		if (totalCount > this.maxFileCount) {
			const remaining = this.maxFileCount - existingCount;

            const message = remaining > 0
                ? `You can upload up to ${this.maxFileCount} files in total. You already have ${existingCount} and can add only ${remaining} more`
                : `You can upload up to ${this.maxFileCount} files and already have ${existingCount}. Replace or remove files to continue`;

            showToast(
                this,
                DEFAULT_OOPS_MESSAGE,
                message,
                'warning'
            );

            return true;
		}

		return false;
	}

	openFileSelection() {
		const fileInput = this.template.querySelector('.file-input');
		if (fileInput) {
			fileInput.click();
		}
	}

    saveGoogleFileLocally(fileToUpload) {
        saveGoogleFileLocally(this.recordId, fileToUpload, UPLOAD_SOURCE)
            .then(async result => {
				let formattedExistingFiles = formatExistingLocalFiles([result]);
				let fileUpdated = formattedExistingFiles[0];
				let fileIndex = this.files.findIndex(file => file.id === fileToUpload.id);
				const isAlreadyListed = this.files.some(file => file.localId === fileUpdated.localId);

				if (isAlreadyListed) {
					this.removeFileById(fileToUpload.id);
				} else if (fileIndex !== -1) {
					this.files[fileIndex] = fileUpdated;
				}

				const eventDetail = {
					fileName: fileUpdated.name,
					fileId: fileUpdated.localId,
					numberOfFiles: this.files?.length ?? 0
				};

				this.dispatchEvent(new CustomEvent('filecreated', { detail: eventDetail }));
				this.dispatchEvent(new FlowAttributeChangeEvent('files', this.files));
            }).catch(error => {
                showToast(
					this,
					DEFAULT_OOPS_MESSAGE,
					'The file was uploaded, but the record creation failed. Please contact your system administrator',
					'error'
				);
            })
    }

	async loadFiles() {
		try {
			const data = await retrieveGoogleFiles({
				relatedRecordId: this.recordId,
				source: UPLOAD_SOURCE
			});

			const savedFiles = formatExistingLocalFiles(data);
			const unsavedFiles = this.files.filter(file => isEmpty(file.localId));

			this.files = [...unsavedFiles, ...savedFiles];
			this.selection = this.selection.retain(savedFiles.map(file => file.localId));
		} catch (error) {
			if (isPermissionMissing(error)) {
				this.isAccessible = false;
			} else {
				showToast(
					this,
					DEFAULT_OOPS_MESSAGE,
					DEFAULT_FAILED_RETRIEVE_MESSAGE,
					'error'
				);
			}
		} finally {
			this.isLoading = false;
		}
	}

	removeFileById(fileId) {
		const index = this.files.findIndex(file => file.id === fileId);
		if (index !== -1) {
			this.files.splice(index, 1);
		}
	}

	showFileToast() {
        const toastElement = this.refs.fileUploadedToast;
        if (!toastElement) return;

        toastElement.classList.remove("file-card__status-overlay--hidden");

        setTimeout(() => {
            toastElement.classList.add("file-card__status-overlay--hidden");
        }, 1500);
    }

    get filesExist() {
        return !isEmpty(this.files);
    }

    get acceptedTypes() {
		return normalizeAllowedTypes(this.supportedFileExtensions);
    }

    get isMultiple() {
        return this.isNewFileVersionUpload === true ? false : this.allowMultipleFiles;
    }

	get dropzoneClass() {
		return this.isDropzoneActive ? 'dropzone dropzone--active' : 'dropzone';
	}

	get displayedFiles() {
		return this.files.map(file => {
			const isSelectable = !isEmpty(file.localId);
			const isSelected = isSelectable && this.selection.has(file.localId);
			const isLocked = this.isFileLocked(file.localId);

			return {
				...file,
				isSelectable,
				isSelected,
				isLocked,
				cardClass: `${FILE_CARD_CLASS}${isSelected ? ' file-card--selected' : ''}${isLocked ? ' file-card--locked' : ''}`,
				selectLabel: `Select ${file.name}`
			};
		});
	}

	get selectableFileIds() {
		return this.files.filter(file => !isEmpty(file.localId)).map(file => file.localId);
	}

	get selectableFileCount() {
		return this.selectableFileIds.length;
	}

	get isBulkBarVisible() {
		return this.isBulkDownloadInProgress || !this.selection.isEmpty;
	}

	get filesSectionClass() {
		return this.isBulkBarVisible ? 'files-section slds-m-top_small' : 'files-section slds-m-top_medium';
	}

	get isSelectionLocked() {
		return this.isBulkDownloadInProgress;
	}
}