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
private class GoogleLocalFileIntelligenceServiceTest {
	private static final String LABEL_DEFINITIONS = '[{"name":"Invoice","labelId":"LABEL_INVOICE","description":"A bill requesting payment for goods or services"}]';

	private static GoogleClientConfig__mdt buildGeminiConfig() {
		return new GoogleClientConfig__mdt(
			IsFileIntelligenceEnabled__c = true,
			CustomGeminiApiKey__c = 'api-key-1',
			CustomModelName__c = 'gemini-2.0-flash'
		);
	}

	private static GoogleClientConfig__mdt buildLabelingConfig() {
		GoogleClientConfig__mdt config = buildGeminiConfig();
		config.IsAiLabelingEnabled__c = true;
		config.AiLabelDefinitions__c = LABEL_DEFINITIONS;
		return config;
	}

	private static GoogleFileVersion__c createAnalyzedVersion(String fileName) {
		GoogleCloudTestFactory.bypassTriggers();
		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName(fileName).withDescription('D').insertRecord();
		return GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName(fileName + '.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(1024)
			.withDriveId('GD_' + fileName)
			.withDocsId('DOCS_' + fileName)
			.insertRecord();
	}

	@IsTest
	private static void testRetrieveIntelligenceStatesPositiveEligibleWithSummary() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildGeminiConfig();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('INT1').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('INT1.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(1024)
			.withDriveId('GD_INT_1')
			.withDocsId('DOCS_INT_1')
			.build();
		localFileVersion.Summary__c = 'This file describes a signed project agreement.';
		insert localFileVersion;

		List<GoogleFileIntelligenceStateDTO> states;
		Test.startTest();
			states = new GoogleLocalFileIntelligenceService().retrieveIntelligenceStates(new List<Id>{ localFileVersion.Id });
		Test.stopTest();

		Assert.areEqual(1, states.size());
		Assert.areEqual(localFileVersion.Id, states[0].versionId);
		Assert.areEqual('This file describes a signed project agreement.', states[0].summary);
		Assert.isTrue(states[0].hasSummary);
		Assert.isTrue(states[0].isIntelligenceEligible);
	}

	@IsTest
	private static void testRetrieveIntelligenceStatesPositiveIncludesAssignedLabel() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildGeminiConfig();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('INTLBL').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('INTLBL.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(1024)
			.withDriveId('GD_INT_LBL')
			.withDocsId('DOCS_INT_LBL')
			.insertRecord();
		GoogleCloudTestFactory.versionLabel()
			.forVersion(localFileVersion.Id)
			.withName('Invoice')
			.withDriveLabelId('LABEL_INVOICE')
			.withConfidence(92)
			.insertRecord();

		List<GoogleFileIntelligenceStateDTO> states;
		Test.startTest();
			states = new GoogleLocalFileIntelligenceService().retrieveIntelligenceStates(new List<Id>{ localFileVersion.Id });
		Test.stopTest();

		Assert.areEqual(1, states.size());
		Assert.areEqual(new List<String>{ 'Invoice' }, states[0].labels);
		Assert.isTrue(new GoogleLocalFileIntelligenceService().retrieveIntelligenceState(null).labels.isEmpty());
	}

	@IsTest
	private static void testRetrieveIntelligenceStatesNegativeTooLarge() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildGeminiConfig();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('INT2').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('INT2.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(GoogleCloudConstants.MAX_SUMMARY_FILE_SIZE_BYTES + 1)
			.withDriveId('GD_INT_2')
			.withDocsId('DOCS_INT_2')
			.insertRecord();

		List<GoogleFileIntelligenceStateDTO> states;
		Test.startTest();
			states = new GoogleLocalFileIntelligenceService().retrieveIntelligenceStates(new List<Id>{ localFileVersion.Id });
		Test.stopTest();

		Assert.areEqual(1, states.size());
		Assert.areEqual(localFileVersion.Id, states[0].versionId);
		Assert.areEqual(null, states[0].summary);
		Assert.isFalse(states[0].hasSummary);
		Assert.isFalse(states[0].isIntelligenceEligible);
	}

	@IsTest
	private static void testRetrieveIntelligenceStatesPositiveLargeUploadWithFittingWorkspaceCopy() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildGeminiConfig();
		GoogleCloudTestFactory.bypassTriggers();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('INT6').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('INT6.pdf')
			.withType('application/pdf')
			.withSize(GoogleCloudConstants.MAX_SUMMARY_FILE_SIZE_BYTES + 1)
			.withDriveId('GD_INT_6')
			.withDocsId('DOCS_INT_6')
			.withDocsSize(112000)
			.insertRecord();

		List<GoogleFileIntelligenceStateDTO> states;
		Test.startTest();
			states = new GoogleLocalFileIntelligenceService().retrieveIntelligenceStates(new List<Id>{ localFileVersion.Id });
		Test.stopTest();

		Assert.areEqual(1, states.size());
		Assert.isTrue(states[0].isIntelligenceEligible);
		Assert.isFalse(states[0].hasSummary);
	}

