import { LightningElement, track, wire } from 'lwc';
import retrieveFileExplorerFiles from '@salesforce/apex/GoogleCloudFilesController.retrieveFileExplorerFiles';
import retrieveAllGoogleFilesPage from '@salesforce/apex/GoogleCloudFilesController.retrieveAllGoogleFilesPage';
import searchFileExplorerFiles from '@salesforce/apex/GoogleCloudFilesController.searchFileExplorerFiles';
import retrieveFileExplorerColumns from '@salesforce/apex/GoogleCloudFilesController.retrieveFileExplorerColumns';
import USER_ID from '@salesforce/user/Id';
import GoogleCloudFileUploadModal from 'c/googleCloudUploaderModal';
import {
    showToast,
    isEmpty,
    normalizeError,
    createBulkSelection,
    DEFAULT_FAILED_RETRIEVE_MESSAGE
} from 'c/googleCloudUtils';
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
import {
    EMPTY_SEARCH_CRITERIA,
    normalizeSearchCriteria,
    hasSearchCriteria,
    toSearchRequest,
    isSameSearchRequest,
    resolveToday
} from 'c/googleCloudFileSearchUtils';
import {
    buildDatatableColumns,
    buildExplorerRows,
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
    ALL: 'all',
    SEARCH: 'search'
};

const EMPTY_STATE = {
    noMatch: { title: 'No files match your search', iconName: 'utility:search', canClear: true },
    noHeaderSearchMatch: { title: 'No files match your search', iconName: 'utility:search' },
    noFiles: { title: 'No files yet', iconName: 'utility:file' }
};

const UPLOAD_SOURCE = 'File Explorer';
const UNABLE_TO_UPLOAD_MESSAGE = 'Unable to upload file(s)';
const UNABLE_TO_RETRIEVE_MESSAGE = 'Unable to retrieve file(s)';

const OPENING_PAGE_SORT = {
    fieldName: 'lastModifiedDisplay',
    direction: 'desc'
};

