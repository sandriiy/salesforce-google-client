import {
	getFocusedTabInfo,
	setTabLabel,
	setTabIcon,
	closeTab,
	openTab
} from 'lightning/platformWorkspaceApi';

const DEFAULT_TAB_POLL_DELAY_MS = 200;
const DEFAULT_TAB_MAX_RETRIES = 5;

export const INT_VIEW_ALL_FILES_PAGE_NAME = 'c__googleCloudRelatedAttachments';
export const INT_VIEW_FILE_DETAILS_PAGE_NAME = 'c__googleCloudFilePageDetails';
export const EXT_VIEW_ALL_FILES_PAGE_NAME = 'gview-all-files';
export const EXT_VIEW_FILE_DETAILS_PAGE_NAME = 'gfile-details';

export async function navigateToByAttributes(pageName, attributes, isNewWindow = true) {
	const isExternal = isExperienceCloudContext();
	const state = normalizeAttributes(attributes);

	if (isExternal) {
		const url = buildExperienceUrl(pageName, state);
		if (isNewWindow) {
			window.open(url, '_blank', 'noopener,noreferrer');
		} else {
			window.location.assign(url);
		}

		return url;
	}

	try {
		const focusedTab = await getFocusedTabInfo();

		if (focusedTab?.tabId) {
			await openTab({
				pageReference: {
					type: 'standard__component',
					attributes: {
						componentName: pageName
					},
					state
				},
				focus: true
			});

			return;
		}
	} catch (e) {}

	const url = buildLightningCmpUrl(pageName, state);
	if (isNewWindow) {
		window.open(url, '_blank', 'noopener,noreferrer');
	} else {
		window.location.assign(url);
	}

	return url;
}

export async function updateTabPresentation({
	label,
	iconName,
	iconOptions,
	targetComponentName,
	maxRetries = DEFAULT_TAB_MAX_RETRIES,
	pollDelayMs = DEFAULT_TAB_POLL_DELAY_MS
} = {}) {
	if (isExperienceCloudContext()) {
		if (label) {
			try { document.title = label; } catch (e) {}
		}
		return { tabInfo: null, isWorkspace: false };
	}

	const ws = await tryGetFocusedTabInfo();
	if (!ws?.tabInfo) {
		if (label) {
			try { document.title = label; } catch (e) {}
		}
		return { tabInfo: null, isWorkspace: false };
	}

	if (!targetComponentName) {
		await trySetTabLabel(ws.tabInfo?.tabId, label);
		if (iconName) {
			await trySetTabIcon(ws.tabInfo?.tabId, iconName, iconOptions);
		}
		return { tabInfo: ws.tabInfo, isWorkspace: true };
	}

	let retries = 0;
	while (retries <= maxRetries) {
		const focused = await tryGetFocusedTabInfo();
		const tabInfo = focused?.tabInfo;

		if (isTargetTab(tabInfo, targetComponentName)) {
			await trySetTabLabel(tabInfo.tabId, label);
			if (iconName) {
				await trySetTabIcon(tabInfo.tabId, iconName, iconOptions);
			}
			return { tabInfo, isWorkspace: true };
		}

		retries++;
		await delay(pollDelayMs);
	}

	if (label) {
		try { document.title = label; } catch (e) {}
	}
	return { tabInfo: null, isWorkspace: false };
}

export async function closeCurrentContext({ tabInfo, fallbackUrl } = {}) {
	if (isExperienceCloudContext()) {
		return closeInBrowser({ fallbackUrl: fallbackUrl || defaultExperienceHome() });
	}

	const tabId = tabInfo?.tabId;
	if (tabId) {
		const ok = await tryCloseWorkspaceTab(tabId);
		if (ok) return true;
	}

	return closeInBrowser({ fallbackUrl: fallbackUrl || '/lightning/page/home' });
}

export async function closeWhenReady({
	getTabInfo,
	maxRetries = DEFAULT_TAB_MAX_RETRIES,
	pollDelayMs = DEFAULT_TAB_POLL_DELAY_MS,
	fallbackUrl
} = {}) {
	// Experience doesn't need tab polling
	if (isExperienceCloudContext()) {
		return closeInBrowser({ fallbackUrl: fallbackUrl || defaultExperienceHome() });
	}

	let retries = 0;
	while (retries <= maxRetries) {
		const tabInfo = typeof getTabInfo === 'function' ? getTabInfo() : null;

		if (tabInfo?.tabId) {
			return closeCurrentContext({ tabInfo, fallbackUrl });
		}

		retries++;
		await delay(pollDelayMs);
	}

	// fallback
	return closeInBrowser({ fallbackUrl: fallbackUrl || '/lightning/page/home' });
}

export function isInSitePreview() {
	const loc = safeLocation();
	if (!loc) return false;

	const href = lower(loc.href);
	const host = lower(loc.hostname);

	if (hostMatches(host, [
		'.builder.salesforce-communities.com',
		'.preview.salesforce-communities.com',
		'.livepreview.salesforce-communities.com',
		'.builder.salesforce-experience.com',
		'.preview.salesforce-experience.com',
		'.livepreview.salesforce-experience.com'
	])) {
		return true;
	}
	if (host.includes('--sitestudio') || host.includes('--sitepreview') || host.includes('--livepreview')) {
		return true;
	}

	return (
		href.includes('sitepreview') ||
		href.includes('livepreview') ||
		href.includes('live-preview') ||
		href.includes('.builder.')
	);
}

