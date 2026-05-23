public abstract with sharing class GenAiGoogleAdapterBase implements IGenAiGoogleAdapter {
    private IGenAiRequestSerializer requestSerializer;
    private IGenAiResponseParser responseParser;

    protected GenAiGoogleAdapterBase() {
        this(new GenAiGoogleRequestSerializer(), new GenAiGoogleResponseParser());
    }

    protected GenAiGoogleAdapterBase(IGenAiRequestSerializer requestSerializer, IGenAiResponseParser responseParser) {
        this.requestSerializer = requestSerializer;
        this.responseParser = responseParser;
    }

    public void validate(GenAiRequest request) {
        validateConfig();
        validateRequest(request);
    }

    public GenAiResponse parse(HttpResponse response) {
        return responseParser.parse(response);
    }

    protected String serialize(GenAiRequest request) {
        return requestSerializer.serialize(request);
    }

    protected GenAiInvocation buildInvocation(String endpoint, GenAiRequest request, Integer timeoutMs) {
        GenAiInvocation invocation = new GenAiInvocation('POST', endpoint, serialize(request), timeoutMs);
        invocation.putHeader('Content-Type', 'application/json');
        return invocation;
    }

    protected void validateRequest(GenAiRequest request) {
        if (request == null) {
            throw new GenAiConfigurationException('GenAi request is required.');
        }

        if (String.isBlank(request.model)) {
            throw new GenAiConfigurationException('Google model is required.');
        }

        if (String.isBlank(request.operation)) {
            throw new GenAiConfigurationException('Google operation is required.');
        }

        if (request.messages.isEmpty()) {
            throw new GenAiConfigurationException('At least one message is required.');
        }

        for (GenAiMessage message : request.messages) {
            if (message == null || message.parts.isEmpty()) {
                throw new GenAiConfigurationException('Each message must include at least one part.');
            }
        }
    }

    protected void ensureGenerateContent(GenAiRequest request) {
        if (request.operation != 'generateContent') {
            throw new GenAiConfigurationException('Google adapter currently supports generateContent only.');
        }
    }

    protected abstract void validateConfig();
}