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
private class GoogleFileTextExtractActionTest {
	private static final String WORKSPACE_TEXT = 'Quarterly budget review covering revenue planning, staffing updates, and milestone approvals.';

	@IsTest
	private static void testExtractTextPositiveReadsLatestVersionOfFile() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();

		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('Budget').insertRecord();
		GoogleFileVersion__c localVersion = GoogleCloudTestFactory.version()
			.forFile(localFile.Id)
			.withName('Budget.pdf')
			.withDriveId('GD_BUDGET')
			.withDocsId('DOCS_BUDGET')
			.isLatest(true)
			.insertRecord();

		GoogleFileTextExtractAction.Input input = new GoogleFileTextExtractAction.Input();
		input.googleFileId = localFile.Id;

		Test.startTest();
		List<GoogleFileTextExtractAction.Output> outputs = GoogleFileTextExtractAction.extractText(new List<GoogleFileTextExtractAction.Input>{ input });
		Test.stopTest();

		Assert.areEqual(1, outputs.size(), 'Flow expects one output per input');
		Assert.areEqual(WORKSPACE_TEXT, outputs[0].text);
		Assert.areEqual(WORKSPACE_TEXT.length(), outputs[0].characterCount);
		Assert.isFalse(outputs[0].isTruncated);
		Assert.areEqual(localVersion.Id, outputs[0].googleFileVersionId);
		Assert.areEqual('Budget.pdf', outputs[0].fileName);
	}

	@IsTest
	private static void testExtractTextPositiveCutsAtMaximumCharacters() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();

		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('Budget').insertRecord();
		GoogleFileVersion__c localVersion = GoogleCloudTestFactory.version()
			.forFile(localFile.Id)
			.withDriveId('GD_BUDGET')
			.withDocsId('DOCS_BUDGET')
			.insertRecord();

		GoogleFileTextExtractAction.Input input = new GoogleFileTextExtractAction.Input();
		input.googleFileVersionId = localVersion.Id;
		input.maxCharacters = 16;

		Test.startTest();
		List<GoogleFileTextExtractAction.Output> outputs = GoogleFileTextExtractAction.extractText(new List<GoogleFileTextExtractAction.Input>{ input });
		Test.stopTest();

		Assert.areEqual('Quarterly budget', outputs[0].text);
		Assert.areEqual(16, outputs[0].characterCount);
		Assert.isTrue(outputs[0].isTruncated);
	}

	@IsTest
	private static void testExtractTextNegativeFileWithoutReadableText() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();

		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('Archive').insertRecord();
		GoogleFileVersion__c localVersion = GoogleCloudTestFactory.version()
			.forFile(localFile.Id)
			.withType('application/zip')
			.withDriveId('GD_ARCHIVE')
			.insertRecord();

		GoogleFileTextExtractAction.Input input = new GoogleFileTextExtractAction.Input();
		input.googleFileVersionId = localVersion.Id;

		Test.startTest();
		try {
			GoogleFileTextExtractAction.extractText(new List<GoogleFileTextExtractAction.Input>{ input });
			Assert.fail('A file without a readable copy must fault the flow with a clear message');
		} catch (GoogleLocalFileVersionService.GoogleFileVersionException ex) {
			Assert.isTrue(ex.getMessage().contains('Text is not available'), ex.getMessage());
		}
		Test.stopTest();
	}

	@IsTest
	private static void testExtractTextNegativeMissingIds() {
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		try {
			GoogleFileTextExtractAction.extractText(new List<GoogleFileTextExtractAction.Input>{ new GoogleFileTextExtractAction.Input() });
			Assert.fail('A request without a file must be refused');
		} catch (GoogleLocalFileVersionService.GoogleFileVersionException ex) {
			Assert.isTrue(ex.getMessage().contains('Provide a Google File Id'), ex.getMessage());
		}
		Test.stopTest();
	}

	@IsTest
	private static void testExtractTextPositiveNullAndEmptyInputs() {
		Test.startTest();
		List<GoogleFileTextExtractAction.Output> nullOutputs = GoogleFileTextExtractAction.extractText(null);
		List<GoogleFileTextExtractAction.Output> emptyOutputs = GoogleFileTextExtractAction.extractText(new List<GoogleFileTextExtractAction.Input>());
		Test.stopTest();

		Assert.areEqual(0, nullOutputs.size());
		Assert.areEqual(0, emptyOutputs.size());
	}
}
