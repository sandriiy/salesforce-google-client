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
public with sharing class GoogleCloudMigrationController {
	private static final String GENERIC_FAILURE_MESSAGE = 'Something went wrong. Please try again later or contact your system administrator';

	@AuraEnabled
	public static GoogleFileMigrationReadinessDTO retrieveMigrationReadiness() {
		try {
			return new GoogleLocalFileMigrationService().retrieveReadiness();
		} catch (Exception ex) {
			throw translate('Retrieve Migration Readiness', ex);
		}
	}

	@AuraEnabled
	public static GoogleFileMigrationPreviewDTO previewMigrationCriteria(String condition) {
		try {
			return new GoogleLocalFileMigrationService().previewCriteria(condition);
		} catch (Exception ex) {
			throw translate('Preview Migration Criteria', ex);
		}
	}

	@AuraEnabled
	public static List<String> describeMigrationObjects(List<String> objectNames) {
		try {
			return new GoogleLocalFileMigrationService().describeObjects(objectNames);
		} catch (Exception ex) {
			throw translate('Describe Migration Objects', ex);
		}
	}

	@AuraEnabled
	public static GoogleFileMigrationStartResultDTO startMigration(String condition, List<String> objectNames, Boolean skipIntelligence) {
		try {
			GoogleFileMigrationRequestDTO request = new GoogleFileMigrationRequestDTO();
			request.condition = condition;
			request.objectNames = objectNames == null ? new List<String>() : objectNames;
			request.skipIntelligence = skipIntelligence == true;
			return new GoogleLocalFileMigrationService().start(request);
		} catch (Exception ex) {
			throw translate('Start Migration', ex);
		}
	}

	@AuraEnabled
	public static GoogleFileMigrationProgressDTO retrieveMigrationProgress(Long countedSinceMillis) {
		try {
			Datetime countedSince = countedSinceMillis == null ? null : Datetime.newInstance(countedSinceMillis);
			return new GoogleLocalFileMigrationService().retrieveProgress(countedSince);
		} catch (Exception ex) {
			throw translate('Retrieve Migration Progress', ex);
		}
	}

	@AuraEnabled
	public static GoogleFileMigrationHiddenFilesDTO retrieveHiddenMigratedFiles() {
		try {
			return new GoogleLocalFileMigrationService().countHiddenMigratedFiles();
		} catch (Exception ex) {
			throw translate('Retrieve Hidden Migrated Files', ex);
		}
	}

	@AuraEnabled
	public static void stopMigration() {
		try {
			new GoogleLocalFileMigrationService().stop();
		} catch (Exception ex) {
			throw translate('Stop Migration', ex);
		}
	}

	private static AuraHandledException translate(String action, Exception ex) {
		if (ex instanceof GoogleLocalFileMigrationService.GoogleLocalFileMigrationException) {
			return new AuraHandledException(ex.getMessage());
		}

		Logger.error(action + ', Message: ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
		Logger.saveLog();
		return new AuraHandledException(GENERIC_FAILURE_MESSAGE);
	}
}
