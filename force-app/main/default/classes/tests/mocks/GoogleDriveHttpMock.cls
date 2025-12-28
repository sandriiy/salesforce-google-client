@IsTest
public class GoogleDriveHttpMock implements HttpCalloutMock {
    private Boolean useDefaultHappyPath = false;

    private List<MockRule> rules = new List<MockRule>();
    private List<CapturedRequest> capturedRequests = new List<CapturedRequest>();

    public GoogleDriveHttpMock withDefaultHappyPath() {
        useDefaultHappyPath = true;
        return this;
    }

    public GoogleDriveHttpMock addRule(MockRule rule) {
        if (rule != null) rules.add(rule);
        return this;
    }

    public RuleBuilder whenRequestMatches(RequestMatcher matcher) {
        return new RuleBuilder(this, matcher);
    }

    public List<CapturedRequest> getCapturedRequests() {
        return new List<CapturedRequest>(capturedRequests);
    }

    public GoogleDriveHttpMock clearCapturedRequests() {
        capturedRequests.clear();
        return this;
    }

    public HTTPResponse respond(HTTPRequest req) {
        capture(req);

        for (MockRule rule : rules) {
            if (rule != null && rule.matches(req)) {
                return rule.buildResponse(req);
            }
        }

        if (useDefaultHappyPath) {
            HTTPResponse routed = routeDefaultHappyPath(req);
            if (routed != null) return routed;
        }

        return buildErrorResponse(500, 'No mock rule matched this request.', req);
    }

    private HTTPResponse routeDefaultHappyPath(HTTPRequest req) {
        String method = safeUpper(req.getMethod());
        String endpoint = String.valueOf(req.getEndpoint());
        String endpointLower = endpoint != null ? endpoint.toLowerCase() : '';

        if (method == 'POST' && endpointLower.contains('uploadtype=multipart')) {
            return new JsonResponses()
                .uploadSmallSuccess('gfile_small_001', 'Uploaded File', new List<String>{ 'parent_001' })
                .toHttpResponse(req);
        }

        if (method == 'POST' && endpointLower.contains('uploadtype=resumable')) {
            return new ResumableResponses()
                .resumableInitSuccess('https://resumable.session/mock/abc123')
                .toHttpResponse(req);
        }

        if (method == 'PUT' &&
            (endpointLower.contains('resumable') ||
             endpointLower.contains('session') ||
             endpointLower.contains('upload'))) {
            return new ResumableResponses().resumableChunkGeneric(req);
        }

        if (method == 'GET' && endpointLower.contains('alt=media')) {
            return new BinaryResponses()
                .downloadSuccess(Blob.valueOf('mock file content'), 'application/octet-stream')
                .toHttpResponse(req);
        }

        if (method == 'GET' &&
            (endpointLower.contains('/export') ||
             endpointLower.contains('export?') ||
             endpointLower.contains('mimetype=application/pdf'))) {
            return new BinaryResponses()
                .downloadSuccess(Blob.valueOf('%PDF-1.4 MOCK PDF CONTENT%'), 'application/pdf')
                .toHttpResponse(req);
        }

        if (method == 'GET' && endpointLower.contains('fields=')) {
            return new JsonResponses()
                .fileDetailsSuccess('gfile_meta_001')
                .toHttpResponse(req);
        }

        if (method == 'POST' &&
            (endpointLower.contains('/clone') ||
             endpointLower.contains('/copy'))) {
            return new JsonResponses()
                .cloneSuccess('gdoc_preview_001')
                .toHttpResponse(req);
        }

        if (method == 'POST' && endpointLower.contains('/permissions')) {
            return new JsonResponses()
                .permissionCreated('perm_anyone_reader_001')
                .toHttpResponse(req);
        }

        if (method == 'DELETE' && endpointLower.contains('/permissions/')) {
            return buildResponse(204, 'application/json', '');
        }

        if (method == 'DELETE' && endpointLower.contains('/files/')) {
            return buildResponse(204, 'application/json', '');
        }

        if (method == 'POST' && endpointLower.contains('trash')) {
            return buildResponse(200, 'application/json', '{"status":"trashed"}');
        }

        return null;
    }

    public class RuleBuilder {
        private GoogleDriveHttpMock parent;
        private RequestMatcher matcher;

        private RuleBuilder(GoogleDriveHttpMock parent, RequestMatcher matcher) {
            this.parent = parent;
            this.matcher = matcher != null ? matcher : new RequestMatcher();
        }

        public GoogleDriveHttpMock thenReturn(MockResponse response) {
            parent.addRule(new MockRule(matcher, response));
            return parent;
        }

