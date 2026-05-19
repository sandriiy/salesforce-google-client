public with sharing class GenAiGoogleAgentPlatformAdapter extends GenAiGoogleAdapterBase {
    private GenAiGoogleAgentPlatformConfig config;

    public GenAiGoogleAgentPlatformAdapter(GenAiGoogleAgentPlatformConfig config) {
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

        if (String.isBlank(config.projectId)) {
            throw new GenAiConfigurationException('Google project ID is required.');
        }

        if (String.isBlank(config.location)) {
            throw new GenAiConfigurationException('Google location is required.');
        }

        if (config.tokenProvider == null) {
            throw new GenAiConfigurationException('Google token provider is required.');
        }
    }
}