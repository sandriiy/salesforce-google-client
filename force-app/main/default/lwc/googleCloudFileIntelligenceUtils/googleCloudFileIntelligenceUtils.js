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
        isIntelligenceEligible: false,
        labels: []
    };
};

const normalizeLabels = (labels) => {
    if (!Array.isArray(labels)) {
        return [];
    }

    return labels
        .filter((label) => typeof label === 'string' && label.trim().length > 0)
        .map((label) => label.trim());
};

const normalizeFileIntelligenceState = (state, versionId = undefined) => {
    const normalizedSummary = normalizeSummary(state?.summary);

    return {
        versionId: state?.versionId || versionId,
        summary: normalizedSummary,
        hasSummary: state?.hasSummary === true || Boolean(normalizedSummary),
        isIntelligenceEligible: state?.isIntelligenceEligible === true,
        labels: normalizeLabels(state?.labels)
    };
};

const isFileIntelligencePanelAvailable = (state) => {
    const normalizedState = normalizeFileIntelligenceState(state);
    return normalizedState.isIntelligenceEligible === true
        || normalizedState.hasSummary === true
        || normalizedState.labels.length > 0;
};

const resolveFileIntelligencePanelOpen = (state, openPreference = null) => {
    const normalizedState = normalizeFileIntelligenceState(state);
    if (!isFileIntelligencePanelAvailable(normalizedState)) {
        return false;
    }

    if (typeof openPreference === 'boolean') {
        return openPreference;
    }

    return normalizedState.isIntelligenceEligible === true && normalizedState.hasSummary === true;
};

export {
    resolveFileHoverText,
    createDefaultFileIntelligenceState,
    normalizeFileIntelligenceState,
    isFileIntelligencePanelAvailable,
    resolveFileIntelligencePanelOpen
};