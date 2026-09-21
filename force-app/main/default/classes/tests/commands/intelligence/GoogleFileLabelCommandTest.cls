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
private class GoogleFileLabelCommandTest {
	private static final String LABEL_DEFINITIONS = '['
		+ '{"name":"Invoice","labelId":"LABEL_INVOICE","description":"A bill requesting payment for goods or services"},'
		+ '{"name":"Contract","labelId":"LABEL_CONTRACT","description":"An agreement signed by two or more parties"},'
		+ '{"name":"Policy (Internal)","labelId":"LABEL_POLICY","description":"An internal policy or guideline document"}'
		+ ']';
	private static final Integer MIN_CONFIDENCE = 70;
	private static final String MODIFY_LABELS_ENDPOINT_PART = '/modifyLabels';

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

	private static GoogleCloudTestFactory.ConfigBuilder labelingConfig() {
		return GoogleCloudTestFactory.config()
			.withPreviewDisabled(true)
			.withFileIntelligence(true)
			.withAiLabeling(true)
			.withAiLabelingMinConfidence(MIN_CONFIDENCE)
			.withAiLabelDefinitions(LABEL_DEFINITIONS);
	}

	private static GoogleDriveHttpMock installMocks() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		GoogleCloudTestFactory.initMocks(driveMock);
		return driveMock;
	}

	private static GoogleFileVersion__c createLabelCandidate(String fileName, String existingLabelName) {
		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName(fileName)
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName(fileName + '.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(2048)
			.withDriveId('GD_' + fileName)
			.withDocsId('DOCS_' + fileName)
			.insertRecord();

		if (String.isNotBlank(existingLabelName)) {
			GoogleCloudTestFactory.versionLabel()
				.forVersion(version.Id)
				.withName(existingLabelName)
				.withDriveLabelId('LABEL_' + existingLabelName.toUpperCase())
				.withConfidence(90)
				.insertRecord();
		}

		return version;
	}

	private static GoogleDriveHttpMock.CapturedRequest findLabelRequest(GoogleDriveHttpMock driveMock) {
		List<GoogleDriveHttpMock.CapturedRequest> labelRequests = findLabelRequests(driveMock);
		return labelRequests.isEmpty() ? null : labelRequests[0];
	}

	private static List<GoogleDriveHttpMock.CapturedRequest> findLabelRequests(GoogleDriveHttpMock driveMock) {
		List<GoogleDriveHttpMock.CapturedRequest> labelRequests = new List<GoogleDriveHttpMock.CapturedRequest>();
		for (GoogleDriveHttpMock.CapturedRequest capturedRequest : driveMock.getCapturedRequests()) {
			if (capturedRequest.endpoint != null && capturedRequest.endpoint.contains(MODIFY_LABELS_ENDPOINT_PART)) {
				labelRequests.add(capturedRequest);
			}
		}

		return labelRequests;
	}

	@IsTest
	private static void testLabelPositiveAppliesConfidentMatch() {
		labelingConfig().apply();
		GoogleDriveHttpMock driveMock = installMocks();
		GoogleFileVersion__c version = createLabelCandidate('LBLCMD1', null);

		GoogleFileLabelResultDTO result;
		Test.startTest();
			result = new GoogleFileLabelCommand().label(version.Id, 'Gemini', 'gemini-2.0-flash', new GenAiClientStub('Label: Invoice\nConfidence: 92', 'STOP'));
		Test.stopTest();

		Assert.isTrue(result.success);
		Assert.isTrue(result.applied);
		Assert.areEqual('Invoice', result.labelName);
		Assert.areEqual('LABEL_INVOICE', result.labelId);
		Assert.areEqual(92, result.confidence);
		Assert.areEqual('Gemini', result.provider);

		List<GoogleDriveHttpMock.CapturedRequest> labelRequests = findLabelRequests(driveMock);
		Assert.areEqual(2, labelRequests.size());
		Assert.isTrue(labelRequests[0].endpoint.contains('GD_LBLCMD1'));
		Assert.isTrue(labelRequests[1].endpoint.contains('DOCS_LBLCMD1'));
		Assert.isTrue(labelRequests[0].body.contains('LABEL_INVOICE'));
		Assert.isTrue(labelRequests[1].body.contains('LABEL_INVOICE'));
		Assert.isFalse(labelRequests[0].body.contains('fieldModifications'));
	}

	@IsTest
	private static void testLabelPositiveKeepsLabelWhenWorkspaceCopyRejectsIt() {
		labelingConfig().apply();
		GoogleDriveHttpMock driveMock = installMocks();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher().withMethod('POST').endpointContains('DOCS_LBLCMD12' + MODIFY_LABELS_ENDPOINT_PART)
		).thenReturnStatus(404, '{ "error": { "message":"Not Found" } }');
		GoogleFileVersion__c version = createLabelCandidate('LBLCMD12', null);

		GoogleFileLabelResultDTO result;
		Test.startTest();
			result = new GoogleFileLabelCommand().label(version.Id, 'Gemini', 'gemini-2.0-flash', new GenAiClientStub('Label: Invoice Confidence: 93', 'STOP'));
		Test.stopTest();

		Assert.isTrue(result.applied);
		Assert.areEqual('Invoice', result.labelName);
		Assert.isTrue(String.isBlank(result.errorMessage));
		Assert.areEqual(2, findLabelRequests(driveMock).size());
	}

	@IsTest
	private static void testLabelPositiveAppliesDecoratedAnswer() {
		labelingConfig().apply();
		GoogleDriveHttpMock driveMock = installMocks();
		GoogleFileVersion__c version = createLabelCandidate('LBLCMD2', null);

		GoogleFileLabelResultDTO result;
		Test.startTest();
			result = new GoogleFileLabelCommand().label(version.Id, 'Gemini', 'gemini-2.0-flash', new GenAiClientStub('Label: **Contract**, Confidence: 88.', 'STOP'));
		Test.stopTest();

		Assert.isTrue(result.applied);
		Assert.areEqual('Contract', result.labelName);
		Assert.areEqual(88, result.confidence);

		GoogleDriveHttpMock.CapturedRequest labelRequest = findLabelRequest(driveMock);
		Assert.isNotNull(labelRequest);
		Assert.isTrue(labelRequest.body.contains('LABEL_CONTRACT'));
	}

	@IsTest
	private static void testLabelPositiveMatchesDefinitionNamesWithDecorations() {
		labelingConfig().apply();
		GoogleDriveHttpMock driveMock = installMocks();
		GoogleFileVersion__c version = createLabelCandidate('LBLCMD13', null);

		GoogleFileLabelResultDTO result;
		Test.startTest();
			result = new GoogleFileLabelCommand().label(version.Id, 'Gemini', 'gemini-2.0-flash', new GenAiClientStub('Label: Policy (Internal)\nConfidence: 90', 'STOP'));
		Test.stopTest();

		Assert.isTrue(result.applied);
		Assert.areEqual('Policy (Internal)', result.labelName);
		Assert.isTrue(findLabelRequest(driveMock).body.contains('LABEL_POLICY'));
	}

	@IsTest
	private static void testLabelPositiveKeepsFileUnlabeledBelowMinimumConfidence() {
		labelingConfig().apply();
		GoogleDriveHttpMock driveMock = installMocks();
		GoogleFileVersion__c version = createLabelCandidate('LBLCMD3', null);

		GoogleFileLabelResultDTO result;
		Test.startTest();
			result = new GoogleFileLabelCommand().label(version.Id, 'Gemini', 'gemini-2.0-flash', new GenAiClientStub('Label: Invoice Confidence: 40', 'STOP'));
		Test.stopTest();

		Assert.isTrue(result.success);
		Assert.areNotEqual(true, result.applied);
		Assert.areEqual('Invoice', result.labelName);
		Assert.areEqual(40, result.confidence);
		Assert.isNull(findLabelRequest(driveMock));
	}

	@IsTest
	private static void testLabelPositiveKeepsFileUnlabeledWhenModelAnswersNone() {
		labelingConfig().apply();
		GoogleDriveHttpMock driveMock = installMocks();
		GoogleFileVersion__c version = createLabelCandidate('LBLCMD4', null);

		GoogleFileLabelResultDTO result;
		Test.startTest();
			result = new GoogleFileLabelCommand().label(version.Id, 'Gemini', 'gemini-2.0-flash', new GenAiClientStub('Label: None Confidence: 97', 'STOP'));
		Test.stopTest();

		Assert.isTrue(result.success);
		Assert.areNotEqual(true, result.applied);
		Assert.isNull(result.labelName);
		Assert.isNull(findLabelRequest(driveMock));
	}

	@IsTest
	private static void testLabelPositiveIgnoresLabelOutsideTheCatalog() {
		labelingConfig().apply();
		GoogleDriveHttpMock driveMock = installMocks();
		GoogleFileVersion__c version = createLabelCandidate('LBLCMD5', null);

		GoogleFileLabelResultDTO result;
		Test.startTest();
			result = new GoogleFileLabelCommand().label(version.Id, 'Gemini', 'gemini-2.0-flash', new GenAiClientStub('Label: Receipt Confidence: 99', 'STOP'));
		Test.stopTest();

		Assert.isTrue(result.success);
		Assert.areNotEqual(true, result.applied);
		Assert.isNull(result.labelName);
		Assert.isNull(findLabelRequest(driveMock));
	}

	@IsTest
	private static void testLabelPositiveTreatsUnparseableAnswerAsNoLabel() {
		labelingConfig().apply();
		GoogleDriveHttpMock driveMock = installMocks();
		GoogleFileVersion__c version = createLabelCandidate('LBLCMD6', null);

		GoogleFileLabelResultDTO result;
		Test.startTest();
			result = new GoogleFileLabelCommand().label(version.Id, 'Gemini', 'gemini-2.0-flash', new GenAiClientStub('This looks like an invoice to me.', 'STOP'));
		Test.stopTest();

		Assert.isTrue(result.success);
		Assert.areNotEqual(true, result.applied);
		Assert.isNull(result.labelName);
		Assert.areEqual(0, result.confidence);
		Assert.isNull(findLabelRequest(driveMock));
	}

	@IsTest
	private static void testLabelNegativeNoDefinitions() {
		labelingConfig().withAiLabelDefinitions('').apply();
		installMocks();
		GoogleFileVersion__c version = createLabelCandidate('LBLCMD7', null);
		GenAiClientStub clientStub = new GenAiClientStub('Label: Invoice Confidence: 95', 'STOP');

		GoogleFileLabelResultDTO result;
		Test.startTest();
			result = new GoogleFileLabelCommand().label(version.Id, 'Gemini', 'gemini-2.0-flash', clientStub);
		Test.stopTest();

		Assert.isTrue(result.blocked);
		Assert.areEqual('No AI labels are defined', result.errorMessage);
		Assert.isNull(clientStub.capturedRequest);
	}

	@IsTest
	private static void testLabelNegativeAlreadyLabeledVersionIsIneligible() {
		labelingConfig().apply();
		installMocks();
		GoogleFileVersion__c version = createLabelCandidate('LBLCMD8', 'Contract');
		GenAiClientStub clientStub = new GenAiClientStub('Label: Invoice Confidence: 95', 'STOP');

		GoogleFileLabelResultDTO result;
		Test.startTest();
			result = new GoogleFileLabelCommand().label(version.Id, 'Gemini', 'gemini-2.0-flash', clientStub);
		Test.stopTest();

		Assert.isTrue(result.blocked);
		Assert.areNotEqual(true, result.applied);
		Assert.isNull(clientStub.capturedRequest);
	}

	@IsTest
	private static void testLabelNegativeDriveRejectsLabel() {
		labelingConfig().apply();
		GoogleDriveHttpMock driveMock = installMocks();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher().withMethod('POST').endpointContains(MODIFY_LABELS_ENDPOINT_PART)
		).thenReturnStatus(403, '{ "error": { "message":"The service account cannot modify labels on this file" } }');
		GoogleFileVersion__c version = createLabelCandidate('LBLCMD9', null);

		GoogleFileLabelResultDTO result;
		Test.startTest();
			result = new GoogleFileLabelCommand().label(version.Id, 'Gemini', 'gemini-2.0-flash', new GenAiClientStub('Label: Invoice Confidence: 91', 'STOP'));
		Test.stopTest();

		Assert.isTrue(result.success);
		Assert.isFalse(result.applied);
		Assert.areEqual('Invoice', result.labelName);
		Assert.isTrue(String.isNotBlank(result.errorMessage));
	}

	@IsTest
	private static void testLabelPositiveReservesThinkingBudgetInOutputTokens() {
		labelingConfig().withAiLabelingThinkingBudget(512).apply();
		installMocks();
		GoogleFileVersion__c version = createLabelCandidate('LBLCMD10', null);
		GenAiClientStub clientStub = new GenAiClientStub('Label: Invoice Confidence: 90', 'STOP');

		Test.startTest();
			new GoogleFileLabelCommand().label(version.Id, 'Gemini', 'gemini-2.0-flash', clientStub);
		Test.stopTest();

		Assert.isNotNull(clientStub.capturedRequest);
		Assert.areEqual(64 + 512, clientStub.capturedRequest.generation.maxTokens);
		Assert.isTrue(clientStub.capturedRequest.systemMessage.text().contains(GoogleMetadataConfigService.DEFAULT_LABELING_PROMPT));
	}

	@IsTest
	private static void testLabelPositiveSendsCatalogAndDocumentToModel() {
		labelingConfig().apply();
		installMocks();
		GoogleFileVersion__c version = createLabelCandidate('LBLCMD11', null);
		GenAiClientStub clientStub = new GenAiClientStub('Label: Invoice Confidence: 90', 'STOP');

		Test.startTest();
			new GoogleFileLabelCommand().label(version.Id, 'Gemini', 'gemini-2.0-flash', clientStub);
		Test.stopTest();

		String userPrompt = clientStub.capturedRequest.messages[0].text();
		Assert.isTrue(userPrompt.contains('1. Invoice - A bill requesting payment for goods or services'));
		Assert.isTrue(userPrompt.contains('2. Contract - An agreement signed by two or more parties'));

		Integer documentStart = userPrompt.indexOf('Document text:');
		Assert.isTrue(documentStart > 0);
		Assert.isTrue(String.isNotBlank(userPrompt.substring(documentStart + 'Document text:'.length())));
	}

	@IsTest
	private static void testLabelNegativeUnavailableConfiguration() {
		labelingConfig().apply();

		GoogleFileLabelResultDTO result = new GoogleFileLabelCommand().label(
			GoogleCloudTestFactory.fakeId(GoogleFileVersion__c.SObjectType),
			'Gemini',
			null,
			null
		);

		Assert.isTrue(result.blocked);
		Assert.areEqual('Google AI labeling configuration is unavailable', result.errorMessage);
	}
}
