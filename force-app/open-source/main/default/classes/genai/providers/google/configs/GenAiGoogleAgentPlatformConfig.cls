public with sharing class GenAiGoogleAgentPlatformConfig extends GenAiGoogleConfig {
    private static final String DEFAULT_ENDPOINT_BASE = 'https://aiplatform.googleapis.com/v1';
    private static final Integer DEFAULT_TIMEOUT_MS = 20000;

    public String projectId;
    public String location;
    public String publisher;
    public IGenAiAccessTokenProvider tokenProvider;

    public GenAiGoogleAgentPlatformConfig(String projectId, String location, IGenAiAccessTokenProvider tokenProvider) {
        this(projectId, location, tokenProvider, DEFAULT_ENDPOINT_BASE);
    }

    public GenAiGoogleAgentPlatformConfig(String projectId, String location, IGenAiAccessTokenProvider tokenProvider, String endpointBase) {
        super(String.isNotBlank(endpointBase) ? endpointBase : DEFAULT_ENDPOINT_BASE, DEFAULT_TIMEOUT_MS);
        this.projectId = projectId;
        this.location = location;
        this.publisher = 'google';
        this.tokenProvider = tokenProvider;
    }

    public GenAiGoogleAgentPlatformConfig withPublisher(String publisher) {
        if (String.isNotBlank(publisher)) {
            this.publisher = publisher;
        }

        return this;
    }

    public GenAiGoogleAgentPlatformConfig withEndpointBase(String endpointBase) {
        if (String.isNotBlank(endpointBase)) {
            this.endpointBase = endpointBase;
        }

        return this;
    }

    public GenAiGoogleAgentPlatformConfig withTimeout(Integer timeoutMs) {
        if (timeoutMs != null && timeoutMs > 0) {
            this.timeoutMs = timeoutMs;
        }
		
        return this;
    }

    public override IGenAiGoogleAdapter adapter() {
        return new GenAiGoogleAgentPlatformAdapter(this);
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

        List<String> segments = new List<String>{
            EncodingUtil.urlEncode(projectId, 'UTF-8'),
            EncodingUtil.urlEncode(location, 'UTF-8'),
            EncodingUtil.urlEncode(publisher, 'UTF-8'),
            EncodingUtil.urlEncode(request.model, 'UTF-8')
        };

        return trimmedBase
            + '/projects/' + segments[0]
            + '/locations/' + segments[1]
            + '/publishers/' + segments[2]
            + '/models/' + segments[3]
            + ':' + request.operation;
    }

    public override void applyAuthentication(GenAiInvocation invocation) {
        if (tokenProvider == null) {
            throw new GenAiConfigurationException('Google token provider is required.');
        }

        GenAiAccessToken accessToken = tokenProvider.token();
        if (accessToken == null || String.isBlank(accessToken.headerValue())) {
            throw new GenAiConfigurationException('Google access token is required.');
        }

        invocation.putHeader('Authorization', accessToken.headerValue());
    }
}