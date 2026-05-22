export const DEFAULT_FILE_INTELLIGENCE_SUMMARY_UNAVAILABLE_MESSAGE = 'No summary is currently available for this file. It may still be processing, so try refreshing the page. If it still does not appear, the file may be too large or unsupported for analysis.';

const DEFAULT_FILE_INTELLIGENCE_NAME = 'Untitled';

const normalizeSummary = (summary) => {
	return typeof summary === 'string'
		? summary.trim()
		: '';
};

const resolveFileHoverText = (summary, fileName, fallbackName = DEFAULT_FILE_INTELLIGENCE_NAME) => {
	const normalizedSummary = normalizeSummary(summary);
	if (normalizedSummary) {
		return normalizedSummary;
	}

	const normalizedFileName = typeof fileName === 'string'
		? fileName.trim()
		: '';

	return normalizedFileName || fallbackName;
};

const createDefaultFileIntelligenceState = (versionId = undefined) => {
	return {
		versionId,
		summary: '',
		hasSummary: false,
		isIntelligenceEligible: false
	};
};

const normalizeFileIntelligenceState = (state, versionId = undefined) => {
	const normalizedSummary = normalizeSummary(state?.summary);

	return {
		versionId: state?.versionId || versionId,
		summary: normalizedSummary,
		hasSummary: state?.hasSummary === true || Boolean(normalizedSummary),
		isIntelligenceEligible: state?.isIntelligenceEligible === true
	};
};

const resolveFileIntelligencePanelOpen = (state, openPreference = null) => {
	const normalizedState = normalizeFileIntelligenceState(state);
	if (normalizedState.isIntelligenceEligible !== true) {
		return false;
	}

	if (typeof openPreference === 'boolean') {
		return openPreference;
	}

	return normalizedState.hasSummary === true;
};

export {
	resolveFileHoverText,
	createDefaultFileIntelligenceState,
	normalizeFileIntelligenceState,
	resolveFileIntelligencePanelOpen
};