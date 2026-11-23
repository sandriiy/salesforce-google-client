import TIME_ZONE from '@salesforce/i18n/timeZone';

const MEBIBYTE = 1024 * 1024;
const MAX_SHOWN_FILE_TYPES = 2;
const ISO_DAY_PATTERN = /^\d{4}-\d{2}-\d{2}$/;
const SALESFORCE_ID_PATTERN = /^[a-zA-Z0-9]{15}([a-zA-Z0-9]{3})?$/;
const FILE_EXTENSION_SEPARATOR = ';';
const OWNER_MINE = 'mine';

const FILE_TYPE_GROUPS = [
    { value: 'pdf', label: 'PDF', extensions: ['pdf'] },
    { value: 'word', label: 'Word documents', extensions: ['doc', 'docx', 'odt', 'rtf'] },
    { value: 'spreadsheets', label: 'Spreadsheets', extensions: ['xls', 'xlsx', 'xlsm', 'ods', 'csv', 'tsv'] },
    { value: 'presentations', label: 'Presentations', extensions: ['ppt', 'pptx', 'odp', 'key'] },
    { value: 'images', label: 'Images', extensions: ['png', 'jpg', 'jpeg', 'gif', 'bmp', 'svg', 'webp', 'tif', 'tiff', 'heic'] },
    { value: 'text', label: 'Text', extensions: ['txt', 'md'] },
    { value: 'video', label: 'Video', extensions: ['mp4', 'mov', 'avi', 'mkv', 'webm', 'wmv', 'm4v'] },
    { value: 'audio', label: 'Audio', extensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac', 'wma'] },
    { value: 'archives', label: 'Archives', extensions: ['zip', 'rar', '7z', 'tar', 'gz', 'tgz'] }
];

const SIZE_OPTIONS = [
    { value: 'underOneMb', label: 'Smaller than 1 MB', maxBytes: MEBIBYTE },
    { value: 'oneToTenMb', label: '1 MB to 10 MB', minBytes: MEBIBYTE, maxBytes: 10 * MEBIBYTE },
    { value: 'tenToHundredMb', label: '10 MB to 100 MB', minBytes: 10 * MEBIBYTE, maxBytes: 100 * MEBIBYTE },
    { value: 'overHundredMb', label: 'Larger than 100 MB', minBytes: 100 * MEBIBYTE }
];

const DATE_PRESET = {
    TODAY: 'today',
    LAST_7_DAYS: 'last7Days',
    LAST_30_DAYS: 'last30Days',
    THIS_YEAR: 'thisYear',
    LAST_YEAR: 'lastYear',
    CUSTOM: 'custom'
};

const DATE_OPTIONS = [
    { value: DATE_PRESET.TODAY, label: 'Today', daysIncludingToday: 1 },
    { value: DATE_PRESET.LAST_7_DAYS, label: 'Last 7 days', daysIncludingToday: 7 },
    { value: DATE_PRESET.LAST_30_DAYS, label: 'Last 30 days', daysIncludingToday: 30 },
    { value: DATE_PRESET.THIS_YEAR, label: 'This year' },
    { value: DATE_PRESET.LAST_YEAR, label: 'Last year' },
    { value: DATE_PRESET.CUSTOM, label: 'Custom range' }
];

const VERSION_OPTIONS = [
    { value: 'onlyOne', label: 'Only one', minVersions: 1, maxVersions: 1 },
    { value: 'twoOrMore', label: '2 or more', minVersions: 2 },
    { value: 'fiveOrMore', label: '5 or more', minVersions: 5 },
    { value: 'tenOrMore', label: '10 or more', minVersions: 10 }
];

const OWNER_OPTIONS = [
    { value: OWNER_MINE, label: 'Me' }
];

const LINK_OPTIONS = [
    { value: 'linked', label: 'Yes' },
    { value: 'unlinked', label: 'No' }
];

const SEARCH_FILTERS = [
    { key: 'fileTypes', label: 'File type', isMultiple: true, options: FILE_TYPE_GROUPS },
    { key: 'size', label: 'Size', options: SIZE_OPTIONS },
    { key: 'created', label: 'Created', isDateRange: true, options: DATE_OPTIONS },
    { key: 'modified', label: 'Last modified', isDateRange: true, options: DATE_OPTIONS },
    { key: 'versions', label: 'Versions', options: VERSION_OPTIONS },
    { key: 'owner', label: 'Owner', options: OWNER_OPTIONS, listsOwners: true },
    { key: 'linked', label: 'Linked', options: LINK_OPTIONS }
];

const EMPTY_SEARCH_CRITERIA = Object.freeze({
    keyPhrases: '',
    fileTypes: Object.freeze([]),
    size: '',
    created: '',
    createdFrom: '',
    createdTo: '',
    modified: '',
    modifiedFrom: '',
    modifiedTo: '',
    versions: '',
    owner: '',
    ownerName: '',
    linked: ''
});

const rangeStartKey = (filterKey) => `${filterKey}From`;

const rangeEndKey = (filterKey) => `${filterKey}To`;

const toIsoDay = (value) => (typeof value === 'string' && ISO_DAY_PATTERN.test(value) ? value : '');

const isOwnerId = (value) => typeof value === 'string' && SALESFORCE_ID_PATTERN.test(value);

const isFilledText = (value) => typeof value === 'string' && value.trim().length > 0;

const findOption = (options, value) => options.find((option) => option.value === value);

const findFilter = (filterKey) => SEARCH_FILTERS.find((filter) => filter.key === filterKey);

/**
 * Reads search criteria from anywhere, a saved session included, and keeps only values the
 * Search view knows, so a stale or hand-edited value can never reach the server.
 *
 * @param {object} rawCriteria - what to read; anything that is not an object reads as empty
 * @returns {object} criteria in the shape of EMPTY_SEARCH_CRITERIA
 */
const normalizeSearchCriteria = (rawCriteria) => {
    const source = rawCriteria && typeof rawCriteria === 'object' ? rawCriteria : {};
    const criteria = { ...EMPTY_SEARCH_CRITERIA };

    criteria.keyPhrases = typeof source.keyPhrases === 'string' ? source.keyPhrases : '';

    SEARCH_FILTERS.forEach((filter) => {
        const value = source[filter.key];

        if (filter.isMultiple) {
            const chosen = Array.isArray(value) ? value : [];
            criteria[filter.key] = filter.options.map((option) => option.value).filter((optionValue) => chosen.includes(optionValue));
            return;
        }

        if (filter.listsOwners) {
            const isNamedOwner = isOwnerId(value) && isFilledText(source.ownerName);
            criteria[filter.key] = value === OWNER_MINE || isNamedOwner ? value : '';
            criteria.ownerName = isNamedOwner ? source.ownerName : '';
            return;
        }

        criteria[filter.key] = findOption(filter.options, value) ? value : '';

        if (filter.isDateRange) {
            criteria[rangeStartKey(filter.key)] = toIsoDay(source[rangeStartKey(filter.key)]);
            criteria[rangeEndKey(filter.key)] = toIsoDay(source[rangeEndKey(filter.key)]);
        }
    });

    return criteria;
};

/**
 * Whether one filter chip is in use.
 *
 * @param {object} filter - an entry of SEARCH_FILTERS
 * @param {object} criteria - normalized criteria
 */
const isSearchFilterSet = (filter, criteria) => {
    const value = criteria?.[filter.key];
    return filter.isMultiple ? Array.isArray(value) && value.length > 0 : Boolean(value);
};

/**
 * Whether anything is entered: a word in the search box or a filter chip in use.
 *
 * @param {object} criteria - normalized criteria
 */
const hasSearchCriteria = (criteria) => {
    const hasKeyPhrases = typeof criteria?.keyPhrases === 'string' && criteria.keyPhrases.trim().length > 0;
    return hasKeyPhrases || SEARCH_FILTERS.some((filter) => isSearchFilterSet(filter, criteria));
};

const formatIsoDay = (isoDay) => {
    const [year, month, day] = isoDay.split('-');
    return `${day}/${month}/${year}`;
};

const isCompleteDayRange = (fromDay, toDay) => Boolean(fromDay && toDay);

const describeDayRange = (fromDay, toDay) => {
    if (isCompleteDayRange(fromDay, toDay)) return `${formatIsoDay(fromDay)} – ${formatIsoDay(toDay)}`;
    return findOption(DATE_OPTIONS, DATE_PRESET.CUSTOM).label;
};

/**
 * The text a filter chip shows: its name alone when unused, its value once in use,
 * for example "File type: PDF, Word documents" or "Created: 01/11/2026 – 07/11/2026".
 * A custom range reads "Custom range" until both of its days are chosen.
 *
 * @param {object} filter - an entry of SEARCH_FILTERS
 * @param {object} criteria - normalized criteria
 */
const describeSearchFilter = (filter, criteria) => {
    if (filter.isMultiple) {
        const labels = filter.options.filter((option) => criteria[filter.key].includes(option.value)).map((option) => option.label);
        if (labels.length === 0) return filter.label;

        const shown = labels.length <= MAX_SHOWN_FILE_TYPES ? labels.join(', ') : `${labels[0]} +${labels.length - 1}`;
        return `${filter.label}: ${shown}`;
    }

    if (filter.listsOwners && isOwnerId(criteria[filter.key])) {
        return `${filter.label}: ${criteria.ownerName}`;
    }

    const option = findOption(filter.options, criteria[filter.key]);
    if (!option) return filter.label;

    if (filter.isDateRange && option.value === DATE_PRESET.CUSTOM) {
        return `${filter.label}: ${describeDayRange(criteria[rangeStartKey(filter.key)], criteria[rangeEndKey(filter.key)])}`;
    }

    return `${filter.label}: ${option.label}`;
};

/**
 * Picks an option of a filter chip. A chip taking several values toggles the option,
 * any other chip takes it as its only value. An owner other than "Me" keeps its name,
 * which is what the chip shows.
 *
 * @param {object} criteria - normalized criteria
 * @param {string} filterKey - the key of an entry of SEARCH_FILTERS
 * @param {string} optionValue - the value of one of its options
 * @param {string} optionLabel - the text of that option
 * @returns {object} new criteria
 */
const pickSearchFilterOption = (criteria, filterKey, optionValue, optionLabel) => {
    const filter = findFilter(filterKey);
    if (!filter) return criteria;

    if (filter.listsOwners) {
        return normalizeSearchCriteria({ ...criteria, [filterKey]: optionValue, ownerName: optionValue === OWNER_MINE ? '' : optionLabel });
    }

    if (!findOption(filter.options, optionValue)) return criteria;

    if (filter.isMultiple) {
        const current = criteria[filterKey];
        const next = current.includes(optionValue) ? current.filter((value) => value !== optionValue) : [...current, optionValue];
        return normalizeSearchCriteria({ ...criteria, [filterKey]: next });
    }

    return normalizeSearchCriteria({ ...criteria, [filterKey]: optionValue });
};

/**
 * Sets one end of a chip's custom date range.
 *
 * @param {object} criteria - normalized criteria
 * @param {string} filterKey - "created" or "modified"
 * @param {boolean} isStart - true for the "from" day, false for the "to" day
 * @param {string} isoDay - the day as YYYY-MM-DD, or blank to clear it
 * @returns {object} new criteria
 */
const setSearchDayRange = (criteria, filterKey, isStart, isoDay) => {
    const filter = findFilter(filterKey);
    if (!filter?.isDateRange) return criteria;

    const edgeKey = isStart ? rangeStartKey(filterKey) : rangeEndKey(filterKey);
    return normalizeSearchCriteria({ ...criteria, [filterKey]: DATE_PRESET.CUSTOM, [edgeKey]: isoDay });
};

/**
 * The days a chip's custom range holds, blank where none was chosen.
 *
 * @param {object} criteria - normalized criteria
 * @param {string} filterKey - "created" or "modified"
 * @returns {{from: string, to: string}} days as YYYY-MM-DD
 */
const searchDayRangeOf = (criteria, filterKey) => {
    return { from: criteria?.[rangeStartKey(filterKey)] || '', to: criteria?.[rangeEndKey(filterKey)] || '' };
};

/**
 * The choices of the Owner filter: "Me" first, then everyone else who owns files the user
 * can open, in the order they came, which is by name.
 *
 * @param {Array} owners - owners from retrieveFileExplorerOwners, each with ownerId and name
 * @param {string} currentUserId - the running user, who is listed as "Me" instead
 * @returns {Array} options in the shape of the other filters' options
 */
const buildOwnerOptions = (owners, currentUserId) => {
    const otherOwners = (Array.isArray(owners) ? owners : [])
        .filter((owner) => isOwnerId(owner?.ownerId) && owner.ownerId !== currentUserId && isFilledText(owner.name))
        .map((owner) => ({ value: owner.ownerId, label: owner.name }));

    return [...OWNER_OPTIONS, ...otherOwners];
};

/**
 * Takes one filter chip out of use, dates of a custom range included.
 *
 * @param {object} criteria - normalized criteria
 * @param {string} filterKey - the key of an entry of SEARCH_FILTERS
 * @returns {object} new criteria
 */
const clearSearchFilter = (criteria, filterKey) => {
    const filter = findFilter(filterKey);
    if (!filter) return criteria;

    const cleared = { ...criteria, [filterKey]: EMPTY_SEARCH_CRITERIA[filterKey] };
    if (filter.isDateRange) {
        cleared[rangeStartKey(filterKey)] = '';
        cleared[rangeEndKey(filterKey)] = '';
    }

    return normalizeSearchCriteria(cleared);
};

const shiftIsoDay = (isoDay, days) => {
    const [year, month, day] = isoDay.split('-').map(Number);
    return new Date(Date.UTC(year, month - 1, day + days)).toISOString().slice(0, 10);
};

const resolveDayRange = (presetValue, fromDay, toDay, today) => {
    const preset = findOption(DATE_OPTIONS, presetValue);
    if (!preset) return { from: null, to: null };

    const currentYear = Number(today.slice(0, 4));

    if (preset.daysIncludingToday) {
        return { from: shiftIsoDay(today, 1 - preset.daysIncludingToday), to: today };
    }

    if (preset.value === DATE_PRESET.THIS_YEAR) {
        return { from: `${currentYear}-01-01`, to: today };
    }

    if (preset.value === DATE_PRESET.LAST_YEAR) {
        return { from: `${currentYear - 1}-01-01`, to: `${currentYear - 1}-12-31` };
    }

    return isCompleteDayRange(fromDay, toDay) ? { from: fromDay, to: toDay } : { from: null, to: null };
};

const resolveFileExtensions = (fileTypes) => {
    const extensions = FILE_TYPE_GROUPS
        .filter((group) => fileTypes.includes(group.value))
        .flatMap((group) => group.extensions);

    return extensions.length > 0 ? extensions.join(FILE_EXTENSION_SEPARATOR) : null;
};

const valueOrNull = (value) => (value === undefined ? null : value);

/**
 * Turns the criteria into the values searchFileExplorerFiles takes: presets become
 * concrete days and byte bounds, file types become their extensions, and anything
 * not in use becomes null. A custom range counts only once both of its days are chosen,
 * so picking the first day alone changes nothing the server is asked.
 *
 * @param {object} criteria - criteria in the shape of EMPTY_SEARCH_CRITERIA
 * @param {string} today - the Salesforce user's today as YYYY-MM-DD, from resolveToday()
 */
const toSearchRequest = (criteria, today) => {
    const normalized = normalizeSearchCriteria(criteria);
    const sizeOption = findOption(SIZE_OPTIONS, normalized.size);
    const versionOption = findOption(VERSION_OPTIONS, normalized.versions);
    const created = resolveDayRange(normalized.created, normalized.createdFrom, normalized.createdTo, today);
    const modified = resolveDayRange(normalized.modified, normalized.modifiedFrom, normalized.modifiedTo, today);

    return {
        keyPhrases: normalized.keyPhrases.trim() || null,
        fileExtensions: resolveFileExtensions(normalized.fileTypes),
        minSizeBytes: valueOrNull(sizeOption?.minBytes),
        maxSizeBytes: valueOrNull(sizeOption?.maxBytes),
        createdFrom: created.from,
        createdTo: created.to,
        modifiedFrom: modified.from,
        modifiedTo: modified.to,
        minVersions: valueOrNull(versionOption?.minVersions),
        maxVersions: valueOrNull(versionOption?.maxVersions),
        ownership: normalized.owner || null,
        linkState: normalized.linked || null
    };
};

/**
 * Whether two sets of criteria ask the server the same thing, so a change that only
 * prepares a filter, such as the first day of a custom range, need not reload the list.
 *
 * @param {object} criteria - criteria in the shape of EMPTY_SEARCH_CRITERIA
 * @param {object} otherCriteria - criteria in the shape of EMPTY_SEARCH_CRITERIA
 * @param {string} today - the Salesforce user's today as YYYY-MM-DD, from resolveToday()
 */
const isSameSearchRequest = (criteria, otherCriteria, today) => {
    return JSON.stringify(toSearchRequest(criteria, today)) === JSON.stringify(toSearchRequest(otherCriteria, today));
};

/**
 * Today in the Salesforce user's time zone, which is the day the server reads dates in,
 * so "Today" means the same day on both sides even when the browser sits elsewhere.
 *
 * @returns {string} the day as YYYY-MM-DD
 */
const resolveToday = () => {
    const now = new Date();

    try {
        const parts = new Intl.DateTimeFormat('en-US', { timeZone: TIME_ZONE, year: 'numeric', month: '2-digit', day: '2-digit' }).formatToParts(now);
        const partValue = (type) => parts.find((part) => part.type === type)?.value;
        return `${partValue('year')}-${partValue('month')}-${partValue('day')}`;
    } catch {
        return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
    }
};

export {
    SEARCH_FILTERS,
    DATE_PRESET,
    EMPTY_SEARCH_CRITERIA,
    normalizeSearchCriteria,
    isSearchFilterSet,
    hasSearchCriteria,
    describeSearchFilter,
    pickSearchFilterOption,
    setSearchDayRange,
    searchDayRangeOf,
    buildOwnerOptions,
    clearSearchFilter,
    toSearchRequest,
    isSameSearchRequest,
    resolveToday
};
