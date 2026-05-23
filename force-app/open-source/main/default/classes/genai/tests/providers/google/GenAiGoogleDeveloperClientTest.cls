@IsTest
private class GenAiGoogleDeveloperClientTest {
    private class ApiKeyProviderStub implements IGenAiApiKeyProvider {
        public GenAiApiKey apiKey() {
            return new GenAiApiKey('provider-key');
        }
    }

    @IsTest
    private static void generatesDeveloperApiResponse() {
        GenAiGoogleHttpMock mock = new GenAiGoogleHttpMock(
            200,
            '{"candidates":[{"content":{"role":"model","parts":[{"text":"OK"}]},"finishReason":"STOP"}],"usageMetadata":{"promptTokenCount":3,"candidatesTokenCount":1,"totalTokenCount":4},"modelVersion":"gemini-2.5-flash"}'
        );
        Test.setMock(HttpCalloutMock.class, mock);

        IGenAiClient client = new GenAiClientFactory().google(
            new GenAiGoogleDeveloperConfig(new GenAiApiKey('developer-key'))
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
        System.assertEquals('developer-key', mock.lastRequest.getHeader('x-goog-api-key'));
        System.assertEquals(
            'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent',
            mock.lastRequest.getEndpoint()
        );
    }

    @IsTest
    private static void acceptsCustomApiKeyProvider() {
        GenAiGoogleHttpMock mock = new GenAiGoogleHttpMock(
            200,
            '{"candidates":[{"content":{"role":"model","parts":[{"text":"OK"}]},"finishReason":"STOP"}],"usageMetadata":{"promptTokenCount":3,"candidatesTokenCount":1,"totalTokenCount":4},"modelVersion":"gemini-2.5-flash"}'
        );
        Test.setMock(HttpCalloutMock.class, mock);

        IGenAiClient client = new GenAiClientFactory().google(
            new GenAiGoogleDeveloperConfig(new ApiKeyProviderStub())
        );

        Test.startTest();
        client.generate(new GenAiRequestBuilder('gemini-2.5-flash').addUserText('Reply with OK.').build());
        Test.stopTest();

        System.assertEquals('provider-key', mock.lastRequest.getHeader('x-goog-api-key'));
    }

    @IsTest
    private static void rejectsMissingApiKey() {
        IGenAiClient client = new GenAiClientFactory().google(
            new GenAiGoogleDeveloperConfig(new GenAiApiKey(''))
        );

        try {
            client.generate(new GenAiRequestBuilder('gemini-2.5-flash').addUserText('Hello').build());
            System.assert(false, 'Expected configuration exception.');
        } catch (GenAiConfigurationException ex) {
            System.assert(ex.getMessage().contains('API key'));
        }
    }
}