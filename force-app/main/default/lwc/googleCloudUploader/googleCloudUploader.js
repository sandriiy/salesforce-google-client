import { LightningElement, api, track, wire } from 'lwc';
import { saveGoogleFileLocally, uploadInChunks, upload } from 'c/googleCloudUploadUtils';
import { BIG_FILE_SIZE } from 'c/googleCloudUploadUtils';
import { DEFAULT_FILE_UPLOAD_FAILURE, DEFAULT_FAILED_RETRIEVE_MESSAGE, DEFAULT_FILE_NOT_ALLOWED_MESSAGE } from 'c/googleCloudUtils';
import { isEmpty, showToast, normalizeAllowedTypes, formatExistingLocalFiles, createNewFilePlaceholder, extractFileExtension } from 'c/googleCloudUtils';

import GoogleCloudFileDeleteModal from 'c/googleCloudFileDeleteModal';
import retrieveGoogleFiles from '@salesforce/apex/GoogleCloudFilesController.retrieveGoogleFiles';

const UNABLE_TO_UPLOAD_MESSAGE = 'Unable to upload file(s)';
const UNABLE_TO_RETRIEVE_FILES = 'Unable to retrieve file(s)';
const UPLOAD_SOURCE = 'Uploader';
export default class GoogleCloudUploader extends LightningElement {
    @api recordId;
    @api supportedFileExtensions;
    @api maximumSizeMb;
    @api allowMultipleFiles;
	@api maxFileCount;

	@track isNewFileVersionUpload = false;
	@track isLoading = true;
    @track files = [];

	connectedCallback() {
		this.loadFiles();
	}

    async handleFileSelect(event) {
        const selectedFiles = [...event.target.files];
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
				allowedFiles.forEach(allowedFile => {
					if (allowedFile.size > BIG_FILE_SIZE) {
						this.handleLargeFileUpload(allowedFile);
					} else {
						this.handleFileUpload(allowedFile);
					}
				});
			}
        }
    }

    handleLargeFileUpload(selectedFile) {
		let newFilePlaceholder = createNewFilePlaceholder(selectedFile);
		this.files.unshift(newFilePlaceholder);

		uploadInChunks(newFilePlaceholder.id, selectedFile, {
			onProgress: (uID, pID, id, progress) => {
				const fileIndex = this.files.findIndex(file => file.id === id);
				const file = this.files[fileIndex];

				if (progress < 100) {
					this.files[fileIndex] = { ...file, progress: String(progress) };
				} else {
					this.files[fileIndex] = { ...file, parentFolderId: pID, id: uID };
					this.saveGoogleFileLocally(this.files[fileIndex]);
					this.showFileToast();
				}
			}
		}).catch(error => {
			this.removeFileById(newFilePlaceholder.id);

			showToast(
				this,
				UNABLE_TO_UPLOAD_MESSAGE,
				DEFAULT_FILE_UPLOAD_FAILURE,
				'error'
			);
		});
	}

    handleFileUpload(selectedFile) {
		let newFilePlaceholder = createNewFilePlaceholder(selectedFile);
		this.files.unshift(newFilePlaceholder);

		upload(newFilePlaceholder.id, selectedFile, {
			onSuccess: (uID, pID, id) => {
				const fileIndex = this.files.findIndex(file => file.id === id);
				const file = this.files[fileIndex];

				this.files[fileIndex] = { ...file, parentFolderId: pID, id: uID };
				this.saveGoogleFileLocally(this.files[fileIndex]);
				this.showFileToast();
			}
		}).catch(error => {
			this.removeFileById(newFilePlaceholder.id);

			showToast(
				this,
				UNABLE_TO_UPLOAD_MESSAGE,
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
		}
	}
	
	handlePreviewCloseReset(event) {
		this.isNewFileVersionUpload = false;
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
				UNABLE_TO_UPLOAD_MESSAGE,
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
		if (isEmpty(this.maxFileCount)) return false;

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
                UNABLE_TO_UPLOAD_MESSAGE,
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
            .then(result => {
				let formattedExistingFiles = formatExistingLocalFiles([result]);
				let fileUpdated = formattedExistingFiles[0];
				let fileIndex = this.files.findIndex(file => file.id === fileToUpload.id);
				this.files[fileIndex] = formattedExistingFiles[0];

				const eventDetail = { 
					fileName: fileUpdated.name,
					fileId: fileUpdated.localId,
					numberOfFiles: this.files?.length ?? 0
				};

				this.dispatchEvent(new CustomEvent('filecreated', { detail: eventDetail }));
            }).catch(error => {
                showToast(
					this,
					'Unable to create file record',
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

			this.files = formatExistingLocalFiles(data);
		} catch (error) {
			showToast(
				this,
				UNABLE_TO_RETRIEVE_FILES,
				DEFAULT_FAILED_RETRIEVE_MESSAGE,
				'error'
			);
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
        return this.isNewFileVersionUpload === true 
			? false
			: this.allowMultipleFiles;
    }
}