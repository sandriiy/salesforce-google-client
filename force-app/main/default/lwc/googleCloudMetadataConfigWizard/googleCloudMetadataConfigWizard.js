import { LightningElement, api, wire } from 'lwc';
import { gql, graphql } from 'lightning/uiGraphQLApi';
import { publish, subscribe, unsubscribe, MessageContext } from 'lightning/messageService';
import { isEmpty, showToast, normalizeError, extractGraphValue } from 'c/googleCloudUtils';
import {
    FILE_EXPLORER_COLUMN_OPTIONS,
    DEFAULT_FILE_EXPLORER_COLUMNS,
    MAX_FILE_EXPLORER_COLUMNS
} from 'c/googleCloudFileExplorerColumns';
import { CONFIG_CONTEXT_MESSAGE_TYPE, CONFIG_SECTION, CONFIG_VIEW, DOCS_BASE_URL } from 'c/googleCloudSetupGuides';

import CONFIG_CONTEXT_CHANNEL from '@salesforce/messageChannel/GoogleClientConfigContext__c';
import checkConfig from '@salesforce/apex/GoogleCloudConfigController.validateLatestMetadataDeploy';
import validateDriveConfig from '@salesforce/apex/GoogleCloudConfigController.validateDriveMetadataConfig';
import validateIntelligenceConfig from '@salesforce/apex/GoogleCloudConfigController.validateIntelligenceMetadataConfig';
import saveConfig from '@salesforce/apex/GoogleCloudConfigController.saveMetadataConfig';
import initializeDirectUpload from '@salesforce/apex/GoogleCloudDirectUploadController.initializeDirectUpload';
import reportDirectUploadOutcome from '@salesforce/apex/GoogleCloudDirectUploadController.reportDirectUploadOutcome';

const PROBE_FILE_NAME = 'google-client-connection-test.tmp';
const PROBE_TOTAL_BYTES = 1048576;
const PROBE_CHUNK_BYTES = 262144;
const PROBE_TIMEOUT_MS = 30000;
const RESUMABLE_INCOMPLETE_STATUS = 308;

const CONFIG_DEV_NAME = 'GoogleClient';
const CONFIG_SECTIONS = [
    {
        key: CONFIG_SECTION.drive,
        label: 'Google Drive',
        icon: 'doctype:gdocs',
        description: 'Configure Google Drive authentication and file organization for this org.',
        importer: () => import('c/googleCloudDriveConfig'),
        validator: validateDriveConfig
    },
    {
        key: CONFIG_SECTION.ai,
        label: 'Gemini & Agent Platform',
        icon: 'utility:magicwand',
        description: 'Configure Gemini Developer API or Agent Platform (ex-Vertex AI) for file analysis in Google Client.',
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
                            AdditionalGoogleUploadFolderIds__c { value }
                            DefaultBigFileSize__c { value }
                            OrganizationalDomain__c { value }
                            IsFilePreviewDisabled__c { value }
                            IsDirectBrowserUploadEnabled__c { value }
                            IsOpenInDriveEnabled__c { value }
                            MaxDeleteChainSize__c { value }
                            CustomGoogleUploadFolderStructure__c { value }

                            CustomGeminiApiKey__c { value }
                            CustomModelName__c { value }
                            CustomAgentLocation__c { value }
                            CustomAgentProjectId__c { value }
                            IsFileIntelligenceEnabled__c { value }
                            CustomSummaryPrompt__c { value }
                            CustomQuestionPrompt__c { value }
                            QuestionMaxOutputTokens__c { value }
                            AiSafetyMode__c { value }
                            CustomAiPromptSafetyGuardClass__c { value }
                            IsAiLabelingEnabled__c { value }
                            CustomLabelingPrompt__c { value }
                            AiLabelingMinConfidence__c { value }
                            AiLabelingThinkingBudget__c { value }
                            AiLabelDefinitions__c { value }

                            FileExplorerColumns__c { value }
                        }
                    }
                }
            }
        }
    }
