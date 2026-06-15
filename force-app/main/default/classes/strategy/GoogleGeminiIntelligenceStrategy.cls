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
public with sharing class GoogleGeminiIntelligenceStrategy implements IGoogleFileIntelligenceStrategy {
    public class GoogleGeminiConfigurationException extends Exception {}

    private static final String VALIDATION_PROMPT = 'Reply with OK.';
	private static final Integer VALIDATION_OUTPUT_TOKENS = 4;
	private static final Integer VALIDATION_THINKING_BUDGET = 0;

    private GoogleMetadataConfigService metadataService;
    private IGenAiApiKeyProvider apiKeyProvider;
	private GoogleFileSummarizeCommand summarizeCommand = new GoogleFileSummarizeCommand();
	private GoogleFileQuestionCommand questionCommand = new GoogleFileQuestionCommand();
	private IGenAiClient genAiClient;

	public GoogleGeminiIntelligenceStrategy() {
        this(new GoogleMetadataConfigService(), new DefaultGoogleGenAiApiKeyProvider());
    }

    public GoogleGeminiIntelligenceStrategy(IGenAiApiKeyProvider apiKeyProvider) {
        this(new GoogleMetadataConfigService(), apiKeyProvider);
    }

    @TestVisible
	private GoogleGeminiIntelligenceStrategy(GoogleMetadataConfigService metadataService, IGenAiApiKeyProvider apiKeyProvider) {
        this.metadataService = metadataService;
        this.apiKeyProvider = apiKeyProvider;
		this.genAiClient = new GenAiClientFactory().google(new GenAiGoogleDeveloperConfig(apiKeyProvider));
    }

	public Boolean validate() {
		validateGeminiConfiguration();

        try {
			GenAiRequest validationRequest = new GenAiRequestBuilder(metadataService.getGoogleAiModel())
				.addUserText(VALIDATION_PROMPT)
				.withTemperature(0.0)
				.withMaxTokens(VALIDATION_OUTPUT_TOKENS)
				.withProviderOptions(new GenAiGoogleOptions().withThinkingBudget(VALIDATION_THINKING_BUDGET))
				.build();
				
            GenAiResponse response = genAiClient.generate(validationRequest);
            return response != null && response.hasCandidates();
        } catch (Exception ex) {
			throw new GoogleGeminiConfigurationException(ex.getMessage());
        }
	}

	public GoogleFileAnalysisResultDTO summarize(Id localGoogleFileVersionId) {
		if (localGoogleFileVersionId == null) {
			return null;
		}

		try {
			validateGeminiConfiguration();
		} catch (Exception ex) {
			return buildBlockedResult(ex.getMessage(), 'SUMMARY');
		}

		return this.summarizeCommand.summarize(localGoogleFileVersionId, 'Gemini', this.metadataService.getGoogleAiModel(), this.genAiClient);
	}

	public GoogleFileAnalysisResultDTO answerQuestion(Id localGoogleFileVersionId, String question) {
		if (localGoogleFileVersionId == null) {
			return null;
		}

		try {
			validateGeminiConfiguration();
		} catch (Exception ex) {
			return buildBlockedResult(ex.getMessage(), 'QUESTION');
		}

		return this.questionCommand.answerQuestion(localGoogleFileVersionId, question, 'Gemini', this.metadataService.getGoogleAiModel(), this.genAiClient);
	}

    private void validateGeminiConfiguration() {
        GenAiApiKey apiKey = apiKeyProvider == null ? null : apiKeyProvider.apiKey();
        String modelName = metadataService.getGoogleAiModel();

		if (apiKey == null || !apiKey.isConfigured()) {
			throw new GoogleGeminiConfigurationException(
				'Unable to locate the Gemini API key. Please verify the Gemini configuration is set correctly'
			);
		}

		if (String.isBlank(modelName)) {
			throw new GoogleGeminiConfigurationException(
				'Unable to locate the Gemini model name. Please verify the Gemini configuration is set correctly'
			);
		}
    }

	private GoogleFileAnalysisResultDTO buildBlockedResult(String errorMessage, String operationType) {
		GoogleFileAnalysisResultDTO result = new GoogleFileAnalysisResultDTO();
		result.blocked = true;
		result.provider = 'Gemini';
		result.operationType = operationType;
		result.errorMessage = errorMessage;
		return result;
	}
}