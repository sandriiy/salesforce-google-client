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
private class GoogleLocalFileVersionServiceTest {
	private static GoogleClientConfig__mdt buildPreviewConfig(Boolean previewDisabled, Long maxSizeBytes) {
		GoogleClientConfig__mdt config = new GoogleClientConfig__mdt();
		config.IsFilePreviewDisabled__c = previewDisabled;
		config.DefaultBigFileSize__c = maxSizeBytes;
		return config;
	}

	@IsTest
	private static void testDownloadPositive() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('VS2').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('V2.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId('GD_VS_2')
			.withDocsId('DOCS_VS_2')
			.insertRecord();

		Test.startTest();
		String base64Body = new GoogleLocalFileVersionService().downloadFileBase64Body(localFileVersion.Id);
		Test.stopTest();

		System.assert(String.isNotBlank(base64Body));
	}

	@IsTest
	private static void testDownloadPositiveRange() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('VS3').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('V3.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId('GD_VS_3')
			.withDocsId('DOCS_VS_3')
			.insertRecord();

		Test.startTest();
		String base64Body = new GoogleLocalFileVersionService().downloadFileBase64Body(localFileVersion.Id, 0L, 10L);
		Test.stopTest();

		System.assert(String.isNotBlank(base64Body));
	}

