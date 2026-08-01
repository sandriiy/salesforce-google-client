import { api, track, wire } from 'lwc';
import LightningModal from 'lightning/modal';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import USER_NAME_FIELD from '@salesforce/schema/User.Name';

import { saveGoogleFileLocally, saveGoogleFileVersionLocally, uploadInChunks, upload } from 'c/googleCloudUploadUtils';
import { BIG_FILE_SIZE } from 'c/googleCloudUploadUtils';
import { DEFAULT_FILE_UPLOAD_FAILURE } from 'c/googleCloudUtils';
import { isEmpty, showToast, createNewFilePlaceholder } from 'c/googleCloudUtils';

const UNABLE_TO_UPLOAD_MESSAGE = 'Unable to upload file(s)';
export default class GoogleCloudUploaderModal extends LightningModal {
    @api recordId;
	@api localGoogleRecordId; // If specified, a new version of the file will be created, otherwise a new file will be created
    @api uploadSource;
    @api inputFiles = [];

    @track isLoading = false;
    @track files = [];
    @track awaitingClosure = false;
    @track locallyProcessedIds = [];
    @track failedUploads = [];

    apexRetryHandlers = new Map();

    @wire(getRecord, { recordId: USER_ID, fields: [USER_NAME_FIELD] })
    userRecord;

    connectedCallback() {
        this.handleFilesUpload();
    }

    handleFilesUpload() {
        if (!isEmpty(this.inputFiles)) {
            this.inputFiles.forEach(inputFile => {
				if (inputFile.size > BIG_FILE_SIZE) {
					this.handleLargeFileUpload(inputFile);
				} else {
					this.handleFileUpload(inputFile);
				}
            });
        } else {
            this.dispatchEvent(new CustomEvent('nofiles'));
            this.close();
        }
    }

    handleLargeFileUpload(selectedFile) {
        let newFilePlaceholder = createNewFilePlaceholder(selectedFile);
        this.files.push(newFilePlaceholder);

        uploadInChunks(newFilePlaceholder.id, selectedFile, {
            onProgress: (uploadedId, parentFolderId, id, progress) => {
                const fileIndex = this.files.findIndex(file => file.id === id);
                const file = this.files[fileIndex];

                if (progress < 100) {
                    const fileUpdated = { ...file, progress: progress};
                    this.files[fileIndex] = fileUpdated;
                } else {
                    const fileUpdated = { 
                        ...file, 
                        progress: progress, 
                        parentFolderId: parentFolderId, 
                        id: uploadedId,
                        style: this.completedIconCssStyles
                    };

                    this.files[fileIndex] = fileUpdated;
                    this.saveGoogleFileLocally(this.files[fileIndex]);
                }
            }
        }).catch(error => {
			this.handleLargeUploadFailure(error, newFilePlaceholder);
		});
    }

    handleLargeUploadFailure(error, filePlaceholder) {
        if (error?.canRetryThroughApex) {
            this.apexRetryHandlers.set(filePlaceholder.id, error.retryThroughApex);
            this.failedUploads = [...this.failedUploads, { id: filePlaceholder.id, name: filePlaceholder.name }];
            return;
        }

        showToast(
            this,
            UNABLE_TO_UPLOAD_MESSAGE,
            DEFAULT_FILE_UPLOAD_FAILURE,
            'error'
        );
    }

    handleRetryThroughApex() {
        const pendingRetries = this.failedUploads;
        this.failedUploads = [];

        pendingRetries.forEach(failedUpload => {
            const retryThroughApex = this.apexRetryHandlers.get(failedUpload.id);
            this.apexRetryHandlers.delete(failedUpload.id);
            if (!retryThroughApex) return;

            retryThroughApex().catch(() => {
                this.discardFailedUpload(failedUpload.id);

                showToast(
                    this,
                    UNABLE_TO_UPLOAD_MESSAGE,
                    DEFAULT_FILE_UPLOAD_FAILURE,
                    'error'
                );
            });
        });
    }

