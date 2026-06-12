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
private class GoogleFileVersionPreviewJobTest {
	private static void mockPreviewQuery(Id versionId) {
		GSOQL.mock(GoogleFileVersionSelector.MOCK_ID).thenReturn(new List<SObject>{
			[
				SELECT Id, Name, Summary__c, GoogleDriveFolderId__c, IsLatestFile__c, PublicLink__c, PublicLinkExpirationDate__c, PublicLinkPermissionId__c,
					CreatedDate, LastModifiedDate, IsPreviewableFile__c, GoogleFileId__c, GoogleDriveFileId__c, GoogleDocsFileId__c, Type__c, Size__c
				FROM GoogleFileVersion__c
				WHERE Id = :versionId
			]
		});
	}

	private static GoogleFileVersion__c createPreviewVersion(String fileName, String mimeType, String driveId, String docsId) {
		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName(fileName + '_Parent')
			.withDescription('D')
			.insertRecord();

		return GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName(fileName)
			.withType(mimeType)
			.withSize(1)
			.withDriveId(driveId)
			.withDocsId(docsId)
			.insertRecord();
	}

	private static GoogleFileVersion__c loadVersion(Id versionId) {
		return [
			SELECT GoogleDocsFileId__c
			FROM GoogleFileVersion__c
			WHERE Id = :versionId
			LIMIT 1
		];
	}

	@IsTest
	private static void testExecutePositiveWithPreviewableVersion() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(IsImageOcrEnabled__c = false);

		GoogleFileVersion__c version = createPreviewVersion('V1.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'GD_PJ_1', null);
		mockPreviewQuery(version.Id);

		Test.startTest();
		new GoogleFileVersionPreviewJob(new Set<Id>{ version.Id }).work();
		Test.stopTest();

		Assert.isTrue(String.isNotBlank(loadVersion(version.Id).GoogleDocsFileId__c));
	}

	@IsTest
	private static void testExecutePositiveWithPreviewablePdfVersion() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(IsImageOcrEnabled__c = false);

		GoogleFileVersion__c version = createPreviewVersion('VPDF.pdf', 'application/pdf', 'GD_PJ_PDF', null);
		mockPreviewQuery(version.Id);

		Test.startTest();
		new GoogleFileVersionPreviewJob(new Set<Id>{ version.Id }).work();
		Test.stopTest();

		Assert.isTrue(String.isNotBlank(loadVersion(version.Id).GoogleDocsFileId__c));
	}

	@IsTest
	private static void testExecutePositiveWithImagePreviewAndImageOcrDisabled() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(IsImageOcrEnabled__c = false);

		GTriggerHandler.setBypass('GoogleFileVersionTriggerHandler', true);
		GoogleFileVersion__c version = createPreviewVersion('Preview.png', 'image/png', 'GD_PJ_IMG_1', null);
		mockPreviewQuery(version.Id);
		GTriggerHandler.setBypass('GoogleFileVersionTriggerHandler', false);

		Test.startTest();
		new GoogleFileVersionPreviewJob(new Set<Id>{ version.Id }).work();
		Test.stopTest();

		Assert.isTrue(String.isNotBlank(loadVersion(version.Id).GoogleDocsFileId__c));

		Integer docsRequestCount = 0;
		for (GoogleDriveHttpMock.CapturedRequest capturedRequest : driveMock.getCapturedRequests()) {
			System.debug(capturedRequest.endpoint);
			if (capturedRequest.endpoint != null && capturedRequest.endpoint.contains('/v1/documents/')) {
				docsRequestCount++;
			}
		}

		Assert.areEqual(2, docsRequestCount);
	}

	@IsTest
	private static void testExecutePositiveWithImagePreviewAndImageOcrEnabled() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(IsImageOcrEnabled__c = true);

		GoogleFileVersion__c version = createPreviewVersion('PreviewEnabled.png', 'image/png', 'GD_PJ_IMG_2', null);
		mockPreviewQuery(version.Id);

		Test.startTest();
		new GoogleFileVersionPreviewJob(new Set<Id>{ version.Id }).work();
		Test.stopTest();

		Assert.isTrue(String.isNotBlank(loadVersion(version.Id).GoogleDocsFileId__c));

		for (GoogleDriveHttpMock.CapturedRequest capturedRequest : driveMock.getCapturedRequests()) {
			Assert.isFalse(capturedRequest.endpoint != null && capturedRequest.endpoint.contains('/v1/documents/'));
		}
	}

	@IsTest
	private static void testExecutePositiveWithImagePreviewCleanupFailure() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('POST')
				.endpointContains(':batchUpdate')
		).thenReturnStatus(500, '{"error":{"message":"Cleanup failed"}}');

		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(IsImageOcrEnabled__c = false);

		GoogleFileVersion__c version = createPreviewVersion('PreviewFailure.png', 'image/png', 'GD_PJ_IMG_3', null);
		mockPreviewQuery(version.Id);

		Test.startTest();
		new GoogleFileVersionPreviewJob(new Set<Id>{ version.Id }).work();
		Test.stopTest();

		Assert.isTrue(String.isNotBlank(loadVersion(version.Id).GoogleDocsFileId__c));
	}

	@IsTest
	private static void testExecutePositiveEmptyVersionIds() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(IsImageOcrEnabled__c = false);

		Test.startTest();
		new GoogleFileVersionPreviewJob(new Set<Id>()).work();
		Test.stopTest();

		Assert.isTrue(true);
	}

	@IsTest
	private static void testExecutePositiveNullVersionIds() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(IsImageOcrEnabled__c = false);

		Test.startTest();
		new GoogleFileVersionPreviewJob(null).work();
		Test.stopTest();

		Assert.isTrue(true);
	}

	@IsTest
	private static void testExecutePositiveAlreadyHasDocs() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(IsImageOcrEnabled__c = false);
		GoogleFileVersion__c version = createPreviewVersion('V2.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'GD_PJ_2', 'DOCS_PJ_2');
		mockPreviewQuery(version.Id);

		Test.startTest();
		new GoogleFileVersionPreviewJob(new Set<Id>{ version.Id }).work();
		Test.stopTest();

		Assert.areEqual('DOCS_PJ_2', loadVersion(version.Id).GoogleDocsFileId__c);
	}
}