`;

const MAX_DEPLOY_STATUS_CHECKS = 10;
const DEPLOY_STATUS_DELAY_MS = 1000;
const DEFAULT_BIG_FILE_SIZE = 2097152;
const DEFAULT_MAX_DELETE_CHAIN_SIZE = 3;
const DEFAULT_QUESTION_MAX_OUTPUT_TOKENS = 1024;
const DEFAULT_AI_SAFETY_MODE = 'Standard';
const DEFAULT_AI_LABELING_MIN_CONFIDENCE = 80;
const DEFAULT_AI_LABELING_THINKING_BUDGET = 0;
const MAX_AI_LABEL_DEFINITIONS = 20;
const MIN_CONFIDENCE_PERCENT = 0;
const MAX_CONFIDENCE_PERCENT = 100;
const AI_SAFETY_MODE_OPTIONS = [
    { label: 'Strict', value: 'Strict' },
    { label: 'Standard', value: 'Standard' },
    { label: 'Relaxed', value: 'Relaxed' },
    { label: 'Off', value: 'Off' }
];
const ADVANCED_TAB_FILE_MANAGEMENT = 'fileManagement';
const ADVANCED_TAB_USER_INTERFACE = 'userInterface';
const ADVANCED_TAB_AI_INTELLIGENCE = 'aiIntelligence';
const ADVANCED_TAB_SAFETY_CUSTOMIZATION = 'safetyCustomization';
const ADVANCED_TABS = [
    { key: ADVANCED_TAB_FILE_MANAGEMENT, label: 'File Management', description: 'Previews, uploads, limits' },
    { key: ADVANCED_TAB_USER_INTERFACE, label: 'User Interface', description: 'File Explorer columns' },
    { key: ADVANCED_TAB_AI_INTELLIGENCE, label: 'AI Intelligence', description: 'Analytics and labeling' },
    { key: ADVANCED_TAB_SAFETY_CUSTOMIZATION, label: 'Safety & Customization', description: 'Prompt inspection' }
];
const ADVANCED_TAB_KEYS = ADVANCED_TABS.map((tab) => tab.key);
const ADVANCED_INPUT_SELECTOR = 'lightning-input, lightning-textarea, lightning-dual-listbox, c-google-cloud-ai-label-editor';
const NOTICE_AI_OFF = 'aiOff';
const NOTICE_AI_PROVIDER_MISSING = 'aiProviderMissing';
const FILE_EXPLORER_REQUIRED_COLUMNS = ['title'];
const FILE_EXPLORER_COLUMNS_OVERFLOW_MESSAGE = `You can display up to ${MAX_FILE_EXPLORER_COLUMNS} columns.`;
const SAFETY_MODE_GUIDE_URL = `${DOCS_BASE_URL}/features/artificial-intelligence/safety/`;
const UI_FILE_EXPLORER_URL = `${DOCS_BASE_URL}/features/file-explorer/`;
const CUSTOM_GUARD_GUIDE_URL = `${DOCS_BASE_URL}/features/artificial-intelligence/safety/#ownguard`;
const AI_LABELING_GUIDE_URL = `${DOCS_BASE_URL}/features/artificial-intelligence/labeling/`;
const DEFAULT_SUMMARY_PROMPT = 'Create a very short summary of the provided document content that starts with "This file describes". Use only the text provided in the document and keep the summary accurate. Focus on the main subject and the most important points, names, dates, and numbers. Omit secondary details if the summary needs to stay brief.';
const DEFAULT_QUESTION_PROMPT = 'You answer user questions about one specific file content. Use only the provided document text and be accurate. If the user refers to a table, column, field, row, section, value, or label with slightly imperfect wording, infer the closest reasonable match from the document before giving up. Prefer the most likely interpretation instead of returning nothing. If multiple interpretations are plausible, answer with the strongest match and briefly mention the ambiguity. If the answer is not available in the document - check if you can figure it out, and if not, reply exactly with "I could not find that in this file". Return plain text only. Keep the response concise, direct, and helpful. Do not use markdown, bullet lists, or headings.';
const DEFAULT_LABELING_PROMPT = 'You classify one business document into exactly one of the labels defined by the administrator. Read the document text and compare it against every label description. Choose a label only when the document clearly matches that description. When the document fits none of the labels, fits several of them equally well, or you are not sure, answer None. Never invent a label that is not in the list and use only the document text provided.';

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
        additionalGoogleUploadFolderIds: '',
        customGoogleUploadFolderStructure: '',
        organizationalDomain: '',
        defaultBigFileSize: DEFAULT_BIG_FILE_SIZE,
        isFilePreviewDisabled: false,
        isDirectBrowserUploadEnabled: false,
        isOpenInDriveEnabled: false,
        maxDeleteChainSize: DEFAULT_MAX_DELETE_CHAIN_SIZE,
        customGeminiApiKey: '',
        customModelName: '',
        customAgentLocation: '',
        customAgentProjectId: '',
        isFileIntelligenceEnabled: false,
        customSummaryPrompt: DEFAULT_SUMMARY_PROMPT,
        customQuestionPrompt: DEFAULT_QUESTION_PROMPT,
        questionMaxOutputTokens: DEFAULT_QUESTION_MAX_OUTPUT_TOKENS,
        aiSafetyMode: DEFAULT_AI_SAFETY_MODE,
        customAiPromptSafetyGuardClass: '',
        isAiLabelingEnabled: false,
        customLabelingPrompt: DEFAULT_LABELING_PROMPT,
        aiLabelingMinConfidence: DEFAULT_AI_LABELING_MIN_CONFIDENCE,
        aiLabelingThinkingBudget: DEFAULT_AI_LABELING_THINKING_BUDGET,
        aiLabelDefinitions: '',
        fileExplorerColumns: ''
    };

    @wire(MessageContext)
    messageContext;

    errorMessage = '';
    customColumnDraft = '';
    configRegistry = CONFIG_SECTIONS;
    selectedConfigKey = CONFIG_SECTIONS?.[0]?.key || CONFIG_SECTION.drive;
    sectionVariant = null;
    isConfigMenuOpen = false;
    viewMode = CONFIG_VIEW.main;
    activeAdvancedTab = ADVANCED_TAB_FILE_MANAGEMENT;
    validationIssues = new Map();
    isDirectUploadProbeRunning = false;
    directUploadProbeSucceeded = false;
    directUploadProbeMessage = '';
    isProviderCheckRunning = false;
    dismissedNoticeKey = null;
    pendingNavigation = null;
    contextSubscription = null;

    connectedCallback() {
        this.initActiveConfigComponent();
        this._windowClickHandler = this.handleWindowClick.bind(this);
        window.addEventListener('click', this._windowClickHandler);
        this.contextSubscription = subscribe(this.messageContext, CONFIG_CONTEXT_CHANNEL, (message) => this.handleContextMessage(message));
        this.publishConfigContext();
    }

    disconnectedCallback() {
        window.removeEventListener('click', this._windowClickHandler);
        unsubscribe(this.contextSubscription);
        this.contextSubscription = null;
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
                const defaultSnapshot = this.buildDefaultServerSnapshot();
                this.server = defaultSnapshot;
                this.draft = this.toDraft(defaultSnapshot);
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

    handleContextMessage(message) {
        if (message?.type === CONFIG_CONTEXT_MESSAGE_TYPE.ready) {
            this.publishConfigContext();
        }
    }

    publishConfigContext() {
        if (!this.messageContext) {
            return;
        }

        publish(this.messageContext, CONFIG_CONTEXT_CHANNEL, {
            type: CONFIG_CONTEXT_MESSAGE_TYPE.context,
            section: this.selectedConfigKey,
            variant: this.sectionVariant,
            view: this.viewMode,
            tab: this.activeAdvancedTab
        });
    }

    handleSectionContextChange(event) {
        this.sectionVariant = event?.detail?.variant || null;
        this.publishConfigContext();
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

        this.isConfigMenuOpen = false;
        this.applyNavigation({ view: CONFIG_VIEW.main, section: newKey });
    }

    handleSetupViewClick() {
        this.requestNavigation({ view: CONFIG_VIEW.main });
    }

    handleAdvancedViewClick() {
        this.requestNavigation({ view: CONFIG_VIEW.advanced });
    }

    handleAdvancedStepClick(event) {
        const nextTab = event?.currentTarget?.dataset?.step;
        if (nextTab && ADVANCED_TAB_KEYS.includes(nextTab)) {
            this.activeAdvancedTab = nextTab;
            this.publishConfigContext();
        }
    }

    requestNavigation(navigation) {
        if (navigation.view === this.viewMode && !navigation.section && !navigation.tab) {
            return;
        }

        if (this.isDirty) {
            this.pendingNavigation = navigation;
            return;
        }

        this.applyNavigation(navigation);
    }

    applyNavigation({ view, section, tab }) {
        if (section && section !== this.selectedConfigKey) {
            this.selectedConfigKey = section;
            this.sectionVariant = null;
            this.initActiveConfigComponent();
        }

        if (tab && ADVANCED_TAB_KEYS.includes(tab)) {
            this.activeAdvancedTab = tab;
        }

        this.viewMode = view === CONFIG_VIEW.advanced ? CONFIG_VIEW.advanced : CONFIG_VIEW.main;
        this.publishConfigContext();
    }

    handleNavigationCancel() {
        this.pendingNavigation = null;
    }

    handleNavigationDiscard() {
        const navigation = this.pendingNavigation;
        this.pendingNavigation = null;
        if (!navigation) {
            return;
        }

        this.draft = this.toDraft(this.server);
        this.applyNavigation(navigation);
    }

    async handleNavigationSave() {
        const navigation = this.pendingNavigation;
        if (!navigation) {
            return;
        }

        await this.saveInternal({ alsoValidate: false });
        if (this.isDirty) {
            return;
        }

        this.pendingNavigation = null;
        this.applyNavigation(navigation);
    }

    handleNoticeDismiss() {
        this.dismissedNoticeKey = this.activeNotice?.key || null;
    }

    handleNoticeAction() {
        const notice = this.activeNotice;
        if (!notice) {
            return;
        }

        this.dismissedNoticeKey = notice.key;
        this.requestNavigation(notice.navigation);
    }

    handleOpenProviderSetup() {
        this.requestNavigation({ view: CONFIG_VIEW.main, section: CONFIG_SECTION.ai });
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

    handleValidityChange(event) {
        const detail = event?.detail || {};
        const { key, isValid, message } = detail;
        if (!key) return;

        if (isValid) {
            this.validationIssues.delete(key);
        } else {
            this.validationIssues.set(key, message || 'Invalid input');
        }
    }

    firstTrackedValidationMessage() {
        if (!this.validationIssues || this.validationIssues.size === 0) return null;
        return this.validationIssues.values().next().value;
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

    async handleIntelligenceToggle(event) {
        const toggle = event.target;
        if (!toggle.checked) {
            this.draft = {
                ...this.draft,
                isFileIntelligenceEnabled: false,
                isAiLabelingEnabled: false
            };
            return;
        }

        if (this.server?.isFileIntelligenceEnabled) {
            this.draft = this.applyIntelligenceDefaults({ ...this.draft, isFileIntelligenceEnabled: true });
            return;
        }

        if (!this.isIntelligenceProviderSaved) {
            toggle.checked = false;
            showToast(this, 'Connect a provider first', 'Set up and validate Gemini or Agent Platform before turning on AI Analytics', 'warning');
            return;
        }

        const isProviderValid = await this.checkIntelligenceProvider();
        if (!isProviderValid) {
            toggle.checked = false;
            return;
        }

        this.draft = this.applyIntelligenceDefaults({ ...this.draft, isFileIntelligenceEnabled: true });
    }

    handleLabelingToggle(event) {
        const isEnabled = event.target.checked;
        if (isEnabled && !this.isIntelligenceEnabled) {
            event.target.checked = false;
            showToast(this, 'Turn on AI Analytics first', 'AI Labeling works on top of AI Analytics, so enable that switch before this one', 'warning');
            return;
        }

        this.draft = this.applyLabelingDefaults({ ...this.draft, isAiLabelingEnabled: isEnabled });
    }

    handleLabelDefinitionsChange(event) {
        this.draft = {
            ...this.draft,
            aiLabelDefinitions: event.detail?.value || ''
        };
    }

    async checkIntelligenceProvider() {
        this.isProviderCheckRunning = true;
        this.busy = true;
        try {
            await validateIntelligenceConfig();
            showToast(this, 'Provider validated', 'AI Analytics is ready to be turned on. Save the configuration to apply it', 'success');
            return true;
        } catch (error) {
            showToast(this, 'Provider not ready', normalizeError(error), 'error');
            return false;
        } finally {
            this.isProviderCheckRunning = false;
            this.busy = false;
        }
    }

    async handleDirectUploadProbe() {
        this.isDirectUploadProbeRunning = true;
        this.directUploadProbeSucceeded = false;
        this.directUploadProbeMessage = 'Testing…';

        let session;
        try {
            session = await initializeDirectUpload({
                fileName: PROBE_FILE_NAME,
                mimeType: 'application/octet-stream',
                totalBytes: PROBE_TOTAL_BYTES
            });
        } catch (error) {
            this.directUploadProbeMessage = `Google rejected the upload session. Check the service account and upload folder configuration. (${normalizeError(error)})`;
            this.isDirectUploadProbeRunning = false;
            return;
        }

        const probeStatus = await this.sendDirectUploadProbeChunk(session.sessionUri);

        if (probeStatus === RESUMABLE_INCOMPLETE_STATUS) {
            this.directUploadProbeSucceeded = true;
            this.directUploadProbeMessage = 'Direct browser upload is ready!';
        } else if (probeStatus === 0) {
            this.directUploadProbeMessage = 'The browser could not reach Google. Check that the CSP Trusted Site for https://www.googleapis.com is active!';
        } else {
            this.directUploadProbeMessage = `Google returned an unexpected response (${probeStatus}). Check the service account and upload folder configuration!`;
        }

        this.discardDirectUploadProbe(session.sessionUri);
        this.isDirectUploadProbeRunning = false;
    }

    sendDirectUploadProbeChunk(sessionUri) {
        return new Promise((resolve) => {
            const request = new XMLHttpRequest();
            request.open('PUT', sessionUri, true);
            request.timeout = PROBE_TIMEOUT_MS;
            request.setRequestHeader('Content-Range', `bytes 0-${PROBE_CHUNK_BYTES - 1}/${PROBE_TOTAL_BYTES}`);

            request.onload = () => resolve(request.status);
            request.onerror = () => resolve(request.status);
            request.ontimeout = () => resolve(0);

            request.send(new Blob([new Uint8Array(PROBE_CHUNK_BYTES)]));
        });
    }

    discardDirectUploadProbe(sessionUri) {
        const request = new XMLHttpRequest();
        request.open('DELETE', sessionUri, true);
        request.onerror = () => {};
        request.send();

        reportDirectUploadOutcome({
            outcome: 'cancelled',
            diagnostics: 'connection test'
        }).catch(() => {});
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

            this.server = {
                ...this.server,
                hasPersistedRecord: true
            };

            if (alsoValidate && !this.isAdvancedView) {
                const didValidate = await this.runValidation({ skipInitialSave: true, showSkippedMessage: false });
                if (!didValidate) {
                    showToast(this, 'Configuration Saved', 'Configuration was saved successfully', 'success');
                }
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
        const trackedMessage = this.firstTrackedValidationMessage();
        if (trackedMessage) {
            showToast(this, 'Invalid Fields', trackedMessage, 'error');
            return false;
        }

        const configComponent = this.refs.configComponent;

        if (!this.isAdvancedView && configComponent && typeof configComponent.reportValidity === 'function') {
            const isValid = configComponent.reportValidity();
            if (!isValid) {
                showToast(this, 'Invalid Fields', 'Please review the highlighted fields and try again', 'error');
                return false;
            }
        }

        if (this.isAdvancedView && this.hasInputErrors(this.scopedAdvancedSelector('.advanced-container'))) {
            this.focusFailingAdvancedTab();
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

    async runValidation({ skipInitialSave = false, showSkippedMessage = true } = {}) {
        if (!this.hasPersistedConfigRecord) {
            if (skipInitialSave) {
                return false;
            }

            if (!this.validateInputsBeforeSave()) {
                return false;
            }

            const changedFieldApiToValue = this.buildChangedFieldMap();
            if (!this.hasChanges(changedFieldApiToValue)) {
                if (showSkippedMessage) {
                    showToast(this, 'Save Required', 'Save the Google Client configuration before validating it', 'info');
                }

                return false;
            }

            await this.saveInternal({ alsoValidate: true });
            return true;
        }

        this.busy = true;
        try {
            const validateConfig = this.activeValidator;
            const result = await validateConfig();
            showToast(this, 'Validation Successful', result, 'success');
            return true;
        } catch (error) {
            showToast(this, 'Validation Failed', normalizeError(error), 'error');
            return false;
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

    buildDefaultServerSnapshot() {
        return {
            hasPersistedRecord: false,
            developerName: CONFIG_DEV_NAME,
            masterLabel: 'Google Client',
            customGoogleAuthorizerClass: null,
            customGoogleServiceAccount: null,
            customGoogleCertificate: null,
            defaultGoogleUploadFolderId: null,
            additionalGoogleUploadFolderIds: '',
            customGoogleUploadFolderStructure: '',
            organizationalDomain: '',
            defaultBigFileSize: DEFAULT_BIG_FILE_SIZE,
            isFilePreviewDisabled: false,
            isDirectBrowserUploadEnabled: false,
            isOpenInDriveEnabled: false,
            maxDeleteChainSize: DEFAULT_MAX_DELETE_CHAIN_SIZE,
            customGeminiApiKey: '',
            customModelName: '',
            customAgentLocation: '',
            customAgentProjectId: '',
            isFileIntelligenceEnabled: false,
            customSummaryPrompt: '',
            customQuestionPrompt: '',
            questionMaxOutputTokens: DEFAULT_QUESTION_MAX_OUTPUT_TOKENS,
            aiSafetyMode: '',
            customAiPromptSafetyGuardClass: '',
            isAiLabelingEnabled: false,
            customLabelingPrompt: '',
            aiLabelingMinConfidence: DEFAULT_AI_LABELING_MIN_CONFIDENCE,
            aiLabelingThinkingBudget: DEFAULT_AI_LABELING_THINKING_BUDGET,
            aiLabelDefinitions: '',
            fileExplorerColumns: ''
        };
    }

    toServerSnapshot(recordNode) {
        return {
            hasPersistedRecord: true,
            developerName: extractGraphValue(recordNode?.DeveloperName),
            masterLabel: extractGraphValue(recordNode?.MasterLabel),
            customGoogleAuthorizerClass: extractGraphValue(recordNode?.CustomGoogleAuthorizerClass__c),
            customGoogleServiceAccount: extractGraphValue(recordNode?.CustomGoogleServiceAccount__c),
            customGoogleCertificate: extractGraphValue(recordNode?.CustomGoogleCertificate__c),
            defaultGoogleUploadFolderId: extractGraphValue(recordNode?.DefaultGoogleUploadFolderId__c),
            additionalGoogleUploadFolderIds: extractGraphValue(recordNode?.AdditionalGoogleUploadFolderIds__c) || '',
            customGoogleUploadFolderStructure: extractGraphValue(recordNode?.CustomGoogleUploadFolderStructure__c) || '',
            organizationalDomain: extractGraphValue(recordNode?.OrganizationalDomain__c) || '',
            defaultBigFileSize: this.toNumberOrNull(extractGraphValue(recordNode?.DefaultBigFileSize__c)),
            isFilePreviewDisabled: !!extractGraphValue(recordNode?.IsFilePreviewDisabled__c),
            isDirectBrowserUploadEnabled: !!extractGraphValue(recordNode?.IsDirectBrowserUploadEnabled__c),
            isOpenInDriveEnabled: !!extractGraphValue(recordNode?.IsOpenInDriveEnabled__c),
            maxDeleteChainSize: this.toNumberOrNull(extractGraphValue(recordNode?.MaxDeleteChainSize__c)),
            customGeminiApiKey: extractGraphValue(recordNode?.CustomGeminiApiKey__c) || '',
            customModelName: extractGraphValue(recordNode?.CustomModelName__c) || '',
            customAgentLocation: extractGraphValue(recordNode?.CustomAgentLocation__c) || '',
            customAgentProjectId: extractGraphValue(recordNode?.CustomAgentProjectId__c) || '',
            isFileIntelligenceEnabled: !!extractGraphValue(recordNode?.IsFileIntelligenceEnabled__c),
            customSummaryPrompt: extractGraphValue(recordNode?.CustomSummaryPrompt__c) || '',
            customQuestionPrompt: extractGraphValue(recordNode?.CustomQuestionPrompt__c) || '',
            questionMaxOutputTokens: this.toNumberOrNull(extractGraphValue(recordNode?.QuestionMaxOutputTokens__c)),
            aiSafetyMode: extractGraphValue(recordNode?.AiSafetyMode__c) || '',
            customAiPromptSafetyGuardClass: extractGraphValue(recordNode?.CustomAiPromptSafetyGuardClass__c) || '',
            isAiLabelingEnabled: !!extractGraphValue(recordNode?.IsAiLabelingEnabled__c),
            customLabelingPrompt: extractGraphValue(recordNode?.CustomLabelingPrompt__c) || '',
            aiLabelingMinConfidence: this.toNumberOrNull(extractGraphValue(recordNode?.AiLabelingMinConfidence__c)),
            aiLabelingThinkingBudget: this.toNumberOrNull(extractGraphValue(recordNode?.AiLabelingThinkingBudget__c)),
            aiLabelDefinitions: extractGraphValue(recordNode?.AiLabelDefinitions__c) || '',
            fileExplorerColumns: extractGraphValue(recordNode?.FileExplorerColumns__c) || ''
        };
    }

    toDraft(serverSnapshot) {
        const inferredMode = this.inferAuthMode(serverSnapshot);
        return this.applyIntelligenceDefaults({
            authMode: inferredMode,
            customGoogleAuthorizerClass: serverSnapshot.customGoogleAuthorizerClass || '',
            customGoogleServiceAccount: serverSnapshot.customGoogleServiceAccount || '',
            customGoogleCertificate: serverSnapshot.customGoogleCertificate || '',
            defaultGoogleUploadFolderId: serverSnapshot.defaultGoogleUploadFolderId || '',
            additionalGoogleUploadFolderIds: serverSnapshot.additionalGoogleUploadFolderIds || '',
            customGoogleUploadFolderStructure: serverSnapshot.customGoogleUploadFolderStructure || '',
            organizationalDomain: serverSnapshot.organizationalDomain || '',
            defaultBigFileSize: serverSnapshot.defaultBigFileSize,
            isFilePreviewDisabled: !!serverSnapshot.isFilePreviewDisabled,
            isDirectBrowserUploadEnabled: !!serverSnapshot.isDirectBrowserUploadEnabled,
            isOpenInDriveEnabled: !!serverSnapshot.isOpenInDriveEnabled,
            maxDeleteChainSize: serverSnapshot.maxDeleteChainSize,
            customGeminiApiKey: serverSnapshot.customGeminiApiKey || '',
            customModelName: serverSnapshot.customModelName || '',
            customAgentLocation: serverSnapshot.customAgentLocation || '',
            customAgentProjectId: serverSnapshot.customAgentProjectId || '',
            isFileIntelligenceEnabled: !!serverSnapshot.isFileIntelligenceEnabled,
            customSummaryPrompt: serverSnapshot.customSummaryPrompt || '',
            customQuestionPrompt: serverSnapshot.customQuestionPrompt || '',
            questionMaxOutputTokens: serverSnapshot.questionMaxOutputTokens,
            aiSafetyMode: serverSnapshot.aiSafetyMode || '',
            customAiPromptSafetyGuardClass: serverSnapshot.customAiPromptSafetyGuardClass || '',
            isAiLabelingEnabled: !!serverSnapshot.isAiLabelingEnabled,
            customLabelingPrompt: serverSnapshot.customLabelingPrompt || '',
            aiLabelingMinConfidence: serverSnapshot.aiLabelingMinConfidence,
            aiLabelingThinkingBudget: serverSnapshot.aiLabelingThinkingBudget,
            aiLabelDefinitions: serverSnapshot.aiLabelDefinitions || '',
            fileExplorerColumns: serverSnapshot.fileExplorerColumns || ''
        });
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
        this.putIfChanged(changed, 'AdditionalGoogleUploadFolderIds__c', serverState.additionalGoogleUploadFolderIds, draftState.additionalGoogleUploadFolderIds);
        this.putIfChanged(changed, 'OrganizationalDomain__c', serverState.organizationalDomain, draftState.organizationalDomain);
        this.putIfChanged(changed, 'DefaultBigFileSize__c', serverState.defaultBigFileSize, draftState.defaultBigFileSize);
        this.putIfChanged(changed, 'IsFilePreviewDisabled__c', !!serverState.isFilePreviewDisabled, !!draftState.isFilePreviewDisabled);
        this.putIfChanged(changed, 'IsDirectBrowserUploadEnabled__c', !!serverState.isDirectBrowserUploadEnabled, !!draftState.isDirectBrowserUploadEnabled);
        this.putIfChanged(changed, 'IsOpenInDriveEnabled__c', !!serverState.isOpenInDriveEnabled, !!draftState.isOpenInDriveEnabled);
        this.putIfChanged(changed, 'MaxDeleteChainSize__c', serverState.maxDeleteChainSize, draftState.maxDeleteChainSize);
        this.putIfChanged(changed, 'CustomGoogleUploadFolderStructure__c', serverState.customGoogleUploadFolderStructure, draftState.customGoogleUploadFolderStructure);
        this.putIfChanged(changed, 'CustomGeminiApiKey__c', serverState.customGeminiApiKey, draftState.customGeminiApiKey);
        this.putIfChanged(changed, 'CustomModelName__c', serverState.customModelName, draftState.customModelName);
        this.putIfChanged(changed, 'CustomAgentLocation__c', serverState.customAgentLocation, draftState.customAgentLocation);
        this.putIfChanged(changed, 'CustomAgentProjectId__c', serverState.customAgentProjectId, draftState.customAgentProjectId);
        this.putIfChanged(changed, 'IsFileIntelligenceEnabled__c', !!serverState.isFileIntelligenceEnabled, !!draftState.isFileIntelligenceEnabled);
        this.putIfChanged(changed, 'CustomSummaryPrompt__c', serverState.customSummaryPrompt, draftState.customSummaryPrompt);
        this.putIfChanged(changed, 'CustomQuestionPrompt__c', serverState.customQuestionPrompt, draftState.customQuestionPrompt);
        this.putIfChanged(changed, 'QuestionMaxOutputTokens__c', serverState.questionMaxOutputTokens, draftState.questionMaxOutputTokens);
        this.putIfChanged(changed, 'AiSafetyMode__c', serverState.aiSafetyMode, draftState.aiSafetyMode);
        this.putIfChanged(changed, 'CustomAiPromptSafetyGuardClass__c', serverState.customAiPromptSafetyGuardClass, draftState.customAiPromptSafetyGuardClass);
        this.putIfChanged(changed, 'IsAiLabelingEnabled__c', !!serverState.isAiLabelingEnabled, !!draftState.isAiLabelingEnabled);
        this.putIfChanged(changed, 'CustomLabelingPrompt__c', serverState.customLabelingPrompt, draftState.customLabelingPrompt);
        this.putIfChanged(changed, 'AiLabelingMinConfidence__c', serverState.aiLabelingMinConfidence, draftState.aiLabelingMinConfidence);
        this.putIfChanged(changed, 'AiLabelingThinkingBudget__c', serverState.aiLabelingThinkingBudget, draftState.aiLabelingThinkingBudget);
        this.putIfChanged(changed, 'AiLabelDefinitions__c', serverState.aiLabelDefinitions, draftState.aiLabelDefinitions);
        this.putIfChanged(changed, 'FileExplorerColumns__c', serverState.fileExplorerColumns, draftState.fileExplorerColumns);

        return changed;
    }

    applyDraftToSnapshot(draftState) {
        return {
            customGoogleAuthorizerClass: draftState.customGoogleAuthorizerClass || '',
            customGoogleServiceAccount: draftState.customGoogleServiceAccount || '',
            customGoogleCertificate: draftState.customGoogleCertificate || '',
            defaultGoogleUploadFolderId: draftState.defaultGoogleUploadFolderId || '',
            additionalGoogleUploadFolderIds: draftState.additionalGoogleUploadFolderIds || '',
            customGoogleUploadFolderStructure: draftState.customGoogleUploadFolderStructure || '',
            organizationalDomain: draftState.organizationalDomain || '',
            defaultBigFileSize: draftState.defaultBigFileSize,
            isFilePreviewDisabled: !!draftState.isFilePreviewDisabled,
            isDirectBrowserUploadEnabled: !!draftState.isDirectBrowserUploadEnabled,
            isOpenInDriveEnabled: !!draftState.isOpenInDriveEnabled,
            maxDeleteChainSize: draftState.maxDeleteChainSize,
            customGeminiApiKey: draftState.customGeminiApiKey || '',
            customModelName: draftState.customModelName || '',
            customAgentLocation: draftState.customAgentLocation || '',
            customAgentProjectId: draftState.customAgentProjectId || '',
            isFileIntelligenceEnabled: !!draftState.isFileIntelligenceEnabled,
            customSummaryPrompt: draftState.customSummaryPrompt || '',
            customQuestionPrompt: draftState.customQuestionPrompt || '',
            questionMaxOutputTokens: draftState.questionMaxOutputTokens,
            aiSafetyMode: draftState.aiSafetyMode || '',
            customAiPromptSafetyGuardClass: draftState.customAiPromptSafetyGuardClass || '',
            isAiLabelingEnabled: !!draftState.isAiLabelingEnabled,
            customLabelingPrompt: draftState.customLabelingPrompt || '',
            aiLabelingMinConfidence: draftState.aiLabelingMinConfidence,
            aiLabelingThinkingBudget: draftState.aiLabelingThinkingBudget,
            aiLabelDefinitions: draftState.aiLabelDefinitions || '',
            fileExplorerColumns: draftState.fileExplorerColumns || ''
        };
    }

    applyIntelligenceDefaults(draftState) {
        if (!draftState?.isFileIntelligenceEnabled) {
            return draftState;
        }

        return this.applyLabelingDefaults({
            ...draftState,
            customSummaryPrompt: draftState.customSummaryPrompt || DEFAULT_SUMMARY_PROMPT,
            customQuestionPrompt: draftState.customQuestionPrompt || DEFAULT_QUESTION_PROMPT,
            questionMaxOutputTokens: draftState.questionMaxOutputTokens ?? DEFAULT_QUESTION_MAX_OUTPUT_TOKENS
        });
    }

    applyLabelingDefaults(draftState) {
        if (!draftState?.isAiLabelingEnabled) {
            return draftState;
        }

        return {
            ...draftState,
            customLabelingPrompt: draftState.customLabelingPrompt || DEFAULT_LABELING_PROMPT,
            aiLabelingMinConfidence: draftState.aiLabelingMinConfidence ?? DEFAULT_AI_LABELING_MIN_CONFIDENCE,
            aiLabelingThinkingBudget: draftState.aiLabelingThinkingBudget ?? DEFAULT_AI_LABELING_THINKING_BUDGET
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

    scopedAdvancedSelector(scope) {
        return ADVANCED_INPUT_SELECTOR
            .split(',')
            .map((selector) => `${scope} ${selector.trim()}`)
            .join(', ');
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

    focusFailingAdvancedTab() {
        for (const tabKey of ADVANCED_TAB_KEYS) {
            const inputs = Array.from(this.template.querySelectorAll(this.scopedAdvancedSelector(`[data-tab="${tabKey}"]`)));
            const hasInvalid = inputs.some((input) => typeof input.checkValidity === 'function' && !input.checkValidity());
            if (hasInvalid) {
                this.activeAdvancedTab = tabKey;
                this.publishConfigContext();
                return;
            }
        }
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
        return this.viewMode === CONFIG_VIEW.advanced;
    }

    get isMainView() {
        return !this.isAdvancedView;
    }

    get setupViewClass() {
        return this.isMainView ? 'view-switch-option is-active' : 'view-switch-option';
    }

    get advancedViewClass() {
        return this.isAdvancedView ? 'view-switch-option is-active' : 'view-switch-option';
    }

    get advancedTabs() {
        return ADVANCED_TABS.map((tab) => ({
            ...tab,
            className: this.advancedStepButtonClass(tab.key)
        }));
    }

    get showUnsavedChangesModal() {
        return this.pendingNavigation !== null;
    }

    get pendingNavigationLabel() {
        return this.pendingNavigation?.view === CONFIG_VIEW.advanced ? 'Advanced settings' : 'Setup';
    }

    get hasPersistedConfigRecord() {
        return this.server?.hasPersistedRecord === true;
    }

    get isIntelligenceProviderSaved() {
        const savedState = this.server;
        if (!savedState) {
            return false;
        }

        const hasModel = !isEmpty(savedState.customModelName);
        const hasGemini = !isEmpty(savedState.customGeminiApiKey);
        const hasAgent = !isEmpty(savedState.customAgentProjectId) && !isEmpty(savedState.customAgentLocation);
        return hasModel && (hasGemini || hasAgent);
    }

    get isIntelligenceEnabled() {
        return !!this.draft?.isFileIntelligenceEnabled;
    }

    get isIntelligenceDisabled() {
        return !this.isIntelligenceEnabled;
    }

    get isIntelligenceToggleDisabled() {
        return this.busy || this.isProviderCheckRunning || (!this.isIntelligenceProviderSaved && !this.isIntelligenceEnabled);
    }

    get showProviderRequiredHint() {
        return !this.isIntelligenceProviderSaved && !this.isIntelligenceEnabled;
    }

    get isLabelingEnabled() {
        return this.isIntelligenceEnabled && !!this.draft?.isAiLabelingEnabled;
    }

    get isLabelingDisabled() {
        return !this.isLabelingEnabled;
    }

    get isLabelingToggleDisabled() {
        return this.busy || this.isIntelligenceDisabled;
    }

    get maxAiLabelDefinitions() {
        return MAX_AI_LABEL_DEFINITIONS;
    }

    get minConfidencePercent() {
        return MIN_CONFIDENCE_PERCENT;
    }

    get maxConfidencePercent() {
        return MAX_CONFIDENCE_PERCENT;
    }

    get aiLabelingGuideUrl() {
        return AI_LABELING_GUIDE_URL;
    }

    get activeNotice() {
        if (this.hasError || this.isLoading) {
            return null;
        }

        if (this.isMainView && this.selectedConfigKey === CONFIG_SECTION.ai && this.isIntelligenceDisabled) {
            return {
                key: NOTICE_AI_OFF,
                title: 'AI analysis is off',
                text: 'Provider details can be saved and validated here, but summaries, questions and labels stay off until AI Analytics is turned on under Advanced → AI Intelligence.',
                actionLabel: 'Open AI Intelligence',
                navigation: { view: CONFIG_VIEW.advanced, tab: ADVANCED_TAB_AI_INTELLIGENCE }
            };
        }

        if (this.isAdvancedView && this.activeAdvancedTab === ADVANCED_TAB_AI_INTELLIGENCE && this.showProviderRequiredHint) {
            return {
                key: NOTICE_AI_PROVIDER_MISSING,
                title: 'Connect a provider first',
                text: 'AI Analytics can be turned on once Gemini or Agent Platform is set up and validated. Do that under Gemini & Agent Platform, then come back here.',
                actionLabel: 'Open Gemini & Agent Platform',
                navigation: { view: CONFIG_VIEW.main, section: CONFIG_SECTION.ai }
            };
        }

        return null;
    }

    get visibleNotice() {
        const notice = this.activeNotice;
        return notice && notice.key !== this.dismissedNoticeKey ? notice : null;
    }

    get aiSafetyModeOptions() {
        return AI_SAFETY_MODE_OPTIONS;
    }

    get effectiveAiSafetyMode() {
        return this.draft?.aiSafetyMode || DEFAULT_AI_SAFETY_MODE;
    }

    get uiFileExplorerUrl() {
        return UI_FILE_EXPLORER_URL;
    }

    get safetyModeGuideUrl() {
        return SAFETY_MODE_GUIDE_URL;
    }

    get customGuardGuideUrl() {
        return CUSTOM_GUARD_GUIDE_URL;
    }

    advancedStepButtonClass(tabKey) {
        return this.activeAdvancedTab === tabKey ? 'advanced-step-button is-active' : 'advanced-step-button';
    }

    advancedTabPanelClass(tabKey) {
        return this.activeAdvancedTab === tabKey ? 'advanced-tab-panel' : 'advanced-tab-panel is-hidden';
    }

    get fileManagementPanelClass() {
        return this.advancedTabPanelClass(ADVANCED_TAB_FILE_MANAGEMENT);
    }

    get isDirectUploadSaved() {
        return !!this.server?.isDirectBrowserUploadEnabled;
    }

    get directUploadProbeClass() {
        let toneClass = 'slds-text-color_weak';
        if (!this.isDirectUploadProbeRunning) {
            toneClass = this.directUploadProbeSucceeded ? 'slds-text-color_success' : 'slds-text-color_error';
        }

        return `slds-text-body_small ${toneClass}`;
    }

    get aiIntelligencePanelClass() {
        return this.advancedTabPanelClass(ADVANCED_TAB_AI_INTELLIGENCE);
    }

    get safetyCustomizationPanelClass() {
        return this.advancedTabPanelClass(ADVANCED_TAB_SAFETY_CUSTOMIZATION);
    }

    get userInterfacePanelClass() {
        return this.advancedTabPanelClass(ADVANCED_TAB_USER_INTERFACE);
    }

    get maxFileExplorerColumns() {
        return MAX_FILE_EXPLORER_COLUMNS;
    }

    get requiredFileExplorerColumns() {
        return FILE_EXPLORER_REQUIRED_COLUMNS;
    }

    get fileExplorerColumnsOverflowMessage() {
        return FILE_EXPLORER_COLUMNS_OVERFLOW_MESSAGE;
    }

    get selectedFileExplorerColumns() {
        return this.splitColumns(this.draft?.fileExplorerColumns);
    }

    get fileExplorerColumnOptions() {
        const catalogValues = new Set(FILE_EXPLORER_COLUMN_OPTIONS.map((option) => option.value));
        const customOptions = this.selectedFileExplorerColumns
            .filter((columnKey) => !catalogValues.has(columnKey))
            .map((columnKey) => ({ label: columnKey, value: columnKey }));

        return [...FILE_EXPLORER_COLUMN_OPTIONS, ...customOptions];
    }

    handleColumnsChange(event) {
        const selectedValues = event.detail?.value || [];
        this.draft = {
            ...this.draft,
            fileExplorerColumns: selectedValues.join(';')
        };
    }

    handleCustomColumnDraftChange(event) {
        this.customColumnDraft = event.target.value || '';
    }

    handleAddCustomColumn() {
        const token = this.customColumnDraft.trim();
        if (isEmpty(token)) {
            return;
        }

        const currentColumns = this.selectedFileExplorerColumns;
        const alreadyPresent = currentColumns.some((columnKey) => columnKey.toLowerCase() === token.toLowerCase());
        if (alreadyPresent) {
            showToast(this, 'Column already added', `“${token}” is already in the list`, 'info');
            this.customColumnDraft = '';
            return;
        }

        if (currentColumns.length >= MAX_FILE_EXPLORER_COLUMNS) {
            showToast(this, 'Too many columns', FILE_EXPLORER_COLUMNS_OVERFLOW_MESSAGE, 'error');
            return;
        }

        this.draft = {
            ...this.draft,
            fileExplorerColumns: [...currentColumns, token].join(';')
        };
        this.customColumnDraft = '';
    }

    splitColumns(rawColumns) {
        const source = isEmpty(rawColumns) ? DEFAULT_FILE_EXPLORER_COLUMNS : rawColumns;
        return source
            .split(';')
            .map((columnKey) => columnKey.trim())
            .filter((columnKey) => columnKey.length > 0);
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
            (serverState.additionalGoogleUploadFolderIds || '') !== (draftState.additionalGoogleUploadFolderIds || '') ||
            (serverState.customGoogleUploadFolderStructure || '') !== (draftState.customGoogleUploadFolderStructure || '') ||
            (serverState.organizationalDomain || '') !== (draftState.organizationalDomain || '') ||
            (serverState.defaultBigFileSize ?? null) !== (draftState.defaultBigFileSize ?? null) ||
            (!!serverState.isFilePreviewDisabled !== !!draftState.isFilePreviewDisabled) ||
            (!!serverState.isDirectBrowserUploadEnabled !== !!draftState.isDirectBrowserUploadEnabled) ||
            (!!serverState.isOpenInDriveEnabled !== !!draftState.isOpenInDriveEnabled) ||
            (serverState.maxDeleteChainSize ?? null) !== (draftState.maxDeleteChainSize ?? null) ||
            (serverState.customGeminiApiKey || '') !== (draftState.customGeminiApiKey || '') ||
            (serverState.customModelName || '') !== (draftState.customModelName || '') ||
            (serverState.customAgentLocation || '') !== (draftState.customAgentLocation || '') ||
            (serverState.customAgentProjectId || '') !== (draftState.customAgentProjectId || '') ||
            (!!serverState.isFileIntelligenceEnabled !== !!draftState.isFileIntelligenceEnabled) ||
            (serverState.customSummaryPrompt || '') !== (draftState.customSummaryPrompt || '') ||
            (serverState.customQuestionPrompt || '') !== (draftState.customQuestionPrompt || '') ||
            (serverState.questionMaxOutputTokens ?? null) !== (draftState.questionMaxOutputTokens ?? null) ||
            (serverState.aiSafetyMode || '') !== (draftState.aiSafetyMode || '') ||
            (serverState.customAiPromptSafetyGuardClass || '') !== (draftState.customAiPromptSafetyGuardClass || '') ||
            (!!serverState.isAiLabelingEnabled !== !!draftState.isAiLabelingEnabled) ||
            (serverState.customLabelingPrompt || '') !== (draftState.customLabelingPrompt || '') ||
            (serverState.aiLabelingMinConfidence ?? null) !== (draftState.aiLabelingMinConfidence ?? null) ||
            (serverState.aiLabelingThinkingBudget ?? null) !== (draftState.aiLabelingThinkingBudget ?? null) ||
            (serverState.aiLabelDefinitions || '') !== (draftState.aiLabelDefinitions || '') ||
            (serverState.fileExplorerColumns || '') !== (draftState.fileExplorerColumns || '')
        );
    }

    get saveDisabled() {
        return this.isLoading || this.busy || !this.server?.developerName || !this.isDirty;
    }

    get revertDisabled() {
        return this.isLoading || this.busy || !this.server?.developerName || !this.isDirty;
    }
}
