public with sharing class GenAiClient implements IGenAiClient {
    private IGenAiProvider provider;
    private IGenAiTransport transport;

    public GenAiClient(IGenAiProvider provider, IGenAiTransport transport) {
        this.provider = provider;
        this.transport = transport;
    }

    public GenAiResponse generate(GenAiRequest request) {
        GenAiInvocation invocation = provider.build(request);
        HttpRequest httpRequest = new HttpRequest();
        httpRequest.setMethod(invocation.method);
        httpRequest.setEndpoint(invocation.endpoint);

        if (invocation.timeoutMs != null) {
            httpRequest.setTimeout(invocation.timeoutMs);
        }

        if (invocation.body != null) {
            httpRequest.setBody(invocation.body);
        }

        for (String headerName : invocation.headers.keySet()) {
            httpRequest.setHeader(headerName, invocation.headers.get(headerName));
        }

        HttpResponse response = transport.send(httpRequest);
        return provider.parse(response);
    }
}