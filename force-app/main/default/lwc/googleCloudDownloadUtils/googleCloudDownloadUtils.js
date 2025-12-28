import downloadFile from '@salesforce/apex/GoogleCloudFilesController.downloadFile';
import downloadFilePartial from '@salesforce/apex/GoogleCloudFilesController.downloadLargeFilePartial';

export const BIG_FILE_SIZE = 2 * 1024 * 1024; // 2 MB
const DEFAULT_CHUNK_SIZE = 2 * 1024 * 1024; // 2 MB
const DEFAULT_THREADS = 4;

/**
 * Full download in one Apex call. Decodes Base64 and triggers a browser download.
 * No return value on success.
 * 
 * @param {string} localGoogleFileVersionId
 * @param {object} options
 * @param {string} options.fileName - e.g., "report.pdf"
 * @param {string} [options.mimeType="application/octet-stream"]
 */
export async function download(localGoogleFileVersionId, options = {}) {
    const { fileName = 'download.bin', mimeType = 'application/octet-stream' } = options;

    try {
        const b64 = await downloadFile({ localGoogleFileVersionId });
        const bytes = base64ToUint8Array(b64);
        triggerDownload(new Blob([bytes], { type: resolveSafeMimeType(mimeType) }), fileName);
    } catch (e) {
        throw normalizeApexError(e);
    }
}

/**
 * Concurrent partial download. Schedules multiple parallel Apex range requests,
 * assembles the file bytes in-order, and triggers a browser download.
 * No return value on success.
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
        onError = () => {}
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

    const buffer = new ArrayBuffer(size);
    const out = new Uint8Array(buffer);

    let nextIndex = 0;
    const worker = async () => {
        while (true) {
            const i = nextIndex++;
            if (i >= ranges.length) return;
            const { start, end } = ranges[i];

            try {
                const b64 = await downloadFilePartial({
                    localGoogleFileVersionId,
                    startByte: start,
                    endByte: end
                });

                const chunk = base64ToUint8Array(b64);

                const expectedLength = end - start + 1;
                if (chunk.length !== expectedLength) {
                    throw new Error(
                        `Chunk length mismatch at [${start}-${end}]: expected ${expectedLength}, got ${chunk.length}`
                    );
                }
                out.set(chunk, start);
            } catch (e) {
                onError(normalizeApexError(e));
                throw e;
            }
        }
    };

    const pool = Array.from({ length: Math.max(1, threads) }, () => worker());
    await Promise.all(pool);

    const blob = new Blob([buffer], { type: resolveSafeMimeType(mimeType) });
    triggerDownload(blob, fileName);
}

const base64ToUint8Array = (base64) => {
    const bin = atob(base64);
    const len = bin.length;
    const bytes = new Uint8Array(len);
    for (let i = 0; i < len; i++) bytes[i] = bin.charCodeAt(i) & 0xff;
    return bytes;
}

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
}

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
}

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