    handleDismissFailedUploads() {
        const dismissedUploads = this.failedUploads;
        this.failedUploads = [];

        dismissedUploads.forEach(failedUpload => {
            this.apexRetryHandlers.delete(failedUpload.id);
            this.discardFailedUpload(failedUpload.id);
        });

        showToast(
            this,
            UNABLE_TO_UPLOAD_MESSAGE,
            DEFAULT_FILE_UPLOAD_FAILURE,
            'error'
        );
    }

    discardFailedUpload(fileId) {
        const fileIndex = this.files.findIndex(file => file.id === fileId);
        if (fileIndex !== -1) {
            this.files.splice(fileIndex, 1);
        }

        this.locallyProcessedIds.push(fileId);
        this.handleCloseRequest();
    }

    handleFileUpload(selectedFile) {
        let newFilePlaceholder = createNewFilePlaceholder(selectedFile);
        this.files.push(newFilePlaceholder);

        upload(newFilePlaceholder.id, selectedFile, {
            onSuccess: (uploadedId, parentFolderId, id) => {
                const fileIndex = this.files.findIndex(file => file.id === id);
                const file = this.files[fileIndex];

                const fileUpdated = { 
                    ...file, 
                    progress: 100, 
                    parentFolderId: parentFolderId, 
                    id: uploadedId,
                    style: this.completedIconCssStyles
                };

                this.files[fileIndex] = fileUpdated;
                this.saveGoogleFileLocally(this.files[fileIndex]);
            }
        }).catch(error => {
			showToast(
				this,
				UNABLE_TO_UPLOAD_MESSAGE,
				DEFAULT_FILE_UPLOAD_FAILURE,
				'error'
			);
		});
    }

    async saveGoogleFileLocally(file) {
		try {
			let fileResult;

			if (isEmpty(this.localGoogleRecordId)) {
				fileResult = await saveGoogleFileLocally(this.recordId, file, this.uploadSource);
			} else {
				fileResult = await saveGoogleFileVersionLocally(this.recordId, this.localGoogleRecordId, file, this.uploadSource);
			}

			const fileIndex = this.files.findIndex(file => file.id === file.id);
			const existingFile = this.files[fileIndex];
			const fileUpdated = { 
				...existingFile, 
				localId: fileResult.Id,
				createdBy: {
					id: USER_ID,
					name: getFieldValue(this.userRecord.data, USER_NAME_FIELD)
				}
			};
			
			this.files[fileIndex] = fileUpdated;
		} catch (ex) {
			showToast(
				this,
				'Unable to create file record',
				'The file was uploaded, but the record creation failed. Please contact your system administrator',
				'error'
			);
		} finally {
            this.locallyProcessedIds.push(file.id);
            this.handleCloseRequest();
		}
    }

    get hasFailedUploads() {
        return this.failedUploads.length > 0;
    }

    get failedUploadsMessage() {
        if (this.failedUploads.length === 1) {
            return `“${this.failedUploads[0].name}” couldn’t be uploaded. Try again with a different approach?`;
        }

        return `${this.failedUploads.length} files couldn’t be uploaded. Try again with a different approach?`;
    }

    get fileCountLabel() {
        let uploadedFilesCount = this.files.filter(file => file.progress === 100).length;
        let allFilesCount = this.files.length;
        return `${uploadedFilesCount} of ${allFilesCount} file${allFilesCount !== 1 ? 's' : ''} uploaded`;
    }

    get isUploading() {
        let uploadedFilesCount = this.files.filter(file => file.progress === 100).length;
        let allFilesCount = this.files.length;

        return uploadedFilesCount !== allFilesCount;
    }

    get completedIconCssStyles() {
        return '--sds-c-icon-color-foreground-default: #28a745;'
    }
    
    handleCloseRequest() {
        let pendingFilesCount = this.locallyProcessedIds.length;
        let allFilesCount = this.inputFiles.length;

        if (pendingFilesCount === allFilesCount && this.awaitingClosure) {
            this.isLoading = false;
            this.close(this.files);
        }
    }

    handleDone() {
        this.awaitingClosure = true;
        this.isLoading = true;
        this.handleCloseRequest();
    }
}