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
private class GoogleFileVersionPreviewSizeJobTest {
	private static final String DOCX_MIME_TYPE = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

	private static GoogleFileVersion__c createVersion(String fileName, String driveId, String docsId, Long docsSize) {
		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName(fileName + '_Parent')
			.withDescription('D')
			.insertRecord();

		return GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName(fileName)
			.withType(DOCX_MIME_TYPE)
			.withSize(5000000)
			.withDriveId(driveId)
			.withDocsId(docsId)
			.withDocsSize(docsSize)
			.insertRecord();
	}

	private static GoogleDriveHttpMock mockPreviewSize(String docsId, String size) {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.endpointContains('/files/' + docsId)
		).thenReturn(new GoogleDriveHttpMock.JsonResponses().fileSizeSuccess(docsId, size));

		return driveMock;
	}

	private static GoogleFileVersion__c loadVersion(Id versionId) {
		return [
			SELECT GoogleDocsFileSize__c
			FROM GoogleFileVersion__c
			WHERE Id = :versionId
			LIMIT 1
		];
	}

	private static Integer countRequestsFor(GoogleDriveHttpMock driveMock, String docsId) {
		Integer requests = 0;
		for (GoogleDriveHttpMock.CapturedRequest capturedRequest : driveMock.getCapturedRequests()) {
			if (capturedRequest.endpoint != null && capturedRequest.endpoint.contains('/files/' + docsId)) {
				requests++;
			}
		}

		return requests;
	}

	@IsTest
	private static void testExecutePositiveStoresMeasuredPreviewSize() {
		GoogleDriveHttpMock driveMock = mockPreviewSize('DOCS_PS_1', '4335');
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleFileVersion__c version = createVersion('PS1.docx', 'GD_PS_1', 'DOCS_PS_1', null);

		Test.startTest();
		new GoogleFileVersionPreviewSizeJob(new Set<Id>{ version.Id }).work();
		Integer rescheduledJobs = Limits.getQueueableJobs();
		Test.stopTest();

		Assert.areEqual(4335, loadVersion(version.Id).GoogleDocsFileSize__c);
		Assert.areEqual(1, countRequestsFor(driveMock, 'DOCS_PS_1'));
		Assert.areEqual(0, rescheduledJobs);
	}

	@IsTest
	private static void testExecutePositiveReschedulesWhileConversionPending() {
		GoogleDriveHttpMock driveMock = mockPreviewSize('DOCS_PS_2', '1');
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleFileVersion__c version = createVersion('PS2.docx', 'GD_PS_2', 'DOCS_PS_2', null);

		Test.startTest();
		new GoogleFileVersionPreviewSizeJob(new Set<Id>{ version.Id }).work();
		Integer rescheduledJobs = Limits.getQueueableJobs();
		GoogleFileVersionPreviewSizeJob.skipExecution = true;
		Test.stopTest();

		Assert.isNull(loadVersion(version.Id).GoogleDocsFileSize__c);
		Assert.areEqual(1, rescheduledJobs);
	}

	@IsTest
	private static void testExecutePositiveStopsReschedulingAfterLastAttempt() {
		GoogleDriveHttpMock driveMock = mockPreviewSize('DOCS_PS_3', '1');
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleFileVersion__c version = createVersion('PS3.docx', 'GD_PS_3', 'DOCS_PS_3', null);

		Test.startTest();
		new GoogleFileVersionPreviewSizeJob(new Set<Id>{ version.Id }, 3).work();
		Integer rescheduledJobs = Limits.getQueueableJobs();
		Test.stopTest();

		Assert.isNull(loadVersion(version.Id).GoogleDocsFileSize__c);
		Assert.areEqual(0, rescheduledJobs);
	}

	@IsTest
	private static void testExecutePositiveSkipsAlreadyMeasuredVersion() {
		GoogleDriveHttpMock driveMock = mockPreviewSize('DOCS_PS_4', '9999');
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleFileVersion__c version = createVersion('PS4.docx', 'GD_PS_4', 'DOCS_PS_4', 700);

		Test.startTest();
		new GoogleFileVersionPreviewSizeJob(new Set<Id>{ version.Id }).work();
		Integer rescheduledJobs = Limits.getQueueableJobs();
		Test.stopTest();

		Assert.areEqual(700, loadVersion(version.Id).GoogleDocsFileSize__c);
		Assert.areEqual(0, countRequestsFor(driveMock, 'DOCS_PS_4'));
		Assert.areEqual(0, rescheduledJobs);
	}

	@IsTest
	private static void testExecutePositiveSkipsVersionWithoutWorkspaceCopy() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleFileVersion__c version = createVersion('PS5.docx', 'GD_PS_5', null, null);

		Test.startTest();
		new GoogleFileVersionPreviewSizeJob(new Set<Id>{ version.Id }).work();
		Integer rescheduledJobs = Limits.getQueueableJobs();
		Integer driveRequests = driveMock.getCapturedRequests().size();
		Test.stopTest();

		Assert.isNull(loadVersion(version.Id).GoogleDocsFileSize__c);
		Assert.areEqual(0, driveRequests);
		Assert.areEqual(0, rescheduledJobs);
	}

	@IsTest
	private static void testExecuteNegativeDriveErrorLeavesSizeBlankAndReschedules() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.endpointContains('/files/DOCS_PS_6')
		).thenReturnStatus(500, '{ "error": { "message": "Backend Error" } }');
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleFileVersion__c version = createVersion('PS6.docx', 'GD_PS_6', 'DOCS_PS_6', null);

		Test.startTest();
		new GoogleFileVersionPreviewSizeJob(new Set<Id>{ version.Id }).work();
		Integer rescheduledJobs = Limits.getQueueableJobs();
		GoogleFileVersionPreviewSizeJob.skipExecution = true;
		Test.stopTest();

		Assert.isNull(loadVersion(version.Id).GoogleDocsFileSize__c);
		Assert.areEqual(1, rescheduledJobs);
	}

	@IsTest
	private static void testExecutePositiveEmptyVersionIds() {
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		new GoogleFileVersionPreviewSizeJob(new Set<Id>()).work();
		Integer rescheduledJobs = Limits.getQueueableJobs();
		Test.stopTest();

		Assert.areEqual(0, rescheduledJobs);
	}

	@IsTest
	private static void testExecutePositiveNullVersionIds() {
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		new GoogleFileVersionPreviewSizeJob(null).work();
		Integer rescheduledJobs = Limits.getQueueableJobs();
		Test.stopTest();

		Assert.areEqual(0, rescheduledJobs);
	}
}
