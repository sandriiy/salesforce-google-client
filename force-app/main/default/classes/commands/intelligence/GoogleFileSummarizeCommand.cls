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
public with sharing class GoogleFileSummarizeCommand extends GoogleFileIntelligenceCommandBase {
	private static final Integer MAX_OUTPUT_TOKENS = 80;
	private static final String OPERATION_TYPE = 'SUMMARY';
	private static final String SYSTEM_PROMPT = 'Create a very short summary of the provided document content. Use only the text provided in the document and keep the summary accurate. Focus on the main subject and the most important points, names, dates, and numbers. Omit secondary details if the summary needs to stay brief. End the summary with a period. Return plain text only, with no line breaks.';

	public GoogleFileAnalysisResultDTO summarize(Id localGoogleFileVersionId, String providerName, String modelName, IGenAiClient genAiClient) {
		return execute(localGoogleFileVersionId, providerName, modelName, genAiClient, null);
	}

	public override String getOperationType() {
		return OPERATION_TYPE;
	}

	public override String getConfigurationLabel() {
		return 'summary';
	}

	public override String getAnalysisContextLabel() {
		return 'summary generation';
	}

	public override String getSystemPrompt() {
		return SYSTEM_PROMPT;
	}

	public override String buildUserPrompt(String normalizedInput, String documentText) {
		return 'Write one short sentence that starts with "This file describes". Aim around 180 characters and never exceed '
			+ GoogleCloudConstants.MAX_SUMMARY_CHARACTERS
			+ ' characters. \n\nDocument text:\n'
			+ documentText;
	}

	public override Integer getMaxOutputTokens() {
		return MAX_OUTPUT_TOKENS;
	}

	public override Boolean isEligible(GoogleFileVersion__c localFileVersion) {
		return super.isEligible(localFileVersion)
			&& !hasExistingSummary(localFileVersion);
	}

	public override String finalizeGeneratedText(String generatedText, String finishReason) {
		return fitSummaryText(generatedText);
	}

	public override String buildAnalysisFailureMessage(String outcomeReason) {
		return String.isBlank(outcomeReason)
			? 'Unable to analyze the document content for summary generation'
			: 'Summary response returned no content (' + outcomeReason + ')';
	}

	private Boolean hasExistingSummary(GoogleFileVersion__c localFileVersion) {
		return localFileVersion != null
			&& localFileVersion.isSet('Summary__c')
			&& String.isNotBlank((String) localFileVersion.get('Summary__c'));
	}

	private String fitSummaryText(String summaryText) {
		if (String.isBlank(summaryText)) return null;

		if (summaryText.length() <= GoogleCloudConstants.MAX_SUMMARY_CHARACTERS && isUsableSummary(summaryText)) {
			return summaryText;
		}

		Integer maxCharactersBeforeSuffix = GoogleCloudConstants.MAX_SUMMARY_CHARACTERS - 3;
		String fittedSummary = summaryText.endsWith('...')
			? summaryText.substring(0, summaryText.length() - 3).trim()
			: summaryText;

		if (fittedSummary.length() > maxCharactersBeforeSuffix) {
			fittedSummary = fittedSummary.substring(0, maxCharactersBeforeSuffix);
			Integer lastWhitespace = fittedSummary.lastIndexOf(' ');
			if (lastWhitespace != -1 && lastWhitespace >= maxCharactersBeforeSuffix / 2) {
				fittedSummary = fittedSummary.substring(0, lastWhitespace);
			}
		}

		fittedSummary = fittedSummary.trim();
		if (String.isBlank(fittedSummary)) {
			Integer fallbackLength = summaryText.length() < maxCharactersBeforeSuffix
				? summaryText.length()
				: maxCharactersBeforeSuffix;
			fittedSummary = summaryText.substring(0, fallbackLength).trim();
		}

		return String.isBlank(fittedSummary)
			? null
			: fittedSummary + '...';
	}

	private Boolean isUsableSummary(String summaryText) {
		return hasTerminalPunctuation(summaryText) || summaryText.endsWith('...');
	}
}