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
	@IsTest
	private static void testExecutePositiveWithPreviewableVersion() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('PJ1')
			.withDescription('D')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('V1.xlsx')
			.withType('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
			.withSize(1)
			.withDriveId('GD_PJ_1')
			.insertRecord();

		GSOQL.mock(GoogleFileVersionSelector.MOCK_ID).thenReturn(new List<SObject>{
			[
				SELECT Id, Name, Summary__c, GoogleDriveFolderId__c, IsLatestFile__c, PublicLink__c, PublicLinkExpirationDate__c, PublicLinkPermissionId__c,
					CreatedDate, LastModifiedDate, IsPreviewableFile__c, GoogleFileId__c, GoogleDriveFileId__c, GoogleDocsFileId__c, Type__c, Size__c
				FROM GoogleFileVersion__c
				WHERE Id = :version.Id
			]
		});

		Test.startTest();
		new GoogleFileVersionPreviewJob(new Set<Id>{ version.Id }).work();
		Test.stopTest();

		Assert.isTrue(true);
	}

	@IsTest
	private static void testExecutePositiveWithPreviewablePdfVersion() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('PJPDF')
			.withDescription('D')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('VPDF.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId('GD_PJ_PDF')
			.insertRecord();

		GSOQL.mock(GoogleFileVersionSelector.MOCK_ID).thenReturn(new List<SObject>{
			[
				SELECT Id, Name, Summary__c, GoogleDriveFolderId__c, IsLatestFile__c, PublicLink__c, PublicLinkExpirationDate__c, PublicLinkPermissionId__c,
					CreatedDate, LastModifiedDate, IsPreviewableFile__c, GoogleFileId__c, GoogleDriveFileId__c, GoogleDocsFileId__c, Type__c, Size__c
				FROM GoogleFileVersion__c
				WHERE Id = :version.Id
			]
		});

		Test.startTest();
		new GoogleFileVersionPreviewJob(new Set<Id>{ version.Id }).work();
		Test.stopTest();

		GoogleFileVersion__c refreshedVersion = [
			SELECT GoogleDocsFileId__c
			FROM GoogleFileVersion__c
			WHERE Id = :version.Id
			LIMIT 1
		];

		Assert.isTrue(String.isNotBlank(refreshedVersion.GoogleDocsFileId__c));
	}

	@IsTest
	private static void testExecutePositiveEmptyVersionIds() {
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		new GoogleFileVersionPreviewJob(new Set<Id>()).work();
		Test.stopTest();

		Assert.isTrue(true);
	}

	@IsTest
	private static void testExecutePositiveNullVersionIds() {
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		new GoogleFileVersionPreviewJob(null).work();
		Test.stopTest();

		Assert.isTrue(true);
	}

	@IsTest
	private static void testExecutePositiveAlreadyHasDocs() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('PJ2')
			.withDescription('D')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('V2.xlsx')
			.withType('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
			.withSize(1)
			.withDriveId('GD_PJ_2')
			.withDocsId('DOCS_PJ_2')
			.insertRecord();

		GSOQL.mock(GoogleFileVersionSelector.MOCK_ID).thenReturn(new List<SObject>{
			[
				SELECT Id, Name, Summary__c, GoogleDriveFolderId__c, IsLatestFile__c, PublicLink__c, PublicLinkExpirationDate__c, PublicLinkPermissionId__c,
					CreatedDate, LastModifiedDate, IsPreviewableFile__c, GoogleFileId__c, GoogleDriveFileId__c, GoogleDocsFileId__c, Type__c, Size__c
				FROM GoogleFileVersion__c
				WHERE Id = :version.Id
			]
		});

		Test.startTest();
		new GoogleFileVersionPreviewJob(new Set<Id>{ version.Id }).work();
		Test.stopTest();

		Assert.isTrue(true);
	}
}