	@IsTest
	private static void testRetrieveIntelligenceStatesNegativeSmallUploadWithOversizedWorkspaceCopy() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildGeminiConfig();
		GoogleCloudTestFactory.bypassTriggers();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('INT7').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('INT7.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(1024)
			.withDriveId('GD_INT_7')
			.withDocsId('DOCS_INT_7')
			.withDocsSize(GoogleCloudConstants.MAX_SUMMARY_FILE_SIZE_BYTES + 1)
			.insertRecord();

		List<GoogleFileIntelligenceStateDTO> states;
		Test.startTest();
			states = new GoogleLocalFileIntelligenceService().retrieveIntelligenceStates(new List<Id>{ localFileVersion.Id });
		Test.stopTest();

		Assert.areEqual(1, states.size());
		Assert.isFalse(states[0].isIntelligenceEligible);
	}

	@IsTest
	private static void testRetrieveIntelligenceStatesNegativeNoConfiguration() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('INT3').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('INT3.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(1024)
			.withDriveId('GD_INT_3')
			.withDocsId('DOCS_INT_3')
			.insertRecord();

		List<GoogleFileIntelligenceStateDTO> states;
		Test.startTest();
			states = new GoogleLocalFileIntelligenceService().retrieveIntelligenceStates(new List<Id>{ localFileVersion.Id });
		Test.stopTest();

		Assert.areEqual(1, states.size());
		Assert.isFalse(states[0].isIntelligenceEligible);
	}

	@IsTest
	private static void testRetrieveIntelligenceStatesHidesHistoricalSummaryContainingSecret() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildGeminiConfig();
		GoogleAiPromptSafetyGuardFactory.resetForTest();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('INT4').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('INT4.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(1024)
			.withDriveId('GD_INT_4')
			.withDocsId('DOCS_INT_4')
			.build();
		localFileVersion.Summary__c = 'Historical summary leaking AIzaSyABCDEFGHIJKLMNOPQRSTUVWXYZ0123456ab key.';
		insert localFileVersion;

		List<GoogleFileIntelligenceStateDTO> states;
		Test.startTest();
			states = new GoogleLocalFileIntelligenceService().retrieveIntelligenceStates(new List<Id>{ localFileVersion.Id });
		Test.stopTest();

		Assert.areEqual(1, states.size());
		Assert.isNull(states[0].summary);
		Assert.isFalse(states[0].hasSummary);
	}

