import saveNewGoogleFileLocally from '@salesforce/apex/GoogleCloudFilesController.saveNewGoogleFile';
import saveNewGoogleFileVersion from '@salesforce/apex/GoogleCloudFilesController.saveNewGoogleFileVersion';
import uploadFilePartial from '@salesforce/apex/GoogleCloudFilesController.uploadLargeFilePartial';
import uploadFile from '@salesforce/apex/GoogleCloudFilesController.uploadFile';

export const BIG_FILE_SIZE = 2 * 1024 * 1024; // 2 MB
const CHUNK_SIZE = 2 * 1024 * 1024; // 2 MB

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

export async function saveGoogleFileLocally(recordId, file, uploadSource) {
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