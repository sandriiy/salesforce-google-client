import { LightningElement, api } from 'lwc';

import { asString, isEmpty } from 'c/googleCloudUtils';

const DEFAULT_MAX_LABELS = 20;
const LABEL_FIELDS = ['name', 'labelId', 'description'];

export default class GoogleCloudAiLabelEditor extends LightningElement {
    @api disabled = false;
    @api maxLabels = DEFAULT_MAX_LABELS;

    localRows = [];
    rowSequence = 0;
    lastAppliedValue = null;

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
    }

    @api checkValidity() {
        return this.validateInputs(false);
    }

    @api reportValidity() {
        return this.validateInputs(true);
    }

    handleFieldChange(event) {
        const rowKey = event.target.dataset.rowKey;
        const field = event.target.dataset.field;
        if (!rowKey || !LABEL_FIELDS.includes(field)) {
            return;
        }

        this.localRows = this.localRows.map((row) => (
            row.key === rowKey
                ? { ...row, [field]: event.target.value == null ? '' : event.target.value }
                : row
        ));
        this.emitChange();
    }

    handleAddLabel() {
        if (!this.canAddLabel) {
            return;
        }

        this.localRows = [...this.localRows, this.createEmptyRow()];
        this.emitChange();
    }

    handleRemoveLabel(event) {
        const rowKey = event.currentTarget.dataset.rowKey;
        this.localRows = this.localRows.filter((row) => row.key !== rowKey);
        this.emitChange();
    }

    emitChange() {
        const serialized = this.serializeRows(this.localRows);
        this.lastAppliedValue = serialized;
        this.dispatchEvent(new CustomEvent('definitionschange', { detail: { value: serialized } }));
    }

    validateInputs(report) {
        const inputs = Array.from(this.template.querySelectorAll('lightning-input, lightning-textarea'));
        let isValid = true;

        inputs.forEach((input) => {
            if (report && typeof input.reportValidity === 'function') {
                input.reportValidity();
            }

            if (typeof input.checkValidity === 'function' && !input.checkValidity()) {
                isValid = false;
            }
        });

        return isValid;
    }

    createEmptyRow() {
        this.rowSequence += 1;
        return {
            key: `ai-label-${this.rowSequence}`,
            name: '',
            labelId: '',
            description: ''
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
            .slice(0, this.effectiveMaxLabels)
            .map((entry) => ({
                ...this.createEmptyRow(),
                name: asString(entry.name),
                labelId: asString(entry.labelId),
                description: asString(entry.description)
            }));
    }

    serializeRows(rows) {
        if (!rows || rows.length === 0) {
            return '';
        }

        return JSON.stringify(rows.map((row) => ({
            name: asString(row.name).trim(),
            labelId: asString(row.labelId).trim(),
            description: asString(row.description).trim()
        })));
    }

    get effectiveMaxLabels() {
        const parsed = Number(this.maxLabels);
        return Number.isInteger(parsed) && parsed > 0 ? parsed : DEFAULT_MAX_LABELS;
    }

    get rows() {
        return this.localRows.map((row, index) => ({
            ...row,
            title: `Label #${index + 1}`,
            nameLabel: asString(row.name).trim() || `Label #${index + 1}`
        }));
    }

    get hasRows() {
        return this.localRows.length > 0;
    }

    get canAddLabel() {
        return !this.disabled && this.localRows.length < this.effectiveMaxLabels;
    }

    get addLabelDisabled() {
        return !this.canAddLabel;
    }

    get countLabel() {
        return `${this.localRows.length} of ${this.effectiveMaxLabels} labels defined`;
    }
}
