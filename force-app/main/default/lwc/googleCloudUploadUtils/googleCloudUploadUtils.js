import saveNewGoogleFileLocally from '@salesforce/apex/GoogleCloudFilesController.saveNewGoogleFile';
import saveNewGoogleFileVersion from '@salesforce/apex/GoogleCloudFilesController.saveNewGoogleFileVersion';
import ensureNewGoogleFileFolderStructure from '@salesforce/apex/GoogleCloudFilesController.ensureGoogleDriveFolderStructure';
import uploadFilePartial from '@salesforce/apex/GoogleCloudFilesController.uploadLargeFilePartial';
import uploadFile from '@salesforce/apex/GoogleCloudFilesController.uploadFile';

import retrieveDirectUploadSettings from '@salesforce/apex/GoogleCloudDirectUploadController.retrieveDirectUploadSettings';
import initializeDirectUpload from '@salesforce/apex/GoogleCloudDirectUploadController.initializeDirectUpload';
import finalizeDirectUpload from '@salesforce/apex/GoogleCloudDirectUploadController.finalizeDirectUpload';
import reportDirectUploadOutcome from '@salesforce/apex/GoogleCloudDirectUploadController.reportDirectUploadOutcome';

export const BIG_FILE_SIZE = 2 * 1024 * 1024; // 2 MB
const CHUNK_SIZE = 2 * 1024 * 1024; // 2 MB
const DIRECT_CHUNK_ALIGNMENT = 256 * 1024;
const DIRECT_CHUNK_SIZE = 16 * 1024 * 1024; // 16 MB, a multiple of the 256 KB Google requires for every non-final chunk
const DIRECT_CHUNK_TIMEOUT_MS = 180000;
const MAX_DIRECT_CHUNK_ATTEMPTS = 5;
const RETRY_BASE_DELAY_MS = 1000;
const RETRYABLE_DIRECT_STATUSES = new Set([408, 429, 500, 502, 503, 504]);
const RESUMABLE_INCOMPLETE_STATUS = 308;
const OUTCOME_FAILED = 'failed';
const OUTCOME_BLOCKED = 'blocked';
const OUTCOME_RECOVERED = 'recovered';
const folderStructurePromisesByRecordId = new Map();

let directUploadSettingsPromise;
let isDirectUploadUnavailable = false;

/**
 * Upload a file to Google Drive in multiple chunks using the Google Drive resumable upload endpoint.
 * Maintains a resumable session, updates uploaded bytes, and calls onProgress after each chunk.
 *
 * @param {string} fileId - The local client-side ID used to track the file.
 * @param {File} file - The file object to upload.
 * @param {object} options
 * @param {function} [options.onProgress] - Callback invoked after each chunk with arguments:
 *   (uploadedFileId, parentFolderId, fileId, progressPercentage).
 */
export async function uploadInChunks(fileId, file, options) {
    const settings = await resolveDirectUploadSettings();
    if (!settings.isDirectUploadEnabled || isDirectUploadUnavailable) {
        return uploadThroughApex(fileId, file, options);
    }

    return uploadDirectToGoogle(fileId, file, options);
}

/**
 * Upload a file in a single request using the Google Drive multipart upload endpoint.
 * Reads the entire file, encodes it in Base64, and sends it to the server.
 * Calls onSuccess after upload completes.
 *
 * @param {string} fileId - The local client-side ID used to track the file.
 * @param {File} file - The file object to upload.
 * @param {object} options
 * @param {function} [options.onSuccess] - Callback invoked with arguments:
 *   (uploadedFileId, parentFolderId, fileId).
 */
export async function upload(fileId, file, options) {
    const onSuccess = options?.onSuccess ?? (() => {});

	const base64Chunk = await readFileChunk(file);
	const result = await uploadFile({
		fileName: file.name,
		contentToUpload: base64Chunk
	});

	const uploadedFileId = result.id;
	const uploaderParentFolderId = result.parents;
	onSuccess(uploadedFileId, getParentFolderId(uploaderParentFolderId), fileId);
}

/**
 * Start resolving, and creating when missing, the Google Drive folder that every file of this upload belongs in.
 * Call this as soon as files are selected and never await it, so the folder is resolved while the files upload.
 * The resolution is awaited later, just before the Salesforce records are created.
 *
 * @param {string} recordId - The Salesforce record the files are being uploaded to.
 */
export function prefetchUploadFolderStructure(recordId) {
    if (!recordId || folderStructurePromisesByRecordId.has(recordId)) return;

    folderStructurePromisesByRecordId.set(
        recordId,
        ensureNewGoogleFileFolderStructure({ relatedRecordId: recordId })
            .catch(() => folderStructurePromisesByRecordId.delete(recordId))
    );
}

async function awaitUploadFolderStructure(recordId) {
    if (!recordId) return;

    prefetchUploadFolderStructure(recordId);
    await folderStructurePromisesByRecordId.get(recordId);
}