	@IsTest
	private static void testRetrieveIntelligenceStatesKeepsBenignHistoricalSummary() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildGeminiConfig();
		GoogleAiPromptSafetyGuardFactory.resetForTest();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('INT5').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('INT5.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(1024)
			.withDriveId('GD_INT_5')
			.withDocsId('DOCS_INT_5')
			.build();
		localFileVersion.Summary__c = 'This file describes a signed project agreement.';
		insert localFileVersion;

		List<GoogleFileIntelligenceStateDTO> states;
		Test.startTest();
			states = new GoogleLocalFileIntelligenceService().retrieveIntelligenceStates(new List<Id>{ localFileVersion.Id });
		Test.stopTest();

		Assert.areEqual(1, states.size());
		Assert.areEqual('This file describes a signed project agreement.', states[0].summary);
		Assert.isTrue(states[0].hasSummary);
	}

	@IsTest
	private static void testRetrieveIntelligenceStatesKeepsHistoricalSummaryQuotingWebAddressUnderStrict() {
		GoogleCloudTestFactory.initMocks();
		GoogleClientConfig__mdt strictConfig = buildGeminiConfig();
		strictConfig.AiSafetyMode__c = GoogleAiPromptContext.MODE_STRICT;
		GoogleMetadataConfigService.configRecordOverride = strictConfig;
		GoogleAiPromptSafetyGuardFactory.resetForTest();
		GoogleCloudTestFactory.bypassTriggers();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('INT8').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('INT8.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(1024)
			.withDriveId('GD_INT_8')
			.withDocsId('DOCS_INT_8')
			.withSummary('This file describes the service terms published at https://example.com/terms.')
			.insertRecord();

		List<GoogleFileIntelligenceStateDTO> states;
		Test.startTest();
			states = new GoogleLocalFileIntelligenceService().retrieveIntelligenceStates(new List<Id>{ localFileVersion.Id });
		Test.stopTest();

		Assert.areEqual('This file describes the service terms published at https://example.com/terms.', states[0].summary);
		Assert.isTrue(states[0].hasSummary);
	}

	@IsTest
	private static void testRetrieveIntelligenceStatesKeepsHistoricalSummaryQuotingSsn() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildGeminiConfig();
		GoogleAiPromptSafetyGuardFactory.resetForTest();
		GoogleCloudTestFactory.bypassTriggers();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file().withName('INT9').withDescription('D').insertRecord();
		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('INT9.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(1024)
			.withDriveId('GD_INT_9')
			.withDocsId('DOCS_INT_9')
			.withSummary('This file describes the employee record filed under 123-45-6789.')
			.insertRecord();

		List<GoogleFileIntelligenceStateDTO> states;
		Test.startTest();
			states = new GoogleLocalFileIntelligenceService().retrieveIntelligenceStates(new List<Id>{ localFileVersion.Id });
		Test.stopTest();

		Assert.areEqual('This file describes the employee record filed under 123-45-6789.', states[0].summary);
		Assert.isTrue(states[0].hasSummary);
	}

	@IsTest
	private static void testRetrieveIntelligenceStatesPositiveReportsLabelingOn() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildLabelingConfig();
		GoogleFileVersion__c localFileVersion = createAnalyzedVersion('INTLON');

		List<GoogleFileIntelligenceStateDTO> states;
		Test.startTest();
			states = new GoogleLocalFileIntelligenceService().retrieveIntelligenceStates(new List<Id>{ localFileVersion.Id });
		Test.stopTest();

		Assert.areEqual(1, states.size());
		Assert.areEqual(true, states[0].isLabelingEnabled, 'The panel keeps checking for a label only when labeling can actually run');
	}

	@IsTest
	private static void testRetrieveIntelligenceStatesNegativeReportsLabelingOffWithoutDefinitions() {
		GoogleCloudTestFactory.initMocks();
		GoogleClientConfig__mdt config = buildGeminiConfig();
		config.IsAiLabelingEnabled__c = true;
		GoogleMetadataConfigService.configRecordOverride = config;
		GoogleFileVersion__c localFileVersion = createAnalyzedVersion('INTLOFF1');

		List<GoogleFileIntelligenceStateDTO> states;
		Test.startTest();
			states = new GoogleLocalFileIntelligenceService().retrieveIntelligenceStates(new List<Id>{ localFileVersion.Id });
		Test.stopTest();

		Assert.areEqual(false, states[0].isLabelingEnabled, 'Labeling switched on with no label to choose from never labels anything, so the panel must not wait for one');
	}

