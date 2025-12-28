import { LightningElement } from 'lwc';

import RELEASES_LINK from '@salesforce/label/c.GoogleClientReleaseNotesLink';
import RELEASE_TITLE from '@salesforce/label/c.GoogleClientReleaseTitle';

export default class GoogleCloudAppHeader extends LightningElement {
	titleLabel = RELEASE_TITLE;
	releaseButtonLabel = 'View Release Notes';

	handleViewReleaseNotes() {
		try {
			window.open(RELEASES_LINK, '_blank', 'noopener,noreferrer');
		} catch (e) {
			window.location.assign(RELEASES_LINK);
		}
	}
}