import { LightningElement, wire } from 'lwc';
import { subscribe, unsubscribe, publish, MessageContext } from 'lightning/messageService';

import CONFIG_CONTEXT_CHANNEL from '@salesforce/messageChannel/GoogleClientConfigContext__c';
import GITHUB_LINK from '@salesforce/label/c.GoogleClientGithubLink';
import SUPPORT_EMAIL from '@salesforce/label/c.GoogleClientSupportEmail';
import { resolveSetupGuide, CONFIG_CONTEXT_MESSAGE_TYPE } from 'c/googleCloudSetupGuides';

const SECTION = {
    guide: 'guide',
    community: 'community'
};

export default class GoogleCloudAppInfo extends LightningElement {
    activeSections = [SECTION.community];
    pendingActiveSections = null;
    guide = null;
    subscription = null;

    @wire(MessageContext)
    messageContext;

    connectedCallback() {
        this.subscription = subscribe(this.messageContext, CONFIG_CONTEXT_CHANNEL, (message) => this.handleContextMessage(message));
        publish(this.messageContext, CONFIG_CONTEXT_CHANNEL, { type: CONFIG_CONTEXT_MESSAGE_TYPE.ready });
    }

    disconnectedCallback() {
        unsubscribe(this.subscription);
        this.subscription = null;
    }

    renderedCallback() {
        if (!this.pendingActiveSections) {
            return;
        }

        this.activeSections = this.pendingActiveSections;
        this.pendingActiveSections = null;
    }

    handleContextMessage(message) {
        if (message?.type !== CONFIG_CONTEXT_MESSAGE_TYPE.context) {
            return;
        }

        const nextGuide = resolveSetupGuide(message);
        if (nextGuide?.key !== this.guide?.key) {
            this.pendingActiveSections = nextGuide ? [SECTION.guide] : [SECTION.community];
        }

        this.guide = nextGuide;
    }

    handleOpenGuideLink() {
        const url = this.guide?.button?.url;
        if (!url) {
            return;
        }

        window.open(url, '_blank', 'noopener,noreferrer');
    }

    handleSectionToggle(event) {
        this.activeSections = event.detail?.openSections || [];
    }

    get showGuide() {
        return !!this.guide;
    }

    get contactHtml() {
        return `
            <div>
                <div style="font-weight: 600; margin-bottom: 6px;">Note</div>
                <div>
                    Contact <a href="mailto:${SUPPORT_EMAIL}">${SUPPORT_EMAIL}</a> to share ideas, report urgent issues, or discuss collaboration opportunities.
                </div>
            </div>
        `;
    }

    get githubUrl() {
        return GITHUB_LINK;
    }
}
