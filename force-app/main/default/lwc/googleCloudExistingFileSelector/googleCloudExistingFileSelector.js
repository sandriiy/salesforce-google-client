import { LightningElement, api, track } from 'lwc';

import retrieveAttachableOwnedGoogleFiles from '@salesforce/apex/GoogleCloudFilesController.retrieveAttachableOwnedGoogleFiles';
import attachExistingFileToRecord from '@salesforce/apex/GoogleCloudFilesSharingController.attachExistingFileToRecord';

import { formatExistingLocalFiles, formatDateAsDayMonthYear, extractGraphValue, isEmpty, normalizeError, showToast } from 'c/googleCloudUtils';
import DEFAULT_OOPS_MESSAGE from 'c/googleCloudUtils';
import DEFAULT_FAILED_RETRIEVE_MESSAGE from 'c/googleCloudUtils';
import DEFAULT_FILES_CAPACITY_MESSAGE from 'c/googleCloudUtils';
import DEFAULT_FAILED_ATTACH_MESSAGE from 'c/googleCloudUtils';

export default class GoogleCloudExistingFileSelector extends LightningElement {
	@api variant = 'default';
	@api remainingSlots;
	@api source;
	@api recordId;

	@track allFiles = [];
	@track errorMessage = '';
	@track searchTerm = '';
	@track isLoading = false;
	@track isRefreshing = false;
	@track attachingFileId;

	connectedCallback() {
		this.loadFiles();
	}

	@api async refresh() {
		await this.loadFiles({ silent: true });
	}

	async loadFiles({ silent = false } = {}) {
		if (!this.recordId) {
			this.allFiles = [];
			this.errorMessage = '';
			this.isLoading = false;
			this.isRefreshing = false;
			return;
		}

		this.errorMessage = '';
		if (silent) {
			this.isRefreshing = true;
		} else {
			this.isLoading = true;
		}

		try {
			const result = await retrieveAttachableOwnedGoogleFiles({ relatedRecordId: this.recordId });
			this.allFiles = this.buildFileItems(Array.isArray(result) ? result : []);
		} catch (error) {
			this.errorMessage = normalizeError(error) || DEFAULT_FAILED_RETRIEVE_MESSAGE;
		} finally {
			this.isLoading = false;
			this.isRefreshing = false;
		}
	}

	buildFileItems(rawFiles) {
		const rawFilesById = new Map(
			(rawFiles || [])
				.filter(file => file?.Id)
				.map(file => [file.Id, file])
		);

		const formattedFiles = formatExistingLocalFiles(rawFiles || []);
		return formattedFiles.map(file => {
			const rawRecord = rawFilesById.get(file.localId);
			const linksCount = Number(extractGraphValue(rawRecord?.NumberOfLinks__c) || 0);

			return {
				...file,
				searchIndex: [file.name, file.type, file.size].filter(Boolean).join(' ').toLowerCase(),
				metaLine: [formatDateAsDayMonthYear(file.lastModifiedDate), file.size, file.type].filter(Boolean).join(' • '),
				linksLabel: linksCount > 0 ? `Linked to ${linksCount} record${linksCount === 1 ? '' : 's'}` : 'Not linked yet'
			};
		});
	}

	handleSearchChange(event) {
		this.searchTerm = event.detail?.value || '';
	}

	async handleAttachClick(event) {
		if (this.isAtCapacity) {
			showToast(this, 'Unable to Attach File', DEFAULT_FILES_CAPACITY_MESSAGE, 'warning');
			return;
		}

		const localFileId = event.currentTarget.dataset.id;
		const selectedFile = this.allFiles.find(file => file.localId === localFileId);
		if (!selectedFile) return;
		

		this.attachingFileId = localFileId;
		try {
			const linkId = await attachExistingFileToRecord({
				localFileRecordId: localFileId,
				relatedRecordId: this.recordId,
				source: this.source
			});

			this.allFiles = this.allFiles.filter(file => file.localId !== localFileId);
			showToast(this, 'File Attached', `${selectedFile.name} is now linked to this record.`, 'success');

			this.dispatchEvent(new CustomEvent('fileattached', {
				detail: {
					linkId,
					localFileId,
					fileName: selectedFile.name
				}
			}));
		} catch (error) {
			showToast(
				this,
				DEFAULT_OOPS_MESSAGE,
				normalizeError(error) || DEFAULT_FAILED_ATTACH_MESSAGE,
				'error'
			);
		} finally {
			this.attachingFileId = undefined;
		}
	}

	handleRefreshClick() {
		this.loadFiles({ silent: true });
	}

	get visibleFiles() {
		const normalizedSearchTerm = (this.searchTerm || '').trim().toLowerCase();
		return this.allFiles
			.filter(file => normalizedSearchTerm === '' || file.searchIndex.includes(normalizedSearchTerm))
			.map(file => ({
				...file,
				isBusy: file.localId === this.attachingFileId,
				isDisabled: this.isAtCapacity || (this.attachingFileId && file.localId !== this.attachingFileId)
			}));
	}

	get hasRecordContext() {
		return !isEmpty(this.recordId);
	}

	get hasFiles() {
		return this.visibleFiles.length > 0;
	}

	get hasError() {
		return !isEmpty(this.errorMessage);
	}

	get isCompact() {
		return this.variant === 'compact';
	}

	get panelClass() {
		return this.isCompact ? 'selector selector--compact' : 'selector';
	}

	get subtitle() {
		if (!this.hasRecordContext) {
			return 'Open a record to attach one of your existing files';
		}

		if (this.isAtCapacity) {
			return 'The record has reached its current file limit';
		}

		return 'Only files you own are available for attachment';
	}

	get emptyStateMessage() {
		if (!this.hasRecordContext) {
			return 'A record is required before existing files can be attached';
		}

		if (!isEmpty(this.searchTerm)) {
			return 'No owned files match your current search';
		}

		return 'All of your eligible files are already linked here, or no owned files are available yet';
	}

	get isAtCapacity() {
		return this.remainingSlots !== null && this.remainingSlots !== undefined && Number(this.remainingSlots) <= 0;
	}
}