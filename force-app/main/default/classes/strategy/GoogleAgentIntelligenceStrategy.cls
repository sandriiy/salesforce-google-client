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

	private static final String GENERATE_CONTENT_ENDPOINT_TEMPLATE = 'https://aiplatform.googleapis.com/v1/projects/{0}/locations/{1}/publishers/google/models/{2}:generateContent';
    private static final String HTTP_METHOD_POST = 'POST';
    private static final String HEADER_AUTHORIZATION = 'Authorization';
    private static final String HEADER_CONTENT_TYPE = 'Content-Type';
    private static final String CONTENT_TYPE_JSON = 'application/json';
    private static final String DEFAULT_TOKEN_TYPE = 'Bearer';
    private static final String VALIDATION_PROMPT = 'Reply with OK.';
    private static final Integer REQUEST_TIMEOUT_MS = 20000;
    private static final Integer MAX_OUTPUT_TOKENS = 8;

	private GoogleClientApiProvider googleApiProvider;
	private GoogleCredential googleCredential;
    private GoogleMetadataConfigService metadataService;

    public GoogleAgentIntelligenceStrategy() {
        this.metadataService = new GoogleMetadataConfigService();
        this.googleApiProvider = new GoogleClientApiProvider();
		this.googleCredential = googleApiProvider.retrieveGoogleClientCreds();
    }

	public Boolean validate() {
       	validateAgentConfiguration();

        try {
            HttpResponse response = sendValidationRequest();
            return isSuccessfulValidationResponse(response);
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
    }

    private HttpResponse sendValidationRequest() {
		String projectId = metadataService.getGoogleAgentProjectId();
        String location = metadataService.getGoogleAgentLocation();
        String modelName = metadataService.getGoogleAiModel();

        HttpRequest request = new HttpRequest();
        request.setEndpoint(buildGenerateContentEndpoint());
        request.setMethod(HTTP_METHOD_POST);
        request.setHeader(HEADER_AUTHORIZATION, buildAuthorizationHeader());
        request.setHeader(HEADER_CONTENT_TYPE, CONTENT_TYPE_JSON);
        request.setTimeout(REQUEST_TIMEOUT_MS);
        request.setBody(buildValidationRequestBody());

        return new Http().send(request);
    }

    private String buildGenerateContentEndpoint() {
		String projectId = metadataService.getGoogleAgentProjectId();
        String location = metadataService.getGoogleAgentLocation();
        String modelName = metadataService.getGoogleAiModel();

        return String.format(
            GENERATE_CONTENT_ENDPOINT_TEMPLATE,
            new List<String>{
                EncodingUtil.urlEncode(projectId, 'UTF-8'),
                EncodingUtil.urlEncode(location, 'UTF-8'),
                EncodingUtil.urlEncode(modelName, 'UTF-8')
            }
        );
    }

    private String buildAuthorizationHeader() {
        String tokenType = String.isBlank(googleCredential.tokenType)
            ? DEFAULT_TOKEN_TYPE
            : googleCredential.tokenType.trim();

        return tokenType + ' ' + googleCredential.accessToken.trim();
    }

    private String buildValidationRequestBody() {
        Map<String, Object> requestBody = new Map<String, Object>{
            'contents' => new List<Object>{
                new Map<String, Object>{
                    'role' => 'user',
                    'parts' => new List<Object>{
                        new Map<String, Object>{
                            'text' => VALIDATION_PROMPT
                        }
                    }
                }
            },
            'generationConfig' => new Map<String, Object>{
                'temperature' => 0,
                'maxOutputTokens' => MAX_OUTPUT_TOKENS
            }
        };

        return JSON.serialize(requestBody);
    }

    private Boolean isSuccessfulValidationResponse(HttpResponse response) {
        if (response == null || response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
			throw new GoogleAgentConfigurationException(response.getBody());
        }

        if (String.isBlank(response.getBody())) {
            return false;
        }

        Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
        List<Object> candidates = (List<Object>) responseBody.get('candidates');

        return candidates != null && !candidates.isEmpty();
    }
}