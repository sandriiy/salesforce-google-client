import downloadFile from '@salesforce/apex/GoogleCloudFilesController.downloadFile';
import downloadFileAs from '@salesforce/apex/GoogleCloudFilesController.downloadFileAs';
import downloadFilePartial from '@salesforce/apex/GoogleCloudFilesController.downloadLargeFilePartial';

import { resolveTransferLimits, formatFileSize } from 'c/googleCloudUtils';

const DEFAULT_THREADS = 4;
const ABORT_ERROR_NAME = 'GoogleCloudDownloadAbortError';
const BYTE_YIELD_INTERVAL = 65536;
const CRC_YIELD_INTERVAL = 1048576;
const BASE64_STRING_CHUNK_SIZE = 0x8000;
const WORKER_YIELD_INTERVAL = 8;
const OCTET_STREAM_MIME_TYPE = 'application/octet-stream';
const ZIP_MIME_TYPE = 'application/zip';
const ZIP = {
    LOCAL_FILE_HEADER_SIGNATURE: 0x04034b50,
    CENTRAL_DIRECTORY_SIGNATURE: 0x02014b50,
    END_OF_CENTRAL_DIRECTORY_SIGNATURE: 0x06054b50,
    LOCAL_FILE_HEADER_BYTES: 30,
    CENTRAL_DIRECTORY_HEADER_BYTES: 46,
    END_OF_CENTRAL_DIRECTORY_BYTES: 22,
    VERSION_NEEDED: 20,
    UTF8_NAMES_FLAG: 0x0800,
    STORED_COMPRESSION: 0,
    FIRST_DOS_YEAR: 1980
};
const UNSAFE_FILE_NAME_CHARACTERS = /[\\/:*?"<>|]/g;

export const MAX_BULK_DOWNLOAD_FILES = 100;
export const MAX_BULK_DOWNLOAD_BYTES = 512 * 1024 * 1024;
export const BULK_DOWNLOAD_NOTHING_SELECTED_MESSAGE = 'Select at least one file to download';
export const BULK_DOWNLOAD_TOO_MANY_FILES_MESSAGE = `Select up to ${MAX_BULK_DOWNLOAD_FILES} files at a time`;
export const BULK_DOWNLOAD_TOO_LARGE_MESSAGE = `The selected files add up to more than ${formatFileSize(MAX_BULK_DOWNLOAD_BYTES, 0)}. Select fewer files to download them together`;
export const BULK_DOWNLOAD_STOPPED_MESSAGE = 'The download was stopped. Nothing was saved';

export const createOperationControl = () => {
    return {
        isAborted: false
    };
};

export const abortOperation = (control) => {
    if (control) {
        control.isAborted = true;
    }
};

export const isOperationAbortedError = (error) => {
    return error?.name === ABORT_ERROR_NAME;
};

/**
 * Retrieves a file through a single server call.
 * By default it downloads in the browser, but callers can ask for Base64 or Blob
 * when the file needs to stay in memory for further processing.
 * 
 * @param {string} localGoogleFileVersionId
 * @param {object} options
 * @param {string} options.fileName - e.g., "report.pdf"
 * @param {string} [options.mimeType="application/octet-stream"]
 */
export async function download(localGoogleFileVersionId, options = {}) {
    const {
        fileName = 'download.bin',
        mimeType = OCTET_STREAM_MIME_TYPE,
        returnBase64 = false,
        returnBlob = false,
        control = null
    } = options;

    try {
        throwIfAborted(control);

        const b64 = await downloadFile({ localGoogleFileVersionId });

        return await finalizeDownload(b64, {
            fileName,
            mimeType,
            returnBase64,
            returnBlob,
            control
        });
    } catch (e) {
        if (isOperationAbortedError(e)) {
            throw e;
        }

        throw normalizeApexError(e);
    }
}

/**
 * Retrieves a converted/exported file through the Download As action.
 *
 * @param {string} localGoogleFileVersionId
 * @param {object} options
 * @param {string} options.exportMimeType
 * @param {string} options.fileName - e.g., "report.pdf"
 * @param {string} [options.mimeType="application/octet-stream"]
 */
export async function downloadAs(localGoogleFileVersionId, options = {}) {
    const {
        exportMimeType = null,
        fileName = 'download.bin',
        mimeType = OCTET_STREAM_MIME_TYPE,
        returnBase64 = false,
        returnBlob = false,
        control = null
    } = options;

    try {
        throwIfAborted(control);

        const b64 = await downloadFileAs({
            localGoogleFileVersionId,
            exportMimeType
        });

        return await finalizeDownload(b64, {
            fileName,
            mimeType,
            returnBase64,
            returnBlob,
            control
        });
    } catch (e) {
        if (isOperationAbortedError(e)) {
            throw e;
        }

        throw normalizeApexError(e);
    }
}

/**
 * Retrieves large files in chunks while preserving the same external behavior as download().
 * This keeps the utility usable for existing callers and also allows cooperative cancellation
 * between chunk requests.
 *
 * @param {string} localGoogleFileVersionId
 * @param {object} options
 * @param {number} options.size
 * @param {string} options.fileName
 * @param {string} [options.mimeType="application/octet-stream"]
 * @param {number} [options.chunkSize] - Defaults to what one request may carry in this org.
 * @param {number} [options.threads=DEFAULT_THREADS]
 * @param {function} [options.onError]
 * @param {function} [options.onProgress] - Receives the bytes assembled so far and the total after every chunk.
 */
export async function downloadInChunks(localGoogleFileVersionId, options = {}) {
    const {
        size,
        fileName = 'download.bin',
        mimeType = OCTET_STREAM_MIME_TYPE,
        chunkSize,
        threads = DEFAULT_THREADS,
        onError = () => {},
        onProgress = () => {},
        returnBase64 = false,
        returnBlob = false,
        control = null
    } = options;

    if (!Number.isFinite(size) || size <= 0) {
        const err = new Error('downloadInChunks: "size" (total bytes) is required and must be > 0.');
        onError(err);
        throw err;
    }

    const resolvedChunkSize = chunkSize || (await resolveTransferLimits()).downloadChunkBytes;
    const ranges = [];
    for (let start = 0; start < size; start += resolvedChunkSize) {
        const endExclusive = Math.min(start + resolvedChunkSize, size);
        ranges.push({ start, end: endExclusive - 1 });
    }

    let assembledBuffer = new ArrayBuffer(size);
    let assembledBytes = new Uint8Array(assembledBuffer);
    let loadedBytes = 0;

    try {
        let nextIndex = 0;
        const worker = async () => {
            while (true) {
                throwIfAborted(control);

                const i = nextIndex++;
                if (i >= ranges.length) return;

                const { start, end } = ranges[i];

                try {
                    const b64 = await downloadFilePartial({
                        localGoogleFileVersionId,
                        startByte: start,
                        endByte: end
                    });

                    throwIfAborted(control);

                    const chunkBytes = await base64ToUint8Array(b64, control);

                    const expectedLength = end - start + 1;
                    if (chunkBytes.length !== expectedLength) {
                        throw new Error(
                            `Chunk length mismatch at [${start}-${end}]: expected ${expectedLength}, got ${chunkBytes.length}`
                        );
                    }

                    assembledBytes.set(chunkBytes, start);
                    loadedBytes += chunkBytes.length;
                    onProgress(loadedBytes, size);

                    if ((i + 1) % WORKER_YIELD_INTERVAL === 0) {
                        await yieldToMainThread();
                    }
                } catch (e) {
                    if (isOperationAbortedError(e)) {
                        throw e;
                    }

                    onError(normalizeApexError(e));
                    throw e;
                }
            }
        };

        const pool = Array.from({ length: Math.max(1, threads) }, () => worker());
        await Promise.all(pool);

        throwIfAborted(control);

        if (returnBase64) {
            return await uint8ArrayToBase64(assembledBytes, control);
        }

        const blob = new Blob([assembledBuffer], { type: resolveSafeMimeType(mimeType) });

        if (returnBlob) {
            return blob;
        }

        triggerDownload(blob, fileName);
    } finally {
        assembledBytes = null;
        assembledBuffer = null;
    }
}

/**
 * Says why a set of files cannot be downloaded together, or null when it can.
 * Hosts call it before starting so the refusal is shown instead of a failed download.
 *
 * @param {Array} files - rows shaped like formatExistingLocalFiles() produces (originalSize in bytes)
 */
export const resolveBulkDownloadRefusal = (files) => {
    if (!Array.isArray(files) || files.length === 0) {
        return BULK_DOWNLOAD_NOTHING_SELECTED_MESSAGE;
    }

    if (files.length > MAX_BULK_DOWNLOAD_FILES) {
        return BULK_DOWNLOAD_TOO_MANY_FILES_MESSAGE;
    }

    if (sumFileSizes(files) > MAX_BULK_DOWNLOAD_BYTES) {
        return BULK_DOWNLOAD_TOO_LARGE_MESSAGE;
    }

    return null;
};

/**
 * Downloads several files one after another and saves them as a single ZIP archive.
 * Each file goes through download() or downloadInChunks() exactly as a single download would,
 * so access is checked per file on the server. A file that fails is left out and reported;
 * the archive is still saved with the rest. Stopping through the control throws the abort
 * error before anything is saved.
 *
 * @param {Array} files - rows shaped like formatExistingLocalFiles() produces
 *                        (id = version Id, name, originalSize, originalType, lastModifiedDate)
 * @param {object} options
 * @param {string|function} options.zipName - e.g., "Acme - 3 files.zip", or a function of the number
 *                                            of files the archive ends up holding
 * @param {function} [options.onProgress] - Receives { current, total, fileName, percent, statusText }
 * @param {object} [options.control] - From createOperationControl(), aborted with abortOperation()
 * @param {number} [options.threads=DEFAULT_THREADS]
 * @returns {Promise<{downloaded: Array, failed: Array<{file: object, error: Error}>}>}
 */
export async function downloadMany(files, options = {}) {
    const {
        zipName = 'files.zip',
        onProgress = () => {},
        control = null,
        threads = DEFAULT_THREADS
    } = options;

    const refusal = resolveBulkDownloadRefusal(files);
    if (refusal) {
        throw new Error(refusal);
    }

    const transferLimits = await resolveTransferLimits();
    const totalBytes = sumFileSizes(files);
    const entries = [];
    const downloaded = [];
    const failed = [];
    let completedBytes = 0;

    const report = (index, file, loadedBytes) => {
        onProgress({
            current: index + 1,
            total: files.length,
            fileName: file.name,
            percent: resolveBulkPercent(completedBytes + loadedBytes, totalBytes, index, files.length)
        });
    };

    for (let index = 0; index < files.length; index++) {
        const file = files[index];
        const size = Number(file.originalSize) || 0;

        throwIfAborted(control);
        report(index, file, 0);

        if (size <= 0) {
            failed.push({ file, error: new Error('The file has no content to download') });
            continue;
        }

        try {
            const blob = size <= transferLimits.downloadChunkBytes
                ? await download(file.id, {
                    fileName: file.name,
                    mimeType: file.originalType,
                    returnBlob: true,
                    control
                })
                : await downloadInChunks(file.id, {
                    size,
                    fileName: file.name,
                    mimeType: file.originalType,
                    returnBlob: true,
                    control,
                    threads,
                    onProgress: (loadedBytes) => report(index, file, loadedBytes)
                });

            entries.push({ name: file.name, blob, lastModified: file.lastModifiedDate });
            downloaded.push(file);
        } catch (error) {
            if (isOperationAbortedError(error)) {
                throw error;
            }

            failed.push({ file, error });
        }

        completedBytes += size;
    }

    throwIfAborted(control);

    if (entries.length > 0) {
        const archiveName = typeof zipName === 'function' ? zipName(entries.length) : zipName;

        onProgress({
            current: files.length,
            total: files.length,
            fileName: archiveName,
            percent: 100,
            statusText: `Preparing ${archiveName}`
        });

        const archive = await buildZipArchive(entries, control);

        throwIfAborted(control);
        triggerDownload(archive, archiveName);
    }

    return { downloaded, failed };
}

const sumFileSizes = (files) => {
    return files.reduce((total, file) => total + (Number(file.originalSize) || 0), 0);
};

const resolveBulkPercent = (bytesDone, totalBytes, fileIndex, fileCount) => {
    if (totalBytes > 0) {
        return Math.min(100, Math.round((bytesDone / totalBytes) * 100));
    }

    return fileCount > 0 ? Math.round((fileIndex / fileCount) * 100) : 0;
};

const buildZipArchive = async (entries, control) => {
    const localParts = [];
    const centralParts = [];
    const usedNames = new Set();
    const encoder = new TextEncoder();
    let offset = 0;

    for (const entry of entries) {
        throwIfAborted(control);

        const bytes = new Uint8Array(await entry.blob.arrayBuffer());
        const nameBytes = encoder.encode(uniqueZipEntryName(entry.name, usedNames));
        const crc = await crc32(bytes, control);
        const { date, time } = toDosDateTime(entry.lastModified);

        const localHeader = new DataView(new ArrayBuffer(ZIP.LOCAL_FILE_HEADER_BYTES));
        localHeader.setUint32(0, ZIP.LOCAL_FILE_HEADER_SIGNATURE, true);
        localHeader.setUint16(4, ZIP.VERSION_NEEDED, true);
        localHeader.setUint16(6, ZIP.UTF8_NAMES_FLAG, true);
        localHeader.setUint16(8, ZIP.STORED_COMPRESSION, true);
        localHeader.setUint16(10, time, true);
        localHeader.setUint16(12, date, true);
        localHeader.setUint32(14, crc, true);
        localHeader.setUint32(18, bytes.length, true);
        localHeader.setUint32(22, bytes.length, true);
        localHeader.setUint16(26, nameBytes.length, true);
        localHeader.setUint16(28, 0, true);
        localParts.push(localHeader.buffer, nameBytes, bytes);

        const centralHeader = new DataView(new ArrayBuffer(ZIP.CENTRAL_DIRECTORY_HEADER_BYTES));
        centralHeader.setUint32(0, ZIP.CENTRAL_DIRECTORY_SIGNATURE, true);
        centralHeader.setUint16(4, ZIP.VERSION_NEEDED, true);
        centralHeader.setUint16(6, ZIP.VERSION_NEEDED, true);
        centralHeader.setUint16(8, ZIP.UTF8_NAMES_FLAG, true);
        centralHeader.setUint16(10, ZIP.STORED_COMPRESSION, true);
        centralHeader.setUint16(12, time, true);
        centralHeader.setUint16(14, date, true);
        centralHeader.setUint32(16, crc, true);
        centralHeader.setUint32(20, bytes.length, true);
        centralHeader.setUint32(24, bytes.length, true);
        centralHeader.setUint16(28, nameBytes.length, true);
        centralHeader.setUint16(30, 0, true);
        centralHeader.setUint16(32, 0, true);
        centralHeader.setUint16(34, 0, true);
        centralHeader.setUint16(36, 0, true);
        centralHeader.setUint32(38, 0, true);
        centralHeader.setUint32(42, offset, true);
        centralParts.push(centralHeader.buffer, nameBytes);

        offset += ZIP.LOCAL_FILE_HEADER_BYTES + nameBytes.length + bytes.length;
    }

    const centralDirectoryBytes = centralParts.reduce((total, part) => total + part.byteLength, 0);
    const endRecord = new DataView(new ArrayBuffer(ZIP.END_OF_CENTRAL_DIRECTORY_BYTES));
    endRecord.setUint32(0, ZIP.END_OF_CENTRAL_DIRECTORY_SIGNATURE, true);
    endRecord.setUint16(4, 0, true);
    endRecord.setUint16(6, 0, true);
    endRecord.setUint16(8, entries.length, true);
    endRecord.setUint16(10, entries.length, true);
    endRecord.setUint32(12, centralDirectoryBytes, true);
    endRecord.setUint32(16, offset, true);
    endRecord.setUint16(20, 0, true);

    return new Blob([...localParts, ...centralParts, endRecord.buffer], { type: ZIP_MIME_TYPE });
};

let crcTable;

const resolveCrcTable = () => {
    if (!crcTable) {
        crcTable = new Uint32Array(256);

        for (let n = 0; n < 256; n++) {
            let c = n;
            for (let k = 0; k < 8; k++) {
                c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
            }
            crcTable[n] = c >>> 0;
        }
    }

    return crcTable;
};

const crc32 = async (bytes, control) => {
    const table = resolveCrcTable();
    let crc = 0xFFFFFFFF;

    for (let i = 0; i < bytes.length; i++) {
        crc = table[(crc ^ bytes[i]) & 0xFF] ^ (crc >>> 8);

        if (i > 0 && i % CRC_YIELD_INTERVAL === 0) {
            throwIfAborted(control);
            await yieldToMainThread();
        }
    }

    return (crc ^ 0xFFFFFFFF) >>> 0;
};

const toDosDateTime = (value) => {
    const parsed = value ? new Date(value) : new Date();
    const date = Number.isNaN(parsed.getTime()) ? new Date() : parsed;
    const year = Math.max(ZIP.FIRST_DOS_YEAR, date.getFullYear());

    return {
        date: ((year - ZIP.FIRST_DOS_YEAR) << 9) | ((date.getMonth() + 1) << 5) | date.getDate(),
        time: (date.getHours() << 11) | (date.getMinutes() << 5) | (date.getSeconds() >> 1)
    };
};

const uniqueZipEntryName = (fileName, usedNames) => {
    const safeName = String(fileName || '').replace(UNSAFE_FILE_NAME_CHARACTERS, '_').trim() || 'download.bin';
    let candidate = safeName;
    let counter = 2;

    while (usedNames.has(candidate.toLowerCase())) {
        candidate = appendNameSuffix(safeName, ` (${counter})`);
        counter++;
    }

    usedNames.add(candidate.toLowerCase());
    return candidate;
};

const appendNameSuffix = (fileName, suffix) => {
    const separator = fileName.lastIndexOf('.');
    if (separator <= 0) {
        return `${fileName}${suffix}`;
    }

    return `${fileName.slice(0, separator)}${suffix}${fileName.slice(separator)}`;
};

const base64ToBlob = async (base64, mimeType, control) => {
    const bytes = await base64ToUint8Array(base64, control);
    return new Blob([bytes], { type: mimeType });
};

const finalizeDownload = async (base64Body, options = {}) => {
    const {
        fileName = 'download.bin',
        mimeType = OCTET_STREAM_MIME_TYPE,
        returnBase64 = false,
        returnBlob = false,
        control = null
    } = options;

    if (returnBase64) {
        return base64Body;
    }

    throwIfAborted(control);
    const blob = await base64ToBlob(base64Body, resolveSafeMimeType(mimeType), control);

    if (returnBlob) {
        return blob;
    }

    throwIfAborted(control);
    triggerDownload(blob, fileName);
};

const base64ToUint8Array = async (base64, control) => {
	const binary = atob(base64);

    const bytes = new Uint8Array(binary.length);

    for (let i = 0; i < binary.length; i++) {
        throwIfAborted(control);
        bytes[i] = binary.charCodeAt(i) & 0xff;

        if (i > 0 && i % BYTE_YIELD_INTERVAL === 0) {
            await yieldToMainThread();
        }
    }

    return bytes;
};

const uint8ArrayToBase64 = async (bytes, control) => {
    const parts = [];

    for (let index = 0; index < bytes.length; index += BASE64_STRING_CHUNK_SIZE) {
        throwIfAborted(control);

        const chunk = bytes.subarray(index, index + BASE64_STRING_CHUNK_SIZE);
        parts.push(String.fromCharCode(...chunk));

        if (index > 0 && Math.floor(index / BASE64_STRING_CHUNK_SIZE) % WORKER_YIELD_INTERVAL === 0) {
            await yieldToMainThread();
        }
    }

    throwIfAborted(control);

    return btoa(parts.join(''));
};

const triggerDownload = (blob, fileName) => {
    const url = createDownloadObjectUrl(blob);

    try {
        const a = document.createElement('a');
        a.href = url;
        a.download = fileName || 'download.bin';
        document.body.appendChild(a);
        a.click();

        a.remove();
    } finally {
        setTimeout(() => URL.revokeObjectURL(url), 0);
    }
};

const createDownloadObjectUrl = (blob) => {
    try {
        return URL.createObjectURL(blob);
    } catch (error) {
        if (!isUnsupportedMimeTypeError(error) || blob?.type === OCTET_STREAM_MIME_TYPE) {
            throw error;
        }

        const fallbackBlob = typeof blob?.slice === 'function'
            ? blob.slice(0, blob.size, OCTET_STREAM_MIME_TYPE)
            : new Blob([blob], { type: OCTET_STREAM_MIME_TYPE });

        return URL.createObjectURL(fallbackBlob);
    }
};

const normalizeApexError = (e) => {
    if (e && typeof e === 'object') {
        const message =
            e.body?.message ||
            e.body?.exceptionType ||
            e.message ||
            JSON.stringify(e);
        return new Error(message);
    }

    return new Error(String(e));
};

const isUnsupportedMimeTypeError = (error) => {
    return /unsupported mime type/i.test(error?.message || '');
};

const resolveSafeMimeType = (mimeType) => {
    const rawType = mimeType || OCTET_STREAM_MIME_TYPE;
    const baseType = rawType.split(';')[0].trim().toLowerCase();

    const isAllowed =
        baseType === OCTET_STREAM_MIME_TYPE ||
        baseType === 'application/json' ||
        baseType === 'application/pdf' ||
        baseType === 'application/zip' ||
        baseType === 'application/x-bzip' ||
        baseType === 'application/x-rar-compressed' ||
        baseType === 'application/x-tar' ||
        baseType === 'text/plain' ||
        baseType === 'text/markdown' ||
        baseType === 'text/html' ||
        baseType === 'text/xml' ||
        baseType === 'image/svg+xml' ||
        baseType.startsWith('image/') ||
        baseType.startsWith('audio/') ||
        baseType.startsWith('video/') ||
        baseType.startsWith('font/');

    return isAllowed ? baseType : OCTET_STREAM_MIME_TYPE;
};

const throwIfAborted = (control) => {
    if (control?.isAborted) {
        const error = new Error('Operation aborted');
        error.name = ABORT_ERROR_NAME;
        throw error;
    }
};

const yieldToMainThread = () => {
    return new Promise((resolve) => {
        setTimeout(resolve, 0);
    });
};