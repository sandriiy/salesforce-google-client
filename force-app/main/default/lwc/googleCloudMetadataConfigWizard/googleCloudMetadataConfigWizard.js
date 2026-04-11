import { LightningElement, api, wire } from 'lwc';
import { gql, graphql } from 'lightning/uiGraphQLApi';
import { isEmpty, showToast, normalizeError, extractGraphValue } from 'c/googleCloudUtils';

import checkConfig from '@salesforce/apex/GoogleCloudConfigController.validateLatestMetadataDeploy';
import validateDriveConfig from '@salesforce/apex/GoogleCloudConfigController.validateDriveMetadataConfig';
import validateIntelligenceConfig from '@salesforce/apex/GoogleCloudConfigController.validateIntelligenceMetadataConfig';
import saveConfig from '@salesforce/apex/GoogleCloudConfigController.saveMetadataConfig';

const CONFIG_DEV_NAME = 'GoogleClient';
const CONFIG_SECTIONS = [
    {
        key: 'drive',
        label: 'Google Drive',
        icon: 'doctype:gdocs',
        description: 'Configure Google Drive authentication and file organization for this org.',
        importer: () => import('c/googleCloudDriveConfig'),
        validator: validateDriveConfig
    },
    {
        key: 'ai',
        label: 'Gemini & Vertex AI',
        icon: 'utility:magicwand',
        description: 'Configure Gemini Developer API or Vertex AI for file analysis in Google Client.',
        importer: () => import('c/googleCloudIntelligenceConfig'),
        validator: validateIntelligenceConfig
    }
];

const QUERY = gql`
    query GoogleClientConfigQuery {
        uiapi {
            query {
                GoogleClientConfig__mdt(first: 10) {
                    edges {
                        node {
                            DeveloperName { value }
                            MasterLabel { value }

                            CustomGoogleAuthorizerClass__c { value }
                            CustomGoogleServiceAccount__c { value }
                            CustomGoogleCertificate__c { value }

                            DefaultGoogleUploadFolderId__c { value }
                            DefaultBigFileSize__c { value }
                            OrganizationalDomain__c { value }
                            IsFilePreviewDisabled__c { value }
                            MaxDeleteChainSize__c { value }
                            CustomGoogleUploadFolderStructure__c { value }

                            CustomGeminiApiKey__c { value }
                            CustomModelName__c { value }
                            CustomVertexLocation__c { value }
                            CustomVertexProjectId__c { value }
                        }
                    }
                }
            }
        }
    }
`;

const MAX_DEPLOY_STATUS_CHECKS = 10;
const DEPLOY_STATUS_DELAY_MS = 1000;

export default class GoogleCloudMetadataConfigWizard extends LightningElement {
    configComponentConstructor;

    @api isLoading = false;
    @api busy = false;
    @api server = null;
    @api draft = {
        authMode: 'admin',
        customGoogleAuthorizerClass: '',
        customGoogleServiceAccount: '',
        customGoogleCertificate: '',
        defaultGoogleUploadFolderId: '',
        customGoogleUploadFolderStructure: '',
        organizationalDomain: '',
        defaultBigFileSize: null,
        isFilePreviewDisabled: false,
        maxDeleteChainSize: null,
        customGeminiApiKey: '',
        customModelName: '',
        customVertexLocation: '',
        customVertexProjectId: ''
    };

    errorMessage = '';
    configRegistry = CONFIG_SECTIONS;
    selectedConfigKey = CONFIG_SECTIONS?.[0]?.key || 'drive';
    isConfigMenuOpen = false;
    viewMode = 'main';

    connectedCallback() {
        this.initActiveConfigComponent();
        this._windowClickHandler = this.handleWindowClick.bind(this);
        window.addEventListener('click', this._windowClickHandler);
    }

    disconnectedCallback() {
        window.removeEventListener('click', this._windowClickHandler);
    }

    @wire(graphql, { query: QUERY })
    wiredConfig({ data, errors }) {
        this.isLoading = true;
        this.errorMessage = '';

        if (errors?.length) {
            this.errorMessage = errors.map((errorItem) => errorItem.message).join(', ');
            this.isLoading = false;
            return;
        }

        if (!data) {
            return;
        }

        try {
            const edges = data?.uiapi?.query?.GoogleClientConfig__mdt?.edges || [];
            const recordNode = this.findRecordByDeveloperName(edges, CONFIG_DEV_NAME);

            if (!recordNode) {
                this.errorMessage = `No GoogleClientConfig__mdt record found for DeveloperName "${CONFIG_DEV_NAME}". Confirm the record exists in this org (Setup → Custom Metadata Types → GoogleClientConfig → Manage Records).`;
                return;
            }

            const serverSnapshot = this.toServerSnapshot(recordNode);
            this.server = serverSnapshot;
            this.draft = this.toDraft(serverSnapshot);
        } catch (error) {
            this.errorMessage = error?.message || 'Unknown error parsing configuration record';
        } finally {
            this.isLoading = false;
        }
    }

