/**
 * MIT License
 *
 * Copyright (c) 2026 Andrii Sukhetskyi
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
@IsTest
public class GoogleIntelligenceHttpMock implements HttpCalloutMock {
    private Integer statusCode;
    private String responseBody;

    public GoogleIntelligenceHttpMock() {
        this.statusCode = 200;
        this.responseBody = buildSuccessResponseBody();
    }

    public GoogleIntelligenceHttpMock withStatusCode(Integer statusCode) {
        this.statusCode = statusCode;
        return this;
    }

    public GoogleIntelligenceHttpMock withResponseBody(String responseBody) {
        this.responseBody = responseBody;
        return this;
    }

    public GoogleIntelligenceHttpMock withEmptyBody() {
        this.responseBody = '';
        return this;
    }

    public GoogleIntelligenceHttpMock withNoCandidates() {
        this.responseBody = '{"candidates":[]}';
        return this;
    }

    public GoogleIntelligenceHttpMock withErrorResponse(Integer statusCode, String errorMessage) {
        this.statusCode = statusCode;
        this.responseBody = '{"error":{"message":"' + errorMessage + '"}}';
        return this;
    }

    public HTTPResponse respond(HTTPRequest req) {
        HTTPResponse response = new HTTPResponse();
        response.setStatusCode(statusCode);
        response.setHeader('Content-Type', 'application/json');
        response.setBody(responseBody);
        return response;
    }

    private static String buildSuccessResponseBody() {
        Map<String, Object> body = new Map<String, Object>{
            'candidates' => new List<Object>{
                new Map<String, Object>{
                    'content' => new Map<String, Object>{
                        'parts' => new List<Object>{
                            new Map<String, Object>{
                                'text' => 'OK'
                            }
                        },
                        'role' => 'model'
                    },
                    'finishReason' => 'STOP'
                }
            }
        };
        return JSON.serialize(body);
    }
}
