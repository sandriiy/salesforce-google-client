import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export const DEFAULT_FILE_UPLOAD_FAILURE = 'Verify that the file is not corrupted, then try again. If the problem continues, please reach out to your System Administrator';
export const DEFAULT_FILE_NOT_ALLOWED_MESSAGE = 'Some files don’t meet the allowed type or size, please check and retry';
export const DEFAULT_FAILED_RETRIEVE_MESSAGE = 'Unable to load files. Please refresh the page or contact your administrator';
export const DEFAULT_FAILED_DOWNLOAD_MESSAGE = 'Unable to download the file. Please try again later or contact your system administrator';
export const DEFAULT_ACCESS_RESTRICTED_MESSAGE = 'You can\’t perform this action on this file. Try another file or contact the file owner';
export const DEFAULT_PREVIEW_UNAVAILABILITY_MESSAGE = 'Preview unavailable. Try downloading instead';
export const GENERIC_ERROR_MESSAGE = 'Something went wrong. Please try again later or contact your system administrator';
export const DEFAULT_FILE_ICON_TYPE = 'doctype:unknown';
export const DEFAULT_FILE_NAME = 'Untitled';

export const FILE_ICON_MAP = {
    doc:  'doctype:word',
    docx: 'doctype:word',
    pdf:  'doctype:pdf',
    txt:  'doctype:txt',
    rtf:  'doctype:rtf',
    xls:  'doctype:excel',
    xlsx: 'doctype:excel',
    csv:  'doctype:csv',
    ppt:  'doctype:ppt',
    pptx: 'doctype:ppt',
    key:  'doctype:keynote',
    pages:'doctype:pages',
    html: 'doctype:html',
    xml:  'doctype:xml',
    js:   'doctype:html',
    json: 'doctype:html',
    css:  'doctype:css',
    jpg:  'doctype:image',
    jpeg: 'doctype:image',
    png:  'doctype:image',
    gif:  'doctype:image',
    bmp:  'doctype:image',
    tiff: 'doctype:image',
    svg:  'doctype:image',
    mp3:  'doctype:audio',
    wav:  'doctype:audio',
    ogg:  'doctype:audio',
    mp4:  'doctype:mp4',
    mov:  'doctype:video',
    avi:  'doctype:video',
    mpeg: 'doctype:video',
    zip:  'doctype:zip',
    rar:  'doctype:zip',
    exe:  'doctype:exe',
    ai:   'doctype:ai',
    psd:  'doctype:psd',
    visio:'doctype:visio',
    gsheet: 'doctype:gsheet',
    gdoc:   'doctype:gdoc',
    gpres:  'doctype:gpres',
    unknown: DEFAULT_FILE_ICON_TYPE
};


const showToast = (context, title, message, variant = 'info', mode = 'dismissable') => {
    context.dispatchEvent(new ShowToastEvent({
        title,
        message,
        variant,
        mode
    }));
};

const isEmpty = (value) => {
    return value === null || value === undefined || value === '' || (Array.isArray(value) && value.length === 0);
};

const generateId = (length = 8) => {
    return Array.from(crypto.getRandomValues(new Uint8Array(length)))
        .map(b => b.toString(36))
        .join('')
        .slice(0, length);
}

const formatFileSize = (bytes, decimals = 1) => {
    if (bytes === 0 || isNaN(bytes)) return '0 B';

    const k = 1024;
    const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));

    const value = bytes / Math.pow(k, i);
    const fixed = value.toFixed(decimals);

    const clean = fixed.replace(/\.0+$|(\.\d*[1-9])0+$/, '$1');
    return `${clean} ${units[i]}`;
}

