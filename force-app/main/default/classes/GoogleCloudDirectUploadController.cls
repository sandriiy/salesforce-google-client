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
public with sharing class GoogleCloudDirectUploadController {
	@TestVisible
	private static GoogleDirectUploadService serviceOverride;

	@AuraEnabled(cacheable=true)
	public static GoogleDirectUploadSettingsDTO retrieveDirectUploadSettings() {
		try {
			return resolveService().resolveSettings();
		} catch (Exception ex) {
			Logger.error('Retrieve Direct Upload Settings, Message: ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();

			throw new AuraHandledException('We couldn’t load the upload settings. Please try again, or contact your system administrator');
		}
	}

	@AuraEnabled
	public static GoogleDirectUploadSessionDTO initializeDirectUpload(String fileName, String mimeType, Long totalBytes) {
		try {
			return resolveService().startUpload(fileName, mimeType, totalBytes);
		} catch (Exception ex) {
			Logger.error('Initialize Direct Upload, File Name: ' + fileName).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.error('Initialize Direct Upload, Total Bytes: ' + String.valueOf(totalBytes)).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.error('Initialize Direct Upload, Message: ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();

			throw new AuraHandledException('We couldn’t start the upload. Please try again, or contact your system administrator');
		}
	}

	@AuraEnabled
	public static GoogleDirectUploadResultDTO finalizeDirectUpload(String fileName, String sessionUri, String finalChunkToUpload, Long startByte, Long totalBytes) {
		try {
			return resolveService().completeUpload(fileName, sessionUri, finalChunkToUpload, startByte, totalBytes);
		} catch (Exception ex) {
			Logger.error('Finalize Direct Upload, File Name: ' + fileName).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.error('Finalize Direct Upload, Start Byte: ' + String.valueOf(startByte) + ', Total Bytes: ' + String.valueOf(totalBytes)).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.error('Finalize Direct Upload, Message: ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();

			throw new AuraHandledException('We couldn’t confirm the uploaded file. Please try again, or contact your system administrator');
		}
	}

	@AuraEnabled
	public static void reportDirectUploadOutcome(String outcome, String diagnostics) {
		try {
			resolveService().reportOutcome(outcome, diagnostics);
		} catch (Exception ex) {
			Logger.error('Report Direct Upload Outcome, Message: ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
		}
	}

	private static GoogleDirectUploadService resolveService() {
		return serviceOverride != null ? serviceOverride : new GoogleDirectUploadService();
	}
}
