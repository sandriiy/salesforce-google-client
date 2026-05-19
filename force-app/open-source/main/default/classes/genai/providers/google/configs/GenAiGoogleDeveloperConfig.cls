public with sharing class GenAiGoogleDeveloperConfig extends GenAiGoogleConfig {
    private static final String DEFAULT_ENDPOINT_BASE = 'https://generativelanguage.googleapis.com/v1beta';
    private static final Integer DEFAULT_TIMEOUT_MS = 20000;

    public IGenAiApiKeyProvider apiKeyProvider;

    public GenAiGoogleDeveloperConfig(IGenAiApiKeyProvider apiKeyProvider) {
        this(apiKeyProvider, DEFAULT_ENDPOINT_BASE);
    }

    public GenAiGoogleDeveloperConfig(IGenAiApiKeyProvider apiKeyProvider, String endpointBase) {
        super(String.isNotBlank(endpointBase) ? endpointBase : DEFAULT_ENDPOINT_BASE, DEFAULT_TIMEOUT_MS);
        this.apiKeyProvider = apiKeyProvider;
    }

    public GenAiGoogleDeveloperConfig withEndpointBase(String endpointBase) {
        if (String.isNotBlank(endpointBase)) {
            this.endpointBase = endpointBase;
        }

        return this;
    }

    public GenAiGoogleDeveloperConfig withTimeout(Integer timeoutMs) {
        if (timeoutMs != null && timeoutMs > 0) {
            this.timeoutMs = timeoutMs;
        }
		
        return this;
    }

    public override IGenAiGoogleAdapter adapter() {
        return new GenAiGoogleDeveloperAdapter(this);
    }

    public override String resolveEndpoint(GenAiRequest request) {
        if (request == null || String.isBlank(request.model)) {
            throw new GenAiConfigurationException('Google model is required.');
        }

        if (String.isBlank(request.operation)) {
            throw new GenAiConfigurationException('Google operation is required.');
        }

        String trimmedBase = endpointBase.endsWith('/')
            ? endpointBase.substring(0, endpointBase.length() - 1)
            : endpointBase;

        return trimmedBase
            + '/models/' + EncodingUtil.urlEncode(request.model, 'UTF-8')
            + ':' + request.operation;
    }

    public override void applyAuthentication(GenAiInvocation invocation) {
        GenAiApiKey apiKey = resolvedApiKey();
        if (apiKey == null || !apiKey.isConfigured()) {
            throw new GenAiConfigurationException('Google API key is required.');
        }

        apiKey.apply(invocation);
    }

    public GenAiApiKey resolvedApiKey() {
        return apiKeyProvider == null ? null : apiKeyProvider.apiKey();
    }
}