    toggleConfigMenu(event) {
        event?.stopPropagation?.();
        this.isConfigMenuOpen = !this.isConfigMenuOpen;
    }

    handleWindowClick(event) {
        if (!this.isConfigMenuOpen) {
            return;
        }

        const selectorRoot = this.template.querySelector('[data-role="selectorRoot"]');
        if (selectorRoot && selectorRoot.contains(event.target)) {
            return;
        }

        this.isConfigMenuOpen = false;
    }

    handleSelectConfig(event) {
        event?.stopPropagation?.();
        const newKey = event.currentTarget?.dataset?.key;

        if (!newKey || newKey === this.selectedConfigKey) {
            this.isConfigMenuOpen = false;
            return;
        }

        this.selectedConfigKey = newKey;
        this.isConfigMenuOpen = false;
        this.initActiveConfigComponent();
    }

    toggleAdvancedView() {
        this.viewMode = this.isAdvancedView ? 'main' : 'advanced';
    }

    handleFieldChange(event) {
        const { field, value } = event.detail || {};
        if (!field) {
            return;
        }

        this.draft = {
            ...this.draft,
            [field]: extractGraphValue(value)
        };
    }

    handleStepError() {
        showToast(this, 'Incomplete setup', 'Complete Authorization before moving to Folder structure', 'warning');
    }

    handleChangeNumber(event) {
        const fieldName = event.target.dataset.field;
        this.draft = {
            ...this.draft,
            [fieldName]: this.toNumberOrNull(event.target.value)
        };
    }

    handleChangeText(event) {
        const fieldName = event.target.dataset.field;
        this.draft = {
            ...this.draft,
            [fieldName]: event.target.value
        };
    }

    handleToggle(event) {
        const fieldName = event.target.dataset.field;
        this.draft = {
            ...this.draft,
            [fieldName]: event.target.checked
        };
    }

    async handleSave() {
        await this.saveInternal({ alsoValidate: false });
    }

    async handleSaveValidate() {
        await this.saveInternal({ alsoValidate: true });
    }

    async handleValidate() {
        await this.runValidation();
    }

    async saveInternal({ alsoValidate }) {
        this.busy = true;
        try {
            if (!this.validateInputsBeforeSave()) {
                return;
            }

            const changedFieldApiToValue = this.buildChangedFieldMap();
            if (!this.hasChanges(changedFieldApiToValue)) {
                showToast(this, 'No changes', 'Nothing to save', 'info');
                return;
            }

            showToast(this, 'Saving Configuration...', 'This may take a moment — we’ll also validate authentication if needed. Please stay on this page.', 'info');
            const deployId = await this.saveMetadata(changedFieldApiToValue);

            this.server = {
                ...this.server,
                ...this.applyDraftToSnapshot(this.draft)
            };

            const deployStatus = await this.waitForDeployResult(deployId);
            const shouldContinue = await this.handleDeployOutcome(deployStatus);
            if (!shouldContinue) {
                return;
            }

            if (alsoValidate) {
                await this.runValidation();
            } else {
                showToast(this, 'Configuration Saved', 'Configuration was saved successfully', 'success');
            }
        } catch (error) {
            showToast(this, 'Action Failed', normalizeError(error), 'error');
        } finally {
            this.busy = false;
        }
    }

    validateInputsBeforeSave() {
        const configComponent = this.refs.configComponent;

        if (!this.isAdvancedView && configComponent && typeof configComponent.reportValidity === 'function') {
            const isValid = configComponent.reportValidity();
            if (!isValid) {
                showToast(this, 'Invalid Fields', 'Please review the highlighted fields and try again', 'error');
                return false;
            }
        }

        if (this.isAdvancedView && this.hasInputErrors('.advanced-container lightning-input')) {
            return false;
        }

        return true;
    }

    hasChanges(changedFieldApiToValue) {
        return !!changedFieldApiToValue && Object.keys(changedFieldApiToValue).length > 0;
    }

