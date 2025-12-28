import { LightningElement, api, wire, track } from 'lwc';
import { MessageContext } from 'lightning/messageService';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';

import GoogleCloudFileUploadModal from 'c/googleCloudUploaderModal';

import { startConfigSession } from 'c/googleCloudConfigBus';
import { navigateToByAttributes, isExperienceCloudContext } from 'c/googleCloudCrossPlatformUtils';
import { isEmpty, showToast, normalizeAllowedTypes, formatExistingLocalFiles, formatDateAsDayMonthYear, extractFileExtension } from 'c/googleCloudUtils';
import { DEFAULT_FAILED_RETRIEVE_MESSAGE, DEFAULT_FILE_NOT_ALLOWED_MESSAGE } from 'c/googleCloudUtils';
import { INT_VIEW_ALL_FILES_PAGE_NAME, EXT_VIEW_ALL_FILES_PAGE_NAME } from 'c/googleCloudCrossPlatformUtils';

import retrieveGoogleFiles from '@salesforce/apex/GoogleCloudFilesController.retrieveGoogleFilesWithLimit';

const UNABLE_TO_UPLOAD_MESSAGE = 'Unable to upload file(s)';
const UNABLE_TO_RETRIEVE_FILES = 'Unable to retrieve file(s)';
const UPLOAD_SOURCE = 'Notes & Attachments';
export default class GoogleCloudAttachments extends NavigationMixin(LightningElement) {
	@api recordId;
	@api objectApiName;
	@api viewDetailsPageName;
	@api icon;
	@api title;
	@api countVisibleFiles = 4;
	@api isMultiple;
	@api fileTypes;
	@api maximumSizeMb;

	@track files = [];
	@track session;
	@track activeActionFileId;
	@track isLoading = true;
	@track isNewFileVersionUpload = false;
	@track isExperienceSite = false;

	wiredFilesResult;
	@wire(retrieveGoogleFiles, { relatedRecordId: '$recordId', source: UPLOAD_SOURCE, recordsCount: '$countVisibleFiles' })
    wiredFiles(result) {
        this.wiredFilesResult = result;
        const { data, error } = result;

        if (data) {
            this.files = this.formatFilesInfo(formatExistingLocalFiles(data));
			this.isLoading = false;
        } else if (error) {
            showToast(
				this,
				UNABLE_TO_RETRIEVE_FILES,
				DEFAULT_FAILED_RETRIEVE_MESSAGE,
				'error'
			);

			this.isLoading = false;
        }
    }

	@wire(MessageContext)
	messageContext;

	connectedCallback() {
		this.isExperienceSite = isExperienceCloudContext();
	}
	
	handleFileUpload(event) {
		const fileInput = this.template.querySelector('.file-input');
		if (fileInput) {
			fileInput.click();
		}
	}

	handleNewVersionRequest(event) {
		let openFileVersionId = event.detail.localGoogleRecordId;
		if (!isEmpty(openFileVersionId)) {
			this.isNewFileVersionUpload = true;
			this.handleFileUpload();
		}
	}

	async handleFileSelected(event) {
		const selectedFiles = [...event.target.files];
		const allowedFiles = this.retrieveAllowedFiles(selectedFiles);
		if (!isEmpty(allowedFiles)) {
			if (this.isNewFileVersionUpload === true) {
				let previewComponent = this.refs.filePreviewModal;
				await previewComponent.uploadNewVersion(allowedFiles, UPLOAD_SOURCE);
			} else {
				await GoogleCloudFileUploadModal.open({
					recordId: this.recordId,
					uploadSource: UPLOAD_SOURCE,
					size: 'small',
					inputFiles: allowedFiles
				});
			}

			await refreshApex(this.wiredFilesResult);
			this.isNewFileVersionUpload = false;
		}
	}

	async handleFileDelete(event) {
		this.isLoading = true;
		await refreshApex(this.wiredFilesResult);
		this.isLoading = false;
	}

	async handleFileEdit(event) {
		this.isLoading = true;
		await refreshApex(this.wiredFilesResult);
		this.isLoading = false;
	}

	handleFilePreviewOpen(event) {
		let previewComponent = this.refs.filePreviewModal;
		let parentContainer = event.target.closest('div[data-id]');
		let parentContainerId = parentContainer.getAttribute('data-id');
		previewComponent.open(parentContainerId);
	}

	handlePreviewCloseReset(event) {
		this.isNewFileVersionUpload = false;
	}

	async openSeparateTab(event) {
		const payload = {
			title: this.title,
			recordId: this.recordId,
			sobjectApiName: this.objectApiName,
			source: UPLOAD_SOURCE,
			isMultiple: this.isMultiple,
			fileTypes: this.fileTypes,
			maximumSizeMb: this.maximumSizeMb
		};

		this.isLoading = true;
		this.session = await startConfigSession(payload);
		navigateToByAttributes(this.viewAllReferenceName, this.session.configId, false);
		this.isLoading = false;
	}

	formatFilesInfo(files) {
		return files.map(file => {
			let parts = [];

			if (file.lastModifiedDate) {
				parts.push(formatDateAsDayMonthYear(file.lastModifiedDate));
			}

			if (file.size) {
				parts.push(file.size);
			}

			if (file.type) {
				parts.push(file.type);
			}

			return {
				...file,
				info: parts.join(' • ')
			};
		});
	}

	retrieveAllowedFiles(selectedFiles) {
		let allowedExts = this.fileTypes
			? new Set(
				this.fileTypes
					.split(',')
					.map(ext => ext.trim().toLowerCase())
					.filter(Boolean)
			  )
			: null;

		let maxSizeMb = this.maximumSizeMb > 0 ? this.maximumSizeMb : null;
		let allowedFiles = [];
		let areNotAllowedFiles = false;

		selectedFiles.forEach(file => {
			const ext = extractFileExtension(file.name).toLowerCase();
			const typeOk = !allowedExts || allowedExts.has(ext);
			const sizeOk = !maxSizeMb || (file.size / (1024 * 1024) <= maxSizeMb);

			if (typeOk && sizeOk) {
				allowedFiles.push(file);
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

	get filesCount() {
		if (isEmpty(this.files)) return '(0)';
		return this.files.length === this.countVisibleFiles
			? `(${this.files.length}+)`
			: `(${this.files.length})`;
	}

	get acceptedTypes() {
		return normalizeAllowedTypes(this.fileTypes);
	}

	get viewAllReferenceName() {
		return this.isExperienceSite
			? EXT_VIEW_ALL_FILES_PAGE_NAME
			: INT_VIEW_ALL_FILES_PAGE_NAME;
	}
}