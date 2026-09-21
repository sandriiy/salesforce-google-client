/**
 * MIT License
 *
 * Copyright (c) 2026 Andrii Sukhetskyi
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
/**
 * Sends bytes to Google Drive. When several upload folders are configured and the one in use hits a
 * hard Drive capacity limit, it moves to the next folder and carries on, which is what keeps uploads
 * working when a shared drive fills up.
 */
public without sharing class GoogleRemoteFileUploader {
	public class GoogleRemoteFileUploaderException extends Exception {}

	private GoogleMetadataConfigService metadataService = new GoogleMetadataConfigService();
	private final GoogleDrive remoteGoogleDrive;
	
	public GoogleRemoteFileUploader() {
		GoogleClientApiProvider remoteFileService = new GoogleClientApiProvider();
		this.remoteGoogleDrive = remoteFileService.retrieveGoogleDriveClient();
	}

    /**
     * Uploads a small file in one request.
     *
     * @param fileName The name the file gets in Drive.
     * @param contentToUpload The content, base64 encoded.
     * @return The created Drive file with its Id and folder.
     */
    public GoogleFileEntity uploadFile(String fileName, String contentToUpload) {
		Blob decodedBlob = EncodingUtil.base64Decode(contentToUpload);
		List<String> candidateFolders = resolveCandidateFolders();
		Integer candidateCount = candidateFolders.size();

		for (Integer i = 0; i < candidateCount; i++) {
			String candidateFolderId = candidateFolders[i];
			Boolean hasNextCandidate = (i + 1) < candidateCount;

			try {
				return this.remoteGoogleDrive.files().multipartCreate()
					.setFileName(fileName)
					.setBody(contentToUpload)
					.setParentFolders(new List<String>{candidateFolderId})
					.setSupportsAllDrives(true)
					.setFields('id, name, parents')
					.execute();
			} catch (Exception ex) {
				if (hasNextCandidate && GoogleDriveCapacityErrorClassifier.isCapacityExhaustedError(ex)) {
					logCapacityFallover('Upload File', fileName, candidateFolderId, ex);
					continue;
				}

				if (!hasNextCandidate && candidateCount > 1 && GoogleDriveCapacityErrorClassifier.isCapacityExhaustedError(ex)) {
					logCapacityFallover('Upload File', fileName, candidateFolderId, ex);
					throw new GoogleRemoteFileUploaderException('All configured shared drives are full. Please contact your system administrator.');
				}

				throw new GoogleRemoteFileUploaderException('Unable to upload the file. Please try again or contact your system administrator.');
			}
		}

		throw new GoogleRemoteFileUploaderException('Unable to upload the file. Please try again or contact your system administrator.');
	}

	/**
	 * Uploads a whole file that is already in memory, opening a session and sending it in one piece. Apex
	 * cannot slice a Blob, so the file has to fit in the heap, which is why anything large is queued rather
	 * than sent this way.
	 *
	 * @param fileName The name the file gets in Drive.
	 * @param mimeType What kind of file it is.
	 * @param content The whole file.
	 * @return The created Drive file with its Id and folder.
	 */
	public GoogleFileEntity uploadFileContent(String fileName, String mimeType, Blob content) {
		if (content == null || content.size() == 0) {
			throw new GoogleRemoteFileUploaderException('Unable to upload an empty file. Please try again or contact your system administrator.');
		}

		GoogleResumableSessionResult session = initializeResumableSession(fileName, mimeType);

		GoogleBigFileEntity uploadedFile;
		try {
			uploadedFile = this.remoteGoogleDrive.files().resumableCreate()
				.setExistingSessionUri(session.sessionUri)
				.setFileName(fileName)
				.setParentFolders(new List<String>{session.folderId})
				.setSupportsAllDrives(true)
				.setStartByte(0L)
				.setTotalBytes(content.size())
				.setBody(content)
				.setFields('id, name, parents')
				.execute();
		} catch (Exception ex) {
			throw new GoogleRemoteFileUploaderException('Unable to upload the file. Please try again or contact your system administrator.');
		}

		if (uploadedFile == null || uploadedFile.file == null || String.isBlank(uploadedFile.file.id)) {
			throw new GoogleRemoteFileUploaderException('The upload did not complete on Google Drive. Please try again or contact your system administrator.');
		}

		return uploadedFile.file;
	}

	/**
	 * Opens an upload session and reports which folder it was opened against, which matters because the
	 * fallover may have moved it.
	 *
	 * @param fileName The name the file gets in Drive.
	 * @param mimeType What kind of file it is.
	 * @return The session address and the folder it belongs to.
	 */
	public GoogleResumableSessionResult initializeResumableSession(String fileName, String mimeType) {
		List<String> candidateFolders = resolveCandidateFolders();
		Integer candidateCount = candidateFolders.size();

		for (Integer i = 0; i < candidateCount; i++) {
			String candidateFolderId = candidateFolders[i];
			Boolean hasNextCandidate = (i + 1) < candidateCount;

			try {
				GoogleResumableFileBuilder sessionBuilder = this.remoteGoogleDrive.files().resumableCreate()
					.setFileName(fileName)
					.setParentFolders(new List<String>{candidateFolderId})
					.setSupportsAllDrives(true)
					.setFields('id, name, parents');

				if (String.isNotBlank(mimeType)) {
					sessionBuilder.setMimeType(mimeType);
				}

				GoogleBigFileEntity initializedSession = sessionBuilder.initialize();
				return new GoogleResumableSessionResult(initializedSession.resumableSessionId, candidateFolderId);
			} catch (Exception ex) {
				if (hasNextCandidate && GoogleDriveCapacityErrorClassifier.isCapacityExhaustedError(ex)) {
					logCapacityFallover('Initialize Resumable Session', fileName, candidateFolderId, ex);
					continue;
				}

				if (!hasNextCandidate && candidateCount > 1 && GoogleDriveCapacityErrorClassifier.isCapacityExhaustedError(ex)) {
					logCapacityFallover('Initialize Resumable Session', fileName, candidateFolderId, ex);
					throw new GoogleRemoteFileUploaderException('All configured shared drives are full. Please contact your system administrator.');
				}

				throw new GoogleRemoteFileUploaderException('Unable to start the file upload. Please try again or contact your system administrator.');
			}
		}

		throw new GoogleRemoteFileUploaderException('Unable to start the file upload. Please try again or contact your system administrator.');
	}

	/**
	 * Sends one chunk of a large upload. Google answers with the file once the last chunk lands and with
	 * progress until then.
	 *
	 * @param fileName The name the file gets in Drive.
	 * @param chunkToUpload This chunk, base64 encoded.
	 * @param resumableSessionId The session to send to. Blank opens a new one.
	 * @param startByte Where this chunk starts in the file.
	 * @param totalBytes The whole file size, which every chunk must agree on.
	 * @return The finished file, or the session and how far it has got.
	 */
	public GoogleBigFileEntity uploadBigFilePartial(String fileName, String chunkToUpload, String resumableSessionId, Long startByte, Long totalBytes) {
		Blob decodedBlob = EncodingUtil.base64Decode(chunkToUpload);

		if (String.isNotBlank(resumableSessionId)) {
			return executeBigFileChunk(fileName, decodedBlob, resumableSessionId, startByte, totalBytes, resolveCandidateFolders());
		}

		List<String> candidateFolders = resolveCandidateFolders();
		Integer candidateCount = candidateFolders.size();

		for (Integer i = 0; i < candidateCount; i++) {
			String candidateFolderId = candidateFolders[i];
			Boolean hasNextCandidate = (i + 1) < candidateCount;

			try {
				return this.remoteGoogleDrive.files().resumableCreate()
					.setExistingSessionUri(resumableSessionId)
					.setFileName(fileName)
					.setParentFolders(new List<String>{candidateFolderId})
					.setSupportsAllDrives(true)
					.setStartByte(startByte)
					.setTotalBytes(totalBytes)
					.setBody(decodedBlob)
					.setFields('id, name, parents')
					.execute();
			} catch (Exception ex) {
				if (hasNextCandidate && GoogleDriveCapacityErrorClassifier.isCapacityExhaustedError(ex)) {
					logCapacityFallover('Upload Large File', fileName, candidateFolderId, ex);
					continue;
				}

				if (!hasNextCandidate && candidateCount > 1 && GoogleDriveCapacityErrorClassifier.isCapacityExhaustedError(ex)) {
					logCapacityFallover('Upload Large File', fileName, candidateFolderId, ex);
					throw new GoogleRemoteFileUploaderException('All configured shared drives are full. Please contact your system administrator.');
				}

				throw new GoogleRemoteFileUploaderException('Unable to upload the file chunk. Please try again or contact your system administrator.');
			}
		}

		throw new GoogleRemoteFileUploaderException('Unable to upload the file chunk. Please try again or contact your system administrator.');
	}

	private GoogleBigFileEntity executeBigFileChunk(String fileName, Blob decodedBlob, String resumableSessionId, Long startByte, Long totalBytes, List<String> candidateFolders) {
		try {
			return this.remoteGoogleDrive.files().resumableCreate()
				.setExistingSessionUri(resumableSessionId)
				.setFileName(fileName)
				.setParentFolders(candidateFolders.isEmpty() ? new List<String>() : new List<String>{candidateFolders[0]})
				.setSupportsAllDrives(true)
				.setStartByte(startByte)
				.setTotalBytes(totalBytes)
				.setBody(decodedBlob)
				.setFields('id, name, parents')
				.execute();
		} catch (Exception ex) {
			throw new GoogleRemoteFileUploaderException('Unable to upload the file chunk. Please try again or contact your system administrator.');
		}
	}

	private List<String> resolveCandidateFolders() {
		List<String> candidates = metadataService.getTargetFolderResolver().resolveUploadFolderCandidates();
		if (candidates == null || candidates.isEmpty()) {
			return new List<String>{metadataService.getDefaultUploadFolderId()};
		}
		return candidates;
	}

	private void logCapacityFallover(String action, String fileName, String folderId, Exception ex) {
		String reason = GoogleDriveCapacityErrorClassifier.extractReason(ex);
		Logger.info(
			action + ' Fallover --> Shared drive is full' +
			', FolderId=' + String.valueOf(folderId) +
			', FileName=' + String.valueOf(fileName) +
			', Reason=' + String.valueOf(reason)
		).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
	}

	/**
	 * An open upload session and the folder it was opened against.
	 */
	public class GoogleResumableSessionResult {
		public String sessionUri;
		public String folderId;

		/**
		 * Holds the session address and its folder.
		 *
		 * @param sessionUri Where the chunks are sent.
		 * @param folderId The Drive folder the file will land in.
		 */
		public GoogleResumableSessionResult(String sessionUri, String folderId) {
			this.sessionUri = sessionUri;
			this.folderId = folderId;
		}
	}
}