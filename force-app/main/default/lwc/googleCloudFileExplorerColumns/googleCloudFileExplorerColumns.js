import { formatDateAsDDMMYYYY_HHMM } from 'c/googleCloudUtils';

const MAX_FILE_EXPLORER_COLUMNS = 7;
const DEFAULT_FILE_EXPLORER_COLUMNS = 'title;isLinked;access;owner;lastModified';

const SERVER_SORTABLE_KEYS = new Set(['title', 'isLinked', 'owner', 'fileOwner', 'lastModified', 'createdDate']);

const FILE_EXPLORER_COLUMN_CATALOG = [
    {
        key: 'title',
        label: 'Title',
        fieldName: 'fileName',
        sortFieldName: 'nameSort',
        type: 'fileTitle',
        sortable: true,
        wrapText: true,
        isRequired: true,
        typeAttributes: {
            label: { fieldName: 'fileName' },
            title: { fieldName: 'fileName' },
            rowId: { fieldName: 'localId' }
        },
        cellAttributes: {
            alignment: 'left'
        }
    },
    {
        key: 'isLinked',
        label: 'Is Linked?',
        fieldName: 'isLinkedLabel',
        sortFieldName: 'isLinkedSort',
        type: 'text',
        sortable: true
    },
    {
        key: 'access',
        label: 'Access',
        fieldName: 'accessLabel',
        sortFieldName: 'accessSort',
        type: 'text',
        sortable: true
    },
    {
        key: 'owner',
        label: 'Created By',
        fieldName: 'ownerName',
        sortFieldName: 'ownerNameSort',
        type: 'userLink',
        sortable: true,
        typeAttributes: {
            label: { fieldName: 'ownerName' },
            userId: { fieldName: 'ownerId' }
        }
    },
    {
        key: 'fileOwner',
        label: 'Owner',
        fieldName: 'fileOwner',
        sortFieldName: 'fileOwnerSort',
        type: 'userLink',
        sortable: true,
        typeAttributes: {
            label: { fieldName: 'fileOwner' },
            userId: { fieldName: 'fileOwnerId' }
        }
    },
    {
        key: 'lastModified',
        label: 'Last Modified Date',
        fieldName: 'lastModifiedDisplay',
        sortFieldName: 'lastModifiedSort',
        type: 'text',
        sortable: true
    },
    {
        key: 'createdDate',
        label: 'Created Date',
        fieldName: 'createdDateDisplay',
        sortFieldName: 'createdDateSort',
        type: 'text',
        sortable: true
    },
    {
        key: 'type',
        label: 'Type',
        fieldName: 'type',
        sortFieldName: 'typeSort',
        type: 'text',
        sortable: true
    },
    {
        key: 'size',
        label: 'Size',
        fieldName: 'size',
        sortFieldName: 'sizeSort',
        type: 'text',
        sortable: true
    },
    {
        key: 'summary',
        label: 'Summary',
        fieldName: 'summary',
        sortFieldName: 'summarySort',
        type: 'text',
        sortable: true,
        wrapText: true
    }
];

const CATALOG_BY_KEY = FILE_EXPLORER_COLUMN_CATALOG.reduce((map, column) => {
    map[column.key] = column;
    return map;
}, {});

const FILE_EXPLORER_COLUMN_OPTIONS = FILE_EXPLORER_COLUMN_CATALOG.map((column) => ({
    label: column.label,
    value: column.key
}));

const toTimestamp = (value) => {
    const time = new Date(value).getTime();
    return Number.isNaN(time) ? 0 : time;
};

const buildEffectiveColumns = (resolvedColumns) => {
    const columns = Array.isArray(resolvedColumns) ? resolvedColumns : [];

    return columns
        .map((column) => {
            if (!column?.isCustomField && CATALOG_BY_KEY[column?.key]) {
                return CATALOG_BY_KEY[column.key];
            }

            if (column?.isCustomField) {
                return {
                    key: column.key,
                    label: column.label || column.key,
                    fieldName: column.key,
                    sortFieldName: `${column.key}Sort`,
                    type: column.dataType || 'text',
                    sortable: true,
                    isCustom: true
                };
            }

            return null;
        })
        .filter(Boolean);
};

const buildDatatableColumns = (resolvedColumns, isPrivileged = false) => {
    return buildEffectiveColumns(resolvedColumns).map((column) => {
        const serverSortable = SERVER_SORTABLE_KEYS.has(column.key);
        const columnDefinition = {
            label: column.label,
            fieldName: column.fieldName,
            type: column.type,
            sortable: isPrivileged ? serverSortable : column.sortable !== false
        };

        if (column.wrapText) {
            columnDefinition.wrapText = true;
        }

        if (column.typeAttributes) {
            columnDefinition.typeAttributes = column.typeAttributes;
        }

        if (column.cellAttributes) {
            columnDefinition.cellAttributes = column.cellAttributes;
        }

        return columnDefinition;
    });
};

const buildStandardColumnValues = (file) => {
    return {
        typeSort: (file?.type || '').toLowerCase(),
        sizeSort: Number(file?.originalSize || 0),
        createdDateDisplay: formatDateAsDDMMYYYY_HHMM(file?.createdDate),
        createdDateSort: toTimestamp(file?.createdDate),
        summarySort: (file?.summary || '').toLowerCase()
    };
};

const buildCustomColumnValues = (resolvedColumns, latestVersionRecord) => {
    const values = {};

    buildEffectiveColumns(resolvedColumns)
        .filter((column) => column.isCustom)
        .forEach((column) => {
            const rawValue = latestVersionRecord ? latestVersionRecord[column.fieldName] : undefined;
            values[column.fieldName] = rawValue;
            values[column.sortFieldName] = normalizeSortValue(rawValue, column.type);
        });

    return values;
};

const normalizeSortValue = (rawValue, dataType) => {
    if (rawValue === null || rawValue === undefined) {
        return dataType === 'number' || dataType === 'date' ? 0 : '';
    }

    if (dataType === 'date') {
        return toTimestamp(rawValue);
    }

    if (dataType === 'number') {
        return Number(rawValue) || 0;
    }

    return String(rawValue).toLowerCase();
};

const resolveSortField = (resolvedColumns, fieldName) => {
    const match = buildEffectiveColumns(resolvedColumns).find((column) => column.fieldName === fieldName);
    return match ? match.sortFieldName : fieldName;
};

const resolveColumnLabel = (resolvedColumns, fieldName) => {
    const match = buildEffectiveColumns(resolvedColumns).find((column) => column.fieldName === fieldName);
    return match ? match.label : '';
};

const resolveDefaultSortFieldName = (resolvedColumns) => {
    const effectiveColumns = buildEffectiveColumns(resolvedColumns);
    const lastModified = effectiveColumns.find((column) => column.fieldName === 'lastModifiedDisplay');
    if (lastModified) {
        return lastModified.fieldName;
    }

    const firstNonTitle = effectiveColumns.find((column) => column.fieldName !== 'fileName');
    return (firstNonTitle || effectiveColumns[0] || { fieldName: 'lastModifiedDisplay' }).fieldName;
};

export {
    FILE_EXPLORER_COLUMN_CATALOG,
    FILE_EXPLORER_COLUMN_OPTIONS,
    DEFAULT_FILE_EXPLORER_COLUMNS,
    MAX_FILE_EXPLORER_COLUMNS,
    SERVER_SORTABLE_KEYS,
    buildDatatableColumns,
    buildStandardColumnValues,
    buildCustomColumnValues,
    resolveSortField,
    resolveColumnLabel,
    resolveDefaultSortFieldName
};
