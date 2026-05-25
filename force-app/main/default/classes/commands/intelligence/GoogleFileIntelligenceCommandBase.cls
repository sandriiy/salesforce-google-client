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
public abstract with sharing class GoogleFileIntelligenceCommandBase {
	private static final String DEFAULT_EXPORT_MIME_TYPE = 'text/plain';
	private static final String DEFAULT_RESPONSE_MIME_TYPE = 'text/plain';
	private static final Integer DEFAULT_CANDIDATE_COUNT = 1;
	private static final Integer DEFAULT_THINKING_BUDGET = 0;

	private final GoogleClientApiProvider googleApiProvider;
	private final GoogleFileVersionContextResolver versionContextResolver;

	public GoogleFileIntelligenceCommandBase() {
		this(new GoogleClientApiProvider(), new GoogleFileVersionContextResolver());
	}

	@TestVisible
	public GoogleFileIntelligenceCommandBase(GoogleClientApiProvider googleApiProvider, GoogleFileVersionContextResolver versionContextResolver) {
		this.googleApiProvider = googleApiProvider == null ? new GoogleClientApiProvider() : googleApiProvider;
		this.versionContextResolver = versionContextResolver == null ? new GoogleFileVersionContextResolver() : versionContextResolver;
	}

	public GoogleFileAnalysisResultDTO execute(Id localGoogleFileVersionId, String providerName, String modelName, IGenAiClient genAiClient, String inputText) {
		GoogleFileAnalysisResultDTO result = createBaseResult(providerName);
		String normalizedInput = normalizeInput(inputText);

		if (localGoogleFileVersionId == null || String.isBlank(modelName) || genAiClient == null) {
			result.blocked = true;
			result.errorMessage = buildConfigurationUnavailableMessage();
			return result;
		}

		String inputValidationMessage = validateInput(normalizedInput);
		if (String.isNotBlank(inputValidationMessage)) {
			result.errorMessage = inputValidationMessage;
			return result;
		}

		try {
			GoogleFileVersion__c localFileVersion = retrieveLocalFileVersion(localGoogleFileVersionId);
			if (!isEligible(localFileVersion)) {
				applyIneligibleResult(result);
				return result;
			}

			String documentText = exportDocumentText(localFileVersion);
			if (String.isBlank(documentText)) {
				result.errorMessage = buildExportFailureMessage();
				return result;
			}

			GenAiResponse response = genAiClient.generate(buildRequest(modelName, normalizedInput, documentText));
			String outcomeReason = response == null ? null : response.outcomeReason();
			result.finishReason = response == null || response.firstCandidate() == null
				? null
				: response.firstCandidate().finishReason;

			String outputText = finalizeGeneratedText(
				normalizeGeneratedText(response == null ? null : response.firstText()),
				result.finishReason
			);
			if (String.isBlank(outputText)) {
				result.errorMessage = buildAnalysisFailureMessage(outcomeReason);
				return result;
			}

			result.success = true;
			result.text = outputText;
			return result;
		} catch (Exception ex) {
			result.errorMessage = ex.getMessage();
			Logger.error('Local Google File Version Id: ' + localGoogleFileVersionId).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.error('Provider Name: ' + providerName).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.error('Model Name: ' + modelName).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.error('Error Message: ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();

			return result;
		}
	}

	public abstract String getOperationType();
	public abstract String getConfigurationLabel();
	public abstract String getAnalysisContextLabel();
	public abstract String getSystemPrompt();
	public abstract String buildUserPrompt(String normalizedInput, String documentText);
	public abstract Integer getMaxOutputTokens();

	public virtual Double getTemperature() {
		return 0.0;
	}

	public virtual Integer getThinkingBudget() {
		return DEFAULT_THINKING_BUDGET;
	}

	public virtual Integer getCandidateCount() {
		return DEFAULT_CANDIDATE_COUNT;
	}

	public virtual String getExportMimeType() {
		return DEFAULT_EXPORT_MIME_TYPE;
	}

	public virtual String getResponseMimeType() {
		return DEFAULT_RESPONSE_MIME_TYPE;
	}

	public virtual String normalizeInput(String inputText) {
		return normalizePlainText(inputText);
	}

	public virtual String validateInput(String normalizedInput) {
		return null;
	}

	public virtual Boolean isEligible(GoogleFileVersion__c localFileVersion) {
		return supportsInteractiveIntelligence(localFileVersion);
	}

	public virtual void applyIneligibleResult(GoogleFileAnalysisResultDTO result) {
		result.blocked = true;
	}

	public virtual String normalizeGeneratedText(String generatedText) {
		return normalizePlainText(generatedText);
	}

	public virtual String finalizeGeneratedText(String generatedText, String finishReason) {
		return generatedText;
	}

	public virtual String buildConfigurationUnavailableMessage() {
		return 'Google AI ' + getConfigurationLabel() + ' configuration is unavailable';
	}

	public virtual String buildExportFailureMessage() {
		return 'Unable to export the document content for analysis';
	}

	public virtual String buildAnalysisFailureMessage(String outcomeReason) {
		String failureMessage = 'Unable to analyze the document content for ' + getAnalysisContextLabel();
		return String.isBlank(outcomeReason)
			? failureMessage
			: failureMessage + ' (' + outcomeReason + ')';
	}

	public String normalizePlainText(String text) {
		return String.isBlank(text)
			? null
			: text.replaceAll('\\s+', ' ').trim();
	}

	public Boolean hasTerminalPunctuation(String text) {
		if (String.isBlank(text)) {
			return false;
		}

		Integer lastCharacterIndex = text.length() - 1;
		while (lastCharacterIndex >= 0) {
			String character = text.substring(lastCharacterIndex, lastCharacterIndex + 1);
			if (character == '"' || character == ')' || character == ']' || character == '}') {
				lastCharacterIndex--;
				continue;
			}

			return character == '.' || character == '!' || character == '?';
		}

		return false;
	}

	private GoogleFileAnalysisResultDTO createBaseResult(String providerName) {
		GoogleFileAnalysisResultDTO result = new GoogleFileAnalysisResultDTO();
		result.provider = providerName;
		result.operationType = getOperationType();
		return result;
	}

	private GoogleFileVersion__c retrieveLocalFileVersion(Id localGoogleFileVersionId) {
		return (GoogleFileVersion__c) GoogleFileVersionSelector.query()
			.withAdvancedFields()
			.byId(localGoogleFileVersionId)
			.toObject();
	}

	private Boolean supportsInteractiveIntelligence(GoogleFileVersion__c localFileVersion) {
		return this.versionContextResolver.supportsInteractiveIntelligence(localFileVersion);
	}

	private String exportDocumentText(GoogleFileVersion__c localFileVersion) {
		GoogleFileEntity result = this.googleApiProvider.retrieveGoogleDriveClient().files().retrieve().export(localFileVersion.GoogleDocsFileId__c)
			.setMimeType(getExportMimeType())
			.setSearchOnAllDrives(true)
			.execute();

		return result == null || result.bodyAsBlob == null
			? null
			: result.bodyAsBlob.toString();
	}

	private GenAiRequest buildRequest(String modelName, String normalizedInput, String documentText) {
		return new GenAiRequestBuilder(modelName)
			.withSystemText(getSystemPrompt())
			.addUserText(buildUserPrompt(normalizedInput, documentText))
			.withCandidates(getCandidateCount())
			.withTemperature(getTemperature())
			.withMaxTokens(getMaxOutputTokens())
			.withProviderOptions(new GenAiGoogleOptions().withThinkingBudget(getThinkingBudget()))
			.withResponseMimeType(getResponseMimeType())
			.build();
	}
}