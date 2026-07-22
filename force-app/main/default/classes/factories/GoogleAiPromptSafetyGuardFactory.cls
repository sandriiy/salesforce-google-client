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
public with sharing class GoogleAiPromptSafetyGuardFactory {
	@TestVisible
	private static IGoogleAiPromptSafetyGuard cachedGuard;

	private final GoogleMetadataConfigService metadataService;

	public GoogleAiPromptSafetyGuardFactory() {
		this(new GoogleMetadataConfigService());
	}

	@TestVisible
	private GoogleAiPromptSafetyGuardFactory(GoogleMetadataConfigService metadataService) {
		this.metadataService = metadataService == null ? new GoogleMetadataConfigService() : metadataService;
	}

	public IGoogleAiPromptSafetyGuard resolve() {
		if (cachedGuard != null) {
			return cachedGuard;
		}

		cachedGuard = buildFromConfig();
		return cachedGuard;
	}

	@TestVisible
	private static void resetForTest() {
		cachedGuard = null;
	}

	private IGoogleAiPromptSafetyGuard buildFromConfig() {
		String customClassName;
		try {
			customClassName = metadataService.getCustomAiPromptSafetyGuardClass();
		} catch (Exception ex) {
			return new DefaultGoogleAiPromptSafetyGuard();
		}

		if (String.isBlank(customClassName)) {
			return new DefaultGoogleAiPromptSafetyGuard();
		}

		try {
			Type customType = Type.forName(customClassName);
			if (customType == null) {
				return new DefaultGoogleAiPromptSafetyGuard();
			}

			Object customInstance = customType.newInstance();
			if (customInstance instanceof IGoogleAiPromptSafetyGuard) {
				return (IGoogleAiPromptSafetyGuard) customInstance;
			}

			return new DefaultGoogleAiPromptSafetyGuard();
		} catch (Exception ex) {
			return new DefaultGoogleAiPromptSafetyGuard();
		}
	}
}
