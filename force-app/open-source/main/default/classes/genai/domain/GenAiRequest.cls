public class GenAiRequest {
    private static final String DEFAULT_OPERATION = 'generateContent';

    public String model;
    public String operation;
    public GenAiMessage systemMessage;
    public List<GenAiMessage> messages;
    public List<GenAiTool> tools;
    public GenAiToolConfig toolConfig;
    public List<GenAiSafetySetting> safetySettings;
    public GenAiGenerationConfig generation;
    public Map<String, String> labels;
    public Object providerOptions;

    public GenAiRequest(String model) {
        this.model = model;
        this.operation = DEFAULT_OPERATION;
        this.messages = new List<GenAiMessage>();
        this.tools = new List<GenAiTool>();
        this.safetySettings = new List<GenAiSafetySetting>();
        this.generation = new GenAiGenerationConfig();
        this.labels = new Map<String, String>();
    }

    public void setOperation(String operation) {
        this.operation = String.isNotBlank(operation) ? operation : DEFAULT_OPERATION;
    }

    public void setSystemMessage(GenAiMessage systemMessage) {
        this.systemMessage = systemMessage;
    }

    public void addMessage(GenAiMessage message) {
        if (message != null) {
            messages.add(message);
        }
    }

    public void addTool(GenAiTool tool) {
        if (tool != null) {
            tools.add(tool);
        }
    }

    public void setToolConfig(GenAiToolConfig toolConfig) {
        this.toolConfig = toolConfig;
    }

    public void addSafetySetting(GenAiSafetySetting safetySetting) {
        if (safetySetting != null) {
            safetySettings.add(safetySetting);
        }
    }

    public void setGeneration(GenAiGenerationConfig generation) {
        this.generation = generation == null ? new GenAiGenerationConfig() : generation;
    }

    public void putLabel(String name, String value) {
        if (String.isNotBlank(name) && value != null) {
            labels.put(name, value);
        }
    }

    public void setProviderOptions(Object providerOptions) {
        this.providerOptions = providerOptions;
    }
}