public with sharing class GoogleGeminiIntelligenceStrategy implements IGoogleFileIntelligenceStrategy {
    public class GoogleGeminiConfigurationException extends Exception {}

	private static final String GENERATE_CONTENT_ENDPOINT_TEMPLATE = 'https://generativelanguage.googleapis.com/v1beta/models/{0}:generateContent';
    private static final String HTTP_METHOD_POST = 'POST';
    private static final String HEADER_API_KEY = 'x-goog-api-key';
    private static final String HEADER_CONTENT_TYPE = 'Content-Type';
    private static final String CONTENT_TYPE_JSON = 'application/json';
    private static final String VALIDATION_PROMPT = 'Reply with OK.';
    private static final Integer REQUEST_TIMEOUT_MS = 20000;
    private static final Integer MAX_OUTPUT_TOKENS = 8;

    private GoogleMetadataConfigService metadataService;

	public GoogleGeminiIntelligenceStrategy() {
        this.metadataService = new GoogleMetadataConfigService();
    }

	public Boolean validate() {
		validateGeminiConfiguration();

        try {
            HttpResponse response = sendValidationRequest();
            return isSuccessfulValidationResponse(response);
        } catch (Exception ex) {
			throw new GoogleGeminiConfigurationException(ex.getMessage());
        }
	}

	public GoogleFileAnalysisResultDTO summarize(Id localGoogleFileVersionId) {
		return null;
	}

	public GoogleFileAnalysisResultDTO answerQuestion(Id localGoogleFileVersionId, String question) {
		return null;
	}

    private void validateGeminiConfiguration() {
        String apiKey = metadataService.getGoogleGeminiKey();
        String modelName = metadataService.getGoogleAiModel();

        if (String.isBlank(apiKey)) {
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

    private HttpResponse sendValidationRequest() {
        HttpRequest request = new HttpRequest();
        request.setEndpoint(buildGenerateContentEndpoint(metadataService.getGoogleAiModel()));
        request.setMethod(HTTP_METHOD_POST);
        request.setHeader(HEADER_API_KEY, metadataService.getGoogleGeminiKey());
        request.setHeader(HEADER_CONTENT_TYPE, CONTENT_TYPE_JSON);
        request.setTimeout(REQUEST_TIMEOUT_MS);
        request.setBody(buildValidationRequestBody());

        return new Http().send(request);
    }

    private String buildGenerateContentEndpoint(String modelName) {
        return String.format(
            GENERATE_CONTENT_ENDPOINT_TEMPLATE,
            new List<String>{ EncodingUtil.urlEncode(modelName, 'UTF-8') }
        );
    }

    private String buildValidationRequestBody() {
        Map<String, Object> requestBody = new Map<String, Object>{
            'contents' => new List<Object>{
                new Map<String, Object>{
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
			throw new GoogleGeminiConfigurationException(response.getBody());
        }

        if (String.isBlank(response.getBody())) {
            return false;
        }

        Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
        List<Object> candidates = (List<Object>) responseBody.get('candidates');

        return candidates != null && !candidates.isEmpty();
    }
}