@IsTest
private class GenAiRequestBuilderTest {
    @IsTest
    private static void buildsRequestWithCoreAndProviderOptions() {
        GenAiTool tool = new GenAiTool('function')
            .withName('lookupAccount')
            .withDescription('Loads one account')
            .withParameters(new Map<String, Object>{
                'type' => 'object',
                'properties' => new Map<String, Object>{
                    'id' => new Map<String, Object>{ 'type' => 'string' }
                }
            });

        GenAiGoogleOptions options = new GenAiGoogleOptions()
            .withCachedContent('projects/demo/locations/us-central1/cachedContents/main')
            .withThinkingBudget(32)
            .withThinkingLevel('LOW')
            .withMediaResolution('LOW');

        GenAiRequest request = new GenAiRequestBuilder('gemini-2.5-flash')
            .withOperation('generateContent')
            .withSystemText('Keep responses short.')
            .addUserText('Reply with OK.')
            .addTool(tool)
            .withToolMode('ANY')
            .allowFunction('lookupAccount')
            .withTemperature(0)
            .withMaxTokens(8)
            .withStop('DONE')
            .withLabel('feature', 'validation')
            .withProviderOptions(options)
            .build();

        System.assertEquals('gemini-2.5-flash', request.model);
		System.assertEquals('generateContent', request.operation);
        System.assertEquals('Keep responses short.', request.systemMessage.text());
        System.assertEquals(1, request.messages.size());
        System.assertEquals('Reply with OK.', request.messages[0].text());
        System.assertEquals(1, request.tools.size());
        System.assertEquals('lookupAccount', request.tools[0].name);
        System.assertEquals('ANY', request.toolConfig.functionMode);
        System.assertEquals(1, request.toolConfig.allowedFunctionNames.size());
        System.assertEquals(8, request.generation.maxTokens);
        System.assertEquals('validation', request.labels.get('feature'));
        System.assertEquals(true, request.providerOptions instanceof GenAiGoogleOptions);
    }

    @IsTest
    private static void buildsMultipartDocumentStyleMessage() {
        GenAiRequest request = new GenAiRequestBuilder('gemini-2.5-pro')
            .addMessage(
                new GenAiMessage('user')
                    .addText('Summarize the attached document.')
                    .addFile('application/pdf', 'gs://docs/contract.pdf')
            )
            .withTemperature(0)
            .withMaxTokens(300)
            .build();

        System.assertEquals('generateContent', request.operation);
        System.assertEquals(1, request.messages.size());
        System.assertEquals(2, request.messages[0].parts.size());
        System.assertEquals('Summarize the attached document.', request.messages[0].parts[0].text);
        System.assertEquals('fileData', request.messages[0].parts[1].kind);
        System.assertEquals('application/pdf', request.messages[0].parts[1].mimeType);
        System.assertEquals('gs://docs/contract.pdf', request.messages[0].parts[1].fileUri);
    }
}