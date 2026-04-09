import { LightningElement, api } from 'lwc';

import { asString } from 'c/googleCloudUtils';

const PROVIDER = {
    GEMINI: 'gemini',
    VERTEX: 'vertex'
};

const GEMINI_SETUP_URL = 'https://ai.google.dev/gemini-api/docs/api-key';
const VERTEX_SETUP_URL = 'https://docs.cloud.google.com/vertex-ai/generative-ai/docs/start';

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
            this.dispatchFieldChange('customVertexProjectId', '');
            this.dispatchFieldChange('customVertexLocation', '');
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
        const hasVertexSetup =
            !!asString(this.draft?.customVertexProjectId).trim() ||
            !!asString(this.draft?.customVertexLocation).trim();
        const hasGeminiSetup = !!asString(this.draft?.customGeminiApiKey).trim();

        if (hasVertexSetup) {
            return PROVIDER.VERTEX;
        }

        if (hasGeminiSetup) {
            return PROVIDER.GEMINI;
        }

        return PROVIDER.VERTEX;
    }

    get provider() {
        const hasAnyConfiguredValue =
            !!asString(this.draft?.customGeminiApiKey).trim() ||
            !!asString(this.draft?.customVertexProjectId).trim() ||
            !!asString(this.draft?.customVertexLocation).trim();

        if (hasAnyConfiguredValue) {
            return this.inferProviderFromDraft();
        }

        return this.currentProvider || PROVIDER.VERTEX;
    }

    get isGeminiMode() {
        return this.provider === PROVIDER.GEMINI;
    }

    get isVertexMode() {
        return this.provider === PROVIDER.VERTEX;
    }

    get geminiOptionClass() {
        return `step-button provider-option ${this.isGeminiMode ? 'is-active' : ''}`;
    }

    get vertexOptionClass() {
        return `step-button provider-option ${this.isVertexMode ? 'is-active' : ''}`;
    }

    get selectedGuideUrl() {
        return this.isGeminiMode ? GEMINI_SETUP_URL : VERTEX_SETUP_URL;
    }

    get setupGuideButtonLabel() {
        return this.isGeminiMode ? 'Open Gemini Setup Guide' : 'Open Vertex Setup Guide';
    }

    get quickSetupTitle() {
        return this.isGeminiMode ? 'Gemini Quick Setup' : 'Vertex Quick Setup';
    }

    get primaryActionLabel() {
        return this.isConfigDirty ? 'Save & Validate' : 'Validate';
    }

    get isConfigDirty() {
        const serverGeminiApiKey = asString(this.server?.customGeminiApiKey).trim();
        const serverModelName = asString(this.server?.customModelName).trim();
        const serverVertexLocation = asString(this.server?.customVertexLocation).trim();
        const serverVertexProjectId = asString(this.server?.customVertexProjectId).trim();

        const draftGeminiApiKey = asString(this.draft?.customGeminiApiKey).trim();
        const draftModelName = asString(this.draft?.customModelName).trim();
        const draftVertexLocation = asString(this.draft?.customVertexLocation).trim();
        const draftVertexProjectId = asString(this.draft?.customVertexProjectId).trim();

        return (
            serverGeminiApiKey !== draftGeminiApiKey ||
            serverModelName !== draftModelName ||
            serverVertexLocation !== draftVertexLocation ||
            serverVertexProjectId !== draftVertexProjectId
        );
    }
}