const PAGE_SIZE = 50;
const MAX_EMPTY_PAGE_FOLLOW_UPS = 5;
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

    resolvedColumns = [];
    columns = [];

    sortedBy = 'lastModifiedDisplay';
    sortedDirection = 'desc';

    isLoadingMore = false;

    @track isPrivileged = false;
    serverRows = [];
    nextCursor = null;
    hasMoreServer = false;
    requestToken = 0;
    listGeneration = 0;
    searchDebounceTimer;

    searchCriteria = normalizeSearchCriteria(EMPTY_SEARCH_CRITERIA);

    selection = createBulkSelection();
    selectedRowIds = [];
    isBulkDownloadInProgress = false;
    isBulkDownloadStopping = false;
    bulkDownloadProgress;
    bulkDownloadControl;

    @wire(CurrentPageReference)
    wiredCurrentPageRef(pageRef) {
        this.currentPageRef = pageRef;
        this.applyTabPresentation();
    }

    connectedCallback() {
        this.loadFiles();
    }

    disconnectedCallback() {
        this.cancelPendingReload();
    }

    get hasError() {
        return !isEmpty(this.errorMessage);
    }

    get pageTitle() {
        if (this.selectedNavKey === NAV.SEARCH) return 'Search';
        if (this.selectedNavKey === NAV.ALL) return 'All Files';
        if (this.selectedNavKey === NAV.SHARED) return 'Shared with Me';
        return 'Owned by Me';
    }

    get navSelectedItem() {
        return this.selectedNavKey;
    }

    get isSearchView() {
        return this.selectedNavKey === NAV.SEARCH;
    }

    get showHeaderSearch() {
        return !this.isSearchView;
    }

    get defaultNavKey() {
        return this.isPrivileged ? NAV.ALL : NAV.OWNED;
    }

    get defaultSortField() {
        return resolveDefaultSortFieldName(this.resolvedColumns);
    }

    get isShownInOpeningPageOrder() {
        return this.sortedBy === OPENING_PAGE_SORT.fieldName && this.sortedDirection === OPENING_PAGE_SORT.direction;
    }

    get storageKey() {
        return `${STORAGE_KEY_PREFIX}${USER_ID}`;
    }

    get visibleRows() {
        return this.serverRows;
    }

    get enableInfiniteLoading() {
        return this.hasMoreServer;
    }

    get metaLine() {
        const count = this.serverRows.length;
        const hasMoreRows = this.hasMoreServer && count > 0;
        const countText = `${count}${hasMoreRows ? '+' : ''}`;
        const isSingle = count === 1 && !hasMoreRows;

        if (this.isSearchView && hasSearchCriteria(this.searchCriteria)) {
            return `${countText} ${isSingle ? 'file matches' : 'files match'} • Sorted by ${this.sortLabel}`;
        }

        if (this.isSearchView) {
            return `${countText} ${isSingle ? 'file' : 'files'} • Sorted by ${this.sortLabel}`;
        }

        return `${countText} ${count === 1 ? 'item' : 'items'} • Sorted by ${this.sortLabel}`;
    }

    get sortLabel() {
        return resolveColumnLabel(this.resolvedColumns, this.sortedBy) || 'Last Modified Date';
    }

    get showEmptyState() {
        return !this.isLoading && !this.isLoadingMore && !this.hasError && this.serverRows.length === 0;
    }

    get emptyState() {
        if (this.isSearchView) {
            return hasSearchCriteria(this.searchCriteria) ? EMPTY_STATE.noMatch : EMPTY_STATE.noFiles;
        }

        return isEmpty(this.searchTerm) ? EMPTY_STATE.noFiles : EMPTY_STATE.noHeaderSearchMatch;
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

    get bulkTotalCount() {
        return this.hasMoreServer ? 0 : this.serverRows.length;
    }

    async loadFiles() {
        const token = ++this.requestToken;
        this.listGeneration++;
        this.isLoading = true;
        this.isLoadingMore = false;
        this.errorMessage = '';

        try {
            const [columnResult, filesResult] = await Promise.all([
                this.loadColumns(),
                retrieveFileExplorerFiles()
            ]);
            if (token !== this.requestToken) return;

            this.isPrivileged = filesResult?.isPrivileged === true;
            this.applyResolvedColumns(columnResult);

            const restored = this.restoreExplorerState();
            this.searchCriteria = normalizeSearchCriteria(restored?.searchCriteria);

            if (this.isNonDefaultContext(restored)) {
                this.sortedBy = restored.sortField || this.defaultSortField;
                this.sortedDirection = restored.sortDirection || 'desc';
                this.searchTerm = restored.searchTerm || '';
                this.selectedNavKey = this.normalizeNavKey(restored.bucket);
                await this.serverReload();
                return;
            }

            this.selectedNavKey = this.defaultNavKey;
            if (!this.isShownInOpeningPageOrder) {
                await this.serverReload();
                return;
            }

            this.applyPageResult(filesResult, true);
            this.isLoading = false;
            await this.followUpEmptyPage();
        } catch (error) {
            if (token !== this.requestToken) return;

            this.errorMessage = normalizeError(error) || DEFAULT_FAILED_RETRIEVE_MESSAGE;
            showToast(this, UNABLE_TO_RETRIEVE_MESSAGE, this.errorMessage, 'error');
        } finally {
            if (token === this.requestToken) {
                this.isLoading = false;
            }
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
        this.columns = buildDatatableColumns(this.resolvedColumns);

        const availableSortFields = this.columns.filter(column => column.sortable).map(column => column.fieldName);
        if (!availableSortFields.includes(this.sortedBy)) {
            this.sortedBy = resolveDefaultSortFieldName(this.resolvedColumns);
            this.sortedDirection = 'desc';
        }
    }

    buildRows(rawFiles) {
        return buildExplorerRows(rawFiles, this.resolvedColumns);
    }

    handleNavSelect(event) {
        const navKey = this.normalizeNavKey(event.detail.name);
        if (navKey === this.selectedNavKey) return;

        this.selectedNavKey = navKey;
        this.searchTerm = '';
        this.serverReload();
    }

    handleSearch(event) {
        this.searchTerm = event.target.value || '';
        this.debouncedServerReload();
    }

    handleSearchCriteriaChange(event) {
        const nextCriteria = normalizeSearchCriteria(event.detail?.criteria);
        const isSameSearch = isSameSearchRequest(this.searchCriteria, nextCriteria, resolveToday());

        this.searchCriteria = nextCriteria;
        this.persistExplorerState();
        if (!isSameSearch) this.debouncedServerReload();
    }

    handleSearchClear() {
        this.cancelPendingReload();
        this.searchCriteria = normalizeSearchCriteria(EMPTY_SEARCH_CRITERIA);
        this.persistExplorerState();
        this.serverReload();
    }

    handleRowSelection(event) {
        const selectedRows = Array.isArray(event.detail?.selectedRows) ? event.detail.selectedRows : [];
        this.applySelection(createBulkSelection(selectedRows.map((row) => row.localId)));
    }

    handleSelectionClear() {
        this.applySelection(this.selection.clear());
    }

    async handleBulkDownload() {
        if (this.isBulkDownloadInProgress) return;

        const selectedFiles = this.selection.pick(this.serverRows, 'localId');
        const refusal = resolveBulkDownloadRefusal(selectedFiles);
        if (refusal) {
            showToast(this, BULK_DOWNLOAD_FAILED_TITLE, refusal, 'warning');
            return;
        }

        this.bulkDownloadControl = createOperationControl();
        this.isBulkDownloadInProgress = true;
        this.isBulkDownloadStopping = false;
        this.bulkDownloadProgress = { current: 0, total: selectedFiles.length, percent: 0 };

        try {
            const result = await downloadMany(selectedFiles, {
                zipName: (includedCount) => resolveBulkArchiveName(null, includedCount),
                control: this.bulkDownloadControl,
                onProgress: (progress) => {
                    this.bulkDownloadProgress = progress;
                }
            });

            this.showBulkDownloadToast(resolveBulkDownloadOutcome(result));
            this.applySelection(this.selection.deselect(result.downloaded.map((file) => file.localId)));
        } catch (error) {
            this.showBulkDownloadToast(resolveBulkDownloadFailure(error));
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
        this.serverReload();
    }

    handleLoadMore() {
        if (this.isLoadingMore || this.isLoading || !this.hasMoreServer || !this.nextCursor) return;
        this.loadMoreUntilRowsArrive();
    }

    async loadMoreUntilRowsArrive() {
        const generation = this.listGeneration;
        const countBefore = this.serverRows.length;
        let attempts = 0;
        let isCurrent = true;

        do {
            // eslint-disable-next-line no-await-in-loop
            isCurrent = await this.fetchServerPage(false);
            attempts++;
        } while (
            isCurrent &&
            generation === this.listGeneration &&
            !this.hasError &&
            this.serverRows.length === countBefore &&
            this.hasMoreServer &&
            this.nextCursor &&
            attempts < MAX_EMPTY_PAGE_FOLLOW_UPS
        );
    }

    async followUpEmptyPage() {
        if (this.hasError || this.serverRows.length > 0 || !this.hasMoreServer || !this.nextCursor) return;
        await this.loadMoreUntilRowsArrive();
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
        this.cancelPendingReload();
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.searchDebounceTimer = setTimeout(() => this.serverReload(), SEARCH_DEBOUNCE_MS);
    }

    cancelPendingReload() {
        if (this.searchDebounceTimer) {
            clearTimeout(this.searchDebounceTimer);
            this.searchDebounceTimer = undefined;
        }
    }

    async serverReload() {
        this.nextCursor = null;
        const isCurrent = await this.fetchServerPage(true);
        if (isCurrent) await this.followUpEmptyPage();
    }

    async fetchServerPage(reset) {
        const token = ++this.requestToken;

        if (reset) {
            this.listGeneration++;
            this.isLoading = true;
            this.isLoadingMore = false;
            this.errorMessage = '';
        } else {
            this.isLoadingMore = true;
        }

        try {
            const result = await this.requestPage(reset ? null : this.nextCursor);
            if (token !== this.requestToken) return false;

            this.applyPageResult(result, reset);
            return true;
        } catch (error) {
            if (token !== this.requestToken) return false;

            this.errorMessage = normalizeError(error) || DEFAULT_FAILED_RETRIEVE_MESSAGE;
            showToast(this, UNABLE_TO_RETRIEVE_MESSAGE, this.errorMessage, 'error');
            return true;
        } finally {
            if (token === this.requestToken) {
                this.isLoading = false;
                this.isLoadingMore = false;
            }
        }
    }

    requestPage(cursor) {
        const pageRequest = {
            sortField: this.sortedBy,
            sortDirection: this.sortedDirection,
            cursor,
            pageSize: PAGE_SIZE
        };

        if (this.isSearchView) {
            return searchFileExplorerFiles({ ...toSearchRequest(this.searchCriteria, resolveToday()), ...pageRequest });
        }

        return retrieveAllGoogleFilesPage({ ...pageRequest, searchTerm: this.searchTerm, bucket: this.selectedNavKey });
    }

    applyPageResult(result, reset) {
        const rows = this.buildRows(Array.isArray(result?.files) ? result.files : []);
        this.serverRows = reset ? rows : this.appendUnique(this.serverRows, rows);
        this.nextCursor = result?.nextCursor || null;
        this.hasMoreServer = result?.hasMore === true;

        if (reset) {
            this.applySelection(this.selection.retain(this.serverRows.map((row) => row.localId)));
        }

        this.persistExplorerState();
    }

    applySelection(nextSelection) {
        this.selection = nextSelection;
        this.selectedRowIds = nextSelection.toArray();
    }

    showBulkDownloadToast({ title, message, variant, mode }) {
        showToast(this, title, message, variant, mode);
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
        this.clearExplorerState();
        this.serverReload();
    }

    normalizeNavKey(navKey) {
        if (navKey === NAV.SEARCH) return NAV.SEARCH;
        if (this.isPrivileged) return NAV.ALL;
        return navKey === NAV.SHARED ? NAV.SHARED : NAV.OWNED;
    }

    isNonDefaultContext(state) {
        if (!state) return false;
        if (!isEmpty(state.searchTerm)) return true;
        if (this.normalizeNavKey(state.bucket) !== this.defaultNavKey) return true;
        if (state.sortField && state.sortField !== this.defaultSortField) return true;
        if (state.sortDirection && state.sortDirection !== 'desc') return true;
        return false;
    }

    persistExplorerState() {
        try {
            const state = {
                sortField: this.sortedBy,
                sortDirection: this.sortedDirection,
                searchTerm: this.searchTerm,
                bucket: this.selectedNavKey,
                searchCriteria: this.searchCriteria
            };
            window.sessionStorage.setItem(this.storageKey, JSON.stringify(state));
        } catch (error) {
            // sessionStorage unavailable — continue in memory
        }
    }

    restoreExplorerState() {
        try {
            const raw = window.sessionStorage.getItem(this.storageKey);
            const state = raw ? JSON.parse(raw) : null;
            if (!state) return null;

            const knownSortFields = this.columns.map(column => column.fieldName);
            if (state.sortField && !knownSortFields.includes(state.sortField)) {
                state.sortField = this.defaultSortField;
            }

            return state;
        } catch (error) {
            return null;
        }
    }

    clearExplorerState() {
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