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
public with sharing class GoogleCloudFolderSetupController {
	private static final String GENERIC_FAILURE_MESSAGE = 'Something went wrong. Please try again later or contact your system administrator';

	@AuraEnabled
	public static GoogleFolderNamePatternCheckDTO checkRecordFolderNamePattern(String objectApiName, String pattern) {
		try {
			return new GoogleLocalFolderService().checkRecordFolderNamePattern(objectApiName, pattern);
		} catch (Exception ex) {
			throw translate('Check Record Folder Name Pattern', ex);
		}
	}

	@AuraEnabled
	public static GoogleDriveFolderCheckDTO checkWorkspaceCopyFolder(String folderId) {
		try {
			return new GoogleLocalFolderService().checkWorkspaceCopyFolder(folderId);
		} catch (Exception ex) {
			throw translate('Check Google Workspace Copies Folder', ex);
		}
	}

	private static AuraHandledException translate(String action, Exception ex) {
		Logger.error(action + ', Message: ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
		Logger.saveLog();
		return new AuraHandledException(GENERIC_FAILURE_MESSAGE);
	}
}
