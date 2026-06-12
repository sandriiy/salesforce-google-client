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
public with sharing class GoogleFileQuestionCommand extends GoogleFileIntelligenceCommandBase {
	private static final String OPERATION_TYPE = 'QUESTION';
	private GoogleMetadataConfigService metadataService = new GoogleMetadataConfigService();

	public GoogleFileAnalysisResultDTO answerQuestion(Id localGoogleFileVersionId, String question, String providerName, String modelName, IGenAiClient genAiClient) {
		return execute(localGoogleFileVersionId, providerName, modelName, genAiClient, question);
	}

	public override String getOperationType() {
		return OPERATION_TYPE;
	}

	public override String getConfigurationLabel() {
		return 'question';
	}

	public override String getAnalysisContextLabel() {
		return 'question answering';
	}

	public override String getSystemPrompt() {
		return metadataService.getQuestionPrompt();
	}

	public override String buildUserPrompt(String normalizedInput, String documentText) {
		return 'Question:\n'
			+ normalizedInput
			+ '\n\nDocument text:\n'
			+ documentText;
	}

	public override Integer getMaxOutputTokens() {
		return metadataService.getQuestionMaxOutputTokens();
	}

	public override Double getTemperature() {
		return 0.15;
	}

	public override String validateInput(String normalizedInput) {
		if (String.isBlank(normalizedInput)) {
			return 'Enter a question about this file';
		}

		if (normalizedInput.length() > GoogleCloudConstants.MAX_SUMMARY_CHARACTERS) {
			return 'Questions must be 255 characters or fewer';
		}

		return null;
	}

	public override void applyIneligibleResult(GoogleFileAnalysisResultDTO result) {
		result.blocked = true;
		result.errorMessage = 'This file is not available for AI questions';
	}

	public override String finalizeGeneratedText(String generatedText, String finishReason) {
		if (String.isBlank(generatedText)) {
			return null;
		}

		if (finishReason == 'MAX_TOKENS' && !generatedText.endsWith('...') && !hasTerminalPunctuation(generatedText)) {
			return generatedText + '...';
		}

		return generatedText;
	}
}