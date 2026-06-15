public with sharing class GenAiGoogleResponseParser implements IGenAiResponseParser {
    public GenAiResponse parse(HttpResponse response) {
        if (response == null) {
            throw new GenAiProviderException('Google response was empty.');
        }

        if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
            throw new GenAiProviderException(response.getBody());
        }

        GenAiResponse parsed = new GenAiResponse();
        parsed.statusCode = response.getStatusCode();
        parsed.rawBody = response.getBody();

        if (String.isBlank(response.getBody())) {
            return parsed;
        }

        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
        parsed.raw = payload;
        parsed.modelVersion = asString(payload.get('modelVersion'));
        parsed.usage = parseUsage((Map<String, Object>) payload.get('usageMetadata'));

        List<Object> candidates = (List<Object>) payload.get('candidates');
        Integer index = 0;

        if (candidates != null) {
            for (Object item : candidates) {
                Map<String, Object> candidatePayload = (Map<String, Object>) item;
                GenAiCandidate candidate = new GenAiCandidate();
                candidate.index = candidatePayload.containsKey('index') ? asInteger(candidatePayload.get('index')) : index;
                candidate.finishReason = asString(candidatePayload.get('finishReason'));
                candidate.avgLogprobs = asDecimal(candidatePayload.get('avgLogprobs'));
                candidate.content = parseMessage((Map<String, Object>) candidatePayload.get('content'));
                candidate.raw = candidatePayload;
                parsed.addCandidate(candidate);
                index++;
            }
        }

        return parsed;
    }

    private GenAiUsage parseUsage(Map<String, Object> usagePayload) {
        if (usagePayload == null) {
            return null;
        }

        GenAiUsage usage = new GenAiUsage();
        usage.promptTokens = asInteger(usagePayload.get('promptTokenCount'));
        usage.candidateTokens = asInteger(usagePayload.get('candidatesTokenCount'));
        usage.totalTokens = asInteger(usagePayload.get('totalTokenCount'));
        return usage;
    }

    private GenAiMessage parseMessage(Map<String, Object> messagePayload) {
        if (messagePayload == null) {
            return null;
        }

        GenAiMessage message = new GenAiMessage(asString(messagePayload.get('role')));
        List<Object> parts = (List<Object>) messagePayload.get('parts');

        if (parts != null) {
            for (Object item : parts) {
                Map<String, Object> partPayload = (Map<String, Object>) item;
                message.addPart(parsePart(partPayload));
            }
        }

        return message;
    }

    private GenAiPart parsePart(Map<String, Object> partPayload) {
        GenAiPart part;

        if (partPayload.containsKey('text')) {
            part = new GenAiPart('text').withText(asString(partPayload.get('text')));
        } else if (partPayload.containsKey('inlineData')) {
            Map<String, Object> inlineData = (Map<String, Object>) partPayload.get('inlineData');
            part = new GenAiPart('inlineData')
                .withMimeType(asString(inlineData.get('mimeType')))
                .withData(asString(inlineData.get('data')));
        } else if (partPayload.containsKey('fileData')) {
            Map<String, Object> fileData = (Map<String, Object>) partPayload.get('fileData');
            part = new GenAiPart('fileData')
                .withMimeType(asString(fileData.get('mimeType')))
                .withFileUri(asString(fileData.get('fileUri')));
        } else if (partPayload.containsKey('functionCall')) {
            Map<String, Object> functionCall = (Map<String, Object>) partPayload.get('functionCall');
            part = new GenAiPart('functionCall')
                .withName(asString(functionCall.get('name')))
                .withPayload((Map<String, Object>) functionCall.get('args'));
        } else if (partPayload.containsKey('functionResponse')) {
            Map<String, Object> functionResponse = (Map<String, Object>) partPayload.get('functionResponse');
            part = new GenAiPart('functionResponse')
                .withName(asString(functionResponse.get('name')))
                .withPayload((Map<String, Object>) functionResponse.get('response'));
        } else if (partPayload.containsKey('executableCode')) {
            part = new GenAiPart('executableCode').withPayload((Map<String, Object>) partPayload.get('executableCode'));
        } else if (partPayload.containsKey('codeExecutionResult')) {
            part = new GenAiPart('codeExecutionResult').withPayload((Map<String, Object>) partPayload.get('codeExecutionResult'));
        } else {
            part = new GenAiPart('raw').withPayload(partPayload);
        }

        if (partPayload.containsKey('mediaResolution')) {
            part.withMediaResolution(asString(partPayload.get('mediaResolution')));
        }

        return part;
    }

    private String asString(Object value) {
        return value == null ? null : String.valueOf(value);
    }

    private Integer asInteger(Object value) {
        return value == null ? null : Integer.valueOf(String.valueOf(value));
    }

    private Decimal asDecimal(Object value) {
        return value == null ? null : Decimal.valueOf(String.valueOf(value));
    }
}