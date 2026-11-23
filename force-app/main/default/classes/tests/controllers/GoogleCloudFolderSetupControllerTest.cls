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
@IsTest
private class GoogleCloudFolderSetupControllerTest {
	private static final String COPIES_FOLDER = 'COPIES_FOLDER_01';

	private static GoogleDriveHttpMock mockCopiesFolder(Integer statusCode, String body) {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.endpointContains('/files/' + COPIES_FOLDER)
		).thenReturnStatus(statusCode, body);
		return driveMock;
	}

	@IsTest
	private static void testCheckRecordFolderNamePatternPositiveAnswersForAUsablePattern() {
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		GoogleFolderNamePatternCheckDTO check = GoogleCloudFolderSetupController.checkRecordFolderNamePattern('GoogleFile__c', 'Name & " (folder)"');
		Test.stopTest();

		Assert.isTrue(check.isValid);
		Assert.areEqual(GoogleFile__c.SObjectType.getDescribe().getLabel(), check.objectLabel);
	}

	@IsTest
	private static void testCheckRecordFolderNamePatternNegativeAnswersWithTheReasonInsteadOfThrowing() {
		GoogleCloudTestFactory.initMocks();

		GoogleFolderNamePatternCheckDTO check;
		Exception checkFailure;
		Test.startTest();
		try {
			check = GoogleCloudFolderSetupController.checkRecordFolderNamePattern('GoogleFile__c', 'Name & Nope__c');
		} catch (Exception ex) {
			checkFailure = ex;
		}
		Test.stopTest();

		Assert.isNull(checkFailure, 'The wizard shows the reason beside the row');
		Assert.isFalse(check.isValid);
		Assert.isTrue(String.isNotBlank(check.message));
	}

	@IsTest
	private static void testCheckWorkspaceCopyFolderPositiveNamesAUsableFolder() {
		GoogleCloudTestFactory.initMocks(mockCopiesFolder(200, JSON.serialize(new Map<String, Object>{
			'id' => COPIES_FOLDER,
			'name' => 'Google Client Copies',
			'mimeType' => GoogleCloudConstants.MIME_TYPE_GOOGLE_FOLDER,
			'trashed' => false,
			'capabilities' => new Map<String, Object>{ 'canAddChildren' => true }
		})));

		Test.startTest();
		GoogleDriveFolderCheckDTO check = GoogleCloudFolderSetupController.checkWorkspaceCopyFolder(COPIES_FOLDER);
		Test.stopTest();

		Assert.isTrue(check.isUsable);
		Assert.areEqual('Google Client Copies', check.folderName);
	}

	@IsTest
	private static void testCheckWorkspaceCopyFolderNegativeAnswersWithTheReasonInsteadOfThrowing() {
		GoogleCloudTestFactory.initMocks(mockCopiesFolder(404, '{"error":{"code":404,"message":"File not found: COPIES_FOLDER_01.","errors":[{"domain":"global","reason":"notFound","message":"File not found: COPIES_FOLDER_01."}]}}'));

		GoogleDriveFolderCheckDTO check;
		Exception checkFailure;
		Test.startTest();
		try {
			check = GoogleCloudFolderSetupController.checkWorkspaceCopyFolder(COPIES_FOLDER);
		} catch (Exception ex) {
			checkFailure = ex;
		}
		Test.stopTest();

		Assert.isNull(checkFailure, 'The wizard shows the reason under the field');
		Assert.isFalse(check.isUsable);
		Assert.isTrue(String.isNotBlank(check.message));
	}
}