export async function saveGoogleFileLocally(recordId, file, uploadSource) {
    await awaitUploadFolderStructure(recordId);

    return await saveNewGoogleFileLocally({
        recordId: recordId,
        fileName: file.name,
        fileType: file.originalType,
        fileSize: file.originalSize,
        googleDriveId: file.id,
        parentFolderId: file.parentFolderId,
        source: uploadSource
    });
}

export async function saveGoogleFileVersionLocally(recordId, localGoogleFileId, file, uploadSource) {
	return await saveNewGoogleFileVersion({
        recordId: recordId,
		localGoogleFileId: localGoogleFileId,
        fileName: file.name,
        fileType: file.originalType,
        fileSize: file.originalSize,
        googleDriveId: file.id,
        parentFolderId: file.parentFolderId,
        source: uploadSource
    });
}

async function uploadThroughApex(fileId, file, options) {
    const onProgress = options?.onProgress ?? (() => {});

    const totalBytes = file.size;
    let uploadedFileId;
    let uploaderParentFolderId;
    let resumeSessionId;
    let uploadedBytes = 0;

    while (uploadedBytes < totalBytes) {
        const start = uploadedBytes;
        const end = Math.min(start + CHUNK_SIZE, totalBytes);

        const fileChunk = file.slice(start, end);

        // Convert chunk to Base64
        const base64Chunk = await readFileChunk(fileChunk);
		const result = await uploadFilePartial({
			fileName: file.name,
			chunkToUpload: base64Chunk,
			resumableSessionId: resumeSessionId,
			startByte: start,
			totalBytes: totalBytes
		});

		uploadedBytes = result.resumableLatestByte; // Number of bytes uploaded
		resumeSessionId = result.resumableSessionId; // Initialized Resumable URL
		uploadedFileId = result.file?.id; // Filled after successful upload
		uploaderParentFolderId = result.file?.parents;

		if (uploadedBytes && !uploadedFileId) {
			let progressPercentage = Math.floor((uploadedBytes / totalBytes) * 100);
			if (progressPercentage != 100) {
				onProgress(
					uploadedFileId, 
					getParentFolderId(uploaderParentFolderId), 
					fileId, 
					progressPercentage
				);
			}
		}
    }

    onProgress(
        uploadedFileId,
        getParentFolderId(uploaderParentFolderId), 
        fileId, 
        100
    );
}

async function uploadDirectToGoogle(fileId, file, options) {
    const onProgress = options?.onProgress ?? (() => {});

    const totalBytes = file.size;
    const diagnostics = [];
    let session;

    try {
        session = await initializeDirectUpload({
            fileName: file.name,
            mimeType: file.type,
            totalBytes: totalBytes
        });
    } catch (error) {
        throw buildDirectUploadFailure(fileId, file, options, OUTCOME_FAILED, `session init failed: ${describeError(error)}`);
    }

    const browserByteLimit = resolveBrowserByteLimit(session.browserByteLimit, totalBytes);
    let uploadedBytes = 0;
    let reportedPercentage = 0;

    while (uploadedBytes < browserByteLimit) {
        const start = uploadedBytes;
        const end = Math.min(start + DIRECT_CHUNK_SIZE, browserByteLimit);

        const response = await sendChunkWithRetries(session.sessionUri, file, start, end, totalBytes, diagnostics);
        if (!response.isAccepted) {
            const outcome = start === 0 && response.status === 0 ? OUTCOME_BLOCKED : OUTCOME_FAILED;
            throw buildDirectUploadFailure(fileId, file, options, outcome, diagnostics.join(' | '));
        }

        const committedBytes = resolveCommittedBytes(response.rangeHeader, end);
        if (committedBytes <= start) {
            diagnostics.push(`bytes ${start}-${end - 1} accepted without progress, committed ${committedBytes}`);
            throw buildDirectUploadFailure(fileId, file, options, OUTCOME_FAILED, diagnostics.join(' | '));
        }

        uploadedBytes = committedBytes;
        reportedPercentage = reportDirectProgress(onProgress, fileId, uploadedBytes, totalBytes, reportedPercentage);
    }

    let result;
    try {
        const finalChunk = await readFileChunk(file.slice(browserByteLimit, totalBytes));
        result = await finalizeDirectUpload({
            fileName: file.name,
            sessionUri: session.sessionUri,
            finalChunkToUpload: finalChunk,
            startByte: browserByteLimit,
            totalBytes: totalBytes
        });
    } catch (error) {
        diagnostics.push(`finalize failed: ${describeError(error)}`);
        throw buildDirectUploadFailure(fileId, file, options, OUTCOME_FAILED, diagnostics.join(' | '));
    }

    if (diagnostics.length > 0) {
        reportOutcome(OUTCOME_RECOVERED, diagnostics.join(' | '));
    }

    onProgress(result.googleDriveId, result.parentFolderId, fileId, 100);
}

