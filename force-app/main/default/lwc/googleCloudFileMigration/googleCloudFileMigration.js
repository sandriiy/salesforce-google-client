import { LightningElement, track } from 'lwc';
import USER_ID from '@salesforce/user/Id';

import retrieveMigrationReadiness from '@salesforce/apex/GoogleCloudMigrationController.retrieveMigrationReadiness';
import previewMigrationCriteria from '@salesforce/apex/GoogleCloudMigrationController.previewMigrationCriteria';
import describeMigrationObjects from '@salesforce/apex/GoogleCloudMigrationController.describeMigrationObjects';
import startMigration from '@salesforce/apex/GoogleCloudMigrationController.startMigration';
import retrieveMigrationProgress from '@salesforce/apex/GoogleCloudMigrationController.retrieveMigrationProgress';
import stopMigration from '@salesforce/apex/GoogleCloudMigrationController.stopMigration';
import retrieveHiddenMigratedFiles from '@salesforce/apex/GoogleCloudMigrationController.retrieveHiddenMigratedFiles';
import retrieveAllGoogleFilesPage from '@salesforce/apex/GoogleCloudFilesController.retrieveAllGoogleFilesPage';
import retrieveFileExplorerColumns from '@salesforce/apex/GoogleCloudFilesController.retrieveFileExplorerColumns';

import {
    showToast,
    isEmpty,
    normalizeError,
    formatFileSize,
    formatDateAsDDMMYYYY_HHMM,
    DEFAULT_FAILED_RETRIEVE_MESSAGE
} from 'c/googleCloudUtils';
import {
    buildDatatableColumns,
    buildExplorerRows,
    resolveDefaultSortFieldName
} from 'c/googleCloudFileExplorerColumns';

const STAGE = {
    readiness: 'readiness',
    criteria: 'criteria',
    scope: 'scope',
    review: 'review'
};
const STAGE_ORDER = [STAGE.readiness, STAGE.criteria, STAGE.scope, STAGE.review];
const STAGE_LABELS = {
    readiness: 'Readiness',
    criteria: 'Files To Migrate',
    scope: 'Records & Options',
    review: 'Review & Start'
};
const CRITERIA_MODE = {
    everything: 'everything',
    condition: 'condition'
};
const RECORD_MODE = {
    any: 'any',
    objects: 'objects'
};
const RUN_STATUS = {
    running: 'running',
    waiting: 'waiting',
    stopping: 'stopping',
    stopped: 'stopped',
    finished: 'finished',
    failed: 'failed'
};
const RUN_STATUS_LABELS = {
    running: 'Running',
    waiting: 'Waiting for the next step',
    stopping: 'Stopping',
    stopped: 'Stopped',
    finished: 'Finished',
    failed: 'Stopped unexpectedly'
};
const FINAL_RUN_STATUSES = new Set([RUN_STATUS.stopped, RUN_STATUS.finished, RUN_STATUS.failed]);

const STORAGE_KEY_PREFIX = 'gcloud_migration_';
const RUN_HANDLE_RETENTION_MS = 7 * 24 * 60 * 60 * 1000;
const PROGRESS_POLL_INTERVAL_MS = 15000;
const STOPPING_POLL_INTERVAL_MS = 5000;
const WAITING_THRESHOLD_MS = 2 * 60 * 1000;
const PACE_WINDOW_SIZE = 4;
const DEFAULT_MAX_FILE_SIZE_BYTES = 5242880;
const DEFAULT_SECONDS_PER_STEP = 150;
const MIGRATED_FILES_BUCKET = 'migrated';
const MIGRATED_FILES_PAGE_SIZE = 50;
const MAX_EMPTY_PAGE_FOLLOW_UPS = 5;
const SEARCH_DEBOUNCE_MS = 300;
const CONDITION_JOIN = ' AND ';
const MIGRATION_STARTED_TITLE = 'Migration started';
const MIGRATION_STOPPING_TITLE = 'Stopping the migration';
const MIGRATION_STOPPING_MESSAGE = 'The files being copied right now will finish first. Keep this page open until the status reads Stopped.';
const UNABLE_TO_START_TITLE = 'Unable to start the migration';
const UNABLE_TO_STOP_TITLE = 'Unable to stop the migration';
const UNABLE_TO_RETRIEVE_FILES_TITLE = 'Unable to retrieve file(s)';
const NO_RUN_MESSAGE = 'No migration is running and no history is available.';
const NO_MATCHING_FILES_MESSAGE = '0 files match this condition, so there is nothing to migrate. Change the condition and check again.';
const NO_FILES_IN_SCOPE_MESSAGE = '0 files are within scope, so there is nothing to migrate.';
const LOADING_MIGRATED_FILES_MESSAGE = 'Loading migrated files...';

