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
private class GoogleFileCloudDeleteJobTest {
	private static GoogleClientConfig__mdt buildDeleteConfig() {
		return new GoogleClientConfig__mdt(
			MaxDeleteChainSize__c = 10
		);
	}

	private static List<String> collectTrashedDriveIds(GoogleDriveHttpMock driveMock) {
		List<String> trashedDriveIds = new List<String>();
		for (GoogleDriveHttpMock.CapturedRequest capturedRequest : driveMock.getCapturedRequests()) {
			String endpoint = capturedRequest.endpoint == null ? '' : capturedRequest.endpoint;
			if (capturedRequest.method != 'POST' || !endpoint.contains('/trash')) continue;

			trashedDriveIds.add(endpoint.substringAfter('/files/').substringBefore('/trash'));
		}

		return trashedDriveIds;
	}

	@IsTest
	private static void testExecutePositiveEmptyList() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildDeleteConfig();

		Test.startTest();
		new GoogleFileCloudDeleteJob(new List<String>()).execute(null);
		Integer chainedJobs = Limits.getQueueableJobs();
		Test.stopTest();

		Assert.isTrue(driveMock.getCapturedRequests().isEmpty(), 'Nothing to delete means Google Drive is never called');
		Assert.areEqual(0, chainedJobs);
	}

	@IsTest
	private static void testExecutePositiveSingleId() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildDeleteConfig();

		List<String> googleDriveIds = new List<String>{ 'GD_1' };

		Test.startTest();
		new GoogleFileCloudDeleteJob(googleDriveIds).execute(null);
		Integer chainedJobs = Limits.getQueueableJobs();
		Test.stopTest();

		Assert.areEqual(new List<String>{ 'GD_1' }, collectTrashedDriveIds(driveMock));
		Assert.areEqual(0, chainedJobs, 'A batch within the chain size is finished by a single job');
	}

	@IsTest
	private static void testExecutePositiveFromVersions() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildDeleteConfig();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('DJ1').insertRecord();
		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withDriveId('GD_DEL_1')
			.withDocsId('DOCS_DEL_1')
			.insertRecord();

		List<GoogleFileVersion__c> versions = [
			SELECT Id, GoogleDriveFileId__c, GoogleDocsFileId__c
			FROM GoogleFileVersion__c
			WHERE Id = :version.Id
		];

		Test.startTest();
		new GoogleFileCloudDeleteJob(versions).execute(null);
		Test.stopTest();

		Assert.areEqual(new List<String>{ 'GD_DEL_1', 'DOCS_DEL_1' }, collectTrashedDriveIds(driveMock), 'The upload and its Workspace copy are both trashed');
	}

	@IsTest
	private static void testExecutePositiveFromIdSet() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildDeleteConfig();

		Set<String> googleDriveIds = new Set<String>{ 'GD_SET_1', 'GD_SET_2' };

		Test.startTest();
		new GoogleFileCloudDeleteJob(googleDriveIds).execute(null);
		Test.stopTest();

		List<String> trashedDriveIds = collectTrashedDriveIds(driveMock);
		Assert.areEqual(googleDriveIds.size(), trashedDriveIds.size());
		Assert.areEqual(googleDriveIds, new Set<String>(trashedDriveIds));
	}

	@IsTest
	private static void testExecutePositiveNullInputs() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildDeleteConfig();

		Test.startTest();
		new GoogleFileCloudDeleteJob((List<GoogleFileVersion__c>) null).execute(null);
		new GoogleFileCloudDeleteJob((Set<String>) null).execute(null);
		new GoogleFileCloudDeleteJob((List<String>) null).execute(null);
		Integer chainedJobs = Limits.getQueueableJobs();
		Test.stopTest();

		Assert.isTrue(driveMock.getCapturedRequests().isEmpty(), 'Nothing to delete means Google Drive is never called');
		Assert.areEqual(0, chainedJobs);
	}
}