    async saveMetadata(fieldApiToValue) {
        return saveConfig({ fieldApiToValue });
    }

    async waitForDeployResult() {
        for (let attempt = 0; attempt < MAX_DEPLOY_STATUS_CHECKS; attempt++) {
            const status = await checkConfig();
            if (status !== 'pending') {
                return status;
            }

            await new Promise((resolve) => setTimeout(resolve, DEPLOY_STATUS_DELAY_MS));
        }

        return 'pending';
    }

    async handleDeployOutcome(deployStatus) {
        if (deployStatus === 'fail') {
            showToast(this, 'Something went wrong', 'Unable to save the configuration. Please try again or contact your System Administrator', 'error');
            return false;
        }

        if (deployStatus === 'pending') {
            showToast(this, 'Still In Progress', 'Taking longer than expected. Refresh the page, confirm it’s saved, then click Validate.', 'info');
            return false;
        }

        return true;
    }

    async runValidation() {
        this.busy = true;
        try {
            const validateConfig = this.activeValidator;
            const result = await validateConfig();
            showToast(this, 'Validation Successful', result, 'success');
        } catch (error) {
            showToast(this, 'Validation Failed', normalizeError(error), 'error');
        } finally {
            this.busy = false;
        }
    }

    async handleRevert() {
        if (!this.server) {
            return;
        }

        this.draft = this.toDraft(this.server);
        showToast(this, 'Reverted', 'Draft values were restored to the last saved configuration', 'info');
    }

    normalizeDeveloperName(value) {
        return String(value || '').trim().toLowerCase();
    }

    findRecordByDeveloperName(edges, developerName) {
        const targetName = this.normalizeDeveloperName(developerName);
        for (const edge of edges) {
            const recordNode = edge?.node;
            const recordName = this.normalizeDeveloperName(recordNode?.DeveloperName?.value);
            if (recordName === targetName) {
                return recordNode;
            }
        }

        return null;
    }

    toServerSnapshot(recordNode) {
        return {
            developerName: extractGraphValue(recordNode?.DeveloperName),
            masterLabel: extractGraphValue(recordNode?.MasterLabel),
            customGoogleAuthorizerClass: extractGraphValue(recordNode?.CustomGoogleAuthorizerClass__c),
            customGoogleServiceAccount: extractGraphValue(recordNode?.CustomGoogleServiceAccount__c),
            customGoogleCertificate: extractGraphValue(recordNode?.CustomGoogleCertificate__c),
            defaultGoogleUploadFolderId: extractGraphValue(recordNode?.DefaultGoogleUploadFolderId__c),
            customGoogleUploadFolderStructure: extractGraphValue(recordNode?.CustomGoogleUploadFolderStructure__c) || '',
            organizationalDomain: extractGraphValue(recordNode?.OrganizationalDomain__c) || '',
            defaultBigFileSize: this.toNumberOrNull(extractGraphValue(recordNode?.DefaultBigFileSize__c)),
            isFilePreviewDisabled: !!extractGraphValue(recordNode?.IsFilePreviewDisabled__c),
            maxDeleteChainSize: this.toNumberOrNull(extractGraphValue(recordNode?.MaxDeleteChainSize__c)),
            customGeminiApiKey: extractGraphValue(recordNode?.CustomGeminiApiKey__c) || '',
            customModelName: extractGraphValue(recordNode?.CustomModelName__c) || '',
            customVertexLocation: extractGraphValue(recordNode?.CustomVertexLocation__c) || '',
            customVertexProjectId: extractGraphValue(recordNode?.CustomVertexProjectId__c) || ''
        };
    }

    toDraft(serverSnapshot) {
        const inferredMode = this.inferAuthMode(serverSnapshot);
        return {
            authMode: inferredMode,
            customGoogleAuthorizerClass: serverSnapshot.customGoogleAuthorizerClass || '',
            customGoogleServiceAccount: serverSnapshot.customGoogleServiceAccount || '',
            customGoogleCertificate: serverSnapshot.customGoogleCertificate || '',
            defaultGoogleUploadFolderId: serverSnapshot.defaultGoogleUploadFolderId || '',
            customGoogleUploadFolderStructure: serverSnapshot.customGoogleUploadFolderStructure || '',
            organizationalDomain: serverSnapshot.organizationalDomain || '',
            defaultBigFileSize: serverSnapshot.defaultBigFileSize,
            isFilePreviewDisabled: !!serverSnapshot.isFilePreviewDisabled,
            maxDeleteChainSize: serverSnapshot.maxDeleteChainSize,
            customGeminiApiKey: serverSnapshot.customGeminiApiKey || '',
            customModelName: serverSnapshot.customModelName || '',
            customVertexLocation: serverSnapshot.customVertexLocation || '',
            customVertexProjectId: serverSnapshot.customVertexProjectId || ''
        };
    }

