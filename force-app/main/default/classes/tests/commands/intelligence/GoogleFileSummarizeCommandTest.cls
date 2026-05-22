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
private class GoogleFileSummarizeCommandTest {
	private class GenAiClientStub implements IGenAiClient {
		private final GenAiResponse response;
		private GenAiRequest capturedRequest;

		private GenAiClientStub(String text, String finishReason) {
			GenAiResponse generatedResponse = new GenAiResponse();
			GenAiCandidate candidate = new GenAiCandidate();
			candidate.finishReason = finishReason;
			candidate.content = new GenAiMessage('model').addText(text);
			generatedResponse.addCandidate(candidate);
			this.response = generatedResponse;
		}

		public GenAiResponse generate(GenAiRequest request) {
			this.capturedRequest = request;
			return this.response;
		}
	}

	@IsTest
	private static void testSummarizeNegativeUnavailableConfiguration() {
		GoogleFileAnalysisResultDTO result = new GoogleFileSummarizeCommand().summarize(
			GoogleCloudTestFactory.fakeId(GoogleFileVersion__c.SObjectType),
			'Gemini',
			null,
			null
		);

		Assert.isTrue(result.blocked);
		Assert.areEqual('Google AI summary configuration is unavailable', result.errorMessage);
	}

	@IsTest
	private static void testSummarizePositiveFitsResponseToCharacterLimit() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(IsFilePreviewDisabled__c = true);

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('SUMCMD1')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('SUMCMD1.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(2048)
			.withDocsId('DOCS_SUMCMD_1')
			.insertRecord();

		GenAiClientStub clientStub = new GenAiClientStub('X'.repeat(256), 'STOP');
		GoogleFileAnalysisResultDTO result;
		Test.startTest();
			result = new GoogleFileSummarizeCommand().summarize(
				version.Id,
				'Gemini',
				'gemini-2.0-flash',
				clientStub
			);
		Test.stopTest();

		Assert.isNotNull(result);
		Assert.isTrue(result.success);
		Assert.areEqual(255, result.text.length());
		Assert.areEqual('X'.repeat(252) + '...', result.text);
		Assert.areEqual(64, clientStub.capturedRequest.generation.maxTokens);
		Assert.areEqual(0, clientStub.capturedRequest.generation.stopSequences.size());
	}

	@IsTest
	private static void testSummarizePositiveAcceptsCompleteMaxTokensResponse() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(IsFilePreviewDisabled__c = true);

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('SUMCMD3')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('SUMCMD3.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(2048)
			.withDocsId('DOCS_SUMCMD_3')
			.insertRecord();

		String generatedText = 'This file describes an Adobe invoice for a Premiere plan subscription billed in CAD.';
		GoogleFileAnalysisResultDTO result;
		Test.startTest();
			result = new GoogleFileSummarizeCommand().summarize(
				version.Id,
				'Gemini',
				'gemini-2.0-flash',
				new GenAiClientStub(generatedText, 'MAX_TOKENS')
			);
		Test.stopTest();

		Assert.isTrue(result.success);
		Assert.areEqual(generatedText, result.text);
	}

	@IsTest
	private static void testSummarizePositiveAddsEllipsisToIncompleteResponse() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(IsFilePreviewDisabled__c = true);

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('SUMCMD4')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('SUMCMD4.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(2048)
			.withDocsId('DOCS_SUMCMD_4')
			.insertRecord();

		String generatedText = 'This file describes an Adobe invoice for a Premiere plan subscription billed in CAD';
		GoogleFileAnalysisResultDTO result;
		Test.startTest();
			result = new GoogleFileSummarizeCommand().summarize(
				version.Id,
				'Gemini',
				'gemini-2.0-flash',
				new GenAiClientStub(generatedText, 'MAX_TOKENS')
			);
		Test.stopTest();

		Assert.isTrue(result.success);
		Assert.areEqual(generatedText + '...', result.text);
	}

	@IsTest
	private static void testSummarizeNegativeNoContent() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(IsFilePreviewDisabled__c = true);

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('SUMCMD2')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('SUMCMD2.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(2048)
			.withDocsId('DOCS_SUMCMD_2')
			.insertRecord();

		GoogleFileAnalysisResultDTO result;
		Test.startTest();
			result = new GoogleFileSummarizeCommand().summarize(
				version.Id,
				'Gemini',
				'gemini-2.0-flash',
				new GenAiClientStub('', 'STOP')
			);
		Test.stopTest();

		Assert.isNotNull(result);
		Assert.areEqual(null, result.success);
		Assert.areEqual('Summary response returned no content (NO_CONTENT_STOP)', result.errorMessage);
	}
}