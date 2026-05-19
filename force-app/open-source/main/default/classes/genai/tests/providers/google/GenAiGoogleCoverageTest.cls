@IsTest
private class GenAiGoogleCoverageTest {
    @IsTest
    private static void coversBuilderSerializerAndValueObjects() {
        GenAiPart part = new GenAiPart('raw')
            .withText('payload')
            .withMimeType('text/plain')
            .withData('cGF5bG9hZA==')
            .withFileUri('gs://docs/sample.txt')
            .withName('sample')
            .withMediaResolution('LOW')
            .withPayload(new Map<String, Object>{ 'value' => 'payload' });

        System.assertEquals('raw', part.kind);
        System.assertEquals('payload', part.text);
        System.assertEquals('text/plain', part.mimeType);
        System.assertEquals('cGF5bG9hZA==', part.data);
        System.assertEquals('gs://docs/sample.txt', part.fileUri);
        System.assertEquals('sample', part.name);
        System.assertEquals('LOW', part.mediaResolution);
        System.assertEquals('payload', part.payload.get('value'));

        GenAiToolConfig standaloneToolConfig = new GenAiToolConfig();
        System.assertEquals(true, standaloneToolConfig.isEmpty());
        standaloneToolConfig.allowFunction('');
        standaloneToolConfig.putExtension('ignored', null);
        standaloneToolConfig.functionMode = 'AUTO';
        standaloneToolConfig.streamFunctionCallArguments = true;
        standaloneToolConfig.allowFunction('lookupAccount');
        standaloneToolConfig.putExtension('retrievalConfig', new Map<String, Object>{ 'mode' => 'dynamic' });
        System.assertEquals(false, standaloneToolConfig.isEmpty());

        GenAiSafetySetting safetySetting = new GenAiSafetySetting(
            'HARM_CATEGORY_HATE_SPEECH',
            'BLOCK_LOW_AND_ABOVE',
            'PROBABILITY'
        );
        System.assertEquals('HARM_CATEGORY_HATE_SPEECH', safetySetting.category);
        System.assertEquals('BLOCK_LOW_AND_ABOVE', safetySetting.threshold);
        System.assertEquals('PROBABILITY', safetySetting.method);

        GenAiTool functionTool = new GenAiTool('function')
            .withName('lookupAccount')
            .withDescription('Loads one account')
            .withParameters(new Map<String, Object>{
                'type' => 'object',
                'properties' => new Map<String, Object>{
                    'id' => new Map<String, Object>{ 'type' => 'string' }
                }
            })
            .withResponseSchema(new Map<String, Object>{
                'type' => 'object',
                'properties' => new Map<String, Object>{
                    'status' => new Map<String, Object>{ 'type' => 'string' }
                }
            });

        GenAiTool googleSearchTool = new GenAiTool('googleSearch')
            .withConfig(new Map<String, Object>{
                'excludeDomains' => new List<Object>{ 'example.com' }
            });

        System.assertEquals('lookupAccount', functionTool.name);
        System.assertEquals('Loads one account', functionTool.description);
        System.assertNotEquals(null, functionTool.parameters);
        System.assertNotEquals(null, functionTool.responseSchema);
        System.assertNotEquals(null, googleSearchTool.config);

        GenAiMessage systemMessage = new GenAiMessage('system').addText('Return structured output.');
        GenAiMessage userMessage = new GenAiMessage('user')
            .addText('Describe the document.')
            .addInlineData('text/plain', Blob.valueOf('sample'))
            .addFile('application/pdf', 'gs://docs/sample.pdf')
            .addFunctionCall('lookupAccount', new Map<String, Object>{ 'id' => '001' })
            .addFunctionResponse('lookupAccount', new Map<String, Object>{ 'status' => 'ok' })
            .addPart(new GenAiPart('executableCode').withPayload(new Map<String, Object>{ 'language' => 'python' }))
            .addPart(new GenAiPart('codeExecutionResult').withPayload(new Map<String, Object>{ 'outcome' => 'ok' }))
            .addPart(new GenAiPart('urlContext').withPayload(new Map<String, Object>{ 'url' => 'https://example.com' }).withMediaResolution('HIGH'));

        System.assertEquals('Describe the document.', userMessage.text());
        System.assertEquals(8, userMessage.parts.size());

        GenAiGoogleAgentPlatformConfig googleConfig = new GenAiGoogleAgentPlatformConfig(
            'demo-project',
            'us-central1',
            new GenAiAccessToken(null, 'token-123')
        )
            .withPublisher('custom-publisher')
            .withEndpointBase('https://example.com/v1/')
            .withTimeout(30000)
            .withTimeout(-1);

        System.assertEquals('custom-publisher', googleConfig.publisher);
        System.assertEquals('https://example.com/v1/', googleConfig.endpointBase);
        System.assertEquals(30000, googleConfig.timeoutMs);

        GenAiGoogleDeveloperConfig developerConfig = new GenAiGoogleDeveloperConfig(new GenAiApiKey('developer-key'))
            .withEndpointBase('https://generativelanguage.googleapis.com/v1beta/')
            .withTimeout(25000)
            .withTimeout(-1);

        System.assertEquals('https://generativelanguage.googleapis.com/v1beta/', developerConfig.endpointBase);
        System.assertEquals(25000, developerConfig.timeoutMs);
        System.assertNotEquals(null, developerConfig.resolvedApiKey());

        GenAiGoogleOptions googleOptions = new GenAiGoogleOptions()
            .withCachedContent('projects/demo/locations/us-central1/cachedContents/primary')
            .withThinkingBudget(16)
            .withThinkingLevel('LOW')
            .withMediaResolution('HIGH');

        GenAiRequest request = new GenAiRequestBuilder('gemini-2.5-pro')
            .withOperation('generateContent')
            .withSystemMessage(systemMessage)
            .addMessage(new GenAiMessage('model').addText('Draft answer'))
            .addMessage(userMessage)
            .addText('', 'ignored')
            .addTool(functionTool)
            .addTool(googleSearchTool)
            .withToolMode('AUTO')
            .allowFunction('lookupAccount')
            .withStreamFunctionCallArguments(true)
            .addSafety('HARM_CATEGORY_HATE_SPEECH', 'BLOCK_LOW_AND_ABOVE', 'PROBABILITY')
            .withTemperature(0.2)
            .withTopP(0.95)
            .withTopK(20)
            .withCandidates(2)
            .withMaxTokens(300)
            .withPresencePenalty(0.4)
            .withFrequencyPenalty(0.2)
            .withStop('END')
            .withResponseMimeType('application/json')
            .withResponseSchema(new Map<String, Object>{
                'type' => 'object',
                'properties' => new Map<String, Object>{
                    'summary' => new Map<String, Object>{ 'type' => 'string' }
                }
            })
            .withResponseModality('TEXT')
            .withSeed(42)
            .withResponseLogprobs(true)
            .withLogprobs(5)
            .withLabel('scenario', 'coverage')
            .withProviderOptions(googleOptions)
            .build();

        System.assertEquals(2, request.messages.size());
    System.assertEquals('generateContent', request.operation);
        System.assertEquals('AUTO', request.toolConfig.functionMode);
        System.assertEquals(true, request.toolConfig.streamFunctionCallArguments);
        System.assertEquals(1, request.toolConfig.allowedFunctionNames.size());
        System.assertEquals(1, request.safetySettings.size());
        System.assertEquals(20, request.generation.topK);
        System.assertEquals(42, request.generation.seed);
        System.assertEquals('coverage', request.labels.get('scenario'));

        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(new GenAiGoogleRequestSerializer().serialize(request));
        List<Object> contents = (List<Object>) payload.get('contents');
        List<Object> tools = (List<Object>) payload.get('tools');
        List<Object> safetySettings = (List<Object>) payload.get('safetySettings');
        Map<String, Object> toolConfig = (Map<String, Object>) payload.get('toolConfig');
        Map<String, Object> generationConfig = (Map<String, Object>) payload.get('generationConfig');
        Map<String, Object> functionCallingConfig = (Map<String, Object>) toolConfig.get('functionCallingConfig');
        Map<String, Object> userContent = (Map<String, Object>) contents[1];
        List<Object> userParts = (List<Object>) userContent.get('parts');

        System.assertEquals(2, tools.size());
        System.assertEquals(1, safetySettings.size());
        System.assertEquals('projects/demo/locations/us-central1/cachedContents/primary', payload.get('cachedContent'));
        System.assertEquals(true, functionCallingConfig.get('streamFunctionCallArguments'));
        System.assertEquals(20, generationConfig.get('topK'));
        System.assertEquals(2, generationConfig.get('candidateCount'));
        System.assertEquals(300, generationConfig.get('maxOutputTokens'));
        System.assertEquals(true, generationConfig.get('responseLogprobs'));
        System.assertEquals(5, generationConfig.get('logprobs'));
        System.assertEquals('HIGH', generationConfig.get('mediaResolution'));
        System.assertEquals(8, userParts.size());
    }

