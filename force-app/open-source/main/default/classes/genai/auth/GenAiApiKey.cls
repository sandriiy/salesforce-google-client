public class GenAiApiKey implements IGenAiApiKeyProvider {
    private static final String DEFAULT_HEADER_NAME = 'x-goog-api-key';

    private String headerName;
    private String value;

    public GenAiApiKey(String value) {
        this(DEFAULT_HEADER_NAME, value);
    }

    public GenAiApiKey(String headerName, String value) {
        this.headerName = String.isNotBlank(headerName) ? headerName : DEFAULT_HEADER_NAME;
        this.value = value;
    }

    public Boolean isConfigured() {
        return String.isNotBlank(value);
    }

    public void apply(GenAiInvocation invocation) {
        if (invocation != null && isConfigured()) {
            invocation.putHeader(headerName, value.trim());
        }
    }

    public GenAiApiKey apiKey() {
        return this;
    }
}