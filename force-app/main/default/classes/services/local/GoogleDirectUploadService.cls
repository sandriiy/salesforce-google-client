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
 * Runs the upload where the browser sends the bytes to Google Drive itself and Apex only sends the last
 * small piece. That final piece comes from the server so the Drive file Id and its folder are told to
 * Salesforce by Google rather than by the browser. Nothing is cached between the calls: the browser
 * hands the session back, because the platform cache is not allocated in every org and a flow that
 * depends on it fails everywhere it is not.
 */
public without sharing class GoogleDirectUploadService {
	public class GoogleDirectUploadException extends Exception {}

	private static final Long CHUNK_ALIGNMENT = 262144L;
	@TestVisible
	private static final String OUTCOME_FAILED = 'failed';
	@TestVisible
	private static final String OUTCOME_BLOCKED = 'blocked';
	@TestVisible
	private static final String OUTCOME_RECOVERED = 'recovered';
	@TestVisible
	private static final String OUTCOME_CANCELLED = 'cancelled';

	private final GoogleMetadataConfigService metadataService;
	private GoogleRemoteFileUploader remoteUploader;

	public GoogleDirectUploadService() {
		this(new GoogleMetadataConfigService(), null);
	}

	/**
	 * Builds the service on parts you already have.
	 *
	 * @param injectedMetadataService The configuration to read. A null gets a fresh one.
	 * @param injectedRemoteUploader The uploader to send through. A null gets one when it is first needed.
	 */
	public GoogleDirectUploadService(GoogleMetadataConfigService injectedMetadataService, GoogleRemoteFileUploader injectedRemoteUploader) {
		this.metadataService = injectedMetadataService == null ? new GoogleMetadataConfigService() : injectedMetadataService;
		this.remoteUploader = injectedRemoteUploader;
	}

	/**
	 * Works out how much the browser may send before the tail Apex finishes with. The answer is aligned to
	 * the chunk size Google requires and always leaves something behind, so there is a tail to send.
	 *
	 * @param totalBytes The whole file size.
	 * @return The number of bytes the browser should send.
	 */
	public static Long resolveBrowserByteLimit(Long totalBytes) {
		if (totalBytes == null || totalBytes <= 0) return 0;

		Long alignment = CHUNK_ALIGNMENT;
		Long alignedLimit = (totalBytes / alignment) * alignment;

		if (alignedLimit >= totalBytes) {
			alignedLimit -= alignment;
		}

		return alignedLimit < 0 ? 0 : alignedLimit;
	}

	/**
	 * Tells the browser whether this org uses direct upload at all.
	 *
	 * @return The settings the uploader needs.
	 */
	public GoogleDirectUploadSettingsDTO resolveSettings() {
		GoogleDirectUploadSettingsDTO settings = new GoogleDirectUploadSettingsDTO();
		settings.isDirectUploadEnabled = metadataService.isDirectBrowserUploadEnabled();
		return settings;
	}

	/**
	 * Opens the upload session with Google and hands the browser the address to send to.
	 *
	 * @param fileName The name the file gets in Drive.
	 * @param mimeType What kind of file it is.
	 * @param totalBytes The whole file size, which Google holds the browser to.
	 * @return The session address and how much the browser may send.
	 */
	public GoogleDirectUploadSessionDTO startUpload(String fileName, String mimeType, Long totalBytes) {
		if (!metadataService.isDirectBrowserUploadEnabled()) {
			throw new GoogleDirectUploadException('Direct browser upload is not enabled for this organization');
		}

		if (String.isBlank(fileName)) {
			throw new GoogleDirectUploadException('A file name is required to start an upload');
		}

		if (totalBytes == null || totalBytes <= 0) {
			throw new GoogleDirectUploadException('A valid file size is required to start an upload');
		}

		GoogleRemoteFileUploader.GoogleResumableSessionResult sessionResult = getRemoteUploader().initializeResumableSession(fileName, mimeType);
		if (sessionResult == null || String.isBlank(sessionResult.sessionUri)) {
			throw new GoogleDirectUploadException('Google did not return an upload session');
		}

		GoogleDirectUploadSessionDTO session = new GoogleDirectUploadSessionDTO();
		session.sessionUri = sessionResult.sessionUri;
		session.browserByteLimit = resolveBrowserByteLimit(totalBytes);
		return session;
	}

	/**
	 * Sends the last piece from Apex and finishes the upload, which is how the Drive file Id reaches
	 * Salesforce at all, since the browser cannot read Google's closing answer.
	 *
	 * @param fileName The name the file gets in Drive.
	 * @param sessionUri The session the browser has been sending to.
	 * @param finalChunkToUpload The last piece, base64 encoded.
	 * @param startByte Where that piece starts in the file.
	 * @param totalBytes The whole file size.
	 * @return The Drive file Id and the folder it landed in.
	 */
	public GoogleDirectUploadResultDTO completeUpload(String fileName, String sessionUri, String finalChunkToUpload, Long startByte, Long totalBytes) {
		if (String.isBlank(sessionUri)) {
			throw new GoogleDirectUploadException('The upload session is missing');
		}

		if (String.isBlank(finalChunkToUpload)) {
			throw new GoogleDirectUploadException('The final upload chunk is missing');
		}

		if (totalBytes == null || totalBytes <= 0 || startByte == null || startByte < 0 || startByte >= totalBytes) {
			throw new GoogleDirectUploadException('The final upload chunk range is invalid');
		}

		GoogleBigFileEntity completedUpload = getRemoteUploader().uploadBigFilePartial(fileName, finalChunkToUpload, sessionUri, startByte, totalBytes);
		if (completedUpload == null || completedUpload.file == null || String.isBlank(completedUpload.file.id)) {
			throw new GoogleDirectUploadException('The upload did not complete on Google Drive');
		}

		GoogleDirectUploadResultDTO result = new GoogleDirectUploadResultDTO();
		result.googleDriveId = completedUpload.file.id;
		result.parentFolderId = resolveParentFolderId(completedUpload.file);
		result.fileName = fileName;
		result.fileSize = totalBytes;
		return result;
	}

	/**
	 * Records how a direct upload ended, so an org can tell a cancelled upload from one that fell back to
	 * Salesforce and one that failed outright.
	 *
	 * @param outcome One of "failed", "blocked", "recovered" or "cancelled".
	 * @param diagnostics What the browser saw.
	 */
	public void reportOutcome(String outcome, String diagnostics) {
		String normalizedOutcome = String.isBlank(outcome) ? OUTCOME_FAILED : outcome;
		String logMessage = 'Direct Browser Upload --> Outcome=' + normalizedOutcome + ', Details=' + String.valueOf(diagnostics);

		Boolean isExpectedOutcome = normalizedOutcome == OUTCOME_RECOVERED
			|| normalizedOutcome == OUTCOME_CANCELLED;

		if (isExpectedOutcome) {
			Logger.info(logMessage).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
		} else {
			Logger.error(logMessage).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
		}

		Logger.saveLog();
	}

	private String resolveParentFolderId(GoogleFileEntity uploadedFile) {
		if (uploadedFile.parents != null && !uploadedFile.parents.isEmpty()) {
			return uploadedFile.parents[0];
		}
		return metadataService.getDefaultUploadFolderId();
	}

	private GoogleRemoteFileUploader getRemoteUploader() {
		if (remoteUploader == null) {
			remoteUploader = new GoogleRemoteFileUploader();
		}
		return remoteUploader;
	}
}