const STARTER_SNIPPETS = [
    { key: 'lastYear', label: 'Created in the last year', snippet: 'CreatedDate = LAST_N_DAYS:365' },
    { key: 'office', label: 'PDF and Office files', snippet: "FileExtension IN ('pdf', 'docx', 'xlsx', 'pptx')" },
    { key: 'owner', label: 'Owned by one user', snippet: "OwnerId = '005...'" },
    { key: 'private', label: 'Private files', snippet: "SharingPrivacy = 'P'" },
    { key: 'records', label: 'Attached to specific records', snippet: "ContentDocumentId IN (SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId IN ('001...'))" }
];

const SAMPLE_COLUMNS = [
    { label: 'Name', fieldName: 'name', type: 'text', wrapText: true },
    { label: 'Type', fieldName: 'fileExtension', type: 'text', initialWidth: 90 },
    { label: 'Size', fieldName: 'sizeLabel', type: 'text', initialWidth: 110 },
    { label: 'Owner', fieldName: 'ownerName', type: 'text' },
    { label: 'Created', fieldName: 'createdLabel', type: 'text', initialWidth: 160 }
];

export default class GoogleCloudFileMigration extends LightningElement {
    @track hasLoadedReadiness = false;
    @track blockers = [];
    @track isIntelligenceEnabled = false;
    uploadFolderId = '';
    maxFileSizeBytes = DEFAULT_MAX_FILE_SIZE_BYTES;

    @track currentStage = STAGE.readiness;
    @track criteriaMode = CRITERIA_MODE.everything;
    @track condition = '';
    @track checkResult = null;
    @track checkError = '';
    @track isChecking = false;
    checkedCondition = null;

    @track recordMode = RECORD_MODE.any;
    @track objectInput = '';
    @track objectError = '';
    @track objects = [];
    @track isValidatingObjects = false;
    @track skipIntelligence = false;
    @track isStarting = false;

    @track run = null;
    @track progress = null;
    @track isStopping = false;
    paceSamples = [];
    pollTimer;

    @track migratedRows = [];
    @track migratedColumns = [];
    @track isLoadingMigrated = false;
    @track isLoadingMoreMigrated = false;
    @track migratedSearchTerm = '';
    resolvedColumns = [];
    migratedSortedBy = 'lastModifiedDisplay';
    migratedSortedDirection = 'desc';
    migratedNextCursor = null;
    hasMoreMigrated = false;
    migratedRequestToken = 0;
    hiddenMigratedCount = 0;
    isHiddenMigratedCountFloor = false;
    searchDebounceTimer;

    sampleColumns = SAMPLE_COLUMNS;
    starterSnippets = STARTER_SNIPPETS;

    async connectedCallback() {
        this.run = this.restoreRunHandle();
        await Promise.all([this.loadReadiness(), this.loadMigratedFiles()]);
        await this.pollProgress();
    }

    disconnectedCallback() {
        this.clearPollTimer();
        if (this.searchDebounceTimer) {
            clearTimeout(this.searchDebounceTimer);
            this.searchDebounceTimer = undefined;
        }
    }

    get isPageLoading() {
        return !this.hasLoadedReadiness;
    }

    get hasBlockers() {
        return this.blockers.length > 0;
    }

    get showBlockers() {
        return this.hasLoadedReadiness && this.hasBlockers;
    }

    get showWorkspace() {
        return this.hasLoadedReadiness && !this.hasBlockers;
    }

    get maxFileSizeLabel() {
        return formatFileSize(this.maxFileSizeBytes, 0);
    }

    get scopeStatement() {
        return `Only Salesforce Files attached to a record and ${this.maxFileSizeLabel} or smaller are moved. Files not attached to any record, larger files, files stored outside Salesforce, notes and earlier versions of a file stay where they are.`;
    }

    get intelligenceStateText() {
        return this.isIntelligenceEnabled
            ? 'AI Analytics is on: migrated files get a summary and a label unless you skip it in the options.'
            : 'AI Analytics is off: migrated files get previews and folder placement only.';
    }

    get uploadFolderText() {
        return `Files land in the upload folder ${this.uploadFolderId} and move to their record's folder when a folder structure is configured.`;
    }

    get stageItems() {
        const currentIndex = STAGE_ORDER.indexOf(this.currentStage);
        return STAGE_ORDER.map((key, index) => ({
            key,
            label: STAGE_LABELS[key],
            className: key === this.currentStage ? 'step-button is-active' : 'step-button',
            disabled: index > currentIndex
        }));
    }

    get isReadinessStage() {
        return this.currentStage === STAGE.readiness;
    }

