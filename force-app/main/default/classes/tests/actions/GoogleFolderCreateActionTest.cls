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
private class GoogleFolderCreateActionTest {
	@IsTest
	private static void testCreateFoldersPositive() {
		GoogleCloudTestFactory.config().withUploadFolderId('ROOT_FOLDER_01').apply();
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.queryContains('q=')
		).thenReturnStatus(200, '{"files":[]}');
		GoogleCloudTestFactory.initMocks(driveMock);

		GoogleFolderCreateAction.Input input = new GoogleFolderCreateAction.Input();
		input.folderName = 'Contracts';
		input.parentFolderId = 'PARENT_01';

		Test.startTest();
		List<GoogleFolderCreateAction.Output> outputs = GoogleFolderCreateAction.createFolders(new List<GoogleFolderCreateAction.Input>{ input });
		Test.stopTest();

		Assert.areEqual(1, outputs.size(), 'Flow expects one output per input');
		Assert.areEqual('gfile_small_001', outputs[0].folderId);
		Assert.areEqual('PARENT_01', outputs[0].parentFolderId);
		Assert.isTrue(outputs[0].wasCreated);
	}

	@IsTest
	private static void testCreateFoldersNegativeSurfacesTheReason() {
		GoogleCloudTestFactory.config().withUploadFolderId('ROOT_FOLDER_01').apply();
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		try {
			GoogleFolderCreateAction.createFolders(new List<GoogleFolderCreateAction.Input>{ new GoogleFolderCreateAction.Input() });
			Assert.fail('The flow must fault with a readable message');
		} catch (GoogleLocalFolderService.GoogleLocalFolderException ex) {
			Assert.isTrue(ex.getMessage().contains('Enter a folder name'), ex.getMessage());
		}
		Test.stopTest();
	}

	@IsTest
	private static void testCreateFoldersPositiveNullInputs() {
		Test.startTest();
		List<GoogleFolderCreateAction.Output> outputs = GoogleFolderCreateAction.createFolders(null);
		Test.stopTest();

		Assert.areEqual(0, outputs.size());
	}

	@IsTest
	private static void testCreateFoldersPositiveEmptyInputs() {
		Test.startTest();
		List<GoogleFolderCreateAction.Output> outputs = GoogleFolderCreateAction.createFolders(new List<GoogleFolderCreateAction.Input>());
		Test.stopTest();

		Assert.areEqual(0, outputs.size());
	}
}
