public abstract with sharing class GenAiGoogleConfig {
    public String endpointBase;
    public Integer timeoutMs;

    protected GenAiGoogleConfig(String endpointBase, Integer timeoutMs) {
        this.endpointBase = endpointBase;
        this.timeoutMs = timeoutMs;
    }

    public abstract IGenAiGoogleAdapter adapter();

    public abstract String resolveEndpoint(GenAiRequest request);

    public abstract void applyAuthentication(GenAiInvocation invocation);
}