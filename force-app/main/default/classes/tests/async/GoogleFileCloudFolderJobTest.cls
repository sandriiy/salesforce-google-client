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
private class GoogleFileCloudFolderJobTest {
	@IsTest
	private static void testExecutePositiveNullRequest() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		GoogleCloudTestFactory.initMocks(driveMock);

		Test.startTest();
		new GoogleFileCloudFolderJob((List<GoogleFileRelocationRequestDTO>) null).work();
		Integer queuedJobs = Limits.getQueueableJobs();
		Test.stopTest();

		Assert.isTrue(driveMock.getCapturedRequests().isEmpty(), 'With nothing to place, Google Drive is never called');
		Assert.areEqual(0, queuedJobs, 'With nothing to place, no retry is scheduled');
	}

	@IsTest
	private static void testExecutePositiveEarlyReturnBlankDriveId() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('FJ1')
			.insertRecord();

		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('V1.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId(null)
			.withDocsId(null)
			.insertRecord();

		GSOQL.mock(GoogleFileVersionSelector.MOCK_ID).thenReturn(new List<SObject>{
			new GoogleFileVersion__c(
				Id = localFileVersion.Id,
				GoogleDriveFileId__c = '',
				GoogleDocsFileId__c = ''
			)
		});

		GoogleFileRelocationRequestDTO relocationRequest = new GoogleFileRelocationRequestDTO(
			UserInfo.getUserId(),
			parentFile.Id,
			localFileVersion.Id,
			null
		);

		Test.startTest();
		new GoogleFileCloudFolderJob(relocationRequest).work();
		Integer calloutsMade = Limits.getCallouts();
		Integer queuedJobs = Limits.getQueueableJobs();
		Test.stopTest();

		Assert.areEqual(0, calloutsMade, 'A version without a Drive file has nothing to move');
		Assert.areEqual(0, queuedJobs, 'A version without a Drive file is settled, not retried');
		Assert.isNull([SELECT GoogleDriveFolderId__c FROM GoogleFileVersion__c WHERE Id = :localFileVersion.Id].GoogleDriveFolderId__c);
	}

	@IsTest
	private static void testExecuteNegativeNullVersionId() {
		GoogleCloudTestFactory.initMocks();

		GoogleFileRelocationRequestDTO relocationRequest = new GoogleFileRelocationRequestDTO(
			UserInfo.getUserId(),
			GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType),
			null,
			GoogleCloudTestFactory.fakeId(GoogleFileLink__c.SObjectType)
		);

		try {
			Test.startTest();
			new GoogleFileCloudFolderJob(relocationRequest).work();
			Test.stopTest();
			Assert.isTrue(false);
		} catch (GoogleFileCloudFolderJob.GoogleFileCloudFolderJobException ex) {
			Assert.isTrue(ex.getMessage().contains('Unable to place the file into a folder'));
		}
	}
}