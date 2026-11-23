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
	private static final String DOCX_MIME_TYPE = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
	private static final Integer INSIDE_RECENT_WINDOW_MINUTES = 19;
	private static final Integer PAST_RECENT_WINDOW_MINUTES = 21;
	private static final String PREVIEWS_OFF_TEXT_MESSAGE = 'Text is not available for this file while file previews are turned off.';
	private static final String RAW_UPLOAD_TEXT = 'mock file content';

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

		Assert.isTrue(String.isNotBlank(base64Body));
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

		Assert.isTrue(String.isNotBlank(base64Body));
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
	private static void testValidatePreviewEligiblePositiveDirectImage() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildPreviewConfig(false, 1000L);

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('PVI1').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('PVI1.png')
			.withType('image/png')
			.withSize(5000000)
			.withDriveId('GD_PVI_1')
			.withDocsId(null)
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
		Test.setCreatedDate(localFileVersion.Id, Datetime.now().addMinutes(-PAST_RECENT_WINDOW_MINUTES));

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
			.withName('PV3.docx')
			.withType(DOCX_MIME_TYPE)
			.withSize(10)
			.withDriveId('GD_PV_3')
			.withDocsId('DOCS_OLDER_COPY_3')
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
		Test.setCreatedDate(localFileVersion.Id, Datetime.now().addMinutes(-PAST_RECENT_WINDOW_MINUTES));

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

	@IsTest
	private static void testValidatePreviewEligiblePositiveConvertUsesWorkspaceSizeWhenUploadedFileTooLarge() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildPreviewConfig(false, 10L);

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('PV7').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('PV7.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(200)
			.withDriveId('GD_PV_7')
			.withDocsId('DOCS_READY_7')
			.withDocsSize(5)
			.insertRecord();

		Test.startTest();
		GoogleFilePreviewAction action = new GoogleLocalFileVersionService().validatePreviewEligible(localFileVersion.Id);
		Test.stopTest();

		Assert.areEqual(GoogleFilePreviewAction.CONVERT, action);
	}

	@IsTest
	private static void testValidatePreviewEligibleNegativeTooLargeByWorkspaceSize() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildPreviewConfig(false, 10L);

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('PV8').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('PV8.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(5)
			.withDriveId('GD_PV_8')
			.withDocsId('DOCS_READY_8')
			.withDocsSize(200)
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
	private static void testValidatePreviewEligiblePositiveDirectIgnoresWorkspaceSize() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildPreviewConfig(false, 10L);

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('PV9').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('PV9.pdf')
			.withType('application/pdf')
			.withSize(5)
			.withDriveId('GD_PV_9')
			.withDocsId('DOCS_READY_9')
			.withDocsSize(200)
			.insertRecord();

		Test.startTest();
		GoogleFilePreviewAction action = new GoogleLocalFileVersionService().validatePreviewEligible(localFileVersion.Id);
		Test.stopTest();

		Assert.areEqual(GoogleFilePreviewAction.DIRECT, action);
	}

	private static GoogleFileVersion__c insertVersion(String fileName, String mimeType, String docsId, Long sizeBytes, Long docsSizeBytes, Integer ageMinutes) {
		GoogleCloudTestFactory.bypassTriggers();
		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName(fileName).withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName(fileName)
			.withType(mimeType)
			.withSize(sizeBytes)
			.withDriveId('GD_' + fileName)
			.withDocsId(docsId)
			.withDocsSize(docsSizeBytes)
			.insertRecord();

		if (ageMinutes != null) {
			Test.setCreatedDate(localFileVersion.Id, Datetime.now().addMinutes(-ageMinutes));
		}

		return localFileVersion;
	}

	private static String previewRefusal(Id localFileVersionId) {
		try {
			new GoogleLocalFileVersionService().validatePreviewEligible(localFileVersionId);
			return null;
		} catch (GoogleLocalFileVersionService.GoogleFileVersionException ex) {
			return ex.getMessage();
		}
	}

	private static String extractionRefusal(Id localFileVersionId) {
		GoogleFileTextExtractRequestDTO request = new GoogleFileTextExtractRequestDTO();
		request.googleFileVersionId = localFileVersionId;

		try {
			new GoogleLocalFileVersionService().extractText(request);
			return null;
		} catch (GoogleLocalFileVersionService.GoogleFileVersionException ex) {
			return ex.getMessage();
		}
	}

	private static Integer countExports(GoogleDriveHttpMock driveMock) {
		Integer exports = 0;
		for (GoogleDriveHttpMock.CapturedRequest capturedRequest : driveMock.getCapturedRequests()) {
			if (capturedRequest.endpoint != null && capturedRequest.endpoint.toLowerCase().contains('/export')) exports++;
		}

		return exports;
	}

	@IsTest
	private static void testValidatePreviewEligiblePositivePdfPreviewsWhilePreviewsAreOff() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildPreviewConfig(true, 1000L);
		GoogleFileVersion__c localFileVersion = insertVersion('OFFPDF.pdf', GoogleCloudConstants.MIME_TYPE_PDF, null, 10L, null, null);

		Test.startTest();
		GoogleFilePreviewAction action = new GoogleLocalFileVersionService().validatePreviewEligible(localFileVersion.Id);
		Test.stopTest();

		Assert.areEqual(GoogleFilePreviewAction.DIRECT, action, 'A PDF never needed a copy, so it keeps its preview while files are stored only');
	}

	@IsTest
	private static void testValidatePreviewEligiblePositiveImagePreviewsWhilePreviewsAreOff() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildPreviewConfig(true, 1000L);
		GoogleFileVersion__c localFileVersion = insertVersion('OFFIMG.png', GoogleCloudConstants.MIME_TYPE_PNG, null, 10L, null, null);

		Test.startTest();
		GoogleFilePreviewAction action = new GoogleLocalFileVersionService().validatePreviewEligible(localFileVersion.Id);
		Test.stopTest();

		Assert.areEqual(GoogleFilePreviewAction.DIRECT, action);
	}

	@IsTest
	private static void testValidatePreviewEligibleNegativeUnknownVersionIsRefusedWhilePreviewsAreOff() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildPreviewConfig(true, 1000L);

		Test.startTest();
		String refusal = previewRefusal(GoogleCloudTestFactory.fakeId(GoogleFileVersion__c.SObjectType));
		Test.stopTest();

		Assert.isNotNull(refusal, 'A version that does not exist is refused before anything else');
	}

	@IsTest
	private static void testValidatePreviewEligibleNegativeImagesLightningCannotShowAreUnavailableAtOnce() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildPreviewConfig(false, 1000L);
		GoogleFileVersion__c svgVersion = insertVersion('NOPV.svg', GoogleCloudConstants.MIME_TYPE_SVG, null, 10L, null, INSIDE_RECENT_WINDOW_MINUTES);
		GoogleFileVersion__c tiffVersion = insertVersion('NOPV.tiff', GoogleCloudConstants.MIME_TYPE_TIFF, null, 10L, null, INSIDE_RECENT_WINDOW_MINUTES);

		Test.startTest();
		String svgRefusal = previewRefusal(svgVersion.Id);
		String tiffRefusal = previewRefusal(tiffVersion.Id);
		String svgTextRefusal = extractionRefusal(svgVersion.Id);
		Test.stopTest();

		Assert.isTrue(svgRefusal != null && svgRefusal.contains('Preview unavailable for the selected file type'), 'Lightning refuses to show an SVG and nothing converts it');
		Assert.isTrue(tiffRefusal != null && tiffRefusal.contains('Preview unavailable for the selected file type'), 'A browser cannot draw a TIFF and nothing converts it');
		Assert.isFalse(svgTextRefusal != null && svgTextRefusal.contains('preparing'), 'No copy is ever made of an SVG, so its text is never said to be on its way');
	}

	@IsTest
	private static void testValidatePreviewEligiblePositiveWebpIsStillShownByTheBrowser() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildPreviewConfig(false, 1000L);
		GoogleFileVersion__c webpVersion = insertVersion('PV.webp', GoogleCloudConstants.MIME_TYPE_WEBP, null, 10L, null, PAST_RECENT_WINDOW_MINUTES);

		Test.startTest();
		GoogleFilePreviewAction action = new GoogleLocalFileVersionService().validatePreviewEligible(webpVersion.Id);
		Test.stopTest();

		Assert.areEqual(GoogleFilePreviewAction.DIRECT, action);
	}

	@IsTest
	private static void testValidatePreviewEligibleNegativeRecentVersionWithoutACopyIsBeingPrepared() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildPreviewConfig(false, 1000L);
		GoogleFileVersion__c localFileVersion = insertVersion('RCNT.docx', DOCX_MIME_TYPE, null, 10L, null, INSIDE_RECENT_WINDOW_MINUTES);

		Test.startTest();
		String refusal = previewRefusal(localFileVersion.Id);
		Test.stopTest();

		Assert.isTrue(refusal != null && refusal.contains('Preview is being prepared'), 'Within twenty minutes the copy may still arrive');
	}

	@IsTest
	private static void testValidatePreviewEligibleNegativeOlderVersionWithoutACopyIsUnavailable() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildPreviewConfig(false, 1000L);
		GoogleFileVersion__c localFileVersion = insertVersion('OLDR.docx', DOCX_MIME_TYPE, null, 10L, null, PAST_RECENT_WINDOW_MINUTES);

		Test.startTest();
		String refusal = previewRefusal(localFileVersion.Id);
		Test.stopTest();

		Assert.isTrue(refusal != null && refusal.contains('Preview unavailable for this file. Please download it to open'), 'An older version without a copy no longer says it is being prepared for good');
		Assert.isFalse(refusal.contains('being prepared'));
	}

	@IsTest
	private static void testValidatePreviewEligibleNegativeRecentUnmeasuredCopyIsBeingPreparedNotTooLarge() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildPreviewConfig(false, 10L);
		GoogleFileVersion__c localFileVersion = insertVersion('RCNTCPY.docx', DOCX_MIME_TYPE, 'DOCS_UNMEASURED', 200L, null, INSIDE_RECENT_WINDOW_MINUTES);

		Test.startTest();
		String refusal = previewRefusal(localFileVersion.Id);
		Test.stopTest();

		Assert.isTrue(refusal != null && refusal.contains('Preview is being prepared'), 'A fresh upload is never "too large" before its copy is measured');
		Assert.isFalse(refusal.contains('too large'));
	}

	@IsTest
	private static void testValidatePreviewEligibleNegativeRecentUploadWithoutACopyIsBeingPreparedNotTooLarge() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildPreviewConfig(false, 10L);
		GoogleFileVersion__c localFileVersion = insertVersion('RCNTBIG.docx', DOCX_MIME_TYPE, null, 200L, null, null);

		Test.startTest();
		String refusal = previewRefusal(localFileVersion.Id);
		Test.stopTest();

		Assert.isTrue(refusal != null && refusal.contains('Preview is being prepared'), 'The first seconds of a large upload say "being prepared" too');
		Assert.isFalse(refusal.contains('too large'));
	}

	@IsTest
	private static void testRetrieveDownloadAsOptionsNegativeNoneWhilePreviewsAreOff() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildPreviewConfig(true, 1000L);
		GoogleFileVersion__c localFileVersion = insertVersion('OFFDA.docx', DOCX_MIME_TYPE, 'DOCS_OLDER_COPY', 10L, 10L, PAST_RECENT_WINDOW_MINUTES);

		Test.startTest();
		List<GoogleFileDownloadAsOptionDTO> options = new GoogleLocalFileVersionService().retrieveDownloadAsOptions(localFileVersion.Id);
		Test.stopTest();

		Assert.isTrue(options.isEmpty(), 'Download As is not offered for any file while files are stored only, older copies included');
	}

	@IsTest
	private static void testDownloadFileBase64BodyAsNegativeRefusedWhilePreviewsAreOff() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildPreviewConfig(true, 1000L);
		GoogleFileVersion__c localFileVersion = insertVersion('OFFDAX.docx', DOCX_MIME_TYPE, 'DOCS_OLDER_COPY', 10L, 10L, PAST_RECENT_WINDOW_MINUTES);

		Exception refusal;
		Test.startTest();
		try {
			new GoogleLocalFileVersionService().downloadFileBase64BodyAs(localFileVersion.Id, GoogleCloudConstants.MIME_TYPE_PDF);
		} catch (Exception ex) {
			refusal = ex;
		}
		Test.stopTest();

		Assert.isNotNull(refusal, 'The server refuses a Download As even when it is called directly');
		Assert.isTrue(refusal.getMessage().contains('download format is unavailable'), refusal.getMessage());
		Assert.areEqual(0, countExports(driveMock), 'Nothing is read from the older copy');
	}

	@IsTest
	private static void testDownloadFileBase64BodyAsPdfNegativeConvertedExportRefusedWhilePreviewsAreOff() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildPreviewConfig(true, 1000L);
		GoogleFileVersion__c localFileVersion = insertVersion('OFFPDFX.docx', DOCX_MIME_TYPE, 'DOCS_OLDER_COPY', 10L, 10L, PAST_RECENT_WINDOW_MINUTES);

		Exception refusal;
		Test.startTest();
		try {
			new GoogleLocalFileVersionService().downloadFileBase64BodyAsPdf(localFileVersion.Id);
		} catch (Exception ex) {
			refusal = ex;
		}
		Test.stopTest();

		Assert.isNotNull(refusal, 'A converted export is refused on the server while files are stored only');
		Assert.areEqual(0, countExports(driveMock));
	}

	@IsTest
	private static void testDownloadFileBase64BodyAsPdfPositivePdfStillDownloadsWhilePreviewsAreOff() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.queryContains('alt=media')
		).thenReturn(
			new GoogleDriveHttpMock.MockResponse()
				.withStatus(200)
				.withHeader('Content-Type', 'application/pdf')
				.withBodyAsBlob(Blob.valueOf('PDF-ORIGINAL'))
		);
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildPreviewConfig(true, 1000L);
		GoogleFileVersion__c localFileVersion = insertVersion('OFFORIG.pdf', GoogleCloudConstants.MIME_TYPE_PDF, null, 10L, null, null);

		Test.startTest();
		String base64Body = new GoogleLocalFileVersionService().downloadFileBase64BodyAsPdf(localFileVersion.Id);
		Test.stopTest();

		Assert.areEqual(EncodingUtil.base64Encode(Blob.valueOf('PDF-ORIGINAL')), base64Body, 'A PDF\'s own content still opens and downloads');
	}

	@IsTest
	private static void testDownloadPositiveOriginalStillDownloadsWhilePreviewsAreOff() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildPreviewConfig(true, 1000L);
		GoogleFileVersion__c localFileVersion = insertVersion('OFFDL.docx', DOCX_MIME_TYPE, 'DOCS_OLDER_COPY', 10L, 10L, null);

		Test.startTest();
		String base64Body = new GoogleLocalFileVersionService().downloadFileBase64Body(localFileVersion.Id);
		Test.stopTest();

		Assert.isTrue(String.isNotBlank(base64Body), 'Downloading the original is unaffected');
	}

	@IsTest
	private static void testExtractTextPositiveReadsPlainTextWhilePreviewsAreOff() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildPreviewConfig(true, 1000L);
		GoogleFileVersion__c localFileVersion = insertVersion('OFFTXT.txt', GoogleCloudConstants.MIME_TYPE_TEXT, null, 10L, null, null);
		GoogleFileTextExtractRequestDTO request = new GoogleFileTextExtractRequestDTO();
		request.googleFileVersionId = localFileVersion.Id;

		Test.startTest();
		GoogleFileTextExtractResultDTO result = new GoogleLocalFileVersionService().extractText(request);
		Test.stopTest();

		Assert.areEqual(RAW_UPLOAD_TEXT, result.text, 'Plain text files always work');
	}

	@IsTest
	private static void testExtractTextPositiveReadsAPlainTextUploadNotItsOlderCopyWhilePreviewsAreOff() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildPreviewConfig(true, 1000L);
		GoogleFileVersion__c localFileVersion = insertVersion('OFFCSV.csv', GoogleCloudConstants.MIME_TYPE_CSV, 'DOCS_OLDER_SHEET', 10L, 10L, PAST_RECENT_WINDOW_MINUTES);
		GoogleFileTextExtractRequestDTO request = new GoogleFileTextExtractRequestDTO();
		request.googleFileVersionId = localFileVersion.Id;

		Test.startTest();
		GoogleFileTextExtractResultDTO result = new GoogleLocalFileVersionService().extractText(request);
		Test.stopTest();

		Assert.areEqual(RAW_UPLOAD_TEXT, result.text, 'A CSV is still read, from the upload itself');
		Assert.areEqual(0, countExports(driveMock), 'Nothing is read from a copy while files are stored only');
	}

	@IsTest
	private static void testExtractTextNegativeRefusesAnOlderCopyWhilePreviewsAreOff() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = buildPreviewConfig(true, 1000L);
		GoogleFileVersion__c localFileVersion = insertVersion('OFFEXT.docx', DOCX_MIME_TYPE, 'DOCS_OLDER_COPY', 10L, 10L, PAST_RECENT_WINDOW_MINUTES);

		Test.startTest();
		String refusal = extractionRefusal(localFileVersion.Id);
		Test.stopTest();

		Assert.areEqual(PREVIEWS_OFF_TEXT_MESSAGE, refusal, 'A flow\'s fault path learns why, older copies included');
		Assert.areEqual(0, countExports(driveMock));
	}

	@IsTest
	private static void testExtractTextNegativeRefusesAFileWithoutACopyWhilePreviewsAreOff() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildPreviewConfig(true, 1000L);
		GoogleFileVersion__c localFileVersion = insertVersion('OFFNOCPY.pdf', GoogleCloudConstants.MIME_TYPE_PDF, null, 10L, null, null);

		Test.startTest();
		String refusal = extractionRefusal(localFileVersion.Id);
		Test.stopTest();

		Assert.areEqual(PREVIEWS_OFF_TEXT_MESSAGE, refusal, 'Never "may still be preparing" while no copy will ever be made');
	}

	@IsTest
	private static void testExtractTextNegativeRecentFileWithoutACopyMayStillBePreparing() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildPreviewConfig(false, 1000L);
		GoogleFileVersion__c localFileVersion = insertVersion('RCNTEXT.docx', DOCX_MIME_TYPE, null, 10L, null, INSIDE_RECENT_WINDOW_MINUTES);

		Test.startTest();
		String refusal = extractionRefusal(localFileVersion.Id);
		Test.stopTest();

		Assert.isTrue(refusal != null && refusal.contains('may still be preparing'));
	}

	@IsTest
	private static void testExtractTextNegativeOlderFileWithoutACopyIsNotAvailable() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildPreviewConfig(false, 1000L);
		GoogleFileVersion__c localFileVersion = insertVersion('OLDREXT.docx', DOCX_MIME_TYPE, null, 10L, null, PAST_RECENT_WINDOW_MINUTES);

		Test.startTest();
		String refusal = extractionRefusal(localFileVersion.Id);
		Test.stopTest();

		Assert.isTrue(refusal != null && refusal.startsWith('Text is not available for this file'));
		Assert.isFalse(refusal.contains('preparing'), 'A file uploaded while files were stored only never says its copy is on the way');
	}
}