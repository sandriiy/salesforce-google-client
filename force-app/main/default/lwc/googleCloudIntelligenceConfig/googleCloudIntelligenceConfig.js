import { LightningElement, api } from 'lwc';

import { asString } from 'c/googleCloudUtils';

const PROVIDER = {
    GEMINI: 'gemini',
    AGENT: 'agent'
};

const GEMINI_SETUP_URL = 'https://ai.google.dev/gemini-api/docs/api-key';
const AGENT_SETUP_URL = 'https://cloud.google.com/vertex-ai/generative-ai/docs/start';

export default class GoogleCloudIntelligenceConfig extends LightningElement {
    @api draft;
    @api server;
    @api busy = false;
    @api isLoading = false;

    currentProvider = null;

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

    dispatchFieldChange(field, value) {
        this.dispatchEvent(new CustomEvent('fieldchange', { detail: { field, value } }));
    }

    dispatchAction(name) {
        this.dispatchEvent(new CustomEvent(name));
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

    handleOpenSelectedGuide() {
        window.open(this.selectedGuideUrl, '_blank');
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

    get selectedGuideUrl() {
        return this.isGeminiMode ? GEMINI_SETUP_URL : AGENT_SETUP_URL;
    }

    get setupGuideButtonLabel() {
        return this.isGeminiMode ? 'Open Gemini Setup Guide' : 'Open Agent Platform Setup Guide';
    }

    get quickSetupTitle() {
        return this.isGeminiMode ? 'Gemini Quick Setup' : 'Agent Platform Quick Setup';
    }

    get primaryActionLabel() {
        if (!this.isConfigDirty) {
            return 'Validate';
        }

        return 'Save & Validate';
    }

    get isIntelligenceEnabled() {
        return !!this.draft?.isFileIntelligenceEnabled;
    }

    get isIntelligenceDisabled() {
        return !this.isIntelligenceEnabled;
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