    get isCriteriaStage() {
        return this.currentStage === STAGE.criteria;
    }

    get isScopeStage() {
        return this.currentStage === STAGE.scope;
    }

    get isReviewStage() {
        return this.currentStage === STAGE.review;
    }

    get showBack() {
        return !this.isReadinessStage;
    }

    get criteriaModeOptions() {
        return [
            { label: 'All Migratable Files', value: CRITERIA_MODE.everything },
            { label: 'Files Matching Conditions', value: CRITERIA_MODE.condition }
        ];
    }

    get recordModeOptions() {
        return [
            { label: 'All Records', value: RECORD_MODE.any },
            { label: 'Only These SObjects', value: RECORD_MODE.objects }
        ];
    }

    get isConditionMode() {
        return this.criteriaMode === CRITERIA_MODE.condition;
    }

    get isObjectsMode() {
        return this.recordMode === RECORD_MODE.objects;
    }

    get normalizedCondition() {
        return this.isConditionMode ? (this.condition || '').trim() : '';
    }

    get isConditionChecked() {
        return this.checkResult !== null && this.checkedCondition === this.normalizedCondition;
    }

    get hasCheckResult() {
        return this.isConditionChecked;
    }

    get hasCheckError() {
        return !isEmpty(this.checkError);
    }

    get checkedTotalFiles() {
        return Number(this.checkResult?.totalFiles) || 0;
    }

    get hasMatchingFiles() {
        return this.isConditionChecked && this.checkedTotalFiles > 0;
    }

    get checkSummary() {
        if (!this.isConditionChecked) return '';
        const total = this.checkedTotalFiles;
        if (total === 0) return this.isConditionMode ? NO_MATCHING_FILES_MESSAGE : NO_FILES_IN_SCOPE_MESSAGE;
        const noun = total === 1 ? 'file matches and is' : 'files match and are';
        return `${this.formatCount(total)} ${noun} ${this.maxFileSizeLabel} or smaller. Files among them that are not attached to a record will be skipped.`;
    }

    get checkIconName() {
        return this.hasMatchingFiles ? 'utility:success' : 'utility:warning';
    }

    get checkIconVariant() {
        return this.hasMatchingFiles ? 'success' : 'warning';
    }

    get sampleCaption() {
        const shown = this.sampleRows.length;
        const total = this.checkedTotalFiles;
        if (total > shown) return `Showing the first ${this.formatCount(shown)} of ${this.formatCount(total)} matching files.`;
        return shown === 1 ? 'Showing the only matching file.' : `Showing all ${this.formatCount(shown)} matching files.`;
    }

    get sampleRows() {
        const samples = Array.isArray(this.checkResult?.sampleFiles) ? this.checkResult.sampleFiles : [];
        return samples.map((sample) => ({
            ...sample,
            fileExtension: (sample.fileExtension || '').toUpperCase(),
            sizeLabel: formatFileSize(Number(sample.size) || 0),
            createdLabel: formatDateAsDDMMYYYY_HHMM(sample.createdDate)
        }));
    }

    get hasSampleRows() {
        return this.sampleRows.length > 0;
    }

    get objectPills() {
        return this.objects.map((entry) => ({ label: `${entry.label} (${entry.name})`, name: entry.name }));
    }

    get hasObjects() {
        return this.objects.length > 0;
    }

    get hasObjectError() {
        return !isEmpty(this.objectError);
    }

    get selectedObjectNames() {
        return this.isObjectsMode ? this.objects.map((entry) => entry.name) : [];
    }

    get canProceed() {
        if (this.isReadinessStage) return !this.hasBlockers;
        if (this.isCriteriaStage) return this.isConditionChecked ? this.hasMatchingFiles : !this.isConditionMode;
        if (this.isScopeStage) return !this.isObjectsMode || this.hasObjects;
        return false;
    }

    get isNextDisabled() {
        return !this.canProceed || this.isChecking;
    }

    get reviewFilesText() {
        return this.isConditionMode ? this.normalizedCondition : 'All Migratable Files';
    }

    get reviewRecordsText() {
        return this.isObjectsMode ? this.objects.map((entry) => entry.label).join(', ') : 'All Records';
    }

    get reviewIntelligenceText() {
        if (!this.isIntelligenceEnabled) return 'Off for this org';
        return this.skipIntelligence ? 'Skipped for these files' : 'Summary and label, like any upload';
    }

    get reviewCountText() {
        if (!this.isConditionChecked) return 'Not checked yet';
        return `${this.formatCount(this.checkResult.totalFiles)} files. Only those attached to ${this.describeRecordScope(this.isObjectsMode ? this.objects : [])} are copied.`;
    }

