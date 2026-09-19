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
private class GoogleFileDownloadActionTest {
	@IsTest
	private static void testDownloadFilesPositive() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();
		GoogleCapturingUnitOfWork uow = new GoogleCapturingUnitOfWork();
		GoogleFileDownloadAction.transferServiceOverride = new GoogleLocalFileTransferService(uow);

		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('Report').insertRecord();
		GoogleFileVersion__c localVersion = GoogleCloudTestFactory.version().forFile(localFile.Id).withName('Report.pdf').withDriveId('GD_REPORT').insertRecord();
		Id relatedRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);

		GoogleFileDownloadAction.Input input = new GoogleFileDownloadAction.Input();
		input.googleFileVersionId = localVersion.Id;
		input.relatedRecordId = relatedRecordId;
		input.fileName = 'Report copy';

		Test.startTest();
		List<GoogleFileDownloadAction.Output> outputs = GoogleFileDownloadAction.downloadFiles(new List<GoogleFileDownloadAction.Input>{ input });
		Test.stopTest();

		Assert.areEqual(1, outputs.size(), 'Flow expects one output per input');
		Assert.areEqual('Report copy.pdf', outputs[0].fileName, 'The original extension is kept when the new name has none');
		Assert.areEqual(17L, outputs[0].fileSize);

		ContentVersion savedFile = (ContentVersion) uow.firstNew();
		Assert.areEqual('Report copy.pdf', savedFile.PathOnClient);
		Assert.areEqual(relatedRecordId, savedFile.FirstPublishLocationId);
	}

	@IsTest
	private static void testDownloadFilesNegativeSurfacesTheReason() {
		GoogleCloudTestFactory.initMocks();
		GoogleFileDownloadAction.transferServiceOverride = new GoogleLocalFileTransferService(new GoogleCapturingUnitOfWork());

		Test.startTest();
		try {
			GoogleFileDownloadAction.downloadFiles(new List<GoogleFileDownloadAction.Input>{ new GoogleFileDownloadAction.Input() });
			Assert.fail('The flow must fault with a readable message');
		} catch (GoogleLocalFileTransferService.GoogleLocalFileTransferException ex) {
			Assert.isTrue(ex.getMessage().contains('Provide a Google File Id'), ex.getMessage());
		}
		Test.stopTest();
	}

	@IsTest
	private static void testDownloadFilesPositiveNullInputs() {
		Test.startTest();
		List<GoogleFileDownloadAction.Output> outputs = GoogleFileDownloadAction.downloadFiles(null);
		Test.stopTest();

		Assert.areEqual(0, outputs.size());
	}

	@IsTest
	private static void testDownloadFilesPositiveEmptyInputs() {
		Test.startTest();
		List<GoogleFileDownloadAction.Output> outputs = GoogleFileDownloadAction.downloadFiles(new List<GoogleFileDownloadAction.Input>());
		Test.stopTest();

		Assert.areEqual(0, outputs.size());
	}
}
