import { LightningElement, track, api, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { NavigationMixin } from 'lightning/navigation';
import { decryptObject } from 'c/googleCloudCryptoUtils';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { requestConfig, stopConfigSession } from 'c/googleCloudConfigBus';

import { updateTabPresentation, closeWhenReady } from 'c/googleCloudCrossPlatformUtils';

import GoogleCloudFileUploadModal from 'c/googleCloudUploaderModal';

import {
	isEmpty,
	showToast,
	normalizeAllowedTypes,
	formatExistingLocalFiles,
	formatDateAsDDMMYYYY_HHMM,
	extractFileExtension
} from 'c/googleCloudUtils';
import { DEFAULT_FAILED_RETRIEVE_MESSAGE, DEFAULT_FILE_NOT_ALLOWED_MESSAGE } from 'c/googleCloudUtils';
import retrieveGoogleFiles from '@salesforce/apex/GoogleCloudFilesController.retrieveGoogleFilesWithoutLimit';

const UNABLE_TO_UPLOAD_MESSAGE = 'Unable to upload file(s)';
const UNABLE_TO_RETRIEVE_FILES = 'Unable to retrieve file(s)';
const TARGET_TAB_COMPONENT = 'c__googleCloudRelatedAttachments';
const TAB_POLL_DELAY_MS = 200;
const TAB_MAX_RETRIES = 5;

export default class GoogleCloudRelatedAttachments extends NavigationMixin(LightningElement) {
	@api title;
	@api recordId;
	@api sobjectApiName;
	@api source;
	@api isMultiple;
	@api fileTypes;
	@api maximumSizeMb;

	@track isNewFileVersionUpload = false;
	@track subscription;
	@track tabInfo;
	@track tabInfoRetries = 0;
	@track isLoading = true;
	@track recordIdentifierName;
	@track recordIdentifierValue;
	@track files = [];

	searchTerm = '';
	sortedByLabel = 'Last Modified';
	sortedBy = 'date';
	sortDirection = 'desc';

	@wire(CurrentPageReference)
	currentPageReference;

	@wire(getObjectInfo, { objectApiName: '$sobjectApiName' })
	wiredObjectInfo({ data, error }) {
		if (data) {
			let nameField = data.nameFields[data.nameFields.length - 1];
			this.recordIdentifierName = `${this.sobjectApiName}.${nameField}`;
		}
	}

	@wire(getRecord, { recordId: '$recordId', fields: '$recordPrimaryField' })
	wiredRecordInfo({ data, error }) {
		if (data) {
			this.recordIdentifierValue = getFieldValue(data, this.recordIdentifierName);
		}
	}

	renderedCallback() {
		if (isEmpty(this.subscription) && !isEmpty(this.currentPageReference)) {
			this.updateTabLabel();
			this.resolvePageState();
		}
	}

	disconnectedCallback() {
		try {
			if (this.subscription?.unsubscribe) {
				this.subscription.unsubscribe();
			} else if (this.subscription) {
				stopConfigSession(this.subscription);
			}
		} catch (e) {}
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
				await previewComponent.uploadNewVersion(allowedFiles, this.source);
				this.handleDataRefresh();
				this.isNewFileVersionUpload = false;
			} else {
				GoogleCloudFileUploadModal.open({
					recordId: this.recordId,
					uploadSource: this.source,
					size: 'small',
					inputFiles: allowedFiles
				}).then((result) => {
					if (!isEmpty(result)) {
						this.files = [...this.formatFilesInfo(result), ...this.files];
					}
				});
			}
		}
	}

	handleColumnSort(event) {
		const fieldName = event.currentTarget.dataset.id;
		const fieldLabel = event.currentTarget.dataset.name;

		if (this.sortedBy === fieldName) {
			this.sortDirection = this.sortDirection === 'asc' ? 'desc' : 'asc';
		} else {
			this.sortedBy = fieldName;
			this.sortDirection = 'asc';
		}

		this.sortRecords(fieldName);
		this.sortedByLabel = fieldLabel;
	}

	handleSearch(event) {
		this.searchTerm = event.target.value.toLowerCase();
	}

	handleDataRefresh(event) {
		this.searchTerm = '';
		this.retrieveAllRelatedFiles();
	}

	handleFilePreview(event) {
		const previewComponent = this.refs.filePreviewModal;
		const parentContainer = event.currentTarget.closest('tr[data-id]');
		const parentContainerId = parentContainer?.getAttribute('data-id');
		previewComponent.open(parentContainerId);
	}

	handleUserPreview(event) {
		const recordId = event.currentTarget.dataset.id;
		this[NavigationMixin.Navigate]({
			type: 'standard__recordPage',
			attributes: {
				recordId: recordId,
				actionName: 'view'
			}
		});
	}

	handleListViewOpen(event) {
		this[NavigationMixin.Navigate]({
			type: 'standard__objectPage',
			attributes: {
				objectApiName: this.sobjectApiName,
				actionName: 'list'
			},
			state: {
				filterName: 'Recent'
			}
		});
	}

	handleRecordOpen(event) {
		this[NavigationMixin.Navigate]({
			type: 'standard__recordPage',
			attributes: {
				recordId: this.recordId,
				actionName: 'view'
			}
		});
	}

	handlePreviewCloseReset(event) {
		this.isNewFileVersionUpload = false;
	}

	getFieldValue(record, path) {
		return path.split('.').reduce((obj, key) => (obj ? obj[key] : undefined), record);
	}

	sortRecords(fieldName) {
		const data = [...this.files];

		data.sort((a, b) => {
			let aVal = this.getFieldValue(a, fieldName);
			let bVal = this.getFieldValue(b, fieldName);

			if (typeof aVal === 'string' && Date.parse(aVal)) {
				aVal = Date.parse(aVal);
				bVal = Date.parse(bVal);
			}

			if (aVal == null && bVal != null) return 1;
			if (bVal == null && aVal != null) return -1;
			if (aVal === bVal) return 0;

			return (aVal > bVal ? 1 : -1) * (this.sortDirection === 'asc' ? 1 : -1);
		});

		this.files = data;
	}

	async resolvePageState() {
		let configId = this.currentPageReference?.state?.c__configId;

		if (isEmpty(configId)) {
			this.closeTabWhenReady();
			return;
		}

		this.subscription = requestConfig(configId, (payload) => {
			if (isEmpty(payload)) {
				this.closeTabWhenReady();
				return;
			}

			this.recordId = payload.recordId;
			this.sobjectApiName = payload.sobjectApiName;
			this.source = payload.source;
			this.title = payload.title;
			this.isMultiple = payload.isMultiple;
			this.fileTypes = payload.fileTypes;
			this.maximumSizeMb = payload.maximumSizeMb;

			if (isEmpty(this.recordId)) {
				this.closeTabWhenReady();
				return;
			}

			this.retrieveAllRelatedFiles();
		});
	}

	updateTabLabel() {
		updateTabPresentation({
			label: 'Notes & Attachments',
			iconName: 'standard:file',
			iconOptions: {
				tooltip: 'Notes & Attachments',
				iconAlt: 'Notes & Attachments'
			},
			targetComponentName: TARGET_TAB_COMPONENT,
			maxRetries: TAB_MAX_RETRIES,
			pollDelayMs: TAB_POLL_DELAY_MS
		}).then((result) => {
			this.tabInfo = result?.tabInfo || null;
			this.tabInfoRetries = 0;
		});
	}

	closeTabWhenReady() {
		closeWhenReady({
			getTabInfo: () => this.tabInfo,
			maxRetries: TAB_MAX_RETRIES,
			pollDelayMs: TAB_POLL_DELAY_MS
		});
	}

	retrieveAllRelatedFiles() {
		this.isLoading = true;

		retrieveGoogleFiles({ relatedRecordId: this.recordId, source: this.source })
			.then((data) => {
				this.files = this.formatFilesInfo(formatExistingLocalFiles(data));
				this.sortRecords(this.sortedBy);
			})
			.catch((error) => {
				console.error(error);
				showToast(this, UNABLE_TO_RETRIEVE_FILES, DEFAULT_FAILED_RETRIEVE_MESSAGE, 'error');
			})
			.finally(() => {
				this.isLoading = false;
			});
	}

	retrieveAllowedFiles(selectedFiles) {
		let allowedExts = this.fileTypes
			? new Set(
					this.fileTypes
						.split(',')
						.map((ext) => ext.trim().toLowerCase())
						.filter(Boolean)
			  )
			: null;

		let maxSizeMb = this.maximumSizeMb > 0 ? this.maximumSizeMb : null;
		let allowedFiles = [];
		let areNotAllowedFiles = false;

		selectedFiles.forEach((file) => {
			const ext = extractFileExtension(file.name).toLowerCase();
			const typeOk = !allowedExts || allowedExts.has(ext);
			const sizeOk = !maxSizeMb || file.size / (1024 * 1024) <= maxSizeMb;

			if (typeOk && sizeOk) {
				allowedFiles.push(file);
			} else {
				areNotAllowedFiles = true;
			}
		});

		if (areNotAllowedFiles) {
			showToast(this, UNABLE_TO_UPLOAD_MESSAGE, DEFAULT_FILE_NOT_ALLOWED_MESSAGE, 'warning');
		}

		return allowedFiles;
	}

	formatFilesInfo(files) {
		return files.map((file) => {
			return {
				...file,
				date: formatDateAsDDMMYYYY_HHMM(file.lastModifiedDate)
			};
		});
	}

	get acceptedTypes() {
		return normalizeAllowedTypes(this.fileTypes);
	}

	get recordPrimaryField() {
		return this.recordIdentifierName ? [this.recordIdentifierName] : [];
	}

	get displayedFiles() {
		if (!this.searchTerm) {
			return this.files;
		}

		return this.files.filter((file) => {
			return (
				file.name.toLowerCase().includes(this.searchTerm) ||
				file.date.toLowerCase().includes(this.searchTerm) ||
				file.size.toLowerCase().includes(this.searchTerm) ||
				file.createdBy.name.toLowerCase().includes(this.searchTerm)
			);
		});
	}
}