        public GoogleDriveHttpMock thenReturnStatus(Integer statusCode, String body) {
            parent.addRule(
                new MockRule(
                    matcher,
                    new MockResponse()
                        .withStatus(statusCode)
                        .withHeader('Content-Type', 'application/json')
                        .withBody(body)
                )
            );
            return parent;
        }
    }

    public class MockRule {
        private RequestMatcher matcher;
        private MockResponse response;

        public MockRule(RequestMatcher matcher, MockResponse response) {
            this.matcher = matcher != null ? matcher : new RequestMatcher();
            this.response = response != null ? response : new MockResponse().withStatus(200);
        }

        public Boolean matches(HTTPRequest req) {
            return matcher.matches(req);
        }

        public HTTPResponse buildResponse(HTTPRequest req) {
            return response.toHttpResponse(req);
        }
    }

    public class RequestMatcher {
        private String method;
        private String endpointEquals;
        private List<String> endpointMustContain = new List<String>();
        private List<String> queryMustContain = new List<String>();
        private Map<String, String> headerMustContain = new Map<String, String>();
        private List<String> bodyMustContain = new List<String>();

        public RequestMatcher withMethod(String m) {
            method = safeUpper(m);
            return this;
        }

        public RequestMatcher withEndpointEquals(String value) {
            endpointEquals = value;
            return this;
        }

        public RequestMatcher endpointContains(String value) {
            if (!String.isBlank(value)) endpointMustContain.add(value);
            return this;
        }

        public RequestMatcher queryContains(String value) {
            if (!String.isBlank(value)) queryMustContain.add(value);
            return this;
        }

        public RequestMatcher headerContains(String name, String value) {
            if (!String.isBlank(name) && value != null) headerMustContain.put(name, value);
            return this;
        }

        public RequestMatcher bodyContains(String value) {
            if (!String.isBlank(value)) bodyMustContain.add(value);
            return this;
        }

        public Boolean matches(HTTPRequest req) {
            if (req == null) return false;

            if (!String.isBlank(method) && method != safeUpper(req.getMethod())) return false;

            String endpoint = String.valueOf(req.getEndpoint());
            String endpointLower = endpoint != null ? endpoint.toLowerCase() : '';

            if (!String.isBlank(endpointEquals) && endpoint != endpointEquals) return false;

            for (String p : endpointMustContain)
                if (!endpointLower.contains(p.toLowerCase())) return false;

            for (String q : queryMustContain)
                if (!endpointLower.contains(q.toLowerCase())) return false;

            for (String h : headerMustContain.keySet()) {
                String actual = req.getHeader(h);
                String expected = headerMustContain.get(h);
                if (actual == null || expected == null) return false;
                if (!actual.toLowerCase().contains(expected.toLowerCase())) return false;
            }

            String body = req.getBody();
            for (String b : bodyMustContain)
                if (body == null || !body.contains(b)) return false;

            return true;
        }
    }

    public class MockResponse {
        private Integer statusCode = 200;
        private String body;
        private Blob bodyAsBlob;
        private Map<String, String> headers = new Map<String, String>();

        public MockResponse withStatus(Integer code) {
            statusCode = code;
            return this;
        }

        public MockResponse withHeader(String name, String value) {
            if (!String.isBlank(name) && value != null) headers.put(name, value);
            return this;
        }

        public MockResponse withBody(String value) {
            body = value;
            bodyAsBlob = null;
            return this;
        }

        public MockResponse withBodyAsBlob(Blob value) {
            bodyAsBlob = value;
            body = null;
            return this;
        }

        public HTTPResponse toHttpResponse(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(statusCode);

            for (String h : headers.keySet())
                res.setHeader(h, headers.get(h));

            if (bodyAsBlob != null) res.setBodyAsBlob(bodyAsBlob);
            else res.setBody(body != null ? body : '');

            return res;
        }
    }

    public class CapturedRequest {
        public final String method;
        public final String endpoint;
        public final String body;
        public final Map<String, String> headers;

        public CapturedRequest(HTTPRequest req) {
            method = req != null ? req.getMethod() : null;
            endpoint = req != null ? req.getEndpoint() : null;
            body = req != null ? req.getBody() : null;

            Map<String, String> temp = new Map<String, String>();
            if (req != null) {
                for (String h : new List<String>{
                    'Authorization', 'Content-Type', 'Accept', 'Content-Range', 'Range'
                }) {
                    String v = req.getHeader(h);
                    if (v != null) temp.put(h, v);
                }
            }
            headers = temp;
        }
    }

    private void capture(HTTPRequest req) {
        capturedRequests.add(new CapturedRequest(req));
    }

    private static String safeUpper(String s) {
        return s == null ? null : s.trim().toUpperCase();
    }

