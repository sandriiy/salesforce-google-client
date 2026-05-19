public with sharing class GenAiGoogleRequestSerializer implements IGenAiRequestSerializer {
    public String serialize(GenAiRequest request) {
        Map<String, Object> body = new Map<String, Object>();
        body.put('contents', serializeMessages(request.messages, true));

        if (request.systemMessage != null && !request.systemMessage.parts.isEmpty()) {
            body.put('systemInstruction', serializeMessage(request.systemMessage, false));
        }

        List<Object> tools = serializeTools(request.tools);
        if (!tools.isEmpty()) {
            body.put('tools', tools);
        }

        Map<String, Object> toolConfig = serializeToolConfig(request.toolConfig);
        if (!toolConfig.isEmpty()) {
            body.put('toolConfig', toolConfig);
        }

        List<Object> safetySettings = serializeSafetySettings(request.safetySettings);
        if (!safetySettings.isEmpty()) {
            body.put('safetySettings', safetySettings);
        }

        Map<String, Object> generationConfig = serializeGeneration(request.generation, request.providerOptions);
        if (!generationConfig.isEmpty()) {
            body.put('generationConfig', generationConfig);
        }

        if (request.labels != null && !request.labels.isEmpty()) {
            body.put('labels', request.labels);
        }

        if (request.providerOptions instanceof GenAiGoogleOptions) {
            GenAiGoogleOptions googleOptions = (GenAiGoogleOptions) request.providerOptions;
            if (String.isNotBlank(googleOptions.cachedContent)) {
                body.put('cachedContent', googleOptions.cachedContent);
            }
        }

        return JSON.serialize(body);
    }

    private List<Object> serializeMessages(List<GenAiMessage> messages, Boolean includeRole) {
        List<Object> serialized = new List<Object>();

        for (GenAiMessage message : messages) {
            serialized.add(serializeMessage(message, includeRole));
        }

        return serialized;
    }

    private Map<String, Object> serializeMessage(GenAiMessage message, Boolean includeRole) {
        Map<String, Object> serialized = new Map<String, Object>();

        if (includeRole && String.isNotBlank(message.role)) {
            serialized.put('role', message.role);
        }

        serialized.put('parts', serializeParts(message.parts));
        return serialized;
    }

    private List<Object> serializeParts(List<GenAiPart> parts) {
        List<Object> serialized = new List<Object>();

        for (GenAiPart part : parts) {
            Map<String, Object> value = new Map<String, Object>();

            if (part.kind == 'text') {
                value.put('text', part.text);
            } else if (part.kind == 'inlineData') {
                value.put('inlineData', new Map<String, Object>{
                    'mimeType' => part.mimeType,
                    'data' => part.data
                });
            } else if (part.kind == 'fileData') {
                value.put('fileData', new Map<String, Object>{
                    'mimeType' => part.mimeType,
                    'fileUri' => part.fileUri
                });
            } else if (part.kind == 'functionCall') {
                value.put('functionCall', new Map<String, Object>{
                    'name' => part.name,
                    'args' => part.payload == null ? new Map<String, Object>() : part.payload
                });
            } else if (part.kind == 'functionResponse') {
                value.put('functionResponse', new Map<String, Object>{
                    'name' => part.name,
                    'response' => part.payload == null ? new Map<String, Object>() : part.payload
                });
            } else if (part.kind == 'executableCode') {
                value.put('executableCode', part.payload == null ? new Map<String, Object>() : part.payload);
            } else if (part.kind == 'codeExecutionResult') {
                value.put('codeExecutionResult', part.payload == null ? new Map<String, Object>() : part.payload);
            } else {
                value.put(part.kind, part.payload == null ? new Map<String, Object>() : part.payload);
            }

            if (String.isNotBlank(part.mediaResolution)) {
                value.put('mediaResolution', part.mediaResolution);
            }

            serialized.add(value);
        }

        return serialized;
    }

    private List<Object> serializeTools(List<GenAiTool> tools) {
        List<Object> serialized = new List<Object>();
        List<Object> functions = new List<Object>();

        for (GenAiTool tool : tools) {
            if (tool.kind == 'function') {
                functions.add(serializeFunction(tool));
            } else {
                Map<String, Object> entry = new Map<String, Object>();
                entry.put(tool.kind, tool.config == null ? new Map<String, Object>() : tool.config);
                serialized.add(entry);
            }
        }

        if (!functions.isEmpty()) {
            serialized.add(new Map<String, Object>{ 'functionDeclarations' => functions });
        }

        return serialized;
    }

    private Map<String, Object> serializeFunction(GenAiTool tool) {
        Map<String, Object> serialized = new Map<String, Object>{
            'name' => tool.name,
            'description' => tool.description
        };

        if (tool.parameters != null && !tool.parameters.isEmpty()) {
            serialized.put('parameters', tool.parameters);
        }

        if (tool.responseSchema != null && !tool.responseSchema.isEmpty()) {
            serialized.put('response', tool.responseSchema);
        }

        return serialized;
    }

    private Map<String, Object> serializeToolConfig(GenAiToolConfig toolConfig) {
        Map<String, Object> serialized = new Map<String, Object>();

        if (toolConfig == null || toolConfig.isEmpty()) {
            return serialized;
        }

        Map<String, Object> functionCallingConfig = new Map<String, Object>();

        if (String.isNotBlank(toolConfig.functionMode)) {
            functionCallingConfig.put('mode', toolConfig.functionMode);
        }

        if (!toolConfig.allowedFunctionNames.isEmpty()) {
            functionCallingConfig.put('allowedFunctionNames', toolConfig.allowedFunctionNames);
        }

        if (toolConfig.streamFunctionCallArguments != null) {
            functionCallingConfig.put('streamFunctionCallArguments', toolConfig.streamFunctionCallArguments);
        }

        if (!functionCallingConfig.isEmpty()) {
            serialized.put('functionCallingConfig', functionCallingConfig);
        }

        for (String key : toolConfig.extensions.keySet()) {
            serialized.put(key, toolConfig.extensions.get(key));
        }

        return serialized;
    }

    private List<Object> serializeSafetySettings(List<GenAiSafetySetting> safetySettings) {
        List<Object> serialized = new List<Object>();

        for (GenAiSafetySetting safetySetting : safetySettings) {
            Map<String, Object> entry = new Map<String, Object>{
                'category' => safetySetting.category,
                'threshold' => safetySetting.threshold
            };

            if (String.isNotBlank(safetySetting.method)) {
                entry.put('method', safetySetting.method);
            }

            serialized.add(entry);
        }

        return serialized;
    }

    private Map<String, Object> serializeGeneration(GenAiGenerationConfig generation, Object providerOptions) {
        Map<String, Object> serialized = new Map<String, Object>();

        if (generation != null && !generation.isEmpty()) {
            if (generation.temperature != null) {
                serialized.put('temperature', generation.temperature);
            }

            if (generation.topP != null) {
                serialized.put('topP', generation.topP);
            }

            if (generation.topK != null) {
                serialized.put('topK', generation.topK);
            }

            if (generation.candidateCount != null) {
                serialized.put('candidateCount', generation.candidateCount);
            }

            if (generation.maxTokens != null) {
                serialized.put('maxOutputTokens', generation.maxTokens);
            }

            if (generation.presencePenalty != null) {
                serialized.put('presencePenalty', generation.presencePenalty);
            }

            if (generation.frequencyPenalty != null) {
                serialized.put('frequencyPenalty', generation.frequencyPenalty);
            }

            if (!generation.stopSequences.isEmpty()) {
                serialized.put('stopSequences', generation.stopSequences);
            }

            if (String.isNotBlank(generation.responseMimeType)) {
                serialized.put('responseMimeType', generation.responseMimeType);
            }

            if (!generation.responseSchema.isEmpty()) {
                serialized.put('responseSchema', generation.responseSchema);
            }

            if (!generation.responseModalities.isEmpty()) {
                serialized.put('responseModalities', generation.responseModalities);
            }

            if (generation.seed != null) {
                serialized.put('seed', generation.seed);
            }

            if (generation.responseLogprobs != null) {
                serialized.put('responseLogprobs', generation.responseLogprobs);
            }

            if (generation.logprobs != null) {
                serialized.put('logprobs', generation.logprobs);
            }
        }

        if (providerOptions instanceof GenAiGoogleOptions) {
            GenAiGoogleOptions googleOptions = (GenAiGoogleOptions) providerOptions;

            if (String.isNotBlank(googleOptions.mediaResolution)) {
                serialized.put('mediaResolution', googleOptions.mediaResolution);
            }

            Map<String, Object> thinkingConfig = new Map<String, Object>();
            if (googleOptions.thinkingBudget != null) {
                thinkingConfig.put('thinkingBudget', googleOptions.thinkingBudget);
            }

            if (String.isNotBlank(googleOptions.thinkingLevel)) {
                thinkingConfig.put('thinkingLevel', googleOptions.thinkingLevel);
            }

            if (!thinkingConfig.isEmpty()) {
                serialized.put('thinkingConfig', thinkingConfig);
            }
        }

        return serialized;
    }
}