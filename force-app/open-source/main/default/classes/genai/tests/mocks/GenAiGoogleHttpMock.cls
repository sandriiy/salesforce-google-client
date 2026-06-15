@IsTest
public class GenAiGoogleHttpMock implements HttpCalloutMock {
    public Integer statusCode;
    public String body;
    public HttpRequest lastRequest;

    public GenAiGoogleHttpMock(Integer statusCode, String body) {
        this.statusCode = statusCode;
        this.body = body;
    }

    public HTTPResponse respond(HttpRequest request) {
        this.lastRequest = request;

        HttpResponse response = new HttpResponse();
        response.setStatusCode(statusCode);
        response.setBody(body);
        response.setHeader('Content-Type', 'application/json');
        return response;
    }
}