    get estimateText() {
        const total = Number(this.checkResult?.totalFiles) || 0;
        const perStep = Number(this.checkResult?.filesPerStep) || 1;
        const seconds = Number(this.checkResult?.secondsPerStep) || DEFAULT_SECONDS_PER_STEP;
        const steps = Math.max(1, Math.ceil(total / perStep));
        return `Up to about ${this.formatDuration(steps * seconds * 1000)} for ${this.formatCount(total)} files, less when files are skipped. The estimate is refined as the migration runs.`;
    }

    get isStartDisabled() {
        return this.isStarting || this.isRunActive || !this.hasMatchingFiles;
    }

    get isRunActive() {
        return this.progress?.isActive === true || this.isStopping;
    }

    get hasRunHandle() {
        return this.run !== null;
    }

    get hasProgressContent() {
        return this.hasRunHandle || this.isRunActive;
    }

    get runStatus() {
        if (this.run) return this.run.status;
        return this.isStopping ? RUN_STATUS.stopping : RUN_STATUS.running;
    }

    get statusLabel() {
        return RUN_STATUS_LABELS[this.runStatus] || '';
    }

    get statusBadgeClass() {
        const status = this.runStatus;
        if (status === RUN_STATUS.finished) return 'slds-badge slds-theme_success';
        if (status === RUN_STATUS.failed) return 'slds-badge slds-theme_error';
        if (status === RUN_STATUS.stopping || status === RUN_STATUS.waiting) return 'slds-badge slds-theme_warning';
        if (status === RUN_STATUS.stopped) return 'slds-badge';
        return 'slds-badge slds-badge_inverse';
    }

    get statusDetail() {
        const status = this.runStatus;
        const startedBy = this.progress?.startedByName ? ` by ${this.progress.startedByName}` : '';
        if (status === RUN_STATUS.waiting && this.progress?.nextStepAtMs) {
            return `Next step at ${formatDateAsDDMMYYYY_HHMM(this.progress.nextStepAtMs)}`;
        }
        if (status === RUN_STATUS.failed) {
            return 'The migration stopped unexpectedly. Files already copied are kept; run it again to continue.';
        }
        if (this.run?.startedAt) {
            return `Started ${formatDateAsDDMMYYYY_HHMM(this.run.startedAt)}${startedBy}`;
        }
        return this.progress?.startedByName ? `Started${startedBy}` : '';
    }

    get isWaitingForNextStep() {
        const nextStepAtMs = this.progress?.nextStepAtMs;
        return this.progress?.isStepRunning !== true && !!nextStepAtMs && nextStepAtMs - Date.now() > WAITING_THRESHOLD_MS;
    }

    get copiedCountLabel() {
        const count = this.formatCount(this.progress?.copiedCount);
        return this.progress?.isCopiedCountCapped ? `${count}+` : count;
    }

    get progressPercent() {
        if (this.isRunFinished) return 100;
        const total = Number(this.run?.totalFiles) || 0;
        const copied = Number(this.progress?.copiedCount) || 0;
        if (total === 0) return FINAL_RUN_STATUSES.has(this.runStatus) ? 100 : 0;
        return Math.min(100, Math.round((copied / total) * 100));
    }

    get isRunFinished() {
        return this.runStatus === RUN_STATUS.finished;
    }

    get notCopiedCount() {
        return Math.max(0, (Number(this.run?.totalFiles) || 0) - (Number(this.progress?.copiedCount) || 0));
    }

    get hasFinishedNote() {
        return this.isRunFinished && this.progress?.isCopiedCountCapped !== true && this.notCopiedCount > 0;
    }

    get finishedNote() {
        return `The other ${this.formatCount(this.notCopiedCount)} matching files stay in Salesforce as expected, because they are already in Google Drive or not attached to ${this.describeRecordScope(this.run?.objects)}. Run again picks up any file that could not be copied.`;
    }

    get progressLine() {
        const total = Number(this.run?.totalFiles) || 0;
        if (this.isRunFinished) {
            return `Migration complete · ${this.copiedCountLabel} files copied to Google Drive`;
        }

        if (FINAL_RUN_STATUSES.has(this.runStatus)) {
            const notCopied = this.notCopiedCount;
            const notCopiedText = notCopied > 0 ? ` · ${this.formatCount(notCopied)} not copied (already in Google Drive, not attached to ${this.describeRecordScope(this.run?.objects)}, or failed)` : '';
            return `${this.copiedCountLabel} of ${this.formatCount(total)} copied${notCopiedText}`;
        }

        const eta = this.etaLabel;
        return `${this.copiedCountLabel} of ${this.formatCount(total)} copied${eta ? ` · ${eta}` : ''}`;
    }

