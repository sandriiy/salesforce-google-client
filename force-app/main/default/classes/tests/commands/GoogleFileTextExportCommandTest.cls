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
private class GoogleFileTextExportCommandTest {
	private static final String WORKSPACE_TEXT = 'Quarterly budget review covering revenue planning, staffing updates, and milestone approvals.';

	@IsTest
	private static void testExtractPlainTextPositiveUsesTheWorkspaceCopy() {
		GoogleCloudTestFactory.initMocks();

		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.withType('application/pdf')
			.withDriveId('GD_1')
			.withDocsId('DOCS_1')
			.build();

		Test.startTest();
		GoogleFileTextExportCommand exportCommand = new GoogleFileTextExportCommand();
		Boolean isSupported = exportCommand.supportsTextExtraction(localFileVersion);
		String text = exportCommand.extractPlainText(localFileVersion);
		Test.stopTest();

		Assert.isTrue(isSupported);
		Assert.areEqual(WORKSPACE_TEXT, text);
	}

	@IsTest
	private static void testExtractPlainTextPositiveReadsPlainTextFilesDirectly() {
		GoogleCloudTestFactory.initMocks();

		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.withType('text/plain')
			.withDriveId('GD_TEXT')
			.build();

		Test.startTest();
		GoogleFileTextExportCommand exportCommand = new GoogleFileTextExportCommand();
		Boolean isSupported = exportCommand.supportsTextExtraction(localFileVersion);
		String text = exportCommand.extractPlainText(localFileVersion);
		Test.stopTest();

		Assert.isTrue(isSupported, 'A plain text file needs no preview copy to be read');
		Assert.areEqual('mock file content', text);
	}

	@IsTest
	private static void testExtractPlainTextNegativeBinaryFileWithoutPreviewCopy() {
		GoogleCloudTestFactory.initMocks();

		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.withType('application/zip')
			.withDriveId('GD_ZIP')
			.build();

		Test.startTest();
		GoogleFileTextExportCommand exportCommand = new GoogleFileTextExportCommand();
		Boolean isSupported = exportCommand.supportsTextExtraction(localFileVersion);
		String text = exportCommand.extractPlainText(localFileVersion);
		Test.stopTest();

		Assert.isFalse(isSupported);
		Assert.isNull(text, 'Nothing is downloaded for a file that cannot be read as text');
		Assert.isNull(exportCommand.extractPlainText(null));
		Assert.isFalse(exportCommand.supportsTextExtraction(null));
	}

	@IsTest
	private static void testExportWorkspaceCopyPositiveHonoursTheRequestedFormat() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		GoogleCloudTestFactory.initMocks(driveMock);

		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.withDriveId('GD_1')
			.withDocsId('DOCS_1')
			.build();

		Test.startTest();
		String text = new GoogleFileTextExportCommand(new GoogleClientApiProvider()).exportWorkspaceCopy(localFileVersion, 'text/plain');
		Test.stopTest();

		Assert.areEqual(WORKSPACE_TEXT, text);

		Boolean exportedAsText = false;
		for (GoogleDriveHttpMock.CapturedRequest captured : driveMock.getCapturedRequests()) {
			if (captured.endpoint != null && captured.endpoint.contains('DOCS_1') && captured.endpoint.toLowerCase().contains('mimetype=text%2fplain')) {
				exportedAsText = true;
			}
		}
		Assert.isTrue(exportedAsText, 'The preview copy must be exported in the format the caller asked for');
	}
}
