import { LightningElement, api, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { NavigationMixin } from 'lightning/navigation';

import { updateTabPresentation, closeWhenReady } from 'c/googleCloudCrossPlatformUtils';

import { BIG_FILE_SIZE } from 'c/googleCloudDownloadUtils';
import { download, downloadInChunks } from 'c/googleCloudDownloadUtils';
import { isEmpty, showToast } from 'c/googleCloudUtils';
import { DEFAULT_FILE_NAME, DEFAULT_ACCESS_RESTRICTED_MESSAGE, DEFAULT_FAILED_DOWNLOAD_MESSAGE } from 'c/googleCloudUtils';
import { INT_VIEW_FILE_DETAILS_PAGE_NAME } from 'c/googleCloudCrossPlatformUtils';

import GoogleCloudUploadFileModal from 'c/googleCloudUploaderModal';
import GoogleCloudFilePublicLinkModal from 'c/googleCloudFilePublicLinkModal';
import GoogleCloudFileDeleteModal from 'c/googleCloudFileDeleteModal';
import GoogleCloudFileSharingModal from 'c/googleCloudFileSharingModal';

import fetchFileAccess from '@salesforce/apex/GoogleCloudFilesController.fetchFileAccess';
import fetchFileHeaderDetails from '@salesforce/apex/GoogleCloudFilesViewController.fetchFileHeaderDetails';

import yesAccesstemplate from './googleCloudFilePageDetails.html';
import noAccessTemplate from './googleCloudFilePageDetailsNoAccess.html';

const OBJECT_API_NAME = 'GoogleFile__c';
const TAB_POLL_DELAY_MS = 200;
const TAB_MAX_RETRIES = 5;

export default class GoogleCloudFilePageDetails extends NavigationMixin(LightningElement) {
	@track fileName;
	@track tabTitle;

	@track tabInfo;
	@track headerFieldData = [];
	@track accessLevel;

	@track hasRecordAccess = false;
	@track isAccessChecked = false;
	@track isHeaderLoading = true;
	@track isMainLoading = true;

	currentPageRef;
	recordId;
	latestVersionRecord;

	@wire(CurrentPageReference)
	wiredCurrentPageRef(pageRef) {
		this.currentPageRef = pageRef;

		const newRecordId = pageRef?.state?.c__recordId;
		if (newRecordId && newRecordId !== this.recordId) {
			this.recordId = newRecordId;
			this.initializePage();
		}
	}

	render() {
		if (!this.isAccessChecked) {
			return yesAccesstemplate;
		}

		return this.hasRecordAccess ? yesAccesstemplate : noAccessTemplate;
	}

	handleLatestVersionSelection(event) {
		this.latestVersionRecord = event.detail.version;
	}

	async handleFlowStatusChange(event) {
		if (event.detail.status === 'ERROR') {
			showToast(
				this,
				'Unable to save File Details',
				'Please try again or contact your System Administrator',
				'error'
			);
		} else if (event.detail.status === 'FINISHED') {
			const headerDto = await fetchFileHeaderDetails({ localFileRecordId: this.recordId });
			this.headerFieldData = headerDto?.compactFields || [];
			this.fileName = headerDto?.name;
		}
	}

	handleRedirectClick(event) {
		const recordId = event.currentTarget.dataset.id;
		this[NavigationMixin.Navigate]({
			type: 'standard__recordPage',
			attributes: {
				recordId: recordId,
				actionName: 'view'
			}
		});
	}

	async handleFileDownload(event) {
		this.showLatestVersionWarning();
		this.isHeaderLoading = true;
		await this.downloadFile();
		this.isHeaderLoading = false;
	}

	handleFilePreview(event) {
		this.showLatestVersionWarning();
		let previewComponent = this.refs.filePreviewModal;
		previewComponent.open(this.recordId);
	}

	async handleFileSharing(event) {
		if (this.denyOperationIfReadOnly()) return;

		await GoogleCloudFileSharingModal.open({
			size: 'small',
			label: `Share ${this.fileName}`,
			localFileRecordId: this.recordId
		});
	}

	handleFileEdit(event) {
		this.initializePage();
	}

	handleFileVersionUpload(event) {
		if (this.denyOperationIfReadOnly()) return;

		const fileInput = this.template.querySelector('.file-input');
		if (fileInput) {
			fileInput.click();
		}
	}

	async handleFileSelected(event) {
		const selectedFiles = [...event.target.files];
		if (!isEmpty(selectedFiles)) {
			await GoogleCloudUploadFileModal.open({
				recordId: this.recordId,
				localGoogleRecordId: this.recordId,
				uploadSource: 'File Details',
				size: 'small',
				inputFiles: selectedFiles
			});

			let versionsComponent = this.refs.versions;
			versionsComponent.refresh();

			const headerDto = await fetchFileHeaderDetails({ localFileRecordId: this.recordId });
			this.headerFieldData = headerDto?.compactFields || [];
		}
	}

	handleNewVersionRequest(event) {
		const fileInput = this.template.querySelector('.file-input');
		if (fileInput) {
			fileInput.click();
		}
	}

	async handlePublicLinkCreate(event) {
		if (this.denyOperationIfReadOnly()) return;

		this.showLatestVersionWarning();
		await GoogleCloudFilePublicLinkModal.open({
			size: 'small',
			label: 'Create public link',
			localFileVersionId: this.latestVersionRecord.Id
		});
	}

	async handleFileDelete(event) {
		if (this.denyOperationIfReadOnly()) return;

		let isDeleted = await GoogleCloudFileDeleteModal.open({
			size: 'small',
			label: `Delete ${this.fileName}`,
			localFileRecordId: this.recordId
		});

		if (isDeleted) {
			showToast(this, `File "${this.fileName}" was deleted`, '', 'success');
			setTimeout(() => {
				closeWhenReady({
					getTabInfo: () => this.tabInfo,
					maxRetries: TAB_MAX_RETRIES,
					pollDelayMs: TAB_POLL_DELAY_MS
				});
			}, 2000);
		}
	}

	async initializePage() {
		this.isHeaderLoading = true;
		this.isMainLoading = true;
		this.isAccessChecked = false;
		this.hasRecordAccess = false;

		if (!this.recordId) {
			this.hasRecordAccess = false;
			this.isAccessChecked = true;
			this.isHeaderLoading = false;
			this.isMainLoading = false;
			this.fileName = undefined;
			this.headerFieldData = [];
			this.updateTabLabel();
			return;
		}

		try {
			const accessLevel = await fetchFileAccess({ localGoogleFileId: this.recordId });

			this.accessLevel = accessLevel;
			this.hasRecordAccess = this.hasAccess;

			if (this.hasRecordAccess) {
				const headerDto = await fetchFileHeaderDetails({
					localFileRecordId: this.recordId
				});

				this.fileName = headerDto?.name;
				this.headerFieldData = headerDto?.compactFields || [];

				if (this.isReadOnlyAccess) {
					showToast(
						this,
						'Read-Only Access',
						'This file is read-only. Some actions are disabled. Contact the file owner for full access',
						'warning'
					);
				}
			} else {
				this.fileName = undefined;
				this.headerFieldData = [];
			}
		} catch (error) {
			this.hasRecordAccess = false;
			this.fileName = undefined;
			this.headerFieldData = [];
		} finally {
			this.isAccessChecked = true;
			this.isHeaderLoading = false;
			this.isMainLoading = false;
			this.updateTabLabel();
		}
	}

	async downloadFile() {
		try {
			let googleVersion = this.latestVersionRecord;
			if (googleVersion.Size__c <= BIG_FILE_SIZE) {
				await download(googleVersion.Id, {
					fileName: googleVersion.Name,
					mimeType: googleVersion.Type__c
				});
			} else {
				await downloadInChunks(googleVersion.Id, {
					size: googleVersion.Size__c,
					fileName: googleVersion.Name,
					mimeType: googleVersion.Type__c,
					onError: (err) => {
						throw new Error(err?.message || err);
					}
				});
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

	showLatestVersionWarning() {
		showToast(
			this,
			`Latest File Version Applied`,
			`Using the file version: ${this.latestVersionRecord?.Name ?? DEFAULT_FILE_NAME}`,
			'info'
		);
	}

	updateTabLabel() {
		const baseTitle = this.hasRecordAccess && this.fileName ? this.fileName : 'No Access';
		const label = `${baseTitle} | File`;

		this.tabTitle = label;

		updateTabPresentation({
			label,
			iconName: 'standard:document',
			iconOptions: {
				tooltip: label,
				iconAlt: 'File'
			},
			targetComponentName: INT_VIEW_FILE_DETAILS_PAGE_NAME,
			maxRetries: TAB_MAX_RETRIES,
			pollDelayMs: TAB_POLL_DELAY_MS
		}).then((result) => {
			this.tabInfo = result?.tabInfo || null;
		});
	}

	denyOperationIfReadOnly() {
		if (this.isReadOnlyAccess) {
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

	get headerCompactFields() {
		const sourceFields = Array.isArray(this.headerFieldData) ? this.headerFieldData : [];

		return sourceFields.map((field, index) => {
			const referenceUrl =
				field.isReference && field.referenceId ? `/${field.referenceId}` : null;

			return {
				...field,
				key: `${field.apiName}-${index}`,
				containerClass: 'cloud-compact-field',
				referenceUrl
			};
		});
	}

	get hasHeaderCompactFields() {
		return Array.isArray(this.headerFieldData) && this.headerFieldData.length > 0;
	}

	get objectApiName() {
		return OBJECT_API_NAME;
	}

	get flowInputVariables() {
		return [
			{
				name: 'fileId',
				type: 'String',
				value: this.recordId
			},
			{
				name: 'IsReadOnly',
				type: 'Boolean',
				value: this.isReadOnlyAccess
			}
		];
	}

	get hasAccess() {
		return isEmpty(this.accessLevel) ? false : true;
	}

	get isEditAccess() {
		return this.accessLevel === 'Edit';
	}

	get isReadOnlyAccess() {
		return this.accessLevel === 'View' || isEmpty(this.accessLevel);
	}
}