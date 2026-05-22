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
public with sharing class GoogleFileSummarizeCommand {
	private static final String OPERATION_TYPE = 'SUMMARY';
	private static final String EXPORT_MIME_TYPE = 'text/plain';
	private static final String RESPONSE_MIME_TYPE = 'text/plain';
	private static final String SYSTEM_PROMPT = 'You create very short document summaries for Salesforce users. Use only the provided document text. Return exactly one plain-text sentence that starts with "This file describes". Keep it under 255 characters, and aim for about 160 to 180 characters when possible. If needed, drop names, numbers, dates, and secondary details before exceeding the limit. Do not use lists, line breaks, or a second sentence.';

	private final GoogleClientApiProvider googleApiProvider;

	public GoogleFileSummarizeCommand() {
		this(new GoogleClientApiProvider());
	}

	@TestVisible
	private GoogleFileSummarizeCommand(GoogleClientApiProvider googleApiProvider) {
		this.googleApiProvider = googleApiProvider == null ? new GoogleClientApiProvider() : googleApiProvider;
	}

	public GoogleFileAnalysisResultDTO summarize(Id localGoogleFileVersionId, String providerName, String modelName, IGenAiClient genAiClient) {
		GoogleFileAnalysisResultDTO result = new GoogleFileAnalysisResultDTO();
		result.provider = providerName;
		result.operationType = OPERATION_TYPE;

		if (localGoogleFileVersionId == null || String.isBlank(modelName) || genAiClient == null) {
			result.blocked = true;
			result.errorMessage = 'Google AI summary configuration is unavailable';
			return result;
		}

		try {
			GoogleFileVersion__c localFileVersion = (GoogleFileVersion__c) GoogleFileVersionSelector.query()
				.withAdvancedFields()
				.byId(localGoogleFileVersionId)
				.toObject();
			
			if (!isEligible(localFileVersion)) {
				result.blocked = true;
				return result;
			}

			String documentText = exportDocumentText(localFileVersion);
			if (String.isBlank(documentText)) {
				result.errorMessage = 'Unable to export the document content for analysis';
				return result;
			}

			GenAiResponse response = genAiClient.generate(
				new GenAiRequestBuilder(modelName)
					.withSystemText(SYSTEM_PROMPT)
					.addUserText(buildSummaryPrompt(documentText))
					.withCandidates(1)
					.withTemperature(0.0)
					.withMaxTokens(64)
					.withProviderOptions(new GenAiGoogleOptions().withThinkingBudget(0))
					.withResponseMimeType(RESPONSE_MIME_TYPE)
					.build()
			);

			String outcomeReason = response == null ? null : response.outcomeReason();
			result.finishReason = response == null || response.firstCandidate() == null
				? null
				: response.firstCandidate().finishReason;

			String summaryText = normalizeSummaryText(response == null ? null : response.firstText());
			if (String.isBlank(summaryText)) {
				result.errorMessage = String.isBlank(outcomeReason)
					? 'Unable to analyze the document content for summary generation'
					: 'Unable to analyze the document content for summary generation (' + outcomeReason + ')';
				
				return result;
			}

			summaryText = fitSummaryText(summaryText);
			if (String.isBlank(summaryText)) {
				result.errorMessage = 'Unable to analyze the document content for summary generation';
				return result;
			}

			result.success = true;
			result.text = summaryText;
			return result;
		} catch (Exception ex) {
			result.errorMessage = ex.getMessage();
			return result;
		}
	}

	private Boolean isEligible(GoogleFileVersion__c localFileVersion) {
		return localFileVersion != null
			&& localFileVersion.Id != null
			&& String.isNotBlank(localFileVersion.GoogleDocsFileId__c)
			&& localFileVersion.Size__c != null
			&& localFileVersion.Size__c <= GoogleCloudConstants.MAX_SUMMARY_FILE_SIZE_BYTES
			&& !hasExistingSummary(localFileVersion);
	}

	private Boolean hasExistingSummary(GoogleFileVersion__c localFileVersion) {
		return localFileVersion != null
			&& localFileVersion.isSet('Summary__c')
			&& String.isNotBlank((String) localFileVersion.get('Summary__c'));
	}

	private String exportDocumentText(GoogleFileVersion__c localFileVersion) {
		GoogleFileEntity result = this.googleApiProvider.retrieveGoogleDriveClient().files().retrieve().export(localFileVersion.GoogleDocsFileId__c)
			.setMimeType(EXPORT_MIME_TYPE)
			.setSearchOnAllDrives(true)
			.execute();

		return result == null || result.bodyAsBlob == null
			? null
			: result.bodyAsBlob.toString();
	}

	private String buildSummaryPrompt(String documentText) {
		return 'Write one short sentence that starts with "This file describes". Aim around 180 characters and never exceed '
			+ GoogleCloudConstants.MAX_SUMMARY_CHARACTERS
			+ ' characters. Keep only the main subject and the most important points, names and numbers. You can drop secondary details if space is tight. End the sentence with a period when complete. Return plain text only with no line breaks.\n\nDocument text:\n'
			+ documentText;
	}

	private String normalizeSummaryText(String summaryText) {
		return String.isBlank(summaryText)
			? null
			: summaryText.replaceAll('\\s+', ' ').trim();
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

	private Boolean hasTerminalPunctuation(String summaryText) {
		if (String.isBlank(summaryText)) {
			return false;
		}

		Integer lastCharacterIndex = summaryText.length() - 1;
		while (lastCharacterIndex >= 0) {
			String character = summaryText.substring(lastCharacterIndex, lastCharacterIndex + 1);
			if (character == '"' || character == ')' || character == ']' || character == '}') {
				lastCharacterIndex--;
				continue;
			}

			return character == '.' || character == '!' || character == '?';
		}

		return false;
	}
}