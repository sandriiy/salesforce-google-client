import { LightningElement, api } from 'lwc';

import { asString } from 'c/googleCloudUtils';

const PROVIDER = {
    GEMINI: 'gemini',
    AGENT: 'agent'
};

const AI_STATUS = {
    on: {
        className: 'ai-status ai-status-on',
        title: 'AI Analytics is on',
        text: 'Summaries, questions and labeling are available to your users.'
    },
    off: {
        className: 'ai-status ai-status-off',
        title: 'AI Analytics is off',
        text: 'Provider details are saved, but nothing is sent to the provider until AI Analytics is turned on under Advanced → AI Intelligence.'
    },
    notConnected: {
        className: 'ai-status ai-status-not-connected',
        title: 'AI is not connected',
        text: 'Connect Gemini or Agent Platform below to make summaries, questions and labeling available.'
    }
};

const SAVED_INTELLIGENCE_KEYS = [
    'customGeminiApiKey',
    'customModelName',
    'customAgentLocation',
    'customAgentProjectId',
    'customSummaryPrompt',
    'customQuestionPrompt',
    'questionMaxOutputTokens',
    'aiSafetyMode',
    'customAiPromptSafetyGuardClass',
    'customLabelingPrompt',
    'aiLabelingMinConfidence',
    'aiLabelingThinkingBudget',
    'aiLabelDefinitions'
];

export default class GoogleCloudIntelligenceConfig extends LightningElement {
    @api draft;
    @api server;
    @api busy = false;
    @api isLoading = false;

    currentProvider = null;
    lastReportedVariant = null;

    renderedCallback() {
        this.reportVariantChange();
    }

    @api reportValidity() {
        const inputs = Array.from(this.template.querySelectorAll('lightning-input'));
        let isValid = true;

        inputs.forEach((input) => {
            if (typeof input.reportValidity === 'function') {
                input.reportValidity();
            }

            if (typeof input.checkValidity === 'function' && !input.checkValidity()) {
                isValid = false;
            }
        });

        return isValid;
    }

    @api resetProviderSelection() {
        this.currentProvider = null;
    }

    dispatchFieldChange(field, value) {
        this.dispatchEvent(new CustomEvent('fieldchange', { detail: { field, value } }));
    }

    dispatchAction(name) {
        this.dispatchEvent(new CustomEvent(name));
    }

    reportVariantChange() {
        const variant = this.provider;
        if (variant === this.lastReportedVariant) {
            return;
        }

        this.lastReportedVariant = variant;
        this.dispatchEvent(new CustomEvent('contextchange', { detail: { variant } }));
    }

    handleProviderChange(event) {
        const provider = event.currentTarget?.dataset?.provider;
        if (!provider) {
            return;
        }

        this.currentProvider = provider;

        if (provider === PROVIDER.GEMINI) {
            this.dispatchFieldChange('customAgentProjectId', '');
            this.dispatchFieldChange('customAgentLocation', '');
            return;
        }

        this.dispatchFieldChange('customGeminiApiKey', '');
    }

    handleTextChange(event) {
        const field = event.target.dataset.field;
        this.dispatchFieldChange(field, event.target.value);
    }

    handlePrimaryAction() {
        if (this.isConfigDirty) {
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
        this.currentProvider = null;
        this.dispatchAction('revert');
    }

    handleDeactivate() {
        this.dispatchAction('deactivate');
    }

    inferProviderFromDraft() {
        const hasAgentSetup =
            !!asString(this.draft?.customAgentProjectId).trim() ||
            !!asString(this.draft?.customAgentLocation).trim();
        const hasGeminiSetup = !!asString(this.draft?.customGeminiApiKey).trim();

        if (hasAgentSetup) {
            return PROVIDER.AGENT;
        }

        if (hasGeminiSetup) {
            return PROVIDER.GEMINI;
        }

        return PROVIDER.AGENT;
    }

    get provider() {
        const hasAnyConfiguredValue =
            !!asString(this.draft?.customGeminiApiKey).trim() ||
            !!asString(this.draft?.customAgentProjectId).trim() ||
            !!asString(this.draft?.customAgentLocation).trim();

        if (hasAnyConfiguredValue) {
            return this.inferProviderFromDraft();
        }

        return this.currentProvider || PROVIDER.AGENT;
    }

    get isGeminiMode() {
        return this.provider === PROVIDER.GEMINI;
    }

    get isAgentMode() {
        return this.provider === PROVIDER.AGENT;
    }

    get geminiOptionClass() {
        return `step-button provider-option ${this.isGeminiMode ? 'is-active' : ''}`;
    }

    get agentOptionClass() {
        return `step-button provider-option ${this.isAgentMode ? 'is-active' : ''}`;
    }

    get primaryActionLabel() {
        if (!this.isConfigDirty) {
            return 'Validate';
        }

        return 'Save & Validate';
    }

    get isAnalysisOn() {
        return !!this.server?.isFileIntelligenceEnabled;
    }

    get isProviderSaved() {
        const hasModel = !!asString(this.server?.customModelName).trim();
        const hasGemini = !!asString(this.server?.customGeminiApiKey).trim();
        const hasAgent = !!asString(this.server?.customAgentProjectId).trim() && !!asString(this.server?.customAgentLocation).trim();
        return hasModel && (hasGemini || hasAgent);
    }

    get hasSavedIntelligenceSetup() {
        if (this.isAnalysisOn || !!this.server?.isAiLabelingEnabled) {
            return true;
        }

        return SAVED_INTELLIGENCE_KEYS.some((key) => {
            const value = this.server?.[key];
            return value !== null && value !== undefined && asString(value).trim() !== '';
        });
    }

    get showDeactivation() {
        return !!this.server?.hasPersistedRecord && this.hasSavedIntelligenceSetup;
    }

    get status() {
        if (this.isAnalysisOn) {
            return AI_STATUS.on;
        }

        return this.isProviderSaved ? AI_STATUS.off : AI_STATUS.notConnected;
    }

    get statusClass() {
        return this.status.className;
    }

    get statusTitle() {
        return this.status.title;
    }

    get statusText() {
        return this.status.text;
    }

    get isConfigDirty() {
        const serverGeminiApiKey = asString(this.server?.customGeminiApiKey).trim();
        const serverModelName = asString(this.server?.customModelName).trim();
        const serverAgentLocation = asString(this.server?.customAgentLocation).trim();
        const serverAgentProjectId = asString(this.server?.customAgentProjectId).trim();

        const draftGeminiApiKey = asString(this.draft?.customGeminiApiKey).trim();
        const draftModelName = asString(this.draft?.customModelName).trim();
        const draftAgentLocation = asString(this.draft?.customAgentLocation).trim();
        const draftAgentProjectId = asString(this.draft?.customAgentProjectId).trim();

        return (
            serverGeminiApiKey !== draftGeminiApiKey ||
            serverModelName !== draftModelName ||
            serverAgentLocation !== draftAgentLocation ||
            serverAgentProjectId !== draftAgentProjectId
        );
    }
}