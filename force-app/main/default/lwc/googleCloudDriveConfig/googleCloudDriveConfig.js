import { LightningElement, api } from 'lwc';

import { asString } from 'c/googleCloudUtils';
import QUICK_SETUP_LINK from '@salesforce/label/c.GoogleClientQuickSetupLink';

const STRUCTURE_ORDER_SEPARATOR = '-';
const QUICK_SETUP_URL = QUICK_SETUP_LINK;
const UPLOAD_FOLDER_SEPARATOR = ';';
const MAX_UPLOAD_FOLDERS = 10;
const VALIDITY_KEY_DUPLICATES = 'upload-folder-duplicates';
const DUPLICATE_ERROR_MESSAGE = 'This folder identification (ID) is already used in another row';
const DUPLICATE_AGGREGATE_MESSAGE = 'Folder identification (ID) values must be unique across all rows';

const STEP = {
    auth: 'auth',
    locations: 'locations',
    structure: 'structure'
};

const STRUCTURE_TOKEN = {
    user: 'User',
    record: 'Record'
};

export default class GoogleCloudDriveConfig extends LightningElement {
    @api draft;
    @api server;
    @api busy = false;
    @api isLoading = false;

    currentStep = STEP.auth;
    draggingKey = null;
    dropTargetKey = null;
    draggingUploadFolderIndex = null;
    dropTargetUploadFolderIndex = null;
    localUploadFolderRows = null;
    lastReportedHasDuplicates = null;

    @api reportValidity() {
        const inputs = Array.from(this.template.querySelectorAll('lightning-input, lightning-radio-group'));
        let isValid = true;

        inputs.forEach((input) => {
            if (typeof input.reportValidity === 'function') input.reportValidity();
            if (typeof input.checkValidity === 'function' && !input.checkValidity()) isValid = false;
        });

        return isValid;
    }

    renderedCallback() {
        this.reconcileLocalUploadFolderRows();
        this.evaluateUploadFolderValidity();
    }

    dispatchFieldChange(field, value) {
        this.dispatchEvent(new CustomEvent('fieldchange', { detail: { field, value } }));
    }

    dispatchAction(name) {
        this.dispatchEvent(new CustomEvent(name));
    }

    notifyValidityChange(key, isValid, message) {
        this.dispatchEvent(new CustomEvent('validitychange', {
            detail: { key, isValid, message }
        }));
    }

    openQuickSetupGuide() {
        window.open(QUICK_SETUP_URL, '_blank');
    }

    handleAuthModeChange(event) {
        const mode = event.detail.value;
        this.dispatchFieldChange('authMode', mode);

        if (mode === 'admin') {
            this.dispatchFieldChange('customGoogleAuthorizerClass', '');
        } else {
            this.dispatchFieldChange('customGoogleServiceAccount', '');
            this.dispatchFieldChange('customGoogleCertificate', '');
        }
    }

    handleTextChange(event) {
        const field = event.target.dataset.field;
        this.dispatchFieldChange(field, event.target.value);
    }

    handleStepClick(event) {
        const step = event.currentTarget?.dataset?.step;
        if (!step) return;

        if (step !== STEP.auth && !this.authorizationStepComplete) {
            this.currentStep = STEP.auth;
            this.dispatchAction('steperror');
            return;
        }

        this.currentStep = step;
    }

    goToAuthStep() {
        this.currentStep = STEP.auth;
    }

    goToLocationsStep() {
        if (!this.authorizationStepComplete) {
            this.dispatchAction('steperror');
            return;
        }

        this.currentStep = STEP.locations;
    }

    goToStructureStep() {
        if (!this.authorizationStepComplete) {
            this.dispatchAction('steperror');
            return;
        }

        this.currentStep = STEP.structure;
    }

    handleAuthPrimaryAction() {
        if (this.authorizationStepDirty) {
            this.handleSaveValidate();
            return;
        }
		
        this.handleValidate();
    }

    handleValidate() {
        this.dispatchAction('validate');
    }

    handleSave() {
        this.dispatchAction('save');
    }

    handleSaveValidate() {
        this.dispatchAction('savevalidate');
    }

