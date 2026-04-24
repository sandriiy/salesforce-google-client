import { LightningElement } from "lwc";

import GITHUB_LINK from "@salesforce/label/c.GoogleClientGithubLink";
import SUPPORT_EMAIL from "@salesforce/label/c.GoogleClientSupportEmail";

export default class GoogleCloudAppInfo extends LightningElement {
  activeSections = ["community"];

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
