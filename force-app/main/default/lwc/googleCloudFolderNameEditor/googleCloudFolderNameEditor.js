import { LightningElement, api } from 'lwc';

import { asString, isEmpty } from 'c/googleCloudUtils';

import checkRecordFolderNamePattern from '@salesforce/apex/GoogleCloudFolderSetupController.checkRecordFolderNamePattern';

const DEFAULT_MAX_PATTERNS = 50;
const CHECK_DELAY_MS = 600;
const PATTERN_FIELDS = ['objectApiName', 'pattern'];
const CHECK_STATUS = {
    saved: 'saved',
    checking: 'checking',
    valid: 'valid',
    invalid: 'invalid'
};
const CHECKING_MESSAGE = 'Checking…';
const CHECK_FAILED_MESSAGE = 'The formula could not be checked. Please try again.';
const INCOMPLETE_MESSAGE = 'Enter both the object and its formula.';
const DUPLICATE_MESSAGE = 'Another row already names this object.';
const WARNING_NOT_CONFIRMED_MESSAGE = 'Tick the acknowledgement under this formula, or change the formula.';
const ACKNOWLEDGEMENT_REQUIRED_MESSAGE = 'Tick this to save the formula, or change the formula.';
const ACKNOWLEDGEMENT_PREFIX = 'I acknowledge that ';
const ACKNOWLEDGEMENT_JOINER = ', and that ';
const ACKNOWLEDGEMENT_LOAD_NOTICE = ', which may slow down your organization and increase its load.';

export default class GoogleCloudFolderNameEditor extends LightningElement {
    @api disabled = false;
    @api maxPatterns = DEFAULT_MAX_PATTERNS;

    localRows = [];
    rowSequence = 0;
    lastAppliedValue = null;
    pendingChecks = new Map();
    checkTimers = new Map();
    lastReportedValidity = null;

    @api
    get value() {
        return this.serializeRows(this.localRows);
    }

    set value(nextValue) {
        const normalizedValue = asString(nextValue).trim();
        if (normalizedValue === this.lastAppliedValue) {
            return;
        }

        this.lastAppliedValue = normalizedValue;
        this.localRows = this.parseRows(normalizedValue);
        this.reportValidityChange();
    }

    @api checkValidity() {
        return this.validationMessage === null;
    }

    @api reportValidity() {
        const inputs = Array.from(this.template.querySelectorAll('lightning-input, lightning-textarea'));
        inputs.forEach((input) => {
            if (input.dataset.role === 'acknowledgement') {
                this.reportAcknowledgement(input);
            } else if (typeof input.reportValidity === 'function') {
                input.reportValidity();
            }
        });

        return this.checkValidity();
    }

    @api async waitForPendingChecks() {
        this.checkTimers.forEach((timer, rowKey) => {
            clearTimeout(timer);
            this.checkTimers.delete(rowKey);
            this.startCheck(rowKey);
        });

        await Promise.all(Array.from(this.pendingChecks.values()));
    }

    connectedCallback() {
        this.lastReportedValidity = undefined;
        this.reportValidityChange();
        this.localRows.forEach((row) => this.scheduleCheck(row.key, 0));
    }

    disconnectedCallback() {
        this.checkTimers.forEach((timer) => clearTimeout(timer));
        this.checkTimers.clear();
    }

    handleFieldChange(event) {
        const rowKey = event.target.dataset.rowKey;
        const field = event.target.dataset.field;
        if (!rowKey || !PATTERN_FIELDS.includes(field)) {
            return;
        }

        this.updateRow(rowKey, {
            [field]: event.target.value == null ? '' : event.target.value,
            status: CHECK_STATUS.checking,
            message: CHECKING_MESSAGE,
            warnings: [],
            isWarningConfirmed: false,
            exampleName: null
        });
        this.emitChange();
        this.scheduleCheck(rowKey, CHECK_DELAY_MS);
    }

    handleWarningConfirmation(event) {
        const acknowledgement = event.target;
        this.updateRow(acknowledgement.dataset.rowKey, { isWarningConfirmed: acknowledgement.checked });
        this.reportAcknowledgement(acknowledgement);
        this.reportValidityChange();
    }