    handleRevert() {
        this.localUploadFolderRows = null;
        this.lastReportedHasDuplicates = null;
        this.notifyValidityChange(VALIDITY_KEY_DUPLICATES, true, null);
        this.dispatchAction('revert');
    }

    handleStructureToggle(event) {
        const key = event.target.dataset.key;
        const enabled = event.target.checked;
        this.applyStructureEnabledState(key, enabled);
    }

    handleMoveUp(event) {
        const key = event.currentTarget.dataset.key;
        this.moveEnabledStructureItem(key, -1);
    }

    handleMoveDown(event) {
        const key = event.currentTarget.dataset.key;
        this.moveEnabledStructureItem(key, 1);
    }

    handleDragStart(event) {
        const key = event.currentTarget?.dataset?.key;
        const items = this.structureItems;
        const item = items.find((i) => i.key === key);

        if (!item?.draggable) {
            event.preventDefault();
            return;
        }

        this.draggingKey = key;
        event.dataTransfer.effectAllowed = 'move';
        event.dataTransfer.setData('text/plain', key);
    }

    handleDragOver(event) {
        if (!this.draggingKey) return;

        const key = event.currentTarget?.dataset?.key;
        if (!key || key === this.draggingKey) return;

        const items = this.structureItems;
        const draggingItem = items.find((i) => i.key === this.draggingKey);
        const overItem = items.find((i) => i.key === key);

        if (!draggingItem?.enabled || !overItem?.enabled) return;

        event.preventDefault();
        event.dataTransfer.dropEffect = 'move';
        this.dropTargetKey = key;
    }

    handleDrop(event) {
        event.preventDefault();

        const fromKey = this.draggingKey;
        const toKey = event.currentTarget?.dataset?.key;

        if (!fromKey || !toKey || fromKey === toKey) {
            this.resetDragState();
            return;
        }

        this.reorderEnabledStructureItems(fromKey, toKey);
        this.resetDragState();
    }

    handleDragEnd() {
        this.resetDragState();
    }

    resetDragState() {
        this.draggingKey = null;
        this.dropTargetKey = null;
    }

    handleUploadFolderChange(event) {
        const index = Number(event.currentTarget?.dataset?.index);
        if (!Number.isInteger(index)) return;

        this.ensureLocalRowsInitialized();
        if (index < 0 || index >= this.localUploadFolderRows.length) return;

        const nextValue = event.target.value == null ? '' : event.target.value;
        const nextRows = this.localUploadFolderRows.map((v, i) => (i === index ? nextValue : v));
        this.localUploadFolderRows = nextRows;
        this.persistUploadFolders(nextRows);
    }

    handleUploadFolderMoveUp(event) {
        const index = Number(event.currentTarget?.dataset?.index);
        this.moveUploadFolderRow(index, -1);
    }

    handleUploadFolderMoveDown(event) {
        const index = Number(event.currentTarget?.dataset?.index);
        this.moveUploadFolderRow(index, 1);
    }

    handleUploadFolderRemove(event) {
        const index = Number(event.currentTarget?.dataset?.index);
        if (!Number.isInteger(index) || index <= 0) return;

        this.ensureLocalRowsInitialized();
        if (index >= this.localUploadFolderRows.length) return;

        const nextRows = this.localUploadFolderRows.filter((_, i) => i !== index);
        this.localUploadFolderRows = nextRows;
        this.persistUploadFolders(nextRows);
    }

    handleUploadFolderAdd() {
        this.ensureLocalRowsInitialized();
        if (this.localUploadFolderRows.length >= MAX_UPLOAD_FOLDERS) return;

        const nextRows = [...this.localUploadFolderRows, ''];
        this.localUploadFolderRows = nextRows;
        this.persistUploadFolders(nextRows);
    }

    handleUploadFolderDragStart(event) {
        const index = Number(event.currentTarget?.dataset?.index);
        this.ensureLocalRowsInitialized();

        if (!Number.isInteger(index) || index === 0 || this.localUploadFolderRows.length <= 2) {
            event.preventDefault();
            return;
        }

        this.draggingUploadFolderIndex = index;
        event.dataTransfer.effectAllowed = 'move';
        event.dataTransfer.setData('text/plain', String(index));
    }