    get etaLabel() {
        if (!this.run || this.paceSamples.length < 2) return '';
        const first = this.paceSamples[0];
        const last = this.paceSamples[this.paceSamples.length - 1];
        const rate = (last.copied - first.copied) / Math.max(1, last.t - first.t);
        if (rate <= 0) return '';
        const remaining = Math.max(0, Number(this.run.totalFiles || 0) - last.copied);
        return `about ${this.formatDuration(remaining / rate)} left`;
    }

    get runFilesText() {
        return this.run?.condition ? this.run.condition : 'All Migratable Files';
    }

    get runRecordsText() {
        const objects = Array.isArray(this.run?.objects) ? this.run.objects : [];
        return objects.length ? objects.map((entry) => entry.label).join(', ') : 'All Records';
    }

    get runIntelligenceText() {
        return this.run?.skipIntelligence ? 'Skipped' : 'As for any upload';
    }

    get anonymousRunText() {
        const startedBy = this.progress?.startedByName ? ` started by ${this.progress.startedByName}` : '';
        return `A migration is running${startedBy}. ${this.copiedCountLabel} files were copied in the last day. Its selection is only shown on the page it was started from.`;
    }

    get noRunMessage() {
        return NO_RUN_MESSAGE;
    }

    get showStop() {
        return this.isRunActive && !this.isStopping;
    }

    get showRunAgain() {
        return this.hasRunHandle && !this.isRunActive;
    }

    get showDismiss() {
        return this.hasRunHandle && !this.isRunActive;
    }

    get migratedMetaLine() {
        if (this.isLoadingMigrated) return LOADING_MIGRATED_FILES_MESSAGE;
        const count = this.migratedRows.length;
        if (this.hasMoreMigrated) return `${this.formatCount(count)}+ migrated files, scroll the list to load more`;
        const noun = count === 1 ? 'migrated file' : 'migrated files';
        return `${this.formatCount(count)} ${noun}`;
    }

    get hasHiddenMigratedFiles() {
        return this.hiddenMigratedCount > 0;
    }

    get hiddenMigratedFilesText() {
        const floor = this.isHiddenMigratedCountFloor ? 'At least ' : '';
        const isSingle = this.hiddenMigratedCount === 1;
        const subject = isSingle ? 'migrated file is' : 'migrated files are';
        return `${floor}${this.formatCount(this.hiddenMigratedCount)} ${subject} not shown because you do not have access to ${isSingle ? 'it' : 'them'}.`;
    }

    get hasNoMigratedFiles() {
        return !this.isLoadingMigrated && this.migratedRows.length === 0;
    }

    get noMigratedFilesMessage() {
        return isEmpty(this.migratedSearchTerm) ? 'No migrated files yet.' : 'No migrated files match your search.';
    }

    get enableMigratedInfiniteLoading() {
        return this.hasMoreMigrated;
    }

    async loadReadiness() {
        try {
            const readiness = await retrieveMigrationReadiness();
            this.blockers = Array.isArray(readiness?.blockers) ? readiness.blockers : [];
            this.isIntelligenceEnabled = readiness?.isIntelligenceEnabled === true;
            this.uploadFolderId = readiness?.uploadFolderId || '';
            this.maxFileSizeBytes = Number(readiness?.maxFileSizeBytes) || DEFAULT_MAX_FILE_SIZE_BYTES;
        } catch (error) {
            this.blockers = [normalizeError(error) || DEFAULT_FAILED_RETRIEVE_MESSAGE];
        } finally {
            this.hasLoadedReadiness = true;
        }
    }

    handleStepClick(event) {
        const stage = event.currentTarget.dataset.stage;
        if (!stage || STAGE_ORDER.indexOf(stage) > STAGE_ORDER.indexOf(this.currentStage)) return;
        this.currentStage = stage;
    }

    handleBack() {
        const index = STAGE_ORDER.indexOf(this.currentStage);
        if (index > 0) this.currentStage = STAGE_ORDER[index - 1];
    }

    async handleNext() {
        if (!this.canProceed) return;

        if (this.isCriteriaStage && !this.isConditionChecked) {
            await this.runCheck();
            if (!this.canProceed) return;
        }

        const index = STAGE_ORDER.indexOf(this.currentStage);
        if (index < STAGE_ORDER.length - 1) this.currentStage = STAGE_ORDER[index + 1];
    }

    handleEditStage(event) {
        const stage = event.currentTarget.dataset.stage;
        if (stage) this.currentStage = stage;
    }

    handleCriteriaModeChange(event) {
        this.criteriaMode = event.detail.value;
        this.resetCheck();
    }

