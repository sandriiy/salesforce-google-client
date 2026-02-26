import { LightningElement, api } from 'lwc';

import { asString } from 'c/googleCloudUtils';
import QUICK_SETUP_LINK from '@salesforce/label/c.GoogleClientQuickSetupLink';

const STRUCTURE_ORDER_SEPARATOR = '-';
const QUICK_SETUP_URL = QUICK_SETUP_LINK;

const STRUCTURE_TOKEN = {
    user: 'User',
    record: 'Record'
};

export default class GoogleCloudDriveConfig extends LightningElement {
    @api draft;
    @api server;
    @api busy = false;
    @api isLoading = false;

    currentStep = 'auth';
    draggingKey = null;
    dropTargetKey = null;

    @api reportValidity() {
        const inputs = Array.from(this.template.querySelectorAll('lightning-input, lightning-radio-group'));
        let isValid = true;

        inputs.forEach((input) => {
            if (typeof input.reportValidity === 'function') input.reportValidity();
            if (typeof input.checkValidity === 'function' && !input.checkValidity()) isValid = false;
        });

        return isValid;
    }

    dispatchFieldChange(field, value) {
        this.dispatchEvent(new CustomEvent('fieldchange', { detail: { field, value } }));
    }

    dispatchAction(name) {
        this.dispatchEvent(new CustomEvent(name));
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

        if (step === 'folder' && !this.authorizationStepComplete) {
            this.currentStep = 'auth';
            this.dispatchAction('steperror');
            return;
        }

        this.currentStep = step;
    }

    goToFolderStep() {
        if (!this.authorizationStepComplete) {
            this.dispatchAction('steperror');
            return;
        }

        this.currentStep = 'folder';
    }

    goToAuthStep() {
        this.currentStep = 'auth';
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

    get authModeOptions() {
        return [
            { label: 'Admin setup (recommended for most orgs)', value: 'admin' },
            { label: 'Developer setup (custom authorization class)', value: 'developer' }
        ];
    }

    get authorizationStepClass() {
        return `step-button ${this.isAuthStep ? 'is-active' : ''}`;
    }

    get folderStepClass() {
        return `step-button ${this.isFolderStep ? 'is-active' : ''}`;
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
        return this.currentStep === 'auth';
    }

    get isFolderStep() {
        return this.currentStep === 'folder';
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