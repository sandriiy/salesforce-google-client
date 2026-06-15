public with sharing class GenAiHttpTransport implements IGenAiTransport {
    public HttpResponse send(HttpRequest request) {
        return new Http().send(request);
    }
}