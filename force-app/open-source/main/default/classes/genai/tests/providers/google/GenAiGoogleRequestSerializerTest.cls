@IsTest
private class GenAiGoogleRequestSerializerTest {
    @IsTest
    private static void serializesGoogleGenerateContentEnvelope() {
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
            .withThinkingBudget(64)
            .withThinkingLevel('HIGH')
            .withMediaResolution('MEDIUM');

        GenAiRequest request = new GenAiRequestBuilder('gemini-2.5-pro')
            .withSystemText('Answer in JSON.')
            .addUserText('Return one object.')
            .addTool(tool)
            .withToolMode('ANY')
            .allowFunction('lookupAccount')
            .withTemperature(0.1)
            .withMaxTokens(128)
            .withResponseMimeType('application/json')
            .withResponseSchema(new Map<String, Object>{
                'type' => 'object',
                'properties' => new Map<String, Object>{
                    'status' => new Map<String, Object>{ 'type' => 'string' }
                }
            })
            .withLabel('channel', 'test')
            .withProviderOptions(options)
            .build();

        String body = new GenAiGoogleRequestSerializer().serialize(request);
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(body);
        List<Object> contents = (List<Object>) payload.get('contents');
        Map<String, Object> systemInstruction = (Map<String, Object>) payload.get('systemInstruction');
        List<Object> tools = (List<Object>) payload.get('tools');
        Map<String, Object> toolConfig = (Map<String, Object>) payload.get('toolConfig');
        Map<String, Object> generationConfig = (Map<String, Object>) payload.get('generationConfig');
        Map<String, Object> functionCallingConfig = (Map<String, Object>) toolConfig.get('functionCallingConfig');
        Map<String, Object> labels = (Map<String, Object>) payload.get('labels');

        System.assertEquals(1, contents.size());
        System.assertNotEquals(null, systemInstruction);
        System.assertEquals(1, tools.size());
        System.assertEquals('projects/demo/locations/us-central1/cachedContents/main', payload.get('cachedContent'));
        System.assertEquals('test', labels.get('channel'));
        System.assertEquals('ANY', functionCallingConfig.get('mode'));
        System.assertEquals('application/json', generationConfig.get('responseMimeType'));
        System.assertEquals('MEDIUM', generationConfig.get('mediaResolution'));
        System.assertNotEquals(null, generationConfig.get('thinkingConfig'));
    }
}