    handleUploadFolderDragOver(event) {
        if (this.draggingUploadFolderIndex === null) return;

        const index = Number(event.currentTarget?.dataset?.index);
        if (!Number.isInteger(index) || index === 0 || index === this.draggingUploadFolderIndex) return;

        event.preventDefault();
        event.dataTransfer.dropEffect = 'move';
        this.dropTargetUploadFolderIndex = index;
    }

    handleUploadFolderDrop(event) {
        event.preventDefault();

        const fromIndex = this.draggingUploadFolderIndex;
        const toIndex = Number(event.currentTarget?.dataset?.index);
        this.resetUploadFolderDragState();

        if (!Number.isInteger(fromIndex) || !Number.isInteger(toIndex) || fromIndex === toIndex) return;
        if (fromIndex === 0 || toIndex === 0) return;

        this.ensureLocalRowsInitialized();
        const rows = this.localUploadFolderRows;
        if (fromIndex < 0 || fromIndex >= rows.length || toIndex < 0 || toIndex >= rows.length) return;

        const nextRows = [...rows];
        const [moved] = nextRows.splice(fromIndex, 1);
        nextRows.splice(toIndex, 0, moved);
        this.localUploadFolderRows = nextRows;
        this.persistUploadFolders(nextRows);
    }

    handleUploadFolderDragEnd() {
        this.resetUploadFolderDragState();
    }

    resetUploadFolderDragState() {
        this.draggingUploadFolderIndex = null;
        this.dropTargetUploadFolderIndex = null;
    }

    moveUploadFolderRow(index, direction) {
        if (!Number.isInteger(index) || index <= 0) return;

        this.ensureLocalRowsInitialized();
        const rows = this.localUploadFolderRows;
        const targetIndex = index + direction;
        if (targetIndex <= 0 || targetIndex >= rows.length) return;

        const nextRows = [...rows];
        const temp = nextRows[targetIndex];
        nextRows[targetIndex] = nextRows[index];
        nextRows[index] = temp;
        this.localUploadFolderRows = nextRows;
        this.persistUploadFolders(nextRows);
    }

    persistUploadFolders(rows) {
        const primaryValue = rows.length ? rows[0] : '';
        const additionalValues = rows.length ? rows.slice(1) : [];
        const primaryTrimmed = asString(primaryValue).trim();
        const additionalSerialized = additionalValues
            .map((v) => asString(v).trim())
            .filter((v) => v.length > 0)
            .join(UPLOAD_FOLDER_SEPARATOR);

        this.dispatchFieldChange('defaultGoogleUploadFolderId', primaryTrimmed);
        this.dispatchFieldChange('additionalGoogleUploadFolderIds', additionalSerialized);
    }

    ensureLocalRowsInitialized() {
        if (this.localUploadFolderRows !== null) return;
        this.localUploadFolderRows = this.deriveRowsFromDraft();
    }

    deriveRowsFromDraft() {
        const primary = asString(this.draft?.defaultGoogleUploadFolderId);
        const additionalRaw = asString(this.draft?.additionalGoogleUploadFolderIds);
        const additionalItems = additionalRaw.length
            ? additionalRaw
                .split(UPLOAD_FOLDER_SEPARATOR)
                .map((v) => asString(v).trim())
                .filter((v) => v.length > 0)
            : [];
        return [primary, ...additionalItems];
    }

    reconcileLocalUploadFolderRows() {
        const draftRows = this.deriveRowsFromDraft();

        if (this.localUploadFolderRows === null) {
            this.localUploadFolderRows = draftRows;
            return;
        }

        const localFilteredKey = JSON.stringify(this.filteredLocalRows(this.localUploadFolderRows));
        const draftKey = JSON.stringify(draftRows);

        if (localFilteredKey !== draftKey) {
            this.localUploadFolderRows = draftRows;
        }
    }