    handleConditionChange(event) {
        this.condition = event.target.value || '';
        this.resetCheck();
    }

    handleSnippetClick(event) {
        const snippet = STARTER_SNIPPETS.find((entry) => entry.key === event.currentTarget.dataset.key);
        if (!snippet) return;

        const current = (this.condition || '').trim();
        this.condition = current ? `${current}${CONDITION_JOIN}${snippet.snippet}` : snippet.snippet;
        this.resetCheck();
    }

    handleCheck() {
        this.runCheck();
    }

    async runCheck() {
        const conditionToCheck = this.normalizedCondition;
        this.isChecking = true;
        this.checkError = '';

        try {
            const result = await previewMigrationCriteria({ condition: conditionToCheck });
            this.checkResult = result;
            this.checkedCondition = conditionToCheck;
        } catch (error) {
            this.checkResult = null;
            this.checkedCondition = null;
            this.checkError = normalizeError(error) || DEFAULT_FAILED_RETRIEVE_MESSAGE;
        } finally {
            this.isChecking = false;
        }
    }

    resetCheck() {
        this.checkResult = null;
        this.checkedCondition = null;
        this.checkError = '';
    }

    handleRecordModeChange(event) {
        this.recordMode = event.detail.value;
        this.objectError = '';
    }

    handleObjectInputChange(event) {
        this.objectInput = event.target.value || '';
    }

    handleObjectInputKeyDown(event) {
        if (event.key !== 'Enter') return;
        event.preventDefault();
        this.handleAddObject();
    }

    async handleAddObject() {
        const objectName = (this.objectInput || '').trim();
        if (!objectName || this.isValidatingObjects) return;

        if (this.objects.some((entry) => entry.name.toLowerCase() === objectName.toLowerCase())) {
            this.objectInput = '';
            return;
        }

        this.isValidatingObjects = true;
        this.objectError = '';

        try {
            const labels = await describeMigrationObjects({ objectNames: [objectName] });
            this.objects = [...this.objects, { name: objectName, label: labels?.[0] || objectName }];
            this.objectInput = '';
        } catch (error) {
            this.objectError = normalizeError(error);
        } finally {
            this.isValidatingObjects = false;
        }
    }

    handleObjectRemove(event) {
        const removedName = event.detail?.item?.name;
        this.objects = this.objects.filter((entry) => entry.name !== removedName);
    }

    handleSkipIntelligenceChange(event) {
        this.skipIntelligence = event.target.checked === true;
    }

    async handleStart() {
        if (this.isStartDisabled) return;
        this.isStarting = true;

        try {
            const result = await startMigration({
                condition: this.normalizedCondition,
                objectNames: this.selectedObjectNames,
                skipIntelligence: this.isIntelligenceEnabled && this.skipIntelligence
            });

            this.run = {
                startedAt: this.toMillis(result?.startedAt) || Date.now(),
                totalFiles: Number(result?.totalFiles) || 0,
                jobId: result?.jobId || null,
                condition: this.normalizedCondition,
                criteriaMode: this.criteriaMode,
                objects: this.isObjectsMode ? [...this.objects] : [],
                skipIntelligence: this.isIntelligenceEnabled && this.skipIntelligence,
                status: RUN_STATUS.running,
                finishedAt: null,
                savedAt: Date.now()
            };
            this.paceSamples = [];
            this.isStopping = false;
            this.progress = null;
            this.persistRunHandle();

            showToast(this, MIGRATION_STARTED_TITLE, `Copying ${this.formatCount(this.run.totalFiles)} files to Google Drive. Progress is shown below.`, 'success');
            this.currentStage = STAGE.readiness;
            this.resetCheck();
            await this.pollProgress();
        } catch (error) {
            showToast(this, UNABLE_TO_START_TITLE, normalizeError(error), 'error');
        } finally {
            this.isStarting = false;
        }
    }

    async handleStop() {
        this.isStopping = true;

        try {
            await stopMigration();
        } catch (error) {
            this.isStopping = false;
            showToast(this, UNABLE_TO_STOP_TITLE, normalizeError(error), 'error');
            return;
        }

        if (this.run) {
            this.run.status = RUN_STATUS.stopping;
            this.persistRunHandle();
        }

        showToast(this, MIGRATION_STOPPING_TITLE, MIGRATION_STOPPING_MESSAGE, 'info');
        await this.pollProgress();
    }