    inferAuthMode(serverSnapshot) {
        const hasDeveloperSetup = !isEmpty(serverSnapshot?.customGoogleAuthorizerClass);
        const hasAdminSetup = !isEmpty(serverSnapshot?.customGoogleServiceAccount) || !isEmpty(serverSnapshot?.customGoogleCertificate);
        if (hasDeveloperSetup && !hasAdminSetup) {
            return 'developer';
        }

        return 'admin';
    }

    buildChangedFieldMap() {
        const serverState = this.server;
        const draftState = this.draft;

        const changed = {};
        this.putIfChanged(changed, 'CustomGoogleAuthorizerClass__c', serverState.customGoogleAuthorizerClass, draftState.customGoogleAuthorizerClass);
        this.putIfChanged(changed, 'CustomGoogleServiceAccount__c', serverState.customGoogleServiceAccount, draftState.customGoogleServiceAccount);
        this.putIfChanged(changed, 'CustomGoogleCertificate__c', serverState.customGoogleCertificate, draftState.customGoogleCertificate);
        this.putIfChanged(changed, 'DefaultGoogleUploadFolderId__c', serverState.defaultGoogleUploadFolderId, draftState.defaultGoogleUploadFolderId);
        this.putIfChanged(changed, 'OrganizationalDomain__c', serverState.organizationalDomain, draftState.organizationalDomain);
        this.putIfChanged(changed, 'DefaultBigFileSize__c', serverState.defaultBigFileSize, draftState.defaultBigFileSize);
        this.putIfChanged(changed, 'IsFilePreviewDisabled__c', !!serverState.isFilePreviewDisabled, !!draftState.isFilePreviewDisabled);
        this.putIfChanged(changed, 'MaxDeleteChainSize__c', serverState.maxDeleteChainSize, draftState.maxDeleteChainSize);
        this.putIfChanged(changed, 'CustomGoogleUploadFolderStructure__c', serverState.customGoogleUploadFolderStructure, draftState.customGoogleUploadFolderStructure);
        this.putIfChanged(changed, 'CustomGeminiApiKey__c', serverState.customGeminiApiKey, draftState.customGeminiApiKey);
        this.putIfChanged(changed, 'CustomModelName__c', serverState.customModelName, draftState.customModelName);
        this.putIfChanged(changed, 'CustomVertexLocation__c', serverState.customVertexLocation, draftState.customVertexLocation);
        this.putIfChanged(changed, 'CustomVertexProjectId__c', serverState.customVertexProjectId, draftState.customVertexProjectId);

        return changed;
    }

    applyDraftToSnapshot(draftState) {
        return {
            customGoogleAuthorizerClass: draftState.customGoogleAuthorizerClass || '',
            customGoogleServiceAccount: draftState.customGoogleServiceAccount || '',
            customGoogleCertificate: draftState.customGoogleCertificate || '',
            defaultGoogleUploadFolderId: draftState.defaultGoogleUploadFolderId || '',
            customGoogleUploadFolderStructure: draftState.customGoogleUploadFolderStructure || '',
            organizationalDomain: draftState.organizationalDomain || '',
            defaultBigFileSize: draftState.defaultBigFileSize,
            isFilePreviewDisabled: !!draftState.isFilePreviewDisabled,
            maxDeleteChainSize: draftState.maxDeleteChainSize,
            customGeminiApiKey: draftState.customGeminiApiKey || '',
            customModelName: draftState.customModelName || '',
            customVertexLocation: draftState.customVertexLocation || '',
            customVertexProjectId: draftState.customVertexProjectId || ''
        };
    }

    initActiveConfigComponent() {
        const activeConfig = this.selectedConfig;

        if (!activeConfig?.importer) {
            this.configComponentConstructor = null;
            return;
        }

        activeConfig.importer()
            .then(({ default: ctor }) => {
                this.configComponentConstructor = ctor;
            })
            .catch((error) => {
                this.configComponentConstructor = null;
                showToast(this, 'Component Load Failed', normalizeError(error), 'error');
            });
    }

