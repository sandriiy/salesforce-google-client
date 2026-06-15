public class GenAiPart {
    public String kind;
    public String text;
    public String mimeType;
    public String data;
    public String fileUri;
    public String name;
    public String mediaResolution;
    public Map<String, Object> payload;

    public GenAiPart(String kind) {
        this.kind = kind;
    }

    public GenAiPart withText(String text) {
        this.text = text;
        return this;
    }

    public GenAiPart withMimeType(String mimeType) {
        this.mimeType = mimeType;
        return this;
    }

    public GenAiPart withData(String data) {
        this.data = data;
        return this;
    }

    public GenAiPart withFileUri(String fileUri) {
        this.fileUri = fileUri;
        return this;
    }

    public GenAiPart withName(String name) {
        this.name = name;
        return this;
    }

    public GenAiPart withMediaResolution(String mediaResolution) {
        this.mediaResolution = mediaResolution;
        return this;
    }

    public GenAiPart withPayload(Map<String, Object> payload) {
        this.payload = payload;
        return this;
    }
}