    handleRunAgain() {
        if (!this.run) return;

        this.criteriaMode = this.run.criteriaMode || CRITERIA_MODE.everything;
        this.condition = this.run.condition || '';
        const objects = Array.isArray(this.run.objects) ? this.run.objects : [];
        this.recordMode = objects.length ? RECORD_MODE.objects : RECORD_MODE.any;
        this.objects = [...objects];
        this.skipIntelligence = this.isIntelligenceEnabled && this.run.skipIntelligence === true;
        this.resetCheck();
        this.currentStage = STAGE.review;
        this.runCheck();

        const wizard = this.template.querySelector('.gc-migration-wizard');
        if (wizard) wizard.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }

    async handleDismiss() {
        this.run = null;
        this.progress = null;
        this.paceSamples = [];
        this.clearRunHandle();
        await this.pollProgress();
    }

    async pollProgress() {
        this.clearPollTimer();

        let next;
        try {
            next = await retrieveMigrationProgress({ countedSinceMillis: this.run ? this.run.startedAt : null });
        } catch {
            if (this.run || this.progress?.isActive) this.scheduleNextPoll();
            return;
        }

        this.applyProgress(next);
        if (this.shouldKeepPolling) this.scheduleNextPoll();
    }

    applyProgress(next) {
        const nowMs = Date.now();
        const isActive = next?.isActive === true;
        this.progress = {
            ...next,
            isActive,
            copiedCount: Number(next?.copiedCount) || 0,
            nextStepAtMs: this.toMillis(next?.nextStepAt),
            lastActivityAtMs: this.toMillis(next?.lastActivityAt)
        };

        if (this.run) {
            if (isActive) {
                this.run.status = this.isStopping
                    ? RUN_STATUS.stopping
                    : (this.isWaitingForNextStep ? RUN_STATUS.waiting : RUN_STATUS.running);
                this.recordPace(nowMs, this.progress.copiedCount);
            } else if (!FINAL_RUN_STATUSES.has(this.run.status)) {
                this.run.status = this.isStopping
                    ? RUN_STATUS.stopped
                    : (next?.lastStepFailed === true ? RUN_STATUS.failed : RUN_STATUS.finished);
                this.run.finishedAt = nowMs;
                this.isStopping = false;
                this.refreshMigratedFiles();
            }

            this.run.savedAt = nowMs;
            this.persistRunHandle();
        } else if (!isActive) {
            this.isStopping = false;
        }

        if (this.isStopping && isActive && this.progress.nextStepAtMs) {
            stopMigration().catch(() => undefined);
        }
    }

    recordPace(nowMs, copied) {
        this.paceSamples = [...this.paceSamples, { t: nowMs, copied }].slice(-PACE_WINDOW_SIZE);
    }

    get shouldKeepPolling() {
        return this.progress?.isActive === true || this.isStopping;
    }

    scheduleNextPoll() {
        this.clearPollTimer();
        const delay = this.isStopping ? STOPPING_POLL_INTERVAL_MS : PROGRESS_POLL_INTERVAL_MS;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.pollTimer = setTimeout(() => this.pollProgress(), delay);
    }

    clearPollTimer() {
        if (this.pollTimer) {
            clearTimeout(this.pollTimer);
            this.pollTimer = undefined;
        }
    }

    get storageKey() {
        return `${STORAGE_KEY_PREFIX}${USER_ID}`;
    }

    persistRunHandle() {
        if (!this.run) return;
        try {
            window.localStorage.setItem(this.storageKey, JSON.stringify(this.run));
        } catch {
            this.isStorageUnavailable = true;
        }
    }

    restoreRunHandle() {
        try {
            const raw = window.localStorage.getItem(this.storageKey);
            const handle = raw ? JSON.parse(raw) : null;
            if (!handle || !handle.startedAt) return null;

            const referenceMs = handle.finishedAt || handle.savedAt || handle.startedAt;
            if (Date.now() - referenceMs > RUN_HANDLE_RETENTION_MS) {
                window.localStorage.removeItem(this.storageKey);
                return null;
            }

            return handle;
        } catch {
            return null;
        }
    }

    clearRunHandle() {
        try {
            window.localStorage.removeItem(this.storageKey);
        } catch {
            this.isStorageUnavailable = true;
        }
    }

    async loadMigratedFiles() {
        try {
            const columnResult = await retrieveFileExplorerColumns();
            this.resolvedColumns = Array.isArray(columnResult) ? columnResult : [];
        } catch {
            this.resolvedColumns = [];
        }

        this.migratedColumns = buildDatatableColumns(this.resolvedColumns);
        this.migratedSortedBy = resolveDefaultSortFieldName(this.resolvedColumns);
        this.loadHiddenMigratedFiles();
        await this.fetchMigratedPage(true);
    }