    putIfChanged(map, apiName, oldVal, newVal) {
        const previousValue = extractGraphValue(oldVal) ?? null;
        const nextValue = extractGraphValue(newVal) ?? null;
        if (previousValue !== nextValue) {
            map[apiName] = nextValue;
        }
    }

    toNumberOrNull(value) {
        if (value === null || value === undefined || String(value).trim() === '') {
            return null;
        }

        const numberValue = Number(value);
        return Number.isFinite(numberValue) ? numberValue : null;
    }

    hasInputErrors(selector, toastTitle = 'Invalid Fields', toastMessage = 'Please review the highlighted fields and try again') {
        const inputs = Array.from(this.template.querySelectorAll(selector));
        if (!inputs.length) {
            return false;
        }

        let hasErrors = false;
        inputs.forEach((input) => {
            if (typeof input.reportValidity === 'function') {
                input.reportValidity();
            }

            if (typeof input.checkValidity === 'function' && !input.checkValidity()) {
                hasErrors = true;
            }
        });

        if (hasErrors) {
            showToast(this, toastTitle, toastMessage, 'error');
            return true;
        }

        return false;
    }

    get hasError() {
        return !isEmpty(this.errorMessage);
    }

    get safeConfigRegistry() {
        return Array.isArray(this.configRegistry) ? this.configRegistry : [];
    }

    get fallbackConfig() {
        return (
            this.safeConfigRegistry[0] || {
                key: 'unknown',
                label: 'Oops...',
                icon: 'standard:feedback',
                description: 'No configuration found for this section. Please refresh the page or contact your system administrator'
            }
        );
    }

    get selectedConfig() {
        const registry = this.safeConfigRegistry;
        const match = registry.find((configItem) => configItem.key === this.selectedConfigKey);
        return match || this.fallbackConfig;
    }

    get activeValidator() {
        return this.selectedConfig?.validator || null;
    }

    get configMenuItems() {
        const selectedKey = this.selectedConfigKey;
        return this.safeConfigRegistry.map((configItem) => ({
            ...configItem,
            isSelected: configItem.key === selectedKey,
            className: configItem.key === selectedKey ? 'config-menu-item is-selected' : 'config-menu-item'
        }));
    }

    get menuClass() {
        return this.isConfigMenuOpen ? 'config-menu is-open' : 'config-menu';
    }

    get isAdvancedView() {
        return this.viewMode === 'advanced';
    }

    get advancedToggleLabel() {
        return this.isAdvancedView ? 'Advanced: On' : 'Advanced';
    }

    get advancedToggleClass() {
        return this.isAdvancedView ? 'action-button action-button-pill is-on' : 'action-button action-button-pill';
    }

    get isDirty() {
        if (!this.server) {
            return false;
        }

        const serverState = this.server;
        const draftState = this.draft;

        return (
            (serverState.customGoogleAuthorizerClass || '') !== (draftState.customGoogleAuthorizerClass || '') ||
            (serverState.customGoogleServiceAccount || '') !== (draftState.customGoogleServiceAccount || '') ||
            (serverState.customGoogleCertificate || '') !== (draftState.customGoogleCertificate || '') ||
            (serverState.defaultGoogleUploadFolderId || '') !== (draftState.defaultGoogleUploadFolderId || '') ||
            (serverState.customGoogleUploadFolderStructure || '') !== (draftState.customGoogleUploadFolderStructure || '') ||
            (serverState.organizationalDomain || '') !== (draftState.organizationalDomain || '') ||
            (serverState.defaultBigFileSize ?? null) !== (draftState.defaultBigFileSize ?? null) ||
            !!serverState.isFilePreviewDisabled !== !!draftState.isFilePreviewDisabled ||
            (serverState.maxDeleteChainSize ?? null) !== (draftState.maxDeleteChainSize ?? null) ||
            (serverState.customGeminiApiKey || '') !== (draftState.customGeminiApiKey || '') ||
            (serverState.customModelName || '') !== (draftState.customModelName || '') ||
            (serverState.customVertexLocation || '') !== (draftState.customVertexLocation || '') ||
            (serverState.customVertexProjectId || '') !== (draftState.customVertexProjectId || '')
        );
    }

    get saveDisabled() {
        return this.isLoading || this.busy || !this.server?.developerName || !this.isDirty;
    }

    get revertDisabled() {
        return this.isLoading || this.busy || !this.server?.developerName || !this.isDirty;
    }
}