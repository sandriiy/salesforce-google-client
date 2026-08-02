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

	public GoogleDirectUploadService(GoogleMetadataConfigService injectedMetadataService, GoogleRemoteFileUploader injectedRemoteUploader) {
		this.metadataService = injectedMetadataService == null ? new GoogleMetadataConfigService() : injectedMetadataService;
		this.remoteUploader = injectedRemoteUploader;
	}

	public static Long resolveBrowserByteLimit(Long totalBytes) {
		if (totalBytes == null || totalBytes <= 0) return 0;

		Long alignment = CHUNK_ALIGNMENT;
		Long alignedLimit = (totalBytes / alignment) * alignment;

		if (alignedLimit >= totalBytes) {
			alignedLimit -= alignment;
		}

		return alignedLimit < 0 ? 0 : alignedLimit;
	}

	public GoogleDirectUploadSettingsDTO resolveSettings() {
		GoogleDirectUploadSettingsDTO settings = new GoogleDirectUploadSettingsDTO();
		settings.isDirectUploadEnabled = metadataService.isDirectBrowserUploadEnabled();
		return settings;
	}

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