    async loadHiddenMigratedFiles() {
        try {
            const result = await retrieveHiddenMigratedFiles();
            this.hiddenMigratedCount = Number(result?.hiddenCount) || 0;
            this.isHiddenMigratedCountFloor = result?.isAtLeast === true;
        } catch {
            this.hiddenMigratedCount = 0;
            this.isHiddenMigratedCountFloor = false;
        }
    }

    async fetchMigratedPage(reset) {
        const token = ++this.migratedRequestToken;
        if (reset) {
            this.isLoadingMigrated = true;
        } else {
            this.isLoadingMoreMigrated = true;
        }

        try {
            const result = await retrieveAllGoogleFilesPage({
                sortField: this.migratedSortedBy,
                sortDirection: this.migratedSortedDirection,
                searchTerm: this.migratedSearchTerm,
                cursor: reset ? null : this.migratedNextCursor,
                pageSize: MIGRATED_FILES_PAGE_SIZE,
                bucket: MIGRATED_FILES_BUCKET
            });
            if (token !== this.migratedRequestToken) return;

            const rows = buildExplorerRows(Array.isArray(result?.files) ? result.files : [], this.resolvedColumns);
            this.migratedRows = reset ? rows : this.appendUnique(this.migratedRows, rows);
            this.migratedNextCursor = result?.nextCursor || null;
            this.hasMoreMigrated = result?.hasMore === true;
        } catch (error) {
            if (token !== this.migratedRequestToken) return;
            showToast(this, UNABLE_TO_RETRIEVE_FILES_TITLE, normalizeError(error) || DEFAULT_FAILED_RETRIEVE_MESSAGE, 'error');
        } finally {
            if (token === this.migratedRequestToken) {
                this.isLoadingMigrated = false;
                this.isLoadingMoreMigrated = false;
            }
        }
    }

    appendUnique(existing, incoming) {
        const seen = new Set((existing || []).map((row) => row.localId));
        const merged = [...(existing || [])];
        (incoming || []).forEach((row) => {
            if (!seen.has(row.localId)) {
                seen.add(row.localId);
                merged.push(row);
            }
        });
        return merged;
    }

    handleMigratedSearch(event) {
        this.migratedSearchTerm = event.target.value || '';
        if (this.searchDebounceTimer) clearTimeout(this.searchDebounceTimer);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.searchDebounceTimer = setTimeout(() => this.fetchMigratedPage(true), SEARCH_DEBOUNCE_MS);
    }

    handleMigratedSort(event) {
        this.migratedSortedBy = event.detail.fieldName;
        this.migratedSortedDirection = event.detail.sortDirection;
        this.fetchMigratedPage(true);
    }

    handleMigratedLoadMore() {
        if (this.isLoadingMoreMigrated || this.isLoadingMigrated || !this.hasMoreMigrated || !this.migratedNextCursor) return;
        this.loadMoreMigratedUntilRowsArrive();
    }

    async loadMoreMigratedUntilRowsArrive() {
        const countBefore = this.migratedRows.length;
        let attempts = 0;

        do {
            // eslint-disable-next-line no-await-in-loop
            await this.fetchMigratedPage(false);
            attempts++;
        } while (
            this.migratedRows.length === countBefore &&
            this.hasMoreMigrated &&
            this.migratedNextCursor &&
            attempts < MAX_EMPTY_PAGE_FOLLOW_UPS
        );
    }

    handleMigratedTitleClick(event) {
        const localFileId = event.detail?.rowId;
        const previewModal = this.refs.filePreviewModal;
        if (!localFileId || !previewModal) return;
        previewModal.open(localFileId);
    }

    handleMigratedRefresh() {
        this.refreshMigratedFiles();
    }

    refreshMigratedFiles() {
        this.loadHiddenMigratedFiles();
        this.fetchMigratedPage(true);
    }

    toMillis(value) {
        if (value === null || value === undefined || value === '') return null;
        const millis = typeof value === 'number' ? value : new Date(value).getTime();
        return Number.isNaN(millis) ? null : millis;
    }

    formatDuration(millis) {
        const totalMinutes = Math.round(millis / 60000);
        if (totalMinutes < 1) return 'under a minute';
        if (totalMinutes < 60) return `${totalMinutes} min`;
        const hours = Math.floor(totalMinutes / 60);
        const minutes = totalMinutes % 60;
        return minutes === 0 ? `${hours} h` : `${hours} h ${minutes} min`;
    }

    formatCount(value) {
        return Number(value || 0).toLocaleString();
    }

    describeRecordScope(objects) {
        const labels = (Array.isArray(objects) ? objects : []).map((entry) => entry.label);
        if (labels.length === 0) return 'a record';
        if (labels.length === 1) return `${labels[0]} records`;
        return `${labels.slice(0, -1).join(', ')} or ${labels[labels.length - 1]} records`;
    }
}
