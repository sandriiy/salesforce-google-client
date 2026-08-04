import { formatDateAsDDMMYYYY_HHMM } from 'c/googleCloudUtils';

const MAX_FILE_EXPLORER_COLUMNS = 7;
const DEFAULT_FILE_EXPLORER_COLUMNS = 'title;isLinked;access;owner;lastModified';

const SERVER_SORTABLE_KEYS = new Set(['title', 'isLinked', 'owner', 'fileOwner', 'lastModified', 'createdDate']);

const FILE_EXPLORER_COLUMN_CATALOG = [
    {
        key: 'title',
        label: 'Title',
        fieldName: 'fileName',
        type: 'fileTitle',
        wrapText: true,
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
        type: 'text'
    },
    {
        key: 'access',
        label: 'Access',
        fieldName: 'accessLabel',
        type: 'text'
    },
    {
        key: 'owner',
        label: 'Created By',
        fieldName: 'createdByName',
        type: 'userLink',
        typeAttributes: {
            label: { fieldName: 'createdByName' },
            userId: { fieldName: 'createdById' }
        }
    },
    {
        key: 'fileOwner',
        label: 'Owner',
        fieldName: 'fileOwner',
        type: 'userLink',
        typeAttributes: {
            label: { fieldName: 'fileOwner' },
            userId: { fieldName: 'fileOwnerId' }
        }
    },
    {
        key: 'lastModified',
        label: 'Last Modified Date',
        fieldName: 'lastModifiedDisplay',
        type: 'text'
    },
    {
        key: 'createdDate',
        label: 'Created Date',
        fieldName: 'createdDateDisplay',
        type: 'text'
    },
    {
        key: 'type',
        label: 'Type',
        fieldName: 'type',
        type: 'text'
    },
    {
        key: 'size',
        label: 'Size',
        fieldName: 'size',
        type: 'text'
    },
    {
        key: 'summary',
        label: 'Summary',
        fieldName: 'summary',
        type: 'text',
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
                    type: column.dataType || 'text',
                    isCustom: true
                };
            }

            return null;
        })
        .filter(Boolean);
};

const buildDatatableColumns = (resolvedColumns) => {
    return buildEffectiveColumns(resolvedColumns).map((column) => {
        const columnDefinition = {
            label: column.label,
            fieldName: column.fieldName,
            type: column.type,
            sortable: SERVER_SORTABLE_KEYS.has(column.key)
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
        createdDateDisplay: formatDateAsDDMMYYYY_HHMM(file?.createdDate)
    };
};

const buildCustomColumnValues = (resolvedColumns, latestVersionRecord) => {
    const values = {};

    buildEffectiveColumns(resolvedColumns)
        .filter((column) => column.isCustom)
        .forEach((column) => {
            values[column.fieldName] = latestVersionRecord ? latestVersionRecord[column.fieldName] : undefined;
        });

    return values;
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

    const firstSortable = effectiveColumns.find((column) => column.fieldName !== 'fileName' && SERVER_SORTABLE_KEYS.has(column.key));
    return (firstSortable || { fieldName: 'lastModifiedDisplay' }).fieldName;
};

export {
    FILE_EXPLORER_COLUMN_OPTIONS,
    DEFAULT_FILE_EXPLORER_COLUMNS,
    MAX_FILE_EXPLORER_COLUMNS,
    buildDatatableColumns,
    buildStandardColumnValues,
    buildCustomColumnValues,
    resolveColumnLabel,
    resolveDefaultSortFieldName
};
