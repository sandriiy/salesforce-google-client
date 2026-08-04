public with sharing class GenAiGoogleProvider implements IGenAiProvider {
    private GenAiGoogleConfig config;
    private IGenAiGoogleAdapter adapter;

    public GenAiGoogleProvider(GenAiGoogleConfig config) {
        this(config, config == null ? null : config.adapter());
    }

    public GenAiGoogleProvider(GenAiGoogleConfig config, IGenAiGoogleAdapter adapter) {
        this.config = config;
        this.adapter = adapter;
    }

    public void validate(GenAiRequest request) {
        if (config == null) {
            throw new GenAiConfigurationException('Google configuration is required.');
        }

        if (adapter == null) {
            throw new GenAiConfigurationException('Google adapter is required.');
        }

        adapter.validate(request);
    }

    public GenAiInvocation build(GenAiRequest request) {
        validate(request);
        return adapter.build(request);
    }

    public GenAiResponse parse(HttpResponse response) {
        if (adapter == null) {
            throw new GenAiConfigurationException('Google adapter is required.');
        }

        return adapter.parse(response);
    }
}