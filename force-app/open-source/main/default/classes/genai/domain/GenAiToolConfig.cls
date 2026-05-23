public class GenAiToolConfig {
    public String functionMode;
    public Boolean streamFunctionCallArguments;
    public List<String> allowedFunctionNames;
    public Map<String, Object> extensions;

    public GenAiToolConfig() {
        this.allowedFunctionNames = new List<String>();
        this.extensions = new Map<String, Object>();
    }

    public GenAiToolConfig allowFunction(String name) {
        if (String.isNotBlank(name)) {
            allowedFunctionNames.add(name);
        }

        return this;
    }

    public GenAiToolConfig putExtension(String name, Object value) {
        if (String.isNotBlank(name) && value != null) {
            extensions.put(name, value);
        }
		
        return this;
    }

    public Boolean isEmpty() {
        return String.isBlank(functionMode)
            && streamFunctionCallArguments == null
            && allowedFunctionNames.isEmpty()
            && extensions.isEmpty();
    }
}