    handleAddPattern() {
        if (!this.canAddPattern) {
            return;
        }

        this.localRows = [...this.localRows, { ...this.createEmptyRow(), status: CHECK_STATUS.invalid, message: INCOMPLETE_MESSAGE }];
        this.emitChange();
    }

    handleRemovePattern(event) {
        const rowKey = event.currentTarget.dataset.rowKey;
        clearTimeout(this.checkTimers.get(rowKey));
        this.checkTimers.delete(rowKey);
        this.pendingChecks.delete(rowKey);
        this.localRows = this.localRows.filter((row) => row.key !== rowKey);
        this.emitChange();
    }

    scheduleCheck(rowKey, delayMs) {
        clearTimeout(this.checkTimers.get(rowKey));
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.checkTimers.set(rowKey, setTimeout(() => {
            this.checkTimers.delete(rowKey);
            this.startCheck(rowKey);
        }, delayMs));
    }

    startCheck(rowKey) {
        const row = this.localRows.find((candidate) => candidate.key === rowKey);
        if (!row) {
            return;
        }

        const objectApiName = asString(row.objectApiName).trim();
        const pattern = asString(row.pattern).trim();
        if (isEmpty(objectApiName) || isEmpty(pattern)) {
            this.updateRow(rowKey, { status: CHECK_STATUS.invalid, message: INCOMPLETE_MESSAGE });
            this.reportValidityChange();
            return;
        }

        const checkPromise = checkRecordFolderNamePattern({ objectApiName, pattern })
            .then((result) => this.applyCheckResult(rowKey, objectApiName, pattern, result))
            .catch(() => this.applyCheckResult(rowKey, objectApiName, pattern, { isValid: false, message: CHECK_FAILED_MESSAGE }))
            .finally(() => {
                if (this.pendingChecks.get(rowKey) === checkPromise) {
                    this.pendingChecks.delete(rowKey);
                }
            });

        this.pendingChecks.set(rowKey, checkPromise);
    }

    applyCheckResult(rowKey, objectApiName, pattern, result) {
        const row = this.localRows.find((candidate) => candidate.key === rowKey);
        if (!row || asString(row.objectApiName).trim() !== objectApiName || asString(row.pattern).trim() !== pattern) {
            return;
        }

        const isSavedRow = row.status === CHECK_STATUS.saved;
        const warnings = Array.isArray(result?.warnings) ? result.warnings : [];
        this.updateRow(rowKey, {
            objectApiName: result?.isValid && result.objectApiName ? result.objectApiName : row.objectApiName,
            status: result?.isValid ? CHECK_STATUS.valid : CHECK_STATUS.invalid,
            message: result?.isValid ? null : result?.message || CHECK_FAILED_MESSAGE,
            warnings,
            isWarningConfirmed: isSavedRow || row.isWarningConfirmed,
            objectLabel: result?.objectLabel || null,
            exampleName: result?.exampleName || null
        });

        if (result?.isValid && result.objectApiName && result.objectApiName !== objectApiName) {
            this.emitChange();
            return;
        }

        this.reportValidityChange();
    }

    reportAcknowledgement(acknowledgement) {
        if (typeof acknowledgement.setCustomValidity !== 'function') {
            return;
        }

        acknowledgement.setCustomValidity(acknowledgement.checked ? '' : ACKNOWLEDGEMENT_REQUIRED_MESSAGE);
        acknowledgement.reportValidity();
    }

    buildAcknowledgement(warnings) {
        const statements = warnings.map((warning) => asString(warning).trim().replace(/\.$/, ''));
        return `${ACKNOWLEDGEMENT_PREFIX}${statements.join(ACKNOWLEDGEMENT_JOINER)}${ACKNOWLEDGEMENT_LOAD_NOTICE}`;
    }

    updateRow(rowKey, changes) {
        this.localRows = this.localRows.map((row) => (row.key === rowKey ? { ...row, ...changes } : row));
    }

    emitChange() {
        const serialized = this.serializeRows(this.localRows);
        this.lastAppliedValue = serialized;
        this.dispatchEvent(new CustomEvent('patternschange', { detail: { value: serialized } }));
        this.reportValidityChange();
    }

    reportValidityChange() {
        const message = this.validationMessage;
        if (message === this.lastReportedValidity) {
            return;
        }

        this.lastReportedValidity = message;
        this.dispatchEvent(new CustomEvent('validitychange', { detail: { isValid: message === null, message } }));
    }