    @IsTest
    private static void coversGoogleResponseParserBranches() {
        GenAiGoogleResponseParser parser = new GenAiGoogleResponseParser();

        try {
            parser.parse(null);
            System.assert(false, 'Expected provider exception for null response.');
        } catch (GenAiProviderException ex) {
            System.assert(ex.getMessage().contains('empty'));
        }

        HttpResponse blankResponse = new HttpResponse();
        blankResponse.setStatusCode(200);
        blankResponse.setBody('');
        GenAiResponse blankParsed = parser.parse(blankResponse);
        System.assertEquals(false, blankParsed.hasCandidates());
        System.assertEquals('NO_CANDIDATE', blankParsed.outcomeReason());

        HttpResponse noContentResponse = new HttpResponse();
        noContentResponse.setStatusCode(200);
        noContentResponse.setBody(
            '{"candidates":[{"finishReason":"MAX_TOKENS","content":{"role":"model"}}],"usageMetadata":{"promptTokenCount":4,"totalTokenCount":17},"modelVersion":"gemini-2.5-flash"}'
        );
        GenAiResponse noContentParsed = parser.parse(noContentResponse);
        System.assertEquals('NO_CONTENT_MAX_TOKENS', noContentParsed.outcomeReason());

        HttpResponse truncatedButUsableResponse = new HttpResponse();
        truncatedButUsableResponse.setStatusCode(200);
        truncatedButUsableResponse.setBody(
            '{"candidates":[{"finishReason":"MAX_TOKENS","content":{"role":"model","parts":[{"text":"OK"}]}}],"usageMetadata":{"promptTokenCount":4,"candidatesTokenCount":1,"totalTokenCount":20},"modelVersion":"gemini-2.5-flash"}'
        );
        GenAiResponse truncatedButUsableParsed = parser.parse(truncatedButUsableResponse);
        System.assertEquals('SUCCESS_MAX_TOKENS', truncatedButUsableParsed.outcomeReason());

        HttpResponse populatedResponse = new HttpResponse();
        populatedResponse.setStatusCode(200);
        populatedResponse.setBody(
            '{"candidates":[{"index":3,"avgLogprobs":-0.5,"finishReason":"STOP","content":{"role":"model","parts":['
            + '{"text":"Hello"},'
            + '{"inlineData":{"mimeType":"image/png","data":"Zm9v"},"mediaResolution":"HIGH"},'
            + '{"fileData":{"mimeType":"application/pdf","fileUri":"gs://docs/file.pdf"}},'
            + '{"functionCall":{"name":"lookup","args":{"id":"001"}}},'
            + '{"functionResponse":{"name":"lookup","response":{"status":"ok"}}},'
            + '{"executableCode":{"language":"python","code":"print(1)"}},'
            + '{"codeExecutionResult":{"outcome":"ok"}},'
            + '{"unknown":{"value":"raw"}}'
            + ']}}],"usageMetadata":{"promptTokenCount":1,"candidatesTokenCount":2,"totalTokenCount":3},"modelVersion":"gemini-2.5-pro"}'
        );

        GenAiResponse parsed = parser.parse(populatedResponse);

        System.assertEquals(1, parsed.candidates.size());
        System.assertEquals('gemini-2.5-pro', parsed.modelVersion);
        System.assertEquals(3, parsed.firstCandidate().index);
        System.assertEquals(-0.5, parsed.firstCandidate().avgLogprobs);
        System.assertEquals(3, parsed.usage.totalTokens);
        System.assertEquals('SUCCESS_STOP', parsed.outcomeReason());
        System.assertEquals(8, parsed.firstCandidate().content.parts.size());
        System.assertEquals('text', parsed.firstCandidate().content.parts[0].kind);
        System.assertEquals('inlineData', parsed.firstCandidate().content.parts[1].kind);
        System.assertEquals('HIGH', parsed.firstCandidate().content.parts[1].mediaResolution);
        System.assertEquals('fileData', parsed.firstCandidate().content.parts[2].kind);
        System.assertEquals('functionCall', parsed.firstCandidate().content.parts[3].kind);
        System.assertEquals('functionResponse', parsed.firstCandidate().content.parts[4].kind);
        System.assertEquals('executableCode', parsed.firstCandidate().content.parts[5].kind);
        System.assertEquals('codeExecutionResult', parsed.firstCandidate().content.parts[6].kind);
        System.assertEquals('raw', parsed.firstCandidate().content.parts[7].kind);
    }
}