    private static HTTPResponse buildResponse(Integer status, String contentType, String body) {
        HTTPResponse res = new HTTPResponse();
        res.setStatusCode(status != null ? status : 200);
        if (!String.isBlank(contentType)) res.setHeader('Content-Type', contentType);
        res.setBody(body != null ? body : '');
        return res;
    }

    private static HTTPResponse buildErrorResponse(Integer status, String message, HTTPRequest req) {
        return new JsonResponses()
            .error(status, message + '\nEndpoint: ' + (req != null ? req.getEndpoint() : 'null'))
            .toHttpResponse(req);
    }

    private static String escapeJson(String s) {
        return s == null ? '' : s.replace('\\', '\\\\').replace('"', '\\"');
    }

    private static String toJsonArray(List<String> values) {
        if (values == null) return '[]';
        List<String> out = new List<String>();
        for (String v : values) out.add('"' + escapeJson(v) + '"');
        return '[' + String.join(out, ',') + ']';
    }

    public class JsonResponses {
        public MockResponse uploadSmallSuccess(String id, String name, List<String> parents) {
            return new MockResponse()
                .withHeader('Content-Type', 'application/json')
                .withBody(
                    '{ "id":"' + escapeJson(id) +
                    '", "name":"' + escapeJson(name) +
                    '", "parents":' + toJsonArray(parents) + ' }'
                );
        }

        public MockResponse cloneSuccess(String id) {
            return new MockResponse()
                .withHeader('Content-Type', 'application/json')
                .withBody('{ "id":"' + escapeJson(id) + '" }');
        }

        public MockResponse fileDetailsSuccess(String id) {
            return new MockResponse()
                .withHeader('Content-Type', 'application/json')
                .withBody(
                    '{ "id":"' + escapeJson(id) +
                    '", "webViewLink":"https://drive.google.com/file/d/' +
                    escapeJson(id) + '/view", "webContentLink":"https://drive.google.com/uc?id=' +
                    escapeJson(id) + '&export=download" }'
                );
        }

        public MockResponse permissionCreated(String id) {
            return new MockResponse()
                .withHeader('Content-Type', 'application/json')
                .withBody(
                    '{ "id":"' + escapeJson(id) +
                    '", "type":"anyone", "role":"reader" }'
                );
        }

        public MockResponse error(Integer status, String msg) {
            return new MockResponse()
                .withStatus(status != null ? status : 400)
                .withHeader('Content-Type', 'application/json')
                .withBody('{ "error": { "message":"' + escapeJson(msg) + '" } }');
        }
    }

    public class BinaryResponses {
        public MockResponse downloadSuccess(Blob b, String type) {
            return new MockResponse()
                .withHeader('Content-Type', String.isBlank(type) ? 'application/octet-stream' : type)
                .withBodyAsBlob(b != null ? b : Blob.valueOf(''));
        }
    }

    public class ResumableResponses {
        public MockResponse resumableInitSuccess(String uri) {
            return new MockResponse()
                .withStatus(200)
                .withHeader('Location', uri)
                .withHeader('Content-Type', 'application/json')
                .withBody('{ "session":"' + escapeJson(uri) + '" }');
        }

        public HTTPResponse resumableChunkGeneric(HTTPRequest req) {
            String contentRange = req != null ? req.getHeader('Content-Range') : null;

            if (String.isBlank(contentRange)) {
                return buildResponse(200, 'application/json', '{ "id":"gfile_big_001" }');
            }

            Long totalBytes = parseTotal(contentRange);
            Long endByte = parseEndByte(contentRange);

            if (totalBytes != null && endByte != null && endByte + 1 < totalBytes) {
                HTTPResponse res = new HTTPResponse();
                res.setStatusCode(308);
                res.setHeader('Range', 'bytes=0-' + String.valueOf(endByte));
                res.setHeader('Content-Type', 'application/json');
                res.setBody('{ "status":"resume" }');
                return res;
            }

            return buildResponse(200, 'application/json', '{ "id":"gfile_big_001" }');
        }

        private Long parseTotal(String r) {
            Integer i = r != null ? r.indexOf('/') : -1;
            if (i < 0) return null;
            String v = r.substring(i + 1).trim();
            try { return Long.valueOf(v); } catch (Exception e) { return null; }
        }

        private Long parseEndByte(String r) {
            if (String.isBlank(r)) return null;
            Integer dash = r.indexOf('-');
            Integer slash = r.indexOf('/');
            if (dash < 0 || slash < 0) return null;
            String v = r.substring(dash + 1, slash).trim();
            try { return Long.valueOf(v); } catch (Exception e) { return null; }
        }
    }
}