	@IsTest
	private static void testDownloadFileBase64BodyAsPdfPositivePdfType() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.queryContains('alt=media')
		).thenReturn(
			new GoogleDriveHttpMock.MockResponse()
				.withStatus(200)
				.withHeader('Content-Type', 'application/pdf')
				.withBodyAsBlob(Blob.valueOf('PDF-DIRECT'))
		);

		GoogleCloudTestFactory.initMocks(driveMock);

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('VS4').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('V4.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId('GD_VS_4')
			.withDocsId('DOCS_VS_4')
			.insertRecord();

		Test.startTest();
		String base64Body = new GoogleLocalFileVersionService().downloadFileBase64BodyAsPdf(localFileVersion.Id);
		Test.stopTest();

		Assert.areEqual(EncodingUtil.base64Encode(Blob.valueOf('PDF-DIRECT')), base64Body);
	}

	@IsTest
	private static void testDownloadFileBase64BodyAsPdfPositiveExport() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.endpointContains('/export')
		).thenReturn(
			new GoogleDriveHttpMock.MockResponse()
				.withStatus(200)
				.withHeader('Content-Type', 'application/pdf')
				.withBodyAsBlob(Blob.valueOf('PDF-EXPORTED'))
		);

		GoogleCloudTestFactory.initMocks(driveMock);

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('VS5').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('V5.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(1)
			.withDriveId('GD_VS_5')
			.withDocsId('DOCS_VS_5')
			.insertRecord();

		Test.startTest();
		String base64Body = new GoogleLocalFileVersionService().downloadFileBase64BodyAsPdf(localFileVersion.Id);
		Test.stopTest();

		Assert.areEqual(EncodingUtil.base64Encode(Blob.valueOf('PDF-EXPORTED')), base64Body);
	}

	@IsTest
	private static void testRetrieveDownloadAsOptionsPositiveDocument() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildPreviewConfig(false, 1000L);

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('DA1').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('Proposal.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(50)
			.withDriveId('GD_DA_1')
			.withDocsId('DOCS_DA_1')
			.insertRecord();

		Test.startTest();
		List<GoogleFileDownloadAsOptionDTO> options = new GoogleLocalFileVersionService().retrieveDownloadAsOptions(localFileVersion.Id);
		Test.stopTest();

		Assert.areEqual(8, options.size());
		Assert.areEqual('Microsoft Word (.docx)', options[0].label);
		Assert.areEqual('application/vnd.openxmlformats-officedocument.wordprocessingml.document', options[0].mimeType);
		Assert.areEqual('Proposal.docx', options[0].fileName);
		Assert.areEqual('Markdown (.md)', options[7].label);
		Assert.areEqual('Proposal.md', options[7].fileName);
	}

	@IsTest
	private static void testRetrieveDownloadAsOptionsPositiveSpreadsheet() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildPreviewConfig(false, 1000L);

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('DA2').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('Revenue.xlsx')
			.withType('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
			.withSize(50)
			.withDriveId('GD_DA_2')
			.withDocsId('DOCS_DA_2')
			.insertRecord();

		Test.startTest();
		List<GoogleFileDownloadAsOptionDTO> options = new GoogleLocalFileVersionService().retrieveDownloadAsOptions(localFileVersion.Id);
		Test.stopTest();

		Assert.areEqual(6, options.size());
		Assert.areEqual('Microsoft Excel (.xlsx)', options[0].label);
		Assert.areEqual('Revenue.xlsx', options[0].fileName);
		Assert.areEqual('Tab Separated Values (.tsv)', options[5].label);
		Assert.areEqual('Revenue.tsv', options[5].fileName);
	}

	@IsTest
	private static void testRetrieveDownloadAsOptionsNegativeMissingGoogleDocsFile() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildPreviewConfig(false, 1000L);

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('DA3').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('Contract.pdf')
			.withType('application/pdf')
			.withSize(50)
			.withDriveId('GD_DA_3')
			.withDocsId(null)
			.insertRecord();

		Test.startTest();
		List<GoogleFileDownloadAsOptionDTO> options = new GoogleLocalFileVersionService().retrieveDownloadAsOptions(localFileVersion.Id);
		Test.stopTest();

		Assert.areEqual(0, options.size());
	}


	@IsTest
	private static void testDownloadFileBase64BodyAsPositiveDocumentExportType() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.endpointContains('/export')
		).thenReturn(
			new GoogleDriveHttpMock.MockResponse()
				.withStatus(200)
				.withHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document')
				.withBodyAsBlob(Blob.valueOf('DOCX-EXPORTED'))
		);

		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildPreviewConfig(false, 1000L);

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('DA4').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('Minutes.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(50)
			.withDriveId('GD_DA_4')
			.withDocsId('DOCS_DA_4')
			.insertRecord();

		Test.startTest();
		String base64Body = new GoogleLocalFileVersionService().downloadFileBase64BodyAs(localFileVersion.Id, 'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
		Test.stopTest();

		Assert.areEqual(EncodingUtil.base64Encode(Blob.valueOf('DOCX-EXPORTED')), base64Body);
	}

	@IsTest
	private static void testDownloadFileBase64BodyAsNegativeUnsupportedFormat() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildPreviewConfig(false, 1000L);

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('DA5').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('Minutes.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(50)
			.withDriveId('GD_DA_5')
			.withDocsId('DOCS_DA_5')
			.insertRecord();

		Test.startTest();
		try {
			new GoogleLocalFileVersionService().downloadFileBase64BodyAs(localFileVersion.Id, 'application/octet-stream');
			Assert.isTrue(false);
		} catch (GoogleLocalFileVersionService.GoogleFileVersionException ex) {
			Assert.isTrue(ex.getMessage().contains('selected download format is unavailable'));
		}
		Test.stopTest();
	}

	@IsTest
	private static void testValidatePreviewEligiblePositiveDirect() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildPreviewConfig(false, 1000L);

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('PV1').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('PV1.pdf')
			.withType('application/pdf')
			.withSize(50)
			.withDriveId('GD_PV_1')
			.withDocsId('DOCS_PV_1')
			.insertRecord();

		Test.startTest();
		GoogleFilePreviewAction action = new GoogleLocalFileVersionService().validatePreviewEligible(localFileVersion.Id);
		Test.stopTest();

		Assert.areEqual(GoogleFilePreviewAction.DIRECT, action);
	}

	@IsTest
	private static void testValidatePreviewEligiblePositiveConvert() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildPreviewConfig(false, 1000L);

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('PV2').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('PV2.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(50)
			.withDriveId('GD_PV_2')
			.withDocsId('DOCS_READY_2')
			.insertRecord();

		Test.startTest();
		GoogleFilePreviewAction action = new GoogleLocalFileVersionService().validatePreviewEligible(localFileVersion.Id);
		Test.stopTest();

		Assert.areEqual(GoogleFilePreviewAction.CONVERT, action);
	}

	@IsTest
	private static void testValidatePreviewEligibleNegativePreviewDisabled() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildPreviewConfig(true, 1000L);

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('PV3').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('PV3.pdf')
			.withType('application/pdf')
			.withSize(10)
			.withDriveId('GD_PV_3')
			.insertRecord();

		Test.startTest();
		try {
			new GoogleLocalFileVersionService().validatePreviewEligible(localFileVersion.Id);
			Assert.isTrue(false);
		} catch (GoogleLocalFileVersionService.GoogleFileVersionException ex) {
			Assert.isTrue(ex.getMessage().contains('Preview Unavailable'));
		}
		Test.stopTest();
	}

	@IsTest
	private static void testValidatePreviewEligibleNegativeTooLarge() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildPreviewConfig(false, 10L);

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('PV4').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('PV4.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(200)
			.withDriveId('GD_PV_4')
			.withDocsId('DOCS_READY_4')
			.insertRecord();

		Test.startTest();
		try {
			new GoogleLocalFileVersionService().validatePreviewEligible(localFileVersion.Id);
			Assert.isTrue(false);
		} catch (GoogleLocalFileVersionService.GoogleFileVersionException ex) {
			Assert.isTrue(ex.getMessage().contains('too large to preview'));
		}
		Test.stopTest();
	}

	@IsTest
	private static void testValidatePreviewEligibleNegativeInProgress() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildPreviewConfig(false, 1000L);

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('PV5').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('PV5.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(5)
			.withDriveId('GD_PV_5')
			.withDocsId(null)
			.insertRecord();

		Test.startTest();
		try {
			new GoogleLocalFileVersionService().validatePreviewEligible(localFileVersion.Id);
			Assert.isTrue(false);
		} catch (GoogleLocalFileVersionService.GoogleFileVersionException ex) {
			Assert.isTrue(ex.getMessage().contains('Preview is being prepared'));
		}
		Test.stopTest();
	}

	@IsTest
	private static void testValidatePreviewEligibleNegativeUnavailable() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildPreviewConfig(false, 1000L);

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('PV6').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('PV6.bin')
			.withType('application/octet-stream')
			.withSize(5)
			.withDriveId('GD_PV_6')
			.withDocsId(null)
			.insertRecord();

		Test.startTest();
		try {
			new GoogleLocalFileVersionService().validatePreviewEligible(localFileVersion.Id);
			Assert.isTrue(false);
		} catch (GoogleLocalFileVersionService.GoogleFileVersionException ex) {
			Assert.isTrue(ex.getMessage().contains('Preview unavailable for the selected file type'));
		}
		Test.stopTest();
	}

}