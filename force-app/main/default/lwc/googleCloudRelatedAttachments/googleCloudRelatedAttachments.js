import { LightningElement, track, api, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { requestConfig, stopConfigSession } from 'c/googleCloudConfigBus';

import { updateTabPresentation, closeWhenReady } from 'c/googleCloudCrossPlatformUtils';

import GoogleCloudFileUploadModal from 'c/googleCloudUploaderModal';
import GoogleCloudExistingFileAttachModal from 'c/googleCloudExistingFileAttachModal';

import {
	isEmpty,
	isPermissionMissing,
	showToast,
	normalizeAllowedTypes,
	formatExistingLocalFiles,
	formatDateAsDDMMYYYY_HHMM,
	extractFileExtension,
	createBulkSelection
} from 'c/googleCloudUtils';
import { DEFAULT_FAILED_RETRIEVE_MESSAGE, DEFAULT_FILE_NOT_ALLOWED_MESSAGE, DEFAULT_FAILED_DOWNLOAD_MESSAGE } from 'c/googleCloudUtils';
import {
	downloadMany,
	resolveBulkDownloadRefusal,
	createOperationControl,
	abortOperation,
	isOperationAbortedError,
	BULK_DOWNLOAD_STOPPED_MESSAGE
} from 'c/googleCloudDownloadUtils';
import hasGoogleClientUserAccess from '@salesforce/customPermission/GoogleClientUserAccess';
import retrieveGoogleFiles from '@salesforce/apex/GoogleCloudFilesController.retrieveGoogleFilesWithoutLimit';

const UNABLE_TO_UPLOAD_MESSAGE = 'Unable to upload file(s)';
const UNABLE_TO_RETRIEVE_FILES = 'Unable to retrieve file(s)';
const UNABLE_TO_DOWNLOAD_FILES_MESSAGE = 'Unable to download files';
const FILES_DOWNLOADED_MESSAGE = 'Files downloaded';
const DOWNLOAD_STOPPED_MESSAGE = 'Download stopped';
const UNSAFE_ARCHIVE_NAME_CHARACTERS = /[\\/:*?"<>|]/g;
const TARGET_TAB_COMPONENT = 'c__googleCloudRelatedAttachments';
const TAB_POLL_DELAY_MS = 200;
const TAB_MAX_RETRIES = 5;
const SORT_FIELD_NAME_BY_COLUMN = {
	createdBy: 'createdBy.name',
	date: 'lastModifiedDate'
};

export default class GoogleCloudRelatedAttachments extends NavigationMixin(LightningElement) {
	@api title;
	@api recordId;
	@api sobjectApiName;
	@api source;
	@api isMultiple;
	@api fileTypes;
	@api maximumSizeMb;

	@track isAccessible = hasGoogleClientUserAccess === true;
	@track isNewFileVersionUpload = false;
	@track subscription;
	@track tabInfo;
	@track tabInfoRetries = 0;
	@track isLoading = true;
	@track recordIdentifierNames = [];
	@track recordIdentifierValue;
	@track files = [];

	searchTerm = '';
	sortedByLabel = 'Last Modified';
	sortedBy = 'date';
	sortDirection = 'desc';
	selection = createBulkSelection();
	isBulkDownloadInProgress = false;
	isBulkDownloadStopping = false;
	bulkDownloadProgress;
	bulkDownloadControl;

	@wire(CurrentPageReference)
	currentPageReference;

	@wire(getObjectInfo, { objectApiName: '$sobjectApiName' })
	wiredObjectInfo({ data, error }) {
		if (data) {
			this.recordIdentifierNames = this.resolveDisplayNameFields(data).map((nameField) => `${this.sobjectApiName}.${nameField}`);
			this.recordIdentifierValue = null;
		} else if (error) {
			this.recordIdentifierNames = [];
			this.recordIdentifierValue = null;
		}
	}

	@wire(getRecord, { recordId: '$recordId', fields: '$recordPrimaryField' })
	wiredRecordInfo({ data, error }) {
		if (data) {
			this.recordIdentifierValue = this.resolveRecordIdentifierValue(data);
		} else if (error) {
			this.recordIdentifierValue = null;
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

	async handleAttachExistingFile() {
		if (isEmpty(this.recordId)) {
			return;
		}

		const modalResult = await GoogleCloudExistingFileAttachModal.open({
			size: 'medium',
			label: 'Attach Existing Files',
			recordId: this.recordId,
			source: this.source
		});

		if (modalResult?.hasChanges) {
			this.handleDataRefresh();
		}
	}

	handleHeaderActionSelect(event) {
		if (event.detail?.value === 'attachExisting') {
			this.handleAttachExistingFile();
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
						this.handleDataRefresh();
					}
				});
			}
		}
	}

	handleFileReset(event) {
		const input = event.target;
		input.value = null;
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
		if (event.detail?.isIntelligenceUpdated === true) {
			this.retrieveAllRelatedFiles();
		}
	}

	handleFileSelectionChange(event) {
		const fileId = event.target.dataset.id;
		if (isEmpty(fileId)) return;

		this.selection = event.target.checked
			? this.selection.select([fileId])
			: this.selection.deselect([fileId]);
	}

	handleVisibleSelectionChange(event) {
		const visibleFileIds = this.displayedFiles.map((file) => file.localId);

		this.selection = event.target.checked
			? this.selection.select(visibleFileIds)
			: this.selection.deselect(visibleFileIds);
	}

	handleSelectionClear() {
		this.selection = this.selection.clear();
	}

	async handleBulkDownload() {
		if (this.isBulkDownloadInProgress) return;

		const selectedFiles = this.selection.pick(this.files, 'localId');
		const refusal = resolveBulkDownloadRefusal(selectedFiles);
		if (refusal) {
			showToast(this, UNABLE_TO_DOWNLOAD_FILES_MESSAGE, refusal, 'warning');
			return;
		}

		this.bulkDownloadControl = createOperationControl();
		this.isBulkDownloadInProgress = true;
		this.isBulkDownloadStopping = false;
		this.bulkDownloadProgress = { current: 0, total: selectedFiles.length, percent: 0 };

		try {
			const result = await downloadMany(selectedFiles, {
				zipName: (includedCount) => this.resolveArchiveName(includedCount),
				control: this.bulkDownloadControl,
				onProgress: (progress) => {
					this.bulkDownloadProgress = progress;
				}
			});

			this.reportBulkDownloadResult(result);
		} catch (error) {
			if (isOperationAbortedError(error)) {
				showToast(this, DOWNLOAD_STOPPED_MESSAGE, BULK_DOWNLOAD_STOPPED_MESSAGE, 'info');
			} else {
				showToast(this, UNABLE_TO_DOWNLOAD_FILES_MESSAGE, DEFAULT_FAILED_DOWNLOAD_MESSAGE, 'error');
			}
		} finally {
			this.isBulkDownloadInProgress = false;
			this.isBulkDownloadStopping = false;
			this.bulkDownloadProgress = undefined;
			this.bulkDownloadControl = null;
		}
	}

	handleBulkDownloadStop() {
		this.isBulkDownloadStopping = true;
		abortOperation(this.bulkDownloadControl);
	}

	reportBulkDownloadResult({ downloaded, failed }) {
		const total = downloaded.length + failed.length;

		if (failed.length === 0) {
			showToast(this, FILES_DOWNLOADED_MESSAGE, `${this.describeFileCount(downloaded.length)} downloaded as one ZIP archive`, 'success');
			this.selection = this.selection.clear();
			return;
		}

		if (downloaded.length === 0) {
			showToast(this, UNABLE_TO_DOWNLOAD_FILES_MESSAGE, DEFAULT_FAILED_DOWNLOAD_MESSAGE, 'error');
			return;
		}

		const failedNames = failed.map((failure) => failure.file.name).join(', ');
		showToast(this, FILES_DOWNLOADED_MESSAGE, `${downloaded.length} of ${this.describeFileCount(total)} downloaded as one ZIP archive. ${failedNames} could not be included and ${failed.length === 1 ? 'stays' : 'stay'} selected`, 'warning', 'sticky');
		this.selection = this.selection.deselect(downloaded.map((file) => file.localId));
	}

	resolveArchiveName(fileCount) {
		const baseName = String(this.recordIdentifierValue || this.title || 'Files')
			.replace(UNSAFE_ARCHIVE_NAME_CHARACTERS, ' ')
			.replace(/\s+/g, ' ')
			.trim();

		return `${baseName} - ${this.describeFileCount(fileCount)}.zip`;
	}

	describeFileCount(count) {
		return `${count} ${count === 1 ? 'file' : 'files'}`;
	}

	resolveDisplayNameFields(objectInfo) {
		const nameFields = objectInfo.nameFields || [];
		const fieldsByApiName = objectInfo.fields || {};

		for (const nameField of nameFields) {
			const fieldInfo = fieldsByApiName[nameField];

			if (fieldInfo?.compound) return [nameField];
			if (fieldInfo?.compoundFieldName) return [fieldInfo.compoundFieldName];
		}

		return nameFields;
	}

	resolveRecordIdentifierValue(recordInfo) {
		for (const fieldName of this.recordIdentifierNames) {
			const fieldValue = getFieldValue(recordInfo, fieldName);

			if (!isEmpty(fieldValue)) {
				return fieldValue;
			}
		}

		return null;
	}

	getFieldValue(record, path) {
		return path.split('.').reduce((obj, key) => (obj ? obj[key] : undefined), record);
	}

	sortRecords(fieldName) {
		const data = [...this.files];
		const sortFieldName = SORT_FIELD_NAME_BY_COLUMN[fieldName] || fieldName;

		data.sort((a, b) => {
			let aVal = this.getFieldValue(a, sortFieldName);
			let bVal = this.getFieldValue(b, sortFieldName);

			if (sortFieldName === 'lastModifiedDate') {
				aVal = aVal ? Date.parse(aVal) : null;
				bVal = bVal ? Date.parse(bVal) : null;
			} else if (typeof aVal === 'string' && typeof bVal === 'string') {
				aVal = aVal.toLowerCase();
				bVal = bVal.toLowerCase();
			}

			if (Number.isNaN(aVal)) return 1;
			if (Number.isNaN(bVal)) return -1;

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
				const formattedFiles = this.formatFilesInfo(formatExistingLocalFiles(data));
				this.files = formattedFiles;
				this.selection = this.selection.retain(formattedFiles.map((file) => file.localId));
				this.sortRecords(this.sortedBy);
			})
			.catch((error) => {
				if (isPermissionMissing(error)) {
					this.isAccessible = false;
					this.closeTabWhenReady();
				} else {
					showToast(this, UNABLE_TO_RETRIEVE_FILES, DEFAULT_FAILED_RETRIEVE_MESSAGE, 'error');
				}
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
		return this.recordIdentifierNames;
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

	get selectableFiles() {
		return this.displayedFiles.map((file) => {
			const isSelected = this.selection.has(file.localId);

			return {
				...file,
				isSelected,
				rowClass: isSelected ? 'slds-is-selected' : '',
				selectLabel: `Select ${file.name}`
			};
		});
	}

	get isBulkBarVisible() {
		return this.isBulkDownloadInProgress || !this.selection.isEmpty;
	}

	get hasSelectedFiles() {
		return !this.selection.isEmpty;
	}

	get bulkDownloadLabel() {
		return `Download (${this.selection.count})`;
	}

	get isSelectionLocked() {
		return this.isBulkDownloadInProgress;
	}

	get hasDisplayedFiles() {
		return this.displayedFiles.length > 0;
	}

	get isEveryDisplayedFileSelected() {
		return this.selection.includesAll(this.displayedFiles.map((file) => file.localId));
	}

	get isSelectAllDisabled() {
		return this.isSelectionLocked || !this.hasDisplayedFiles;
	}

	get sobjectNameValue() {
		if (isEmpty(this.recordIdentifierValue)) return 'Unknown';

		return (
			this.recordIdentifierValue.length > 50
				? `${this.recordIdentifierValue.slice(0, 47)}...`
				: this.recordIdentifierValue
		);
	}
}