public class GenAiInvocation {
    public String method;
    public String endpoint;
    public String body;
    public Integer timeoutMs;
    public Map<String, String> headers;

    public GenAiInvocation(String method, String endpoint, String body, Integer timeoutMs) {
        this.method = method;
        this.endpoint = endpoint;
        this.body = body;
        this.timeoutMs = timeoutMs;
        this.headers = new Map<String, String>();
    }

    public void putHeader(String name, String value) {
        if (String.isNotBlank(name) && value != null) {
            headers.put(name, value);
        }
    }
}