    createEmptyRow() {
        this.rowSequence += 1;
        return {
            key: `folder-name-${this.rowSequence}`,
            objectApiName: '',
            pattern: '',
            status: CHECK_STATUS.saved,
            message: null,
            warnings: [],
            isWarningConfirmed: true,
            objectLabel: null,
            exampleName: null
        };
    }

    parseRows(rawValue) {
        if (isEmpty(rawValue)) {
            return [];
        }

        let parsed;
        try {
            parsed = JSON.parse(rawValue);
        } catch {
            return [];
        }

        if (!Array.isArray(parsed)) {
            return [];
        }

        return parsed
            .filter((entry) => entry && typeof entry === 'object')
            .slice(0, this.effectiveMaxPatterns)
            .map((entry) => ({
                ...this.createEmptyRow(),
                objectApiName: asString(entry.objectApiName),
                pattern: asString(entry.pattern)
            }));
    }

    serializeRows(rows) {
        if (!rows || rows.length === 0) {
            return '';
        }

        return JSON.stringify(rows.map((row) => ({
            objectApiName: asString(row.objectApiName).trim(),
            pattern: asString(row.pattern).trim()
        })));
    }

    resolveRowProblem(row, duplicateKeys) {
        if (isEmpty(asString(row.objectApiName).trim()) || isEmpty(asString(row.pattern).trim())) {
            return INCOMPLETE_MESSAGE;
        }

        if (duplicateKeys.has(row.key)) {
            return DUPLICATE_MESSAGE;
        }

        if (row.status === CHECK_STATUS.checking) {
            return CHECKING_MESSAGE;
        }

        if (row.status === CHECK_STATUS.invalid) {
            return row.message || CHECK_FAILED_MESSAGE;
        }

        if (row.warnings?.length > 0 && !row.isWarningConfirmed) {
            return WARNING_NOT_CONFIRMED_MESSAGE;
        }

        return null;
    }

    resolveDuplicateKeys() {
        const seenObjects = new Set();
        const duplicateKeys = new Set();
        this.localRows.forEach((row) => {
            const objectKey = asString(row.objectApiName).trim().toLowerCase();
            if (isEmpty(objectKey)) {
                return;
            }

            if (seenObjects.has(objectKey)) {
                duplicateKeys.add(row.key);
            }

            seenObjects.add(objectKey);
        });

        return duplicateKeys;
    }

    get validationMessage() {
        const duplicateKeys = this.resolveDuplicateKeys();
        for (const row of this.localRows) {
            const problem = this.resolveRowProblem(row, duplicateKeys);
            if (problem) {
                const objectName = asString(row.objectApiName).trim();
                return objectName ? `Folder name for ${objectName}: ${problem}` : `Folder name: ${problem}`;
            }
        }

        return null;
    }

    get effectiveMaxPatterns() {
        const parsed = Number(this.maxPatterns);
        return Number.isInteger(parsed) && parsed > 0 ? parsed : DEFAULT_MAX_PATTERNS;
    }

    get rows() {
        const duplicateKeys = this.resolveDuplicateKeys();
        return this.localRows.map((row, index) => {
            const problem = this.resolveRowProblem(row, duplicateKeys);
            const hasWarnings = row.warnings?.length > 0 && row.status === CHECK_STATUS.valid;
            return {
                ...row,
                title: row.objectLabel || asString(row.objectApiName).trim() || `Formula #${index + 1}`,
                hasWarnings,
                acknowledgement: hasWarnings ? this.buildAcknowledgement(row.warnings) : null,
                showProblem: !!problem && problem !== WARNING_NOT_CONFIRMED_MESSAGE && row.status !== CHECK_STATUS.checking,
                problem,
                isChecking: row.status === CHECK_STATUS.checking,
                hasExample: !problem && !!row.exampleName
            };
        });
    }

    get hasRows() {
        return this.localRows.length > 0;
    }

    get canAddPattern() {
        return !this.disabled && this.localRows.length < this.effectiveMaxPatterns;
    }

    get addPatternDisabled() {
        return !this.canAddPattern;
    }

    get countLabel() {
        return `${this.localRows.length} of ${this.effectiveMaxPatterns} objects`;
    }
}
