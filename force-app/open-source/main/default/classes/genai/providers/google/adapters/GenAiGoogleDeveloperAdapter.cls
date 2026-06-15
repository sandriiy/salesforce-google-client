public with sharing class GenAiGoogleDeveloperAdapter extends GenAiGoogleAdapterBase {
    private GenAiGoogleDeveloperConfig config;

    public GenAiGoogleDeveloperAdapter(GenAiGoogleDeveloperConfig config) {
        this.config = config;
    }

    public GenAiInvocation build(GenAiRequest request) {
        validate(request);
        ensureGenerateContent(request);

        GenAiInvocation invocation = buildInvocation(config.resolveEndpoint(request), request, config.timeoutMs);
        config.applyAuthentication(invocation);
        return invocation;
    }

    protected override void validateConfig() {
        if (config == null) {
            throw new GenAiConfigurationException('Google configuration is required.');
        }

        GenAiApiKey apiKey = config.resolvedApiKey();
        if (apiKey == null || !apiKey.isConfigured()) {
            throw new GenAiConfigurationException('Google API key is required.');
        }
    }
}