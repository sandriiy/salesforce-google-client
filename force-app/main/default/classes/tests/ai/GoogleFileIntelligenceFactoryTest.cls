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
private class GoogleFileIntelligenceFactoryTest {
	private static final String LABEL_DEFINITIONS = '[{"name":"Invoice","labelId":"LABEL_INVOICE","description":"A bill requesting payment"}]';

	@IsTest
	private static void testCreateForLabelingNegativeLabelingDisabled() {
		GoogleCloudTestFactory.config()
			.withFileIntelligence(true)
			.withGeminiApiKey('api-key-1')
			.withAiModel('gemini-2.0-flash')
			.withAiLabelDefinitions(LABEL_DEFINITIONS)
			.apply();

		Test.startTest();
		try {
			new GoogleFileIntelligenceFactory().createForLabeling();
			Assert.fail('Labeling must stay off until the administrator enables it');
		} catch (GoogleFileIntelligenceFactory.GoogleFileIntelligenceFactoryException ex) {
			Assert.isTrue(ex.getMessage().contains('labeling is disabled'));
		}
		Test.stopTest();
	}

	@IsTest
	private static void testCreateForLabelingNegativeIntelligenceDisabled() {
		GoogleCloudTestFactory.config()
			.withAiLabeling(true)
			.withGeminiApiKey('api-key-1')
			.withAiModel('gemini-2.0-flash')
			.withAiLabelDefinitions(LABEL_DEFINITIONS)
			.apply();

		Test.startTest();
		try {
			new GoogleFileIntelligenceFactory().createForLabeling();
			Assert.fail('Labeling must not run while file intelligence is off');
		} catch (GoogleFileIntelligenceFactory.GoogleFileIntelligenceFactoryException ex) {
			Assert.isTrue(ex.getMessage().contains('intelligence is disabled'));
		}
		Test.stopTest();
	}

	@IsTest
	private static void testCreateForLabelingPositiveReturnsConfiguredStrategy() {
		GoogleCloudTestFactory.config()
			.withFileIntelligence(true)
			.withAiLabeling(true)
			.withGeminiApiKey('api-key-1')
			.withAiModel('gemini-2.0-flash')
			.withAiLabelDefinitions(LABEL_DEFINITIONS)
			.apply();

		Test.startTest();
		GoogleFileIntelligenceFactory factory = new GoogleFileIntelligenceFactory();
		IGoogleFileLabelingStrategy strategy = factory.createForLabeling();
		Test.stopTest();

		Assert.isTrue(factory.isLabelingConfigured());
		Assert.isTrue(strategy instanceof GoogleGeminiIntelligenceStrategy);
	}

	@IsTest
	private static void testIsLabelingConfiguredNegativeWithoutDefinitions() {
		GoogleCloudTestFactory.config()
			.withFileIntelligence(true)
			.withAiLabeling(true)
			.withGeminiApiKey('api-key-1')
			.withAiModel('gemini-2.0-flash')
			.apply();

		Assert.isFalse(new GoogleFileIntelligenceFactory().isLabelingConfigured());
	}

	@IsTest
	private static void testCreateNegativeNoConfig() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt();

		Test.startTest();
		try {
			new GoogleFileIntelligenceFactory().create();
			Assert.isTrue(false);
		} catch (GoogleFileIntelligenceFactory.GoogleFileIntelligenceFactoryException ex) {
			Assert.isTrue(ex.getMessage().contains('disabled'));
		}
		Test.stopTest();
	}
}