export function isExperienceCloudContext({ allowSoftGuess = false } = {}) {
	const loc = safeLocation();
	if (!loc) return false;

	const host = lower(loc.hostname);
	const path = lower(loc.pathname);

	if (pathStartsWith(path, ['/lightning', '/lightning/'])) return false;

	if (isInSitePreview()) return true;

	if (hasPathSegment(path, 's')) return true;

	if (hostMatches(host, [
		'.salesforce-communities.com',
		'.salesforce-experience.com'
	])) {
		return true;
	}

	return !!allowSoftGuess;
}

function normalizeAttributes(attributes) {
	if (attributes == null) {
		return {};
	}

	if (typeof attributes !== 'object' || Array.isArray(attributes)) {
		return { c__configId: attributes };
	}

	const state = {};
	Object.entries(attributes).forEach(([key, value]) => {
		if (value !== undefined && value !== null && value !== '') {
			state[key] = value;
		}
	});

	return state;
}

async function tryGetFocusedTabInfo() {
	try {
		const tabInfo = await getFocusedTabInfo();
		return { tabInfo };
	} catch (e) {
		return { tabInfo: null };
	}
}

async function trySetTabLabel(tabId, label) {
	try {
		if (!tabId || !label) return false;
		await setTabLabel(tabId, label);
		return true;
	} catch (e) {
		return false;
	}
}

async function trySetTabIcon(tabId, iconName, iconOptions) {
	try {
		if (!tabId || !iconName) return false;
		await setTabIcon(tabId, iconName, iconOptions || {});
		return true;
	} catch (e) {
		return false;
	}
}

async function tryCloseWorkspaceTab(tabId) {
	try {
		if (!tabId) return false;
		await closeTab(tabId);
		return true;
	} catch (e) {
		return false;
	}
}

function isTargetTab(tabInfo, targetComponentName) {
	if (!tabInfo || !tabInfo.pageReference) return false;
	const pageRef = tabInfo.pageReference;
	return pageRef?.attributes?.componentName === targetComponentName;
}

function closeInBrowser({ fallbackUrl } = {}) {
	try {
		if (window.history?.length > 1) {
			window.history.back();
			return true;
		}
	} catch (e) {}

	try {
		if (fallbackUrl) {
			window.location.assign(fallbackUrl);
			return true;
		}
	} catch (e) {}

	try {
		window.close();
	} catch (e) {}

	return false;
}

function defaultExperienceHome() {
	try {
		const loc = safeLocation();
		const prefix = getExperienceSitePrefix(loc?.pathname);
		return `${prefix}/s/`;
	} catch (e) {
		return '/s/';
	}
}

function buildExperienceUrl(pageNameOrPath, params = {}) {
	const base = new URL(window.location.origin);
	const path = normalizeExperiencePath(pageNameOrPath);
	const url = new URL(path, base);

	Object.entries(params).forEach(([key, value]) => {
		if (value !== undefined && value !== null && value !== '') {
			url.searchParams.set(key, String(value));
		}
	});

	return url.toString();
}

function buildLightningCmpUrl(componentName, state = {}) {
	const base = new URL(window.location.origin);

	const cmp = String(componentName || '').trim();
	const url = new URL('/lightning/cmp/' + encodeURIComponent(cmp), base);

	Object.entries(state).forEach(([key, value]) => {
		if (value !== undefined && value !== null && value !== '') {
			url.searchParams.set(key, String(value));
		}
	});

	return url.toString();
}

function normalizeExperiencePath(pageNameOrPath) {
	const loc = safeLocation();
	const sitePrefix = getExperienceSitePrefix(loc?.pathname);

	let p = (pageNameOrPath || '').trim();
	if (!p) return `${sitePrefix}/s/`;

	if (!p.startsWith('/')) p = `/${p}`;

	if (hasPathSegment(p, 's')) {
		if (sitePrefix && lower(p).startsWith(lower(sitePrefix) + '/')) return p;
		return `${sitePrefix}${p}`;
	}

	if (p === '/') return `${sitePrefix}/s/`;
	return `${sitePrefix}/s${p}`;
}

function getExperienceSitePrefix(pathname) {
	const path = lower(pathname || '');

	const idx = path.indexOf('/s/');
	if (idx > 0) return path.slice(0, idx);

	const m = path.match(/^(.*)\/s$/);
	if (m && m[1] && m[1] !== '/') return m[1];
	return '';
}

function safeLocation() {
	try {
		return typeof window !== 'undefined' ? window.location : null;
	} catch {
		return null;
	}
}

function lower(v) {
	return (v || '').toLowerCase();
}

function hostMatches(host, parts) {
	const h = lower(host);
	return parts.some(p => h.includes(lower(p)));
}

function pathStartsWith(path, prefixes) {
	const p = lower(path);
	return prefixes.some(x => p === lower(x) || p.startsWith(lower(x)));
}

function hasPathSegment(path, seg) {
	const p = lower(path);
	const s = lower(seg).replace(/^\/|\/$/g, '');
	return new RegExp(`(^|/)${escapeRegExp(s)}(/|$)`).test(p);
}

function escapeRegExp(str) {
	return String(str).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function delay(ms) {
	return new Promise(resolve => window.setTimeout(resolve, ms));
}