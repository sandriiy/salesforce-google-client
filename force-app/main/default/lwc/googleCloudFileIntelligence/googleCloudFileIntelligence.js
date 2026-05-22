import { LightningElement, api, track } from 'lwc';

import retrieveFileIntelligenceState from '@salesforce/apex/GoogleCloudFileIntelligenceController.retrieveFileIntelligenceState';
import {
	DEFAULT_FILE_INTELLIGENCE_SUMMARY_UNAVAILABLE_MESSAGE,
	createDefaultFileIntelligenceState,
	normalizeFileIntelligenceState,
	resolveFileIntelligencePanelOpen
} from 'c/googleCloudFileIntelligenceUtils';

export default class GoogleCloudFileIntelligence extends LightningElement {
	@track intelligenceState = createDefaultFileIntelligenceState();
	@track isLoading = false;
	@track isOpen = false;

	requestSequence = 0;
	userOpenPreference = null;
	versionIdValue;

	@api
	get versionId() {
		return this.versionIdValue;
	}

	set versionId(value) {
		const normalizedVersionId = value || undefined;
		if (this.versionIdValue === normalizedVersionId) {
			return;
		}

		this.versionIdValue = normalizedVersionId;
		this.userOpenPreference = null;
		this.requestSequence += 1;
		this.intelligenceState = createDefaultFileIntelligenceState(normalizedVersionId);
		this.isLoading = false;
		this.isOpen = false;

		if (!normalizedVersionId) {
			this.emitStateChange();
			return;
		}

		void this.loadIntelligenceState(normalizedVersionId);
	}

	@api
	async refresh() {
		if (!this.versionIdValue) {
			return;
		}

		await this.loadIntelligenceState(this.versionIdValue);
	}

	handleOpen() {
		this.userOpenPreference = true;
		this.isOpen = true;
		this.dispatchEvent(new CustomEvent('panelopen'));
		this.emitStateChange();
	}

	handleClose() {
		this.userOpenPreference = false;
		this.isOpen = false;
		this.dispatchEvent(new CustomEvent('panelclose'));
		this.emitStateChange();
	}

	async loadIntelligenceState(versionId) {
		const currentRequestSequence = ++this.requestSequence;
		this.isLoading = true;
		this.emitStateChange();

		try {
			const intelligenceState = await retrieveFileIntelligenceState({
				localFileVersionId: versionId
			});

			if (currentRequestSequence !== this.requestSequence || versionId !== this.versionIdValue) {
				return;
			}

			this.intelligenceState = normalizeFileIntelligenceState(intelligenceState, versionId);
			this.isOpen = resolveFileIntelligencePanelOpen(this.intelligenceState, this.userOpenPreference);
		} catch (error) {
			if (currentRequestSequence !== this.requestSequence || versionId !== this.versionIdValue) {
				return;
			}

			this.intelligenceState = createDefaultFileIntelligenceState(versionId);
			this.isOpen = false;
		} finally {
			if (currentRequestSequence === this.requestSequence && versionId === this.versionIdValue) {
				this.isLoading = false;
				this.emitStateChange();
			}
		}
	}

	emitStateChange() {
		this.dispatchEvent(new CustomEvent('statechange', {
			detail: {
				isEligible: this.intelligenceState?.isIntelligenceEligible === true,
				isLoading: this.isLoading === true,
				isOpen: this.isOpen === true
			}
		}));
	}

	get summaryCopy() {
		return this.intelligenceState?.hasSummary === true && this.intelligenceState?.summary
			? this.intelligenceState.summary
			: DEFAULT_FILE_INTELLIGENCE_SUMMARY_UNAVAILABLE_MESSAGE;
	}

	get summaryCopyClass() {
		return this.intelligenceState?.hasSummary === true
			? 'intelligence-summary-copy'
			: 'intelligence-summary-copy intelligence-summary-copy--placeholder';
	}

	get showTrigger() {
		return this.intelligenceState?.isIntelligenceEligible === true && this.isOpen !== true;
	}

	get showPanel() {
		return this.intelligenceState?.isIntelligenceEligible === true && this.isOpen === true;
	}
}