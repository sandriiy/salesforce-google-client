import { LightningElement, track, wire } from 'lwc';
import retrieveAllGoogleFiles from '@salesforce/apex/GoogleCloudFilesController.retrieveAllGoogleFiles';
import USER_ID from '@salesforce/user/Id';
import GoogleCloudFileUploadModal from 'c/googleCloudUploaderModal';
import {
    showToast,
    isEmpty,
    normalizeError,
    formatExistingLocalFiles,
    formatDateAsDDMMYYYY_HHMM,
    extractGraphValue,
    asString,
    DEFAULT_FAILED_RETRIEVE_MESSAGE
} from 'c/googleCloudUtils';

import { CurrentPageReference } from 'lightning/navigation';
import { updateTabPresentation } from 'c/googleCloudCrossPlatformUtils';

const TAB_FALLBACK_COMPONENT_NAME = 'c__googleCloudFileExplorer';
const TAB_FALLBACK_NAV_ITEM_API_NAME = 'GoogleClientFileExplorer';

const TAB_POLL_DELAY_MS = 200;
const TAB_MAX_RETRIES = 5;

const NAV = {
    OWNED: 'owned',
    SHARED: 'shared'
};

const COLUMN = {
    TITLE: 'nameSort',
    IS_LINKED: 'isLinkedSort',
    ACCESS: 'accessSort',
    OWNER: 'ownerNameSort',
    LAST_MODIFIED: 'lastModifiedSort'
};

const UPLOAD_SOURCE = 'File Explorer';
const UNABLE_TO_UPLOAD_MESSAGE = 'Unable to upload file(s)';

export default class GoogleCloudFileExplorer extends LightningElement {
    @track isLoading = true;
    @track errorMessage = '';
    @track selectedNavKey = NAV.OWNED;
    @track isNewFileVersionUpload = false;
    @track activeActionFileId = null;

    currentPageRef;
    tabInfo;
    hasAppliedTabPresentation = false;

    allRows = [];
    bucketOwned = [];
    bucketShared = [];

    sortedBy = 'lastModifiedDisplay';
    sortedDirection = 'desc';

    columns = [
        {
            label: 'Title',
            fieldName: 'fileName',
            type: 'button',
            sortable: true,
            wrapText: true,
            typeAttributes: {
                label: { fieldName: 'fileName' },
                name: 'openPreview',
                variant: 'base',
                title: { fieldName: 'fileName' }
            },
            cellAttributes: {
                alignment: 'left',
                class: 'slds-text-align_left'
            }
        },
        {
            label: 'Is Linked?',
            fieldName: 'isLinkedLabel',
            type: 'text',
            sortable: true
        },
        {
            label: 'Access',
            fieldName: 'accessLabel',
            type: 'text',
            sortable: true
        },
        {
            label: 'Owner',
            fieldName: 'ownerName',
            type: 'text',
            sortable: true
        },
        {
            label: 'Last Modified Date',
            fieldName: 'lastModifiedDisplay',
            type: 'text',
            sortable: true
        }
    ];

    @wire(CurrentPageReference)
    wiredCurrentPageRef(pageRef) {
        this.currentPageRef = pageRef;
        this.applyTabPresentation();
    }

    connectedCallback() {
        this.loadFiles();
    }

    get hasError() {
        return !isEmpty(this.errorMessage);
    }

    get pageTitle() {
        if (this.selectedNavKey === NAV.OWNED) return 'Owned by Me';
        if (this.selectedNavKey === NAV.SHARED) return 'Shared with Me';
        return 'Unknown';
    }

    get visibleRows() {
        return this.applySort(this.getSelectedBucket(), this.sortedBy, this.sortedDirection);
    }

    get metaLine() {
        const count = this.getSelectedBucket().length;
        const itemText = count === 1 ? 'item' : 'items';
        return `${count} ${itemText} • Sorted by ${this.sortLabel}`;
    }

    get sortLabel() {
        switch (this.sortedBy) {
            case 'fileName':
                return 'Title';
            case 'isLinkedLabel':
                return 'Is Linked?';
            case 'accessLabel':
                return 'Access';
            case 'ownerName':
                return 'Owner';
            case 'lastModifiedDisplay':
                return 'Last Modified Date';
            default:
                return 'Last Modified Date';
        }
    }

