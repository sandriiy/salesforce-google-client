@IsTest
private class GenAiGoogleClientTest {
    private class AccessTokenProviderStub implements IGenAiAccessTokenProvider {
        public GenAiAccessToken token() {
            return new GenAiAccessToken('Bearer', 'token-from-provider');
        }
    }

    @IsTest
    private static void generatesGoogleResponse() {
        GenAiGoogleHttpMock mock = new GenAiGoogleHttpMock(
            200,
            '{"candidates":[{"content":{"role":"model","parts":[{"text":"OK"}]},"finishReason":"STOP"}],"usageMetadata":{"promptTokenCount":3,"candidatesTokenCount":1,"totalTokenCount":4},"modelVersion":"gemini-2.5-flash"}'
        );
        Test.setMock(HttpCalloutMock.class, mock);

        IGenAiClient client = new GenAiClientFactory().google(
            new GenAiGoogleAgentPlatformConfig(
                'demo-project',
                'us-central1',
                new GenAiAccessToken('Bearer', 'token-123')
            )
        );

        GenAiRequest request = new GenAiRequestBuilder('gemini-2.5-flash')
            .addUserText('Reply with OK.')
            .withTemperature(0)
            .withMaxTokens(8)
            .build();

        Test.startTest();
        GenAiResponse response = client.generate(request);
        Test.stopTest();

        System.assertEquals(true, response.hasCandidates());
        System.assertEquals('OK', response.firstText());
        System.assertEquals('gemini-2.5-flash', response.modelVersion);
        System.assertEquals(4, response.usage.totalTokens);
        System.assertNotEquals(null, mock.lastRequest);
        System.assertEquals('POST', mock.lastRequest.getMethod());
        System.assertEquals('Bearer token-123', mock.lastRequest.getHeader('Authorization'));
        System.assertEquals('application/json', mock.lastRequest.getHeader('Content-Type'));
        System.assertEquals(
            'https://aiplatform.googleapis.com/v1/projects/demo-project/locations/us-central1/publishers/google/models/gemini-2.5-flash:generateContent',
            mock.lastRequest.getEndpoint()
        );
    }

    @IsTest
    private static void acceptsCustomAccessTokenProvider() {
        GenAiGoogleHttpMock mock = new GenAiGoogleHttpMock(
            200,
            '{"candidates":[{"content":{"role":"model","parts":[{"text":"OK"}]},"finishReason":"STOP"}],"usageMetadata":{"promptTokenCount":3,"candidatesTokenCount":1,"totalTokenCount":4},"modelVersion":"gemini-2.5-flash"}'
        );
        Test.setMock(HttpCalloutMock.class, mock);

        IGenAiClient client = new GenAiClientFactory().google(
            new GenAiGoogleAgentPlatformConfig(
                'demo-project',
                'us-central1',
                new AccessTokenProviderStub()
            )
        );

        Test.startTest();
        client.generate(new GenAiRequestBuilder('gemini-2.5-flash').addUserText('Reply with OK.').build());
        Test.stopTest();

        System.assertEquals('Bearer token-from-provider', mock.lastRequest.getHeader('Authorization'));
    }

    @IsTest
    private static void rejectsInvalidGoogleConfig() {
        IGenAiClient client = new GenAiClientFactory().google(
            new GenAiGoogleAgentPlatformConfig(
                null,
                'us-central1',
                new GenAiAccessToken('Bearer', 'token-123')
            )
        );

        try {
            client.generate(new GenAiRequestBuilder('gemini-2.5-flash').addUserText('Hello').build());
            System.assert(false, 'Expected configuration exception.');
        } catch (GenAiConfigurationException ex) {
            System.assert(ex.getMessage().contains('project ID'));
        }
    }

    @IsTest
    private static void surfacesProviderFailures() {
        Test.setMock(HttpCalloutMock.class, new GenAiGoogleHttpMock(400, '{"error":"bad request"}'));

        IGenAiClient client = new GenAiClientFactory().google(
            new GenAiGoogleAgentPlatformConfig(
                'demo-project',
                'us-central1',
                new GenAiAccessToken('Bearer', 'token-123')
            )
        );

        try {
            client.generate(new GenAiRequestBuilder('gemini-2.5-flash').addUserText('Hello').build());
            System.assert(false, 'Expected provider exception.');
        } catch (GenAiProviderException ex) {
            System.assert(ex.getMessage().contains('bad request'));
        }
    }
}