async function sendChunkWithRetries(sessionUri, file, start, end, totalBytes, diagnostics) {
    let lastResponse;

    for (let attempt = 1; attempt <= MAX_DIRECT_CHUNK_ATTEMPTS; attempt++) {
        lastResponse = await sendChunk(sessionUri, file.slice(start, end), start, end - 1, totalBytes);
        if (lastResponse.isAccepted) {
            return lastResponse;
        }

        diagnostics.push(`bytes ${start}-${end - 1} attempt ${attempt} status ${lastResponse.status}`);

        if (!isRetryableChunkResponse(lastResponse, start)) {
            return lastResponse;
        }

        if (attempt < MAX_DIRECT_CHUNK_ATTEMPTS) {
            await waitBeforeRetry(attempt);
        }
    }

    return lastResponse;
}

function isRetryableChunkResponse(response, start) {
    if (response.status === 0) {
        return start > 0;
    }

    return RETRYABLE_DIRECT_STATUSES.has(response.status);
}

function sendChunk(sessionUri, chunkBlob, startByte, endByte, totalBytes) {
    return new Promise((resolve) => {
        const request = new XMLHttpRequest();
        request.open('PUT', sessionUri, true);
        request.timeout = DIRECT_CHUNK_TIMEOUT_MS;
        request.setRequestHeader('Content-Range', `bytes ${startByte}-${endByte}/${totalBytes}`);

        const settle = (outcome) => {
            request.onload = null;
            request.onerror = null;
            request.ontimeout = null;
            resolve(outcome);
        };

        request.onload = () => settle({
            isAccepted: request.status === RESUMABLE_INCOMPLETE_STATUS,
            status: request.status,
            rangeHeader: request.getResponseHeader('Range')
        });
        request.onerror = () => settle({ isAccepted: false, status: request.status, rangeHeader: null });
        request.ontimeout = () => settle({ isAccepted: false, status: 0, rangeHeader: null });

        request.send(chunkBlob);
    });
}

function resolveBrowserByteLimit(serverByteLimit, totalBytes) {
    const serverLimit = Number(serverByteLimit);
    if (Number.isFinite(serverLimit) && serverLimit >= 0 && serverLimit < totalBytes) {
        return serverLimit;
    }

    const alignedLimit = Math.floor(totalBytes / DIRECT_CHUNK_ALIGNMENT) * DIRECT_CHUNK_ALIGNMENT;
    return alignedLimit >= totalBytes ? Math.max(0, alignedLimit - DIRECT_CHUNK_ALIGNMENT) : alignedLimit;
}

function resolveCommittedBytes(rangeHeader, fallbackEnd) {
    if (!rangeHeader) return fallbackEnd;

    const match = /(\d+)\s*$/.exec(rangeHeader);
    if (!match) return fallbackEnd;

    const committed = Number(match[1]) + 1;
    return committed > 0 && committed <= fallbackEnd ? committed : fallbackEnd;
}

function reportDirectProgress(onProgress, fileId, uploadedBytes, totalBytes, reportedPercentage) {
    const rawPercentage = Math.floor((uploadedBytes / totalBytes) * 100);
    const nextPercentage = Math.max(reportedPercentage, Math.min(rawPercentage, 99));

    if (nextPercentage > reportedPercentage) {
        onProgress(undefined, undefined, fileId, nextPercentage);
    }

    return nextPercentage;
}

function buildDirectUploadFailure(fileId, file, options, outcome, diagnostics) {
    reportOutcome(outcome, diagnostics);

    if (outcome === OUTCOME_BLOCKED) {
        isDirectUploadUnavailable = true;
    }

    const failure = new Error(diagnostics);
    failure.name = 'DirectUploadFailure';
    failure.canRetryThroughApex = true;
    failure.retryThroughApex = () => {
        isDirectUploadUnavailable = true;
        return uploadThroughApex(fileId, file, options);
    };

    return failure;
}

function reportOutcome(outcome, diagnostics) {
    reportDirectUploadOutcome({
        outcome: outcome,
        diagnostics: diagnostics
    }).catch(() => {});
}

function resolveDirectUploadSettings() {
    if (!directUploadSettingsPromise) {
        directUploadSettingsPromise = retrieveDirectUploadSettings()
            .catch(() => ({ isDirectUploadEnabled: false }));
    }

    return directUploadSettingsPromise;
}

function waitBeforeRetry(attempt) {
    const backoff = RETRY_BASE_DELAY_MS * Math.pow(2, attempt - 1);
    const jitter = backoff * 0.2 * (Math.random() - 0.5);
    return new Promise((resolve) => setTimeout(resolve, Math.round(backoff + jitter)));
}

function describeError(error) {
    if (!error) return 'unknown error';
    if (error.body?.message) return error.body.message;
    return error.message || 'unknown error';
}

const getParentFolderId = (uploaderParentFolderId) => {
    if (uploaderParentFolderId) {
    	const parents = Array.isArray(uploaderParentFolderId) ? uploaderParentFolderId : [];
        return parents.length > 0 ? parents[0] : undefined;
    }
}

const readFileChunk = (fileChunk) => {
    return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => resolve(reader.result.split(',')[1]);
        reader.onerror = reject;
        reader.readAsDataURL(fileChunk);
    });
}
