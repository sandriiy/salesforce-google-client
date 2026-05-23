public class GenAiTool {
    public String kind;
    public String name;
    public String description;
    public Map<String, Object> parameters;
    public Map<String, Object> responseSchema;
    public Map<String, Object> config;

    public GenAiTool(String kind) {
        this.kind = kind;
    }

    public GenAiTool withName(String name) {
        this.name = name;
        return this;
    }

    public GenAiTool withDescription(String description) {
        this.description = description;
        return this;
    }

    public GenAiTool withParameters(Map<String, Object> parameters) {
        this.parameters = parameters;
        return this;
    }

    public GenAiTool withResponseSchema(Map<String, Object> responseSchema) {
        this.responseSchema = responseSchema;
        return this;
    }

    public GenAiTool withConfig(Map<String, Object> config) {
        this.config = config;
        return this;
    }
}