	@IsTest
	private static void testRetrieveIntelligenceStatesNegativeReportsLabelingOffWhileAnalysisIsOff() {
		GoogleCloudTestFactory.initMocks();
		GoogleClientConfig__mdt config = buildLabelingConfig();
		config.IsFileIntelligenceEnabled__c = false;
		GoogleMetadataConfigService.configRecordOverride = config;
		GoogleFileVersion__c localFileVersion = createAnalyzedVersion('INTLOFF2');

		List<GoogleFileIntelligenceStateDTO> states;
		Test.startTest();
			states = new GoogleLocalFileIntelligenceService().retrieveIntelligenceStates(new List<Id>{ localFileVersion.Id });
		Test.stopTest();

		Assert.areEqual(false, states[0].isLabelingEnabled);
	}

	@IsTest
	private static void testRetrieveIntelligenceStatesNegativeReportsLabelingOffOnAFreshInstall() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt();
		GoogleFileVersion__c localFileVersion = createAnalyzedVersion('INTLOFF3');

		List<GoogleFileIntelligenceStateDTO> states;
		Test.startTest();
			states = new GoogleLocalFileIntelligenceService().retrieveIntelligenceStates(new List<Id>{ localFileVersion.Id });
		Test.stopTest();

		Assert.areEqual(false, states[0].isLabelingEnabled);
	}

	@IsTest
	private static void testAnswerQuestionNegativeTimeoutSaysTheServiceTookTooLong() {
		GoogleIntelligenceHttpMock intelligenceMock = new GoogleIntelligenceHttpMock().withCalloutException('Read timed out');
		GoogleCloudTestFactory.initMocks(new GoogleCompositeHttpMock(new GoogleDriveHttpMock().withDefaultHappyPath(), intelligenceMock));
		GoogleMetadataConfigService.configRecordOverride = buildGeminiConfig();
		GoogleFileVersion__c localFileVersion = createAnalyzedVersion('INTQTO');

		GoogleFileAnalysisResultDTO result;
		Test.startTest();
			result = new GoogleLocalFileIntelligenceService().answerQuestion(localFileVersion.Id, 'What does this file cover?');
		Test.stopTest();

		Assert.areEqual(1, intelligenceMock.getRequestCount(), 'A question is asked once and never retried automatically');
		Assert.areNotEqual(true, result.success);
		Assert.areEqual(GoogleFileIntelligenceCommandBase.AI_SERVICE_TIMEOUT_MESSAGE, result.errorMessage);
	}

	@IsTest
	private static void testAnswerQuestionPositiveNoLimitSendsNoCap() {
		GoogleIntelligenceHttpMock intelligenceMock = new GoogleIntelligenceHttpMock();
		GoogleCloudTestFactory.initMocks(new GoogleCompositeHttpMock(new GoogleDriveHttpMock().withDefaultHappyPath(), intelligenceMock));
		GoogleClientConfig__mdt config = buildGeminiConfig();
		config.QuestionMaxOutputTokens__c = 0;
		GoogleMetadataConfigService.configRecordOverride = config;
		GoogleFileVersion__c localFileVersion = createAnalyzedVersion('INTQNL');

		GoogleFileAnalysisResultDTO result;
		Test.startTest();
			result = new GoogleLocalFileIntelligenceService().answerQuestion(localFileVersion.Id, 'What does this file cover?');
		Test.stopTest();

		Assert.isTrue(result.success);
		Assert.isNotNull(intelligenceMock.getLastRequestBody());
		Assert.isFalse(intelligenceMock.getLastRequestBody().contains('maxOutputTokens'), 'No limit reaches Google as a request without an output cap');
	}
}