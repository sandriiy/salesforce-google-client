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
/**
 * Sends summaries, questions and labeling to the Gemini Developer API, which authenticates with an API
 * key and needs no Google Cloud project. Good for development and sandboxes, while Agent Platform is the
 * better fit for production. A missing key or model comes back as a blocked result rather than an
 * exception, so a caller reads the reason instead of catching.
 */
public with sharing class GoogleGeminiIntelligenceStrategy implements IGoogleFileIntelligenceStrategy, IGoogleFileLabelingStrategy {
    public class GoogleGeminiConfigurationException extends Exception {}

    private static final String VALIDATION_PROMPT = 'Reply with OK.';
	private static final Integer VALIDATION_OUTPUT_TOKENS = 4;
	private static final Integer VALIDATION_THINKING_BUDGET = 0;

    private GoogleMetadataConfigService metadataService;
    private IGenAiApiKeyProvider apiKeyProvider;
	private GoogleFileSummarizeCommand summarizeCommand = new GoogleFileSummarizeCommand();
	private GoogleFileQuestionCommand questionCommand = new GoogleFileQuestionCommand();
	private GoogleFileLabelCommand labelCommand = new GoogleFileLabelCommand();
	private IGenAiClient genAiClient;

	public GoogleGeminiIntelligenceStrategy() {
        this(new GoogleMetadataConfigService(), new DefaultGoogleGenAiApiKeyProvider());
    }

    /**
     * Builds the strategy on your own source of the API key, for an org that keeps it somewhere other than
     * the Google Client configuration.
     *
     * @param apiKeyProvider Where the key comes from.
     */
    public GoogleGeminiIntelligenceStrategy(IGenAiApiKeyProvider apiKeyProvider) {
        this(new GoogleMetadataConfigService(), apiKeyProvider);
    }

    @TestVisible
	private GoogleGeminiIntelligenceStrategy(GoogleMetadataConfigService metadataService, IGenAiApiKeyProvider apiKeyProvider) {
        this.metadataService = metadataService;
        this.apiKeyProvider = apiKeyProvider;
		this.genAiClient = new GenAiClientFactory().google(new GenAiGoogleDeveloperConfig(apiKeyProvider));
    }

	/**
	 * Sends a tiny request to check the key and model really work.
	 *
	 * @return True when Gemini answered.
	 */
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

	/**
	 * Summarizes a file with Gemini.
	 *
	 * @param localGoogleFileVersionId The version to summarize.
	 * @return The summary, or why there is none.
	 */
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

	/**
	 * Answers a question about a file with Gemini.
	 *
	 * @param localGoogleFileVersionId The version being asked about.
	 * @param question What the user asked.
	 * @return The answer, or why there is none.
	 */
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

	/**
	 * Chooses and applies a Google Drive label with Gemini.
	 *
	 * @param localGoogleFileVersionId The version to label.
	 * @return The chosen label and whether Drive accepted it.
	 */
	public GoogleFileLabelResultDTO label(Id localGoogleFileVersionId) {
		if (localGoogleFileVersionId == null) {
			return null;
		}

		try {
			validateGeminiConfiguration();
		} catch (Exception ex) {
			return buildBlockedLabelResult(ex.getMessage());
		}

		return this.labelCommand.label(localGoogleFileVersionId, 'Gemini', this.metadataService.getGoogleAiModel(), this.genAiClient);
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

	private GoogleFileLabelResultDTO buildBlockedLabelResult(String errorMessage) {
		GoogleFileLabelResultDTO result = new GoogleFileLabelResultDTO();
		result.blocked = true;
		result.provider = 'Gemini';
		result.errorMessage = errorMessage;
		return result;
	}
}