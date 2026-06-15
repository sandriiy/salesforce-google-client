public class GenAiMessage {
    public String role;
    public List<GenAiPart> parts;

    public GenAiMessage(String role) {
        this.role = role;
        this.parts = new List<GenAiPart>();
    }

    public GenAiMessage addPart(GenAiPart part) {
        if (part != null) {
            parts.add(part);
        }

        return this;
    }

    public GenAiMessage addText(String text) {
        if (String.isNotBlank(text)) {
            parts.add(new GenAiPart('text').withText(text));
        }

        return this;
    }

    public GenAiMessage addInlineData(String mimeType, Blob content) {
        if (content != null) {
            parts.add(new GenAiPart('inlineData').withMimeType(mimeType).withData(EncodingUtil.base64Encode(content)));
        }

        return this;
    }

    public GenAiMessage addFile(String mimeType, String fileUri) {
        if (String.isNotBlank(fileUri)) {
            parts.add(new GenAiPart('fileData').withMimeType(mimeType).withFileUri(fileUri));
        }
		
        return this;
    }

    public GenAiMessage addFunctionCall(String name, Map<String, Object> arguments) {
        parts.add(new GenAiPart('functionCall').withName(name).withPayload(arguments));
        return this;
    }

    public GenAiMessage addFunctionResponse(String name, Map<String, Object> response) {
        parts.add(new GenAiPart('functionResponse').withName(name).withPayload(response));
        return this;
    }

    public String text() {
        List<String> textParts = new List<String>();

        for (GenAiPart part : parts) {
            if (part != null && part.kind == 'text' && String.isNotBlank(part.text)) {
                textParts.add(part.text);
            }
        }

        return textParts.isEmpty() ? null : String.join(textParts, '\n');
    }
}