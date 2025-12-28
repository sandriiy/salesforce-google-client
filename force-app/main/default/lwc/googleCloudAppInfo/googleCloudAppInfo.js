import { LightningElement } from 'lwc';

import GITHUB_LINK from '@salesforce/label/c.GoogleClientGithubLink';
import SUPPORT_EMAIL from '@salesforce/label/c.GoogleClientSupportEmail';

export default class GoogleCloudAppInfo extends LightningElement {
    activeSections = ['community'];

    get contactHtml() {
        return `
            <div>
                <div style="font-weight: 600; margin-bottom: 6px;">Contact</div>
                <div>
                    Email <a href="mailto:${SUPPORT_EMAIL}">${SUPPORT_EMAIL}</a> to discuss Standard vs Premium and to arrange onboarding.
                </div>
            </div>
        `;
    }

	get githubUrl() {
		return GITHUB_LINK;
	}
}