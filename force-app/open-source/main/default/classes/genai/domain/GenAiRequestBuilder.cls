public with sharing class GenAiRequestBuilder {
    private GenAiRequest request;

    public GenAiRequestBuilder(String model) {
        this.request = new GenAiRequest(model);
    }

    public GenAiRequestBuilder withSystemText(String text) {
        if (String.isNotBlank(text)) {
            request.setSystemMessage(new GenAiMessage('system').addText(text));
        }

        return this;
    }

    public GenAiRequestBuilder withSystemMessage(GenAiMessage message) {
        request.setSystemMessage(message);
        return this;
    }

    public GenAiRequestBuilder withOperation(String operation) {
        request.setOperation(operation);
        return this;
    }

    public GenAiRequestBuilder addMessage(GenAiMessage message) {
        request.addMessage(message);
        return this;
    }

    public GenAiRequestBuilder addText(String role, String text) {
        if (String.isNotBlank(role) && String.isNotBlank(text)) {
            request.addMessage(new GenAiMessage(role).addText(text));
        }
		
        return this;
    }

    public GenAiRequestBuilder addUserText(String text) {
        return addText('user', text);
    }

    public GenAiRequestBuilder addModelText(String text) {
        return addText('model', text);
    }

    public GenAiRequestBuilder addTool(GenAiTool tool) {
        request.addTool(tool);
        return this;
    }

    public GenAiRequestBuilder withToolMode(String functionMode) {
        toolConfig().functionMode = functionMode;
        return this;
    }

    public GenAiRequestBuilder allowFunction(String functionName) {
        toolConfig().allowFunction(functionName);
        return this;
    }

    public GenAiRequestBuilder withStreamFunctionCallArguments(Boolean streamFunctionCallArguments) {
        toolConfig().streamFunctionCallArguments = streamFunctionCallArguments;
        return this;
    }

    public GenAiRequestBuilder addSafety(String category, String threshold, String method) {
        request.addSafetySetting(new GenAiSafetySetting(category, threshold, method));
        return this;
    }

    public GenAiRequestBuilder withTemperature(Decimal temperature) {
        generation().temperature = temperature;
        return this;
    }

    public GenAiRequestBuilder withTopP(Decimal topP) {
        generation().topP = topP;
        return this;
    }

    public GenAiRequestBuilder withTopK(Integer topK) {
        generation().topK = topK;
        return this;
    }

    public GenAiRequestBuilder withCandidates(Integer candidateCount) {
        generation().candidateCount = candidateCount;
        return this;
    }

    public GenAiRequestBuilder withMaxTokens(Integer maxTokens) {
        generation().maxTokens = maxTokens;
        return this;
    }

    public GenAiRequestBuilder withPresencePenalty(Decimal presencePenalty) {
        generation().presencePenalty = presencePenalty;
        return this;
    }

    public GenAiRequestBuilder withFrequencyPenalty(Decimal frequencyPenalty) {
        generation().frequencyPenalty = frequencyPenalty;
        return this;
    }

    public GenAiRequestBuilder withStop(String stopSequence) {
        generation().addStop(stopSequence);
        return this;
    }

    public GenAiRequestBuilder withResponseMimeType(String responseMimeType) {
        generation().responseMimeType = responseMimeType;
        return this;
    }

    public GenAiRequestBuilder withResponseSchema(Map<String, Object> responseSchema) {
        generation().setResponseSchema(responseSchema);
        return this;
    }

    public GenAiRequestBuilder withResponseModality(String responseModality) {
        generation().addResponseModality(responseModality);
        return this;
    }

    public GenAiRequestBuilder withSeed(Integer seed) {
        generation().seed = seed;
        return this;
    }

    public GenAiRequestBuilder withResponseLogprobs(Boolean responseLogprobs) {
        generation().responseLogprobs = responseLogprobs;
        return this;
    }

    public GenAiRequestBuilder withLogprobs(Integer logprobs) {
        generation().logprobs = logprobs;
        return this;
    }

    public GenAiRequestBuilder withLabel(String name, String value) {
        request.putLabel(name, value);
        return this;
    }

    public GenAiRequestBuilder withProviderOptions(Object providerOptions) {
        request.setProviderOptions(providerOptions);
        return this;
    }

    public GenAiRequest build() {
        return request;
    }

    private GenAiToolConfig toolConfig() {
        if (request.toolConfig == null) {
            request.setToolConfig(new GenAiToolConfig());
        }

        return request.toolConfig;
    }

    private GenAiGenerationConfig generation() {
        if (request.generation == null) {
            request.setGeneration(new GenAiGenerationConfig());
        }

        return request.generation;
    }
}