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
public class GoogleCompositeHttpMock implements HttpCalloutMock {
    private final GoogleDriveHttpMock driveMock;
    private final GoogleIntelligenceHttpMock intelligenceMock;

    public GoogleCompositeHttpMock() {
        this.driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
        this.intelligenceMock = new GoogleIntelligenceHttpMock();
    }

    public GoogleCompositeHttpMock(GoogleDriveHttpMock driveMock, GoogleIntelligenceHttpMock intelligenceMock) {
        this.driveMock = driveMock;
        this.intelligenceMock = intelligenceMock;
    }

    public HTTPResponse respond(HTTPRequest req) {
        String endpoint = req.getEndpoint();
        if (endpoint == null) endpoint = '';
        String endpointLower = endpoint.toLowerCase();

        if (endpointLower.contains('generativelanguage.googleapis.com') ||
            endpointLower.contains('aiplatform.googleapis.com')) {
            return intelligenceMock.respond(req);
        }

        return driveMock.respond(req);
    }
}