    async loadFiles() {
        this.isLoading = true;
        this.errorMessage = '';

        try {
            const result = await retrieveAllGoogleFiles();
            const rawFiles = Array.isArray(result) ? result : [];
            const rows = this.buildRows(rawFiles);

            this.allRows = rows;
            this.bucketOwned = rows.filter(row => row.ownerId === USER_ID);
            this.bucketShared = rows.filter(row => row.ownerId && row.ownerId !== USER_ID);
        } catch (error) {
            this.errorMessage = normalizeError(error) || DEFAULT_FAILED_RETRIEVE_MESSAGE;
            showToast(this, 'Unable to retrieve file(s)', this.errorMessage, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    buildRows(rawFiles) {
        const formattedFiles = formatExistingLocalFiles(rawFiles);
        const rawByLocalId = this.indexRawFilesById(rawFiles);

        return formattedFiles.map(file => {
            const rawRecord = rawByLocalId.get(file.localId);
            const linksCount = Number(extractGraphValue(rawRecord?.NumberOfLinks__c) || 0);
            const isLinked = linksCount > 0;
            const ownerName = asString(rawRecord?.CreatedBy?.Name) || (file.createdBy?.name || '');
            const ownerId = asString(rawRecord?.CreatedById) || (file.createdBy?.id || '');
            const accessLabel = asString(file.mode) || 'Viewer';

            return {
                ...file,
                fileName: file.name || 'Untitled',
                nameSort: (file.name || 'Untitled').toLowerCase(),
                isLinkedLabel: isLinked ? 'Yes' : 'No',
                isLinkedSort: isLinked ? 1 : 0,
                accessLabel,
                accessSort: accessLabel.toLowerCase(),
                ownerName,
                ownerId,
                ownerNameSort: (ownerName || '').toLowerCase(),
                lastModifiedDisplay: formatDateAsDDMMYYYY_HHMM(file.lastModifiedDate),
                lastModifiedSort: this.toTimestamp(file.lastModifiedDate)
            };
        });
    }

    indexRawFilesById(rawFiles) {
        const byId = new Map();
        (rawFiles || []).forEach(record => {
            if (record?.Id) byId.set(record.Id, record);
        });
        return byId;
    }

    toTimestamp(value) {
        const time = new Date(value).getTime();
        return Number.isNaN(time) ? 0 : time;
    }

    getSelectedBucket() {
        if (this.selectedNavKey === NAV.OWNED) return this.bucketOwned || [];
        if (this.selectedNavKey === NAV.SHARED) return this.bucketShared || [];
        return [];
    }

    handleNavSelect(event) {
        this.selectedNavKey = event.detail.name;
    }

    handleSort(event) {
        this.sortedBy = event.detail.fieldName;
        this.sortedDirection = event.detail.sortDirection;
    }

    resolveSortKey(fieldName) {
        switch (fieldName) {
            case 'fileName':
                return COLUMN.TITLE;
            case 'isLinkedLabel':
                return COLUMN.IS_LINKED;
            case 'accessLabel':
                return COLUMN.ACCESS;
            case 'ownerName':
                return COLUMN.OWNER;
            case 'lastModifiedDisplay':
                return COLUMN.LAST_MODIFIED;
            default:
                return COLUMN.LAST_MODIFIED;
        }
    }

    applySort(rows, fieldName, direction) {
        const isDesc = direction === 'desc';
        const sortKey = this.resolveSortKey(fieldName);
        const sortedRows = [...(rows || [])];

        sortedRows.sort((leftRow, rightRow) => {
            const leftValue = leftRow?.[sortKey];
            const rightValue = rightRow?.[sortKey];

            if (sortKey.endsWith('Sort')) {
                if (typeof leftValue === 'number' || typeof rightValue === 'number') {
                    const leftNumber = Number(leftValue || 0);
                    const rightNumber = Number(rightValue || 0);
                    return isDesc ? rightNumber - leftNumber : leftNumber - rightNumber;
                }

                const leftText = (leftValue ?? '').toString().toLowerCase();
                const rightText = (rightValue ?? '').toString().toLowerCase();
                if (leftText === rightText) return 0;
                return isDesc ? (leftText < rightText ? 1 : -1) : (leftText < rightText ? -1 : 1);
            }

            const leftText = (leftValue ?? '').toString().toLowerCase();
            const rightText = (rightValue ?? '').toString().toLowerCase();
            if (leftText === rightText) return 0;
            return isDesc ? (leftText < rightText ? 1 : -1) : (leftText < rightText ? -1 : 1);
        });

        return sortedRows;
    }

    /**
     * Applies tab label/icon in workspace, supporting both:
     * 1) standard__component (URL-addressable LWC)
     * 2) standard__navItemPage (custom Lightning tab)
     *
     * We pass a broad target so the utility can match whichever routing mode opened this page.
     */
    async applyTabPresentation() {
        if (this.hasAppliedTabPresentation) return;

        const label = 'File Explorer';
        const pageRef = this.currentPageRef || {};
        const pageRefType = pageRef?.type;
        const pageRefAttributes = pageRef?.attributes || {};

        const target = {
            componentName: pageRefAttributes.componentName || TAB_FALLBACK_COMPONENT_NAME,
            navItemApiName: pageRefAttributes.apiName || TAB_FALLBACK_NAV_ITEM_API_NAME,
            pageRefType: pageRefType || null
        };

        try {
            const result = await updateTabPresentation({
                label,
                iconName: 'standard:document',
                iconOptions: {
                    tooltip: label,
                    iconAlt: 'File Explorer'
                },
                target,
                maxRetries: TAB_MAX_RETRIES,
                pollDelayMs: TAB_POLL_DELAY_MS
            });

            this.tabInfo = result?.tabInfo || null;
            this.hasAppliedTabPresentation = true;
        } catch (e) {
            this.tabInfo = null;
        }
    }

    handleRowAction(event) {
        const actionName = event.detail?.action?.name;
        const row = event.detail?.row;
        if (actionName !== 'openPreview' || !row?.localId) return;
        this.openPreview(row.localId);
    }

    openPreview(localFileId) {
        const previewModal = this.refs.filePreviewModal;
        if (!previewModal || !localFileId) return;
        previewModal.open(localFileId);
    }

    handleUploadClick() {
        const fileInput = this.template.querySelector('.gcdc-file-explorer-file-input');
        if (fileInput) fileInput.click();
    }

    async handleFileSelected(event) {
        const selectedFiles = [...(event.target.files || [])];
        if (isEmpty(selectedFiles)) return;

        try {
            this.isLoading = true;

            if (this.isNewFileVersionUpload) {
                const previewModal = this.refs.filePreviewModal;

                if (!previewModal || !this.activeActionFileId) {
                    throw new Error('Unable to upload new version: preview context is missing.');
                }

                await previewModal.uploadNewVersion(selectedFiles, UPLOAD_SOURCE);
            } else {
                await GoogleCloudFileUploadModal.open({
                    uploadSource: UPLOAD_SOURCE,
                    size: 'small',
                    inputFiles: selectedFiles
                });
            }

            await this.refreshExplorerData();
        } catch (error) {
            const message = normalizeError(error);
            showToast(this, UNABLE_TO_UPLOAD_MESSAGE, message, 'error');
        } finally {
            this.isLoading = false;
            this.handleFileInputReset(event);
            this.isNewFileVersionUpload = false;
            this.activeActionFileId = null;
        }
    }

    handleFileInputReset(event) {
        const input = event?.target || this.template.querySelector('.gcdc-file-explorer-file-input');
        if (input) input.value = null;
    }

    handleNewVersionRequest(event) {
        const localGoogleRecordId = event?.detail?.localGoogleRecordId;
        if (isEmpty(localGoogleRecordId)) return;

        this.activeActionFileId = localGoogleRecordId;
        this.isNewFileVersionUpload = true;
        this.handleUploadClick();
    }

    handlePreviewCloseReset() {
        this.isNewFileVersionUpload = false;
        this.activeActionFileId = null;
    }

    handleFileDelete() {
        this.refreshExplorerData();
    }

    handleFileEdit() {
        this.refreshExplorerData();
    }

    async refreshExplorerData() {
        await this.loadFiles();
    }
}