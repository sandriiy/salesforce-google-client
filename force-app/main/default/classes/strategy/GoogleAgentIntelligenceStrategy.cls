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
public with sharing class GoogleAgentIntelligenceStrategy implements IGoogleFileIntelligenceStrategy {
    public class GoogleAgentConfigurationException extends Exception {}

    private static final String VALIDATION_PROMPT = 'Reply with OK.';
    private static final Integer VALIDATION_OUTPUT_TOKENS = 20;

    private GoogleMetadataConfigService metadataService;
    private IGenAiAccessTokenProvider tokenProvider;
	private IGenAiClient genAiClient;

    public GoogleAgentIntelligenceStrategy() {
        this(new GoogleMetadataConfigService(), new DefaultGoogleGenAiAccessTokenProvider());
    }

    public GoogleAgentIntelligenceStrategy(IGenAiAccessTokenProvider tokenProvider) {
        this(new GoogleMetadataConfigService(), tokenProvider);
    }

    @TestVisible
    private GoogleAgentIntelligenceStrategy(GoogleMetadataConfigService metadataService, IGenAiAccessTokenProvider tokenProvider) {
        this.metadataService = metadataService;
        this.tokenProvider = tokenProvider;
		this.genAiClient = new GenAiClientFactory().google(
            new GenAiGoogleAgentPlatformConfig(
                metadataService.getGoogleAgentProjectId(),
                metadataService.getGoogleAgentLocation(),
                tokenProvider
            )
        );
    }

	public Boolean validate() {
       	validateAgentConfiguration();

        try {
			GenAiRequest validationRequest = new GenAiRequestBuilder(metadataService.getGoogleAiModel())
				.addUserText(VALIDATION_PROMPT)
				.withTemperature(0.0)
				.withMaxTokens(VALIDATION_OUTPUT_TOKENS)
				.build();
			
            GenAiResponse response = genAiClient.generate(validationRequest);
			System.debug('REPLY');
			System.debug(response.firstText());
            return response != null && response.hasCandidates();
        } catch (Exception ex) {
			throw new GoogleAgentConfigurationException(ex.getMessage());
        }
	}

    public GoogleFileAnalysisResultDTO summarize(Id localGoogleFileVersionId) {
		return null;
	}

	public GoogleFileAnalysisResultDTO answerQuestion(Id localGoogleFileVersionId, String question) {
		return null;
	}

    private void validateAgentConfiguration() {
        String projectId = metadataService.getGoogleAgentProjectId();
        String location = metadataService.getGoogleAgentLocation();
        String modelName = metadataService.getGoogleAiModel();
        GenAiAccessToken accessToken = tokenProvider == null ? null : tokenProvider.token();

        if (String.isBlank(projectId)) {
			throw new GoogleAgentConfigurationException(
				'Unable to locate the Agent Platform project ID. Please verify the Agent Platform configuration is set correctly'
			);
		}

		if (String.isBlank(location)) {
			throw new GoogleAgentConfigurationException(
				'Unable to locate the Agent Platform location. Please verify the Agent Platform configuration is set correctly'
			);
		}

		if (String.isBlank(modelName)) {
			throw new GoogleAgentConfigurationException(
				'Unable to locate the Agent Platform model name. Please verify the Agent Platform configuration is set correctly'
			);
		}

        if (accessToken == null || String.isBlank(accessToken.headerValue())) {
            throw new GoogleAgentConfigurationException(
                'Unable to locate the Agent Platform access token. Please verify the Google service account configuration is set correctly'
            );
        }
    }
}