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
private class GoogleGeminiIntelligenceStrategyTest {
	private class ApiKeyProviderStub implements IGenAiApiKeyProvider {
		public GenAiApiKey apiKey() {
			return new GenAiApiKey('custom-api-key');
		}
	}

	private static GoogleClientConfig__mdt buildGeminiConfig(String apiKey, String modelName) {
		GoogleClientConfig__mdt config = new GoogleClientConfig__mdt();
		config.CustomGeminiApiKey__c = apiKey;
		config.CustomModelName__c = modelName;
		return config;
	}

	@IsTest
	private static void testValidatePositive() {
		GoogleMetadataConfigService.configRecordOverride = buildGeminiConfig('api-key-1', 'gemini-2.0-flash');
		Test.setMock(HttpCalloutMock.class, new GoogleIntelligenceHttpMock());

		Test.startTest();
		Boolean isValid = new GoogleGeminiIntelligenceStrategy().validate();
		Test.stopTest();

		Assert.isTrue(isValid);
	}

	@IsTest
	private static void testValidatePositiveWithCustomApiKeyProvider() {
		GoogleMetadataConfigService.configRecordOverride = buildGeminiConfig(null, 'gemini-2.0-flash');
		Test.setMock(HttpCalloutMock.class, new GoogleIntelligenceHttpMock());

		Test.startTest();
		Boolean isValid = new GoogleGeminiIntelligenceStrategy(new ApiKeyProviderStub()).validate();
		Test.stopTest();

		Assert.isTrue(isValid);
	}

	@IsTest
	private static void testValidatePositiveEmptyBody() {
		GoogleMetadataConfigService.configRecordOverride = buildGeminiConfig('api-key-1', 'gemini-2.0-flash');
		Test.setMock(HttpCalloutMock.class, new GoogleIntelligenceHttpMock().withEmptyBody());

		Test.startTest();
		Boolean isValid = new GoogleGeminiIntelligenceStrategy().validate();
		Test.stopTest();

		Assert.isFalse(isValid);
	}

	@IsTest
	private static void testValidateNegativeNoModel() {
		GoogleMetadataConfigService.configRecordOverride = buildGeminiConfig('api-key-1', null);
		Test.setMock(HttpCalloutMock.class, new GoogleIntelligenceHttpMock());

		Test.startTest();
		try {
			new GoogleGeminiIntelligenceStrategy().validate();
			Assert.isTrue(false);
		} catch (GoogleGeminiIntelligenceStrategy.GoogleGeminiConfigurationException ex) {
			Assert.isTrue(ex.getMessage().contains('Unable to locate the Gemini model name'));
		}
		Test.stopTest();
	}

	@IsTest
	private static void testValidateNegativeHttpError() {
		GoogleMetadataConfigService.configRecordOverride = buildGeminiConfig('api-key-1', 'gemini-2.0-flash');
		Test.setMock(HttpCalloutMock.class, new GoogleIntelligenceHttpMock().withErrorResponse(401, 'Unauthorized Gemini request'));

		Test.startTest();
		try {
			new GoogleGeminiIntelligenceStrategy().validate();
			Assert.isTrue(false);
		} catch (GoogleGeminiIntelligenceStrategy.GoogleGeminiConfigurationException ex) {
			Assert.isTrue(ex.getMessage().contains('Unauthorized Gemini request'));
		}
		Test.stopTest();
	}

	@IsTest
	private static void testSummarizePositiveNull() {
		Test.startTest();
		GoogleFileAnalysisResultDTO result = new GoogleGeminiIntelligenceStrategy().summarize(null);
		Test.stopTest();

		Assert.areEqual(null, result);
	}

	@IsTest
	private static void testAnswerQuestionPositiveNull() {
		Test.startTest();
		GoogleFileAnalysisResultDTO result = new GoogleGeminiIntelligenceStrategy().answerQuestion(null, null);
		Test.stopTest();

		Assert.areEqual(null, result);
	}
}
