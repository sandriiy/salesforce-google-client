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
private class GoogleAgentIntelligenceStrategyTest {
	private class AccessTokenProviderStub implements IGenAiAccessTokenProvider {
		public GenAiAccessToken token() {
			return new GenAiAccessToken('Bearer', 'custom-access-token');
		}
	}

	private static GoogleClientConfig__mdt buildAgentConfig(String projectId, String location, String modelName) {
		GoogleClientConfig__mdt config = new GoogleClientConfig__mdt();
		config.CustomAgentProjectId__c = projectId;
		config.CustomAgentLocation__c = location;
		config.CustomModelName__c = modelName;
		return config;
	}

	@IsTest
	private static void testValidateNegativeNoConfig() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt();
		Test.setMock(HttpCalloutMock.class, new GoogleCompositeHttpMock());

		Test.startTest();
		try {
			new GoogleAgentIntelligenceStrategy().validate();
			Assert.isTrue(false);
		} catch (GoogleAgentIntelligenceStrategy.GoogleAgentConfigurationException ex) {
			Assert.isTrue(ex.getMessage().contains('Unable to locate the Agent Platform'));
		}
		Test.stopTest();
	}

	@IsTest
	private static void testValidatePositive() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildAgentConfig('project-1', 'us-central1', 'gemini-2.0-flash');
		Test.setMock(HttpCalloutMock.class, new GoogleIntelligenceHttpMock());

		Test.startTest();
		Boolean isValid = new GoogleAgentIntelligenceStrategy().validate();
		Test.stopTest();

		Assert.isTrue(isValid);
	}

	@IsTest
	private static void testValidatePositiveWithCustomTokenProvider() {
		GoogleMetadataConfigService.configRecordOverride = buildAgentConfig('project-1', 'us-central1', 'gemini-2.0-flash');
		Test.setMock(HttpCalloutMock.class, new GoogleIntelligenceHttpMock());

		Test.startTest();
		Boolean isValid = new GoogleAgentIntelligenceStrategy(new AccessTokenProviderStub()).validate();
		Test.stopTest();

		Assert.isTrue(isValid);
	}

	@IsTest
	private static void testValidatePositiveEmptyBody() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildAgentConfig('project-1', 'us-central1', 'gemini-2.0-flash');
		Test.setMock(HttpCalloutMock.class, new GoogleIntelligenceHttpMock().withEmptyBody());

		Test.startTest();
		Boolean isValid = new GoogleAgentIntelligenceStrategy().validate();
		Test.stopTest();

		Assert.isFalse(isValid);
	}

	@IsTest
	private static void testValidateNegativeNoModel() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildAgentConfig('project-1', 'us-central1', null);
		Test.setMock(HttpCalloutMock.class, new GoogleCompositeHttpMock());

		Test.startTest();
		try {
			new GoogleAgentIntelligenceStrategy().validate();
			Assert.isTrue(false);
		} catch (GoogleAgentIntelligenceStrategy.GoogleAgentConfigurationException ex) {
			Assert.isTrue(ex.getMessage().contains('Unable to locate the Agent Platform model name'));
		}
		Test.stopTest();
	}

	@IsTest
	private static void testValidateNegativeHttpError() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = buildAgentConfig('project-1', 'us-central1', 'gemini-2.0-flash');
		Test.setMock(HttpCalloutMock.class, new GoogleIntelligenceHttpMock().withErrorResponse(403, 'Agent permission denied'));

		Test.startTest();
		try {
			new GoogleAgentIntelligenceStrategy().validate();
			Assert.isTrue(false);
		} catch (GoogleAgentIntelligenceStrategy.GoogleAgentConfigurationException ex) {
			Assert.isTrue(ex.getMessage().contains('Agent permission denied'));
		}
		Test.stopTest();
	}

	@IsTest
	private static void testSummarizePositiveNull() {
		GoogleCloudTestFactory.initMocks();
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt();

		Test.startTest();
		GoogleFileAnalysisResultDTO result = new GoogleAgentIntelligenceStrategy().summarize(null);
		Test.stopTest();

		Assert.areEqual(null, result);
	}

	@IsTest
	private static void testSummarizePositive() {
		GoogleCloudTestFactory.initMocks(new GoogleCompositeHttpMock());
		GoogleMetadataConfigService.configRecordOverride = buildAgentConfig('project-1', 'us-central1', 'gemini-2.0-flash');

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('AGTSUM')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('AGTSUM.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(1024)
			.withDocsId('DOCS_AGENT_SUM')
			.insertRecord();

		Test.startTest();
		GoogleFileAnalysisResultDTO result = new GoogleAgentIntelligenceStrategy().summarize(version.Id);
		Test.stopTest();

		Assert.isTrue(result.success);
		Assert.areEqual('Agent Platform', result.provider);
		Assert.areEqual('SUMMARY', result.operationType);
	}

	@IsTest
	private static void testAnswerQuestionPositiveNull() {
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		GoogleFileAnalysisResultDTO result = new GoogleAgentIntelligenceStrategy().answerQuestion(null, null);
		Test.stopTest();

		Assert.areEqual(null, result);
	}

	@IsTest
	private static void testAnswerQuestionPositive() {
		GoogleCloudTestFactory.initMocks(new GoogleCompositeHttpMock());
		GoogleMetadataConfigService.configRecordOverride = buildAgentConfig('project-1', 'us-central1', 'gemini-2.0-flash');

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('AGTQ')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('AGTQ.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(1024)
			.withDocsId('DOCS_AGENT_Q')
			.insertRecord();

		Test.startTest();
		GoogleFileAnalysisResultDTO result = new GoogleAgentIntelligenceStrategy().answerQuestion(version.Id, 'What does this file cover?');
		Test.stopTest();

		Assert.isTrue(result.success);
		Assert.areEqual('Agent Platform', result.provider);
		Assert.areEqual('QUESTION', result.operationType);
		Assert.areEqual('OK', result.text);
	}
}
