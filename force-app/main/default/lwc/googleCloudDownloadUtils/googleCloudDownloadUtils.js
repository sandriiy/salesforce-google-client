import downloadFile from '@salesforce/apex/GoogleCloudFilesController.downloadFile';
import downloadFilePartial from '@salesforce/apex/GoogleCloudFilesController.downloadLargeFilePartial';

export const BIG_FILE_SIZE = 2 * 1024 * 1024; // 2 MB
const DEFAULT_CHUNK_SIZE = 2 * 1024 * 1024; // 2 MB
const DEFAULT_THREADS = 4;
const ABORT_ERROR_NAME = 'GoogleCloudDownloadAbortError';
const BYTE_YIELD_INTERVAL = 65536;
const BASE64_STRING_CHUNK_SIZE = 0x8000;
const WORKER_YIELD_INTERVAL = 8;

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
        mimeType = 'application/octet-stream',
        returnBase64 = false,
        returnBlob = false,
        control = null
    } = options;

    try {
        throwIfAborted(control);

        const b64 = await downloadFile({ localGoogleFileVersionId });
		if (returnBase64) return b64;
        
        throwIfAborted(control);
        const blob = await base64ToBlob(b64, resolveSafeMimeType(mimeType), control);
		if (returnBlob) return blob;

        throwIfAborted(control);
        triggerDownload(blob, fileName);
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
 * @param {number} [options.chunkSize=DEFAULT_CHUNK_SIZE]
 * @param {number} [options.threads=DEFAULT_THREADS]
 * @param {function} [options.onError]
 */
export async function downloadInChunks(localGoogleFileVersionId, options = {}) {
    const {
        size,
        fileName = 'download.bin',
        mimeType = 'application/octet-stream',
        chunkSize = DEFAULT_CHUNK_SIZE,
        threads = DEFAULT_THREADS,
        onError = () => {},
        returnBase64 = false,
        returnBlob = false,
        control = null
    } = options;

    if (!Number.isFinite(size) || size <= 0) {
        const err = new Error('downloadInChunks: "size" (total bytes) is required and must be > 0.');
        onError(err);
        throw err;
    }

    const ranges = [];
    for (let start = 0; start < size; start += chunkSize) {
        const endExclusive = Math.min(start + chunkSize, size);
        ranges.push({ start, end: endExclusive - 1 });
    }

    let assembledBuffer = new ArrayBuffer(size);
    let assembledBytes = new Uint8Array(assembledBuffer);

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

const base64ToBlob = async (base64, mimeType, control) => {
    const bytes = await base64ToUint8Array(base64, control);
    return new Blob([bytes], { type: mimeType });
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
    const url = URL.createObjectURL(blob);
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

const resolveSafeMimeType = (mimeType) => {
    const rawType = mimeType || 'application/octet-stream';
    const baseType = rawType.split(';')[0].trim().toLowerCase();

    const isAllowed =
        baseType === 'application/octet-stream' ||
        baseType === 'application/json' ||
        baseType === 'application/pdf' ||
        baseType === 'application/zip' ||
        baseType === 'application/x-bzip' ||
        baseType === 'text/plain' ||
        baseType === 'text/markdown' ||
        baseType === 'text/html' ||
        baseType === 'text/xml' ||
        baseType === 'image/svg+xml' ||
        baseType.startsWith('image/') ||
        baseType.startsWith('audio/') ||
        baseType.startsWith('video/') ||
        baseType.startsWith('font/');

    return isAllowed ? baseType : 'application/octet-stream';
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