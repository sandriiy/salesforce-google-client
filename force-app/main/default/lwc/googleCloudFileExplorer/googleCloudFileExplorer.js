import { LightningElement, track, wire } from 'lwc';
import retrieveAllGoogleFiles from '@salesforce/apex/GoogleCloudFilesController.retrieveAllGoogleFiles';
import retrieveAllGoogleFilesPage from '@salesforce/apex/GoogleCloudFilesController.retrieveAllGoogleFilesPage';
import retrieveFileExplorerColumns from '@salesforce/apex/GoogleCloudFilesController.retrieveFileExplorerColumns';
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
import {
    buildDatatableColumns,
    buildStandardColumnValues,
    buildCustomColumnValues,
    resolveSortField,
    resolveColumnLabel,
    resolveDefaultSortFieldName
} from 'c/googleCloudFileExplorerColumns';

import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import { updateTabPresentation } from 'c/googleCloudCrossPlatformUtils';

const TAB_FALLBACK_COMPONENT_NAME = 'c__googleCloudFileExplorer';
const TAB_FALLBACK_NAV_ITEM_API_NAME = 'GoogleClientFileExplorer';

const TAB_POLL_DELAY_MS = 200;
const TAB_MAX_RETRIES = 5;

const NAV = {
    OWNED: 'owned',
    SHARED: 'shared',
    ALL: 'all'
};

const UPLOAD_SOURCE = 'File Explorer';
const UNABLE_TO_UPLOAD_MESSAGE = 'Unable to upload file(s)';

const PAGE_SIZE = 50;
const SEARCH_DEBOUNCE_MS = 300;
const STORAGE_KEY_PREFIX = 'gcloud_explorer_';

export default class GoogleCloudFileExplorer extends NavigationMixin(LightningElement) {
    @track isLoading = true;
    @track errorMessage = '';
    @track selectedNavKey = NAV.OWNED;
    @track isNewFileVersionUpload = false;
    @track activeActionFileId = null;
    @track searchTerm = '';

    currentPageRef;
    tabInfo;
    hasAppliedTabPresentation = false;

    allRows = [];
    bucketOwned = [];
    bucketShared = [];

    resolvedColumns = [];
    columns = [];

    sortedBy = 'lastModifiedDisplay';
    sortedDirection = 'desc';

    filteredSortedRows = [];
    renderedCount = PAGE_SIZE;
    isLoadingMore = false;

