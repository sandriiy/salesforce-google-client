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
/**
 * Picks one of the configured Google Drive labels for a file and applies it in Drive when the model is
 * sure enough. It asks for two plain text lines rather than JSON because the shipped guard envelope
 * forbids JSON, and it never labels a version twice. The label goes on the uploaded file first, and on
 * the Workspace copy only as a courtesy, since the original is the one that counts.
 */
public with sharing class GoogleFileLabelCommand extends GoogleFileIntelligenceCommandBase {
	private static final String OPERATION_TYPE = GoogleAiPromptContext.OPERATION_LABEL;
	private static final String NO_LABEL_ANSWER = 'None';
	private static final Integer DECISION_OUTPUT_TOKENS = 64;
	private static final Integer MAX_CONFIDENCE_PERCENT = 100;
	private static final String MODIFIED_LABELS_FIELDS = 'modifiedLabels';
	private static final Pattern DECISION_PATTERN = Pattern.compile('(?i)label\\s*:\\s*(.+?)\\s*confidence\\s*:\\s*(\\d{1,3})');
	private static final Pattern DECORATION_PATTERN = Pattern.compile('[*`"\'\\[\\]()]');
	private static final Pattern TRAILING_SEPARATOR_PATTERN = Pattern.compile('[\\s,;|.\\-]+$');
	private static final Pattern WHITESPACE_RUN_PATTERN = Pattern.compile('\\s+');

	private GoogleMetadataConfigService metadataService = new GoogleMetadataConfigService();
	private List<GoogleAiLabelDefinitionDTO> labelDefinitions = new List<GoogleAiLabelDefinitionDTO>();
	private GoogleFileVersion__c targetFileVersion;

	/**
	 * Decides on a label for one version and applies it when the confidence reaches the configured minimum.
	 * A file the model is unsure about comes back with applied false and no error, which is the normal way
	 * for a file to stay unlabeled.
	 *
	 * @param localGoogleFileVersionId The version to label.
	 * @param providerName The provider name to report back.
	 * @param modelName The model to call.
	 * @param genAiClient The client the request goes through.
	 * @return The chosen label, the confidence, and whether Drive accepted it.
	 */
	public GoogleFileLabelResultDTO label(Id localGoogleFileVersionId, String providerName, String modelName, IGenAiClient genAiClient) {
		GoogleFileLabelResultDTO result = new GoogleFileLabelResultDTO();
		result.provider = providerName;

		this.labelDefinitions = metadataService.getAiLabelDefinitions();
		if (this.labelDefinitions.isEmpty()) {
			result.blocked = true;
			result.errorMessage = 'No AI labels are defined';
			return result;
		}

		GoogleFileAnalysisResultDTO analysis = execute(localGoogleFileVersionId, providerName, modelName, genAiClient, null);
		result.blocked = analysis.blocked;
		result.finishReason = analysis.finishReason;
		result.errorMessage = analysis.errorMessage;
		if (analysis.success != true || String.isBlank(analysis.text)) {
			return result;
		}

		LabelDecision decision = parseDecision(analysis.text);
		result.success = true;
		result.confidence = decision.confidence;
		result.labelName = decision.definition == null ? null : decision.definition.name;
		result.labelId = decision.definition == null ? null : decision.definition.labelId;
		if (decision.definition == null || decision.confidence < metadataService.getAiLabelingMinConfidence()) {
			return result;
		}

		result.applied = applyLabel(decision.definition, localGoogleFileVersionId, result);
		return result;
	}

	public override String getOperationType() {
		return OPERATION_TYPE;
	}

	public override String getConfigurationLabel() {
		return 'labeling';
	}

	public override String getAnalysisContextLabel() {
		return 'label assignment';
	}

	public override String getSystemPrompt() {
		return metadataService.getLabelingPrompt();
	}

	public override String buildUserPrompt(String normalizedInput, String documentText) {
		return 'Available labels:\n'
			+ buildLabelCatalog()
			+ '\n\nReply with exactly two lines and nothing else:\nLabel: <one label name from the list, written exactly as listed, or '
			+ NO_LABEL_ANSWER
			+ '>\nConfidence: <whole number from 0 to '
			+ MAX_CONFIDENCE_PERCENT
			+ ' for how certain you are>\n\nDocument text:\n'
			+ documentText;
	}

	public override Integer getMaxOutputTokens() {
		return DECISION_OUTPUT_TOKENS;
	}

	public override Integer getThinkingBudget() {
		return metadataService.getAiLabelingThinkingBudget();
	}

	public override void onLocalFileVersionLoaded(GoogleFileVersion__c localFileVersion) {
		this.targetFileVersion = localFileVersion;
	}

	public override Boolean isEligible(GoogleFileVersion__c localFileVersion) {
		return super.isEligible(localFileVersion)
			&& String.isNotBlank(localFileVersion.GoogleDriveFileId__c)
			&& String.isBlank(localFileVersion.AiLabels__c);
	}

	public override String buildAnalysisFailureMessage(String outcomeReason) {
		return String.isBlank(outcomeReason)
			? 'Unable to analyze the document content for label assignment'
			: 'Label response returned no content (' + outcomeReason + ')';
	}

	private String buildLabelCatalog() {
		List<String> catalogLines = new List<String>();
		for (Integer index = 0; index < this.labelDefinitions.size(); index++) {
			GoogleAiLabelDefinitionDTO definition = this.labelDefinitions[index];
			catalogLines.add((index + 1) + '. ' + definition.name.trim() + ' - ' + normalizePlainText(definition.description));
		}

		return String.join(catalogLines, '\n');
	}

	private LabelDecision parseDecision(String generatedText) {
		LabelDecision decision = new LabelDecision();

		Matcher decisionMatcher = DECISION_PATTERN.matcher(generatedText);
		if (!decisionMatcher.find()) {
			return decision;
		}

		decision.confidence = Math.min(Integer.valueOf(decisionMatcher.group(2)), MAX_CONFIDENCE_PERCENT);
		decision.definition = findDefinitionByName(decisionMatcher.group(1));
		return decision;
	}

	private String toLabelKey(String rawLabelName) {
		String cleaned = DECORATION_PATTERN.matcher(rawLabelName).replaceAll('');
		cleaned = TRAILING_SEPARATOR_PATTERN.matcher(cleaned).replaceAll('');
		return WHITESPACE_RUN_PATTERN.matcher(cleaned).replaceAll(' ').trim().toLowerCase();
	}

	private GoogleAiLabelDefinitionDTO findDefinitionByName(String answeredLabelName) {
		String answeredKey = toLabelKey(answeredLabelName);
		if (String.isBlank(answeredKey) || answeredKey == NO_LABEL_ANSWER.toLowerCase()) {
			return null;
		}

		for (GoogleAiLabelDefinitionDTO definition : this.labelDefinitions) {
			if (toLabelKey(definition.name) == answeredKey) {
				return definition;
			}
		}

		return null;
	}

	private Boolean applyLabel(GoogleAiLabelDefinitionDTO definition, Id localGoogleFileVersionId, GoogleFileLabelResultDTO result) {
		GoogleDrive remoteGoogleDrive = getGoogleApiProvider().retrieveGoogleDriveClient();
		String originalFileId = this.targetFileVersion.GoogleDriveFileId__c;
		String originalFailure = modifyLabels(remoteGoogleDrive, originalFileId, definition, localGoogleFileVersionId);
		if (originalFailure != null) {
			result.errorMessage = originalFailure;
			return false;
		}

		String workspaceCopyId = this.targetFileVersion.GoogleDocsFileId__c;
		if (String.isNotBlank(workspaceCopyId) && workspaceCopyId != originalFileId) {
			modifyLabels(remoteGoogleDrive, workspaceCopyId, definition, localGoogleFileVersionId);
		}

		return true;
	}

	private String modifyLabels(GoogleDrive remoteGoogleDrive, String remoteFileId, GoogleAiLabelDefinitionDTO definition, Id localGoogleFileVersionId) {
		try {
			remoteGoogleDrive.labels().modify(remoteFileId)
				.addLabelModification(new GoogleLabelModificationBuilder().setLabelId(definition.labelId))
				.setFields(MODIFIED_LABELS_FIELDS)
				.execute();

			return null;
		} catch (Exception ex) {
			Logger.error('Google Drive label could not be applied --> VersionId=' + localGoogleFileVersionId + ', FileId=' + remoteFileId + ', Label=' + definition.name + ', Message=' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			return ex.getMessage();
		}
	}

	private class LabelDecision {
		private GoogleAiLabelDefinitionDTO definition;
		private Integer confidence = 0;
	}
}