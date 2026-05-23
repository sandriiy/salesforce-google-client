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
private class GoogleGenAiCredentialProviderTest {
    private static void resetOverrides() {
        GoogleMetadataConfigService.configRecordOverride = null;
    }

    private static GoogleClientConfig__mdt buildGeminiConfig(String apiKey) {
        GoogleClientConfig__mdt config = new GoogleClientConfig__mdt();
        config.CustomGeminiApiKey__c = apiKey;
        return config;
    }

    @IsTest
    private static void testAccessTokenProviderPositive() {
        GoogleCloudTestFactory.initMocks();

        Test.startTest();
        GenAiAccessToken accessToken = new DefaultGoogleGenAiAccessTokenProvider().token();
        Test.stopTest();

        Assert.areEqual('Bearer client.test-access-token', accessToken.headerValue());
        resetOverrides();
    }

    @IsTest
    private static void testApiKeyProviderPositive() {
        GoogleMetadataConfigService.configRecordOverride = buildGeminiConfig('api-key-1');
        GenAiInvocation invocation = new GenAiInvocation('POST', 'https://example.com', null, 1000);

        Test.startTest();
        GenAiApiKey apiKey = new DefaultGoogleGenAiApiKeyProvider().apiKey();
        apiKey.apply(invocation);
        Test.stopTest();

        Assert.areEqual('api-key-1', invocation.headers.get('x-goog-api-key'));
        resetOverrides();
    }
}