    @track isPrivileged = false;
    serverRows = [];
    nextCursor = null;
    hasMoreServer = false;
    requestToken = 0;
    searchDebounceTimer;

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
        if (this.isPrivileged) return 'All Files';
        if (this.selectedNavKey === NAV.OWNED) return 'Owned by Me';
        if (this.selectedNavKey === NAV.SHARED) return 'Shared with Me';
        return 'Unknown';
    }

    get navSelectedItem() {
        return this.isPrivileged ? NAV.ALL : this.selectedNavKey;
    }

    get defaultSortField() {
        return resolveDefaultSortFieldName(this.resolvedColumns);
    }

    get storageKey() {
        return `${STORAGE_KEY_PREFIX}${USER_ID}`;
    }

    get visibleRows() {
        if (this.isPrivileged) return this.serverRows;
        return this.filteredSortedRows.slice(0, this.renderedCount);
    }

    get enableInfiniteLoading() {
        if (this.isPrivileged) return this.hasMoreServer;
        return this.renderedCount < this.filteredSortedRows.length;
    }

    get metaLine() {
        const count = this.isPrivileged ? this.serverRows.length : this.filteredSortedRows.length;
        const suffix = this.isPrivileged && this.hasMoreServer ? '+' : '';
        const itemText = count === 1 ? 'item' : 'items';
        return `${count}${suffix} ${itemText} • Sorted by ${this.sortLabel}`;
    }

    get sortLabel() {
        return resolveColumnLabel(this.resolvedColumns, this.sortedBy) || 'Last Modified Date';
    }

    get hasNoSearchResults() {
        const count = this.isPrivileged ? this.serverRows.length : this.filteredSortedRows.length;
        return !this.hasError && !isEmpty(this.searchTerm) && count === 0;
    }

    async loadFiles() {
        this.isLoading = true;
        this.errorMessage = '';

        try {
            const [columnResult, filesResult] = await Promise.all([
                this.loadColumns(),
                retrieveAllGoogleFiles()
            ]);

            this.isPrivileged = filesResult?.isPrivileged === true;
            this.applyResolvedColumns(columnResult);

            if (this.isPrivileged) {
                const restored = this.restoreCursorState();
                if (this.isNonDefaultContext(restored)) {
                    this.sortedBy = restored.sortField;
                    this.sortedDirection = restored.sortDirection || 'desc';
                    this.searchTerm = restored.searchTerm || '';
                    this.columns = buildDatatableColumns(this.resolvedColumns, true);
                    await this.fetchServerPage(true);
                } else {
                    this.serverRows = this.buildRows(Array.isArray(filesResult?.files) ? filesResult.files : []);
                    this.nextCursor = filesResult?.nextCursor || null;
                    this.hasMoreServer = filesResult?.hasMore === true;
                    this.persistCursorState();
                }
            } else {
                const rows = this.buildRows(Array.isArray(filesResult?.files) ? filesResult.files : []);
                this.allRows = rows;
                this.bucketOwned = rows.filter(row => row.ownerId === USER_ID);
                this.bucketShared = rows.filter(row => row.ownerId && row.ownerId !== USER_ID);
                this.recomputeRows();

                if (filesResult?.hasMore) {
                    showToast(
                        this,
                        'Showing a subset of files',
                        `Showing the first ${rows.length} files. Use global search to reach the rest.`,
                        'info'
                    );
                }
            }
        } catch (error) {
            this.errorMessage = normalizeError(error) || DEFAULT_FAILED_RETRIEVE_MESSAGE;
            showToast(this, 'Unable to retrieve file(s)', this.errorMessage, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async loadColumns() {
        try {
            return await retrieveFileExplorerColumns();
        } catch (error) {
            return [];
        }
    }

    applyResolvedColumns(columnResult) {
        this.resolvedColumns = Array.isArray(columnResult) ? columnResult : [];
        this.columns = buildDatatableColumns(this.resolvedColumns, this.isPrivileged);

        const availableSortFields = this.columns.map(column => column.fieldName);
        if (!availableSortFields.includes(this.sortedBy)) {
            this.sortedBy = resolveDefaultSortFieldName(this.resolvedColumns);
            this.sortedDirection = 'desc';
        }
    }

    buildRows(rawFiles) {
        const formattedFiles = formatExistingLocalFiles(rawFiles);
        const rawByLocalId = this.indexRawFilesById(rawFiles);

        return formattedFiles.map(file => {
            const rawRecord = rawByLocalId.get(file.localId);
            const latestVersion = rawRecord?.GoogleFileVersions__r?.[0];
            const linksCount = Number(extractGraphValue(rawRecord?.NumberOfLinks__c) || 0);
            const isLinked = linksCount > 0;
            const ownerName = asString(rawRecord?.CreatedBy?.Name) || (file.createdBy?.name || '');
            const ownerId = asString(rawRecord?.CreatedById) || (file.createdBy?.id || '');
            const fileOwner = asString(rawRecord?.Owner?.Name) || '';
            const fileOwnerId = asString(rawRecord?.OwnerId) || '';
            const accessLabel = asString(rawRecord?.UserAccessLevel__c) || 'View';

            return {
                ...file,
                ...buildStandardColumnValues(file),
                ...buildCustomColumnValues(this.resolvedColumns, latestVersion),
                fileName: file.name || 'Untitled',
                nameSort: (file.name || 'Untitled').toLowerCase(),
                isLinkedLabel: isLinked ? 'Yes' : 'No',
                isLinkedSort: linksCount,
                accessLabel,
                accessSort: accessLabel.toLowerCase(),
                ownerName,
                ownerId,
                ownerNameSort: (ownerName || '').toLowerCase(),
                fileOwner,
                fileOwnerId,
                fileOwnerSort: fileOwner.toLowerCase(),
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

    getFilteredBucket() {
        const bucket = this.getSelectedBucket();
        if (isEmpty(this.searchTerm)) return bucket;

        const term = this.searchTerm.toLowerCase();
        return bucket.filter(row => {
            const name = (row.fileName || '').toLowerCase();
            const summary = (row.summary || '').toLowerCase();
            return name.includes(term) || summary.includes(term);
        });
    }

    recomputeRows() {
        this.filteredSortedRows = this.applySort(this.getFilteredBucket(), this.sortedBy, this.sortedDirection);
        this.renderedCount = PAGE_SIZE;
    }

    handleNavSelect(event) {
        if (this.isPrivileged) return;
        this.selectedNavKey = event.detail.name;
        this.searchTerm = '';
        this.recomputeRows();
    }

    handleSearch(event) {
        this.searchTerm = event.target.value || '';
        if (this.isPrivileged) {
            this.debouncedServerReload();
        } else {
            this.recomputeRows();
        }
    }

    handleUserClick(event) {
        const userId = event.detail?.userId;
        if (isEmpty(userId)) return;

        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: userId,
                actionName: 'view'
            }
        });
    }

    handleSort(event) {
        this.sortedBy = event.detail.fieldName;
        this.sortedDirection = event.detail.sortDirection;
        if (this.isPrivileged) {
            this.serverReload();
        } else {
            this.recomputeRows();
        }
    }

    handleLoadMore() {
        if (this.isPrivileged) {
            if (this.isLoadingMore || !this.hasMoreServer || !this.nextCursor) return;
            this.fetchServerPage(false);
            return;
        }

        if (this.isLoadingMore || !this.enableInfiniteLoading) return;

        this.isLoadingMore = true;
        this.renderedCount = Math.min(this.renderedCount + PAGE_SIZE, this.filteredSortedRows.length);
        this.isLoadingMore = false;
    }

    applySort(rows, fieldName, direction) {
        const isDesc = direction === 'desc';
        const sortKey = resolveSortField(this.resolvedColumns, fieldName);
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

	handleTitleClick(event) {
		const localFileId = event.detail?.rowId;
		if (!localFileId) return;
		this.openPreview(localFileId);
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

    debouncedServerReload() {
        if (this.searchDebounceTimer) {
            clearTimeout(this.searchDebounceTimer);
        }
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.searchDebounceTimer = setTimeout(() => this.serverReload(), SEARCH_DEBOUNCE_MS);
    }

    async serverReload() {
        this.nextCursor = null;
        await this.fetchServerPage(true);
    }

    async fetchServerPage(reset) {
        const token = ++this.requestToken;

        if (reset) {
            this.isLoading = true;
        } else {
            this.isLoadingMore = true;
        }

        try {
            const request = {
                sortField: this.sortedBy,
                sortDirection: this.sortedDirection,
                searchTerm: this.searchTerm,
                cursor: reset ? null : this.nextCursor,
                pageSize: PAGE_SIZE
            };

            const result = await retrieveAllGoogleFilesPage({ request });
            if (token !== this.requestToken) return;

            const rows = this.buildRows(Array.isArray(result?.files) ? result.files : []);
            this.serverRows = reset ? rows : this.appendUnique(this.serverRows, rows);
            this.nextCursor = result?.nextCursor || null;
            this.hasMoreServer = result?.hasMore === true;
            this.persistCursorState();
        } catch (error) {
            this.errorMessage = normalizeError(error) || DEFAULT_FAILED_RETRIEVE_MESSAGE;
            showToast(this, 'Unable to retrieve file(s)', this.errorMessage, 'error');
        } finally {
            if (reset) {
                this.isLoading = false;
            } else {
                this.isLoadingMore = false;
            }
        }
    }

    appendUnique(existing, incoming) {
        const seen = new Set((existing || []).map(row => row.localId));
        const merged = [...(existing || [])];
        (incoming || []).forEach(row => {
            if (!seen.has(row.localId)) {
                seen.add(row.localId);
                merged.push(row);
            }
        });
        return merged;
    }

    handleRefresh() {
        if (this.isPrivileged) {
            this.clearCursorState();
            this.serverReload();
        } else {
            this.refreshExplorerData();
        }
    }

    isNonDefaultContext(state) {
        if (!state) return false;
        if (!isEmpty(state.searchTerm)) return true;
        if (state.sortField && state.sortField !== this.defaultSortField) return true;
        if (state.sortDirection && state.sortDirection !== 'desc') return true;
        return false;
    }

    persistCursorState() {
        try {
            const state = {
                sortField: this.sortedBy,
                sortDirection: this.sortedDirection,
                searchTerm: this.searchTerm,
                cursor: this.nextCursor
            };
            window.sessionStorage.setItem(this.storageKey, JSON.stringify(state));
        } catch (error) {
            // sessionStorage unavailable — continue in memory
        }
    }

    restoreCursorState() {
        try {
            const raw = window.sessionStorage.getItem(this.storageKey);
            return raw ? JSON.parse(raw) : null;
        } catch (error) {
            return null;
        }
    }

    clearCursorState() {
        try {
            window.sessionStorage.removeItem(this.storageKey);
        } catch (error) {
            // ignore
        }
    }

    async refreshExplorerData() {
        await this.loadFiles();
    }
}