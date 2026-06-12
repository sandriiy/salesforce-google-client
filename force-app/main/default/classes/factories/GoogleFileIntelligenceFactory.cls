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
public with sharing class GoogleFileIntelligenceFactory {
	public class GoogleFileIntelligenceFactoryException extends Exception {}

	private GoogleMetadataConfigService metadataConfig;
	public GoogleFileIntelligenceFactory() {
		this.metadataConfig = new GoogleMetadataConfigService();
	}

	public Boolean isConfigured() {
		return metadataConfig.isFileIntelligenceEnabled() && (hasGeminiConfiguration() || hasAgentConfiguration());
	}

    public IGoogleFileIntelligenceStrategy create() {
		if (!metadataConfig.isFileIntelligenceEnabled()) {
			throw new GoogleFileIntelligenceFactoryException('AI file intelligence is disabled. Enable it in Advanced settings and save the configuration before using summaries or questions');
		}

		return createConfiguredStrategy();
	}

	public IGoogleFileIntelligenceStrategy createForValidation() {
		return createConfiguredStrategy();
	}

	private IGoogleFileIntelligenceStrategy createConfiguredStrategy() {
		if (hasGeminiConfiguration()) {
			return new GoogleGeminiIntelligenceStrategy();
		} else if (hasAgentConfiguration()) {
			return new GoogleAgentIntelligenceStrategy();
		} else {
			throw new GoogleFileIntelligenceFactoryException('Unable to determine which Google AI Strategy to use. Please verify the configuration for Gemini or Agent Platform (ex-Vertex AI) is set correctly');
		}
	}

	private Boolean hasGeminiConfiguration() {
		return String.isNotBlank(metadataConfig.getGoogleGeminiKey())
			&& String.isNotBlank(metadataConfig.getGoogleAiModel());
	}

	private Boolean hasAgentConfiguration() {
		return String.isNotBlank(metadataConfig.getGoogleAgentLocation())
			&& String.isNotBlank(metadataConfig.getGoogleAgentProjectId())
			&& String.isNotBlank(metadataConfig.getGoogleAiModel());
	}
}