    filteredLocalRows(rows) {
        if (!rows || !rows.length) return [];
        const [primary, ...rest] = rows;
        return [
            asString(primary).trim(),
            ...rest.map((v) => asString(v).trim()).filter((v) => v.length > 0)
        ];
    }

    evaluateUploadFolderValidity() {
        const inputs = Array.from(this.template.querySelectorAll('lightning-input[data-role="upload-folder-input"]'));
        if (!inputs.length) {
            if (this.lastReportedHasDuplicates !== null) {
                this.lastReportedHasDuplicates = null;
                this.notifyValidityChange(VALIDITY_KEY_DUPLICATES, true, null);
            }
            return;
        }

        const counts = new Map();
        inputs.forEach((el) => {
            const v = asString(el.value).trim();
            if (!v) return;
            counts.set(v, (counts.get(v) || 0) + 1);
        });

        let hasDuplicates = false;
        inputs.forEach((el) => {
            const v = asString(el.value).trim();
            const isDup = v.length > 0 && counts.get(v) > 1;
            if (isDup) {
                hasDuplicates = true;
                if (typeof el.setCustomValidity === 'function') el.setCustomValidity(DUPLICATE_ERROR_MESSAGE);
            } else if (typeof el.setCustomValidity === 'function') {
                el.setCustomValidity('');
            }
            if (typeof el.reportValidity === 'function') el.reportValidity();
        });

        if (this.lastReportedHasDuplicates !== hasDuplicates) {
            this.lastReportedHasDuplicates = hasDuplicates;
            this.notifyValidityChange(
                VALIDITY_KEY_DUPLICATES,
                !hasDuplicates,
                hasDuplicates ? DUPLICATE_AGGREGATE_MESSAGE : null
            );
        }
    }

    applyStructureEnabledState(key, enabled) {
        const tokens = this.folderStructureTokens.slice();
        const token = this.keyToToken(key);
        if (!token) return;

        const hasToken = tokens.includes(token);

        if (enabled && !hasToken) tokens.push(token);
        if (!enabled && hasToken) tokens.splice(tokens.indexOf(token), 1);

        this.persistFolderStructureTokens(tokens);
    }

    moveEnabledStructureItem(key, direction) {
        const tokens = this.folderStructureTokens.slice();
        const token = this.keyToToken(key);
        if (!token) return;

        const index = tokens.indexOf(token);
        if (index < 0) return;

        const targetIndex = index + direction;
        if (targetIndex < 0 || targetIndex >= tokens.length) return;

        const temp = tokens[targetIndex];
        tokens[targetIndex] = tokens[index];
        tokens[index] = temp;

        this.persistFolderStructureTokens(tokens);
    }

    reorderEnabledStructureItems(fromKey, toKey) {
        const tokens = this.folderStructureTokens.slice();
        const fromToken = this.keyToToken(fromKey);
        const toToken = this.keyToToken(toKey);

        if (!fromToken || !toToken) return;

        const fromIndex = tokens.indexOf(fromToken);
        const toIndex = tokens.indexOf(toToken);

        if (fromIndex < 0 || toIndex < 0) return;

        tokens.splice(fromIndex, 1);
        tokens.splice(toIndex, 0, fromToken);

        this.persistFolderStructureTokens(tokens);
    }

    keyToToken(key) {
        if (key === 'user') return STRUCTURE_TOKEN.user;
        if (key === 'record') return STRUCTURE_TOKEN.record;
        return null;
    }

    persistFolderStructureTokens(tokens) {
        const normalizedTokens = this.normalizeTokens(tokens);
        const structureString = this.serializeFolderStructure(normalizedTokens);
        this.dispatchFieldChange('customGoogleUploadFolderStructure', structureString);
    }

    normalizeTokens(tokens) {
        const allowed = new Set([STRUCTURE_TOKEN.user, STRUCTURE_TOKEN.record]);
        const seen = new Set();
        const result = [];

        tokens.forEach((t) => {
            const token = String(t || '').trim();
            if (!allowed.has(token)) return;
            if (seen.has(token)) return;
            seen.add(token);
            result.push(token);
        });

        return result;
    }

    parseFolderStructure(value) {
        const raw = asString(value).trim();
        if (!raw) return [];

        const matches = raw.match(/\{(User|Record)\}/g) || [];
        const tokens = matches.map((m) => m.replace(/[{}]/g, ''));
        return this.normalizeTokens(tokens);
    }

    serializeFolderStructure(tokens) {
        if (!tokens?.length) return '';
        return tokens.map((t) => `{${t}}`).join(STRUCTURE_ORDER_SEPARATOR);
    }

    get authMode() {
        const draftMode = asString(this.draft?.authMode).trim();
        if (draftMode) return draftMode;

        const hasDeveloperSetup = !!asString(this.draft?.customGoogleAuthorizerClass).trim();
        const hasAdminSetup =
            !!asString(this.draft?.customGoogleServiceAccount).trim() ||
            !!asString(this.draft?.customGoogleCertificate).trim();

        if (hasDeveloperSetup && !hasAdminSetup) return 'developer';
        if (hasAdminSetup && !hasDeveloperSetup) return 'admin';
        return 'admin';
    }

    get uploadFolderRows() {
        const rows = this.localUploadFolderRows !== null ? this.localUploadFolderRows : this.deriveRowsFromDraft();
        const total = rows.length;

        return rows.map((value, index) => {
            const isPrimary = index === 0;
            const isDragging = this.draggingUploadFolderIndex === index;
            const isDropTarget =
                this.dropTargetUploadFolderIndex === index &&
                this.draggingUploadFolderIndex !== null &&
                this.draggingUploadFolderIndex !== index;

            const containerClass = [
                'upload-folder-item',
                isPrimary ? 'is-primary' : '',
                !isPrimary && total > 2 ? 'drag-cursor' : '',
                isDragging ? 'is-dragging' : '',
                isDropTarget ? 'is-drop-target' : ''
            ]
                .filter(Boolean)
                .join(' ');

            return {
                key: `upload-folder-${index}`,
                index,
                value,
                isPrimary,
                showControls: !isPrimary,
                title: isPrimary
                    ? 'Default Location (ID)'
                    : `Folder Location (ID) #${index + 1}`,
                placeholder: isPrimary
                    ? 'e.g. 1a2B3cD4eF5g...'
                    : 'Fallback Google Drive folder ID',
                required: isPrimary,
                draggable: !isPrimary && total > 2,
                disableMoveUp: isPrimary || total <= 2 || index === 1,
                disableMoveDown: isPrimary || total <= 2 || index === total - 1,
                containerClass
            };
        });
    }

    get canAddUploadFolder() {
        const rows = this.localUploadFolderRows !== null ? this.localUploadFolderRows : this.deriveRowsFromDraft();
        return rows.length < MAX_UPLOAD_FOLDERS;
    }

    get addUploadFolderDisabled() {
        return this.busy || !this.canAddUploadFolder;
    }

    get uploadFolderCountLabel() {
        const rows = this.localUploadFolderRows !== null ? this.localUploadFolderRows : this.deriveRowsFromDraft();
        return `${rows.length} of ${MAX_UPLOAD_FOLDERS} folder IDs configured`;
    }

    get hasMultipleUploadFolders() {
        const rows = this.localUploadFolderRows !== null ? this.localUploadFolderRows : this.deriveRowsFromDraft();
        return rows.filter((v) => asString(v).trim().length > 0).length > 1;
    }

    get authModeOptions() {
        return [
            { label: 'Admin setup (recommended for most orgs)', value: 'admin' },
            { label: 'Developer setup (custom authorization class)', value: 'developer' }
        ];
    }

    get authorizationStepClass() {
        return `step-button ${this.isAuthStep ? 'is-active' : ''}`;
    }

    get locationsStepClass() {
        return `step-button ${this.isLocationsStep ? 'is-active' : ''}`;
    }

    get structureStepClass() {
        return `step-button ${this.isStructureStep ? 'is-active' : ''}`;
    }

    get isDeveloperMode() {
        return this.authMode === 'developer';
    }

    get isAdminMode() {
        return this.authMode === 'admin';
    }

    get authorizationStepComplete() {
        if (!this.draft) return false;
        if (this.isDeveloperMode) return !!asString(this.draft?.customGoogleAuthorizerClass).trim();
        return (
            !!asString(this.draft?.customGoogleServiceAccount).trim() &&
            !!asString(this.draft?.customGoogleCertificate).trim()
        );
    }

    get authorizationStepDirty() {
        const serverAuthorizer = asString(this.server?.customGoogleAuthorizerClass).trim();
        const serverServiceAccount = asString(this.server?.customGoogleServiceAccount).trim();
        const serverCertificate = asString(this.server?.customGoogleCertificate).trim();

        const draftAuthorizer = asString(this.draft?.customGoogleAuthorizerClass).trim();
        const draftServiceAccount = asString(this.draft?.customGoogleServiceAccount).trim();
        const draftCertificate = asString(this.draft?.customGoogleCertificate).trim();

        return (
            serverAuthorizer !== draftAuthorizer ||
            serverServiceAccount !== draftServiceAccount ||
            serverCertificate !== draftCertificate
        );
    }

    get authPrimaryActionLabel() {
        return this.authorizationStepDirty ? 'Save & Validate' : 'Validate';
    }

    get isAuthStep() {
        return this.currentStep === STEP.auth;
    }

    get isLocationsStep() {
        return this.currentStep === STEP.locations;
    }

    get isStructureStep() {
        return this.currentStep === STEP.structure;
    }

    get folderStructureTokens() {
        return this.parseFolderStructure(this.draft?.customGoogleUploadFolderStructure);
    }

    get folderStructurePreview() {
        const tokens = this.folderStructureTokens;
        if (!tokens.length) return 'Default';
        return `Default / ${tokens.join(' / ')}`;
    }

    get structureItems() {
        const tokens = this.folderStructureTokens;
        const enabled = new Set(tokens);

        const baseItems = [
            {
                key: 'user',
                token: STRUCTURE_TOKEN.user,
                title: 'User folder',
                subtitle: 'Create a folder per user',
                enabled: enabled.has(STRUCTURE_TOKEN.user)
            },
            {
                key: 'record',
                token: STRUCTURE_TOKEN.record,
                title: 'Record folder',
                subtitle: 'Create a folder per record',
                enabled: enabled.has(STRUCTURE_TOKEN.record)
            }
        ];

        const orderedKeys = [];
        tokens.forEach((t) => {
            if (t === STRUCTURE_TOKEN.user) orderedKeys.push('user');
            if (t === STRUCTURE_TOKEN.record) orderedKeys.push('record');
        });

        baseItems.forEach((i) => {
            if (!orderedKeys.includes(i.key)) orderedKeys.push(i.key);
        });

        const enabledKeys = orderedKeys.filter((k) => baseItems.find((i) => i.key === k)?.enabled);
        const disabledKeys = orderedKeys.filter((k) => !baseItems.find((i) => i.key === k)?.enabled);

        const finalOrder = [...enabledKeys, ...disabledKeys];
        const enabledCount = enabledKeys.length;

        return finalOrder.map((key, index) => {
            const item = baseItems.find((i) => i.key === key);
            const isEnabled = !!item?.enabled;
            const draggable = isEnabled && enabledCount > 1;

            const disableMoveUp = !isEnabled || enabledCount <= 1 || index === 0 || !enabledKeys.includes(key);
            const disableMoveDown = !isEnabled || enabledCount <= 1 || !enabledKeys.includes(key) || index === enabledCount - 1;

            const isDragging = this.draggingKey === key;
            const isDropTarget = this.dropTargetKey === key && this.draggingKey && this.draggingKey !== key;

            const containerClass = [
                'folder-structure-item',
                isEnabled ? '' : 'is-disabled',
                enabledCount > 1 ? 'drag-cursor' : '',
                isDragging ? 'is-dragging' : '',
                isDropTarget ? 'is-drop-target' : ''
            ]
                .filter(Boolean)
                .join(' ');

            return {
                ...item,
                draggable,
                disableMoveUp,
                disableMoveDown,
                containerClass
            };
        });
    }
}