const formatExistingLocalFiles = (localGoogleFiles) => {
    let formattedFiles = [];

    localGoogleFiles.forEach(fileRecord => {
        let versions = fileRecord.GoogleFileVersions__r;
        if (!versions || versions.length === 0) {
            return;
        }

        const latestVersion = versions[0];
        formattedFiles.push({
            id: latestVersion.Id || '',
            localId: fileRecord.Id || '',
            name: latestVersion.Name || '',
			mode: fileRecord.UserAccessLevel__c || 'View',
            type: getFileType(latestVersion.Type__c) || '',
            size: latestVersion.Size__c
                ? formatFileSize(latestVersion.Size__c)
                : '',
            createdBy: latestVersion.CreatedBy
                ? { id: latestVersion.CreatedBy.Id, name: latestVersion.CreatedBy.Name }
                : '',
            originalType: latestVersion.Type__c,
			originalSize: latestVersion.Size__c,
            createdDate: latestVersion.CreatedDate,
            lastModifiedDate: latestVersion.LastModifiedDate,
            progress: undefined,
            icon: getFileIcon(latestVersion.Name || ''),
			isEditAccess: fileRecord.UserAccessLevel__c === 'Edit',
			isReadAccess: fileRecord.UserAccessLevel__c !== 'Edit',
        });
    });

    return formattedFiles;
}

const formatDateAsDayMonthYear = (dateValue) => {
    const date = new Date(dateValue);
    if (isNaN(date)) {
        return 'N/A';
    }

    const day = date.getDate();
    const monthNames = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const month = monthNames[date.getMonth()];
    const year = date.getFullYear();

    return `${day} ${month} ${year}`;
}

const formatDateAsDDMMYYYY_HHMM = (dateValue) => {
    const date = new Date(dateValue);
    if (isNaN(date)) {
        return 'N/A';
    }

    const pad = (num) => num.toString().padStart(2, '0');

    const day     = pad(date.getDate());
    const month   = pad(date.getMonth() + 1);
    const year    = date.getFullYear();
    const hours   = pad(date.getHours());
    const minutes = pad(date.getMinutes());

    return `${day}/${month}/${year}, ${hours}:${minutes}`;
};

const createNewFilePlaceholder = (inputFile) => {
    return {
        id: generateId(),
        localId: undefined,
        name: inputFile.name,
		mode: 'Edit',
        type: getFileType(inputFile.type),
		originalType: inputFile.type,
        originalSize: inputFile.size,
        size: formatFileSize(inputFile.size),
        createdDate: getLocalOffsetDateTime(),
        lastModifiedDate: getLocalOffsetDateTime(),
        progress: 0,
        icon: getFileIcon(inputFile.name),
    };
}

const getFileIcon = (fileName) => {
    const fileExtension = extractFileExtension(fileName);
    if (fileExtension && FILE_ICON_MAP[fileExtension]) {
        return FILE_ICON_MAP[fileExtension];
    } else {
        return DEFAULT_FILE_ICON_TYPE;
    }
}

const getFileType = (mimeType) => {
    if (!mimeType) return undefined;

    const match = mimeType.match(/\/([^;]+)$/);
    let type = match ? match[1].toLowerCase() : mimeType.toLowerCase();

    if (mimeType.includes('vnd.openxmlformats-officedocument.wordprocessingml.document')) return 'msword';
    if (mimeType.includes('vnd.openxmlformats-officedocument.spreadsheetml.sheet')) return 'excel';
    if (mimeType.includes('vnd.openxmlformats-officedocument.presentationml.presentation')) return 'powerpoint';
    if (mimeType.includes('vnd.oasis.opendocument.presentation')) return 'presentation';
    if (mimeType.includes('vnd.oasis.opendocument.spreadsheet')) return 'spreadsheet';
    if (mimeType.includes('vnd.oasis.opendocument.text')) return 'text';
	if (mimeType.includes('vnd.ms-powerpoint')) return 'powerpoint';

    return type;
};

const extractFileExtension = (fileName) => {
    return fileName.split('.').pop().toLowerCase();
}

const getLocalOffsetDateTime = () => {
    const pad = (n, width = 2) => String(n).padStart(width, '0');
    const d = new Date();
    const yyyy = d.getFullYear();
    const MM   = pad(d.getMonth() + 1);
    const dd   = pad(d.getDate());
    const hh   = pad(d.getHours());
    const mm   = pad(d.getMinutes());
    const ss   = pad(d.getSeconds());
    const mmm  = pad(d.getMilliseconds(), 3);

    const offsetMin = -d.getTimezoneOffset();
    const sign = offsetMin >= 0 ? '+' : '-';
    const absMin = Math.abs(offsetMin);
    const offHH = pad(Math.floor(absMin / 60));
    const offMM = pad(absMin % 60);

    return `${yyyy}-${MM}-${dd}T${hh}:${mm}:${ss}.${mmm}${sign}${offHH}${offMM}`;
}

const normalizeAllowedTypes = (fileTypes) => {
	if (isEmpty(fileTypes) || fileTypes.trim() === '*') {
		return '*/*';
	}

	return fileTypes
		.split(',')
		.map(type => type.trim().toLowerCase())
		.filter(Boolean)
		.map(ext => (ext.startsWith('.') ? ext : `.${ext}`))
		.join(',');
}

const normalizeError = (input) => {
	try {
		let messages = [];

		const pickFromOne = (one) => {
			if (typeof one === 'string') return [one];

			if (one && typeof one === 'object') {
				if (Array.isArray(one.body)) {
				return one.body
					.map((e) => (e && typeof e === 'object' && typeof e.message === 'string' ? e.message : ''))
					.filter(Boolean);
				}

				if (one.body && typeof one.body === 'object' && typeof one.body.message === 'string') {
					return [one.body.message];
				}
			}

			return [];
		};

		if (Array.isArray(input)) {
			input.forEach((it) => (messages = messages.concat(pickFromOne(it))));
		} else if (typeof input === 'string') {
			messages = [input];
		} else {
			messages = pickFromOne(input);
		}

		const unique = Array.from(new Set(messages.map((m) => (m || '').trim()).filter(Boolean)));
		if (unique.length !== 1) return GENERIC_ERROR_MESSAGE;

		let msg = unique[0];
		msg = msg.replace(/^[A-Z0-9_]{3,}\s*:\s*/g, '');
		msg = msg.replace(/\s*\(([A-Z0-9_]{3,})\)\s*$/g, '');
		msg = msg.replace(
			/No such column\s+'([^']+)'\s+on entity\s+'([^']+)'/i,
			(m, col, obj) => `Field "${col}" isn’t available on "${obj}".`
		);
		msg = msg
			.replace(/\b([A-Za-z0-9_]+)__(?:c|r)\b/g, (_, base) => base)
			.replace(/_/g, ' ')
			.replace(/\s{2,}/g, ' ')
			.trim();

		if (msg && msg[0] === msg[0].toLowerCase()) {
			msg = msg.charAt(0).toUpperCase() + msg.slice(1);
		}

		return msg || GENERIC_ERROR_MESSAGE;
	} catch {
		return GENERIC_ERROR_MESSAGE;
	}
}

const findIconForRecordType = (sobjectType) => {
	switch (sobjectType) {
		case 'Account': return 'standard:account';
		case 'Contact': return 'standard:contact';
		case 'Opportunity': return 'standard:opportunity';
		case 'Case': return 'standard:case';
		default: return 'standard:record';
	}
};

const findRoleForAccessType = (access) => {
	if (access === 'All' || access === 'Owner') return 'Owner';
	if (access === 'Collaborator' || access === 'Edit') return 'Collaborator';
	if (access === 'InferredFromRecord') return 'InferredFromRecord';
	return 'Viewer';
};

export { showToast, isEmpty, normalizeError, normalizeAllowedTypes, generateId, formatFileSize, formatExistingLocalFiles, getLocalOffsetDateTime, formatDateAsDayMonthYear, formatDateAsDDMMYYYY_HHMM, createNewFilePlaceholder, getFileIcon, getFileType, extractFileExtension, findIconForRecordType, findRoleForAccessType };