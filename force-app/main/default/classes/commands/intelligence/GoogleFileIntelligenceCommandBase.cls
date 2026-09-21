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
 * The shared body of every AI operation: it exports the document text, runs the safety guard over the
 * request and again over the answer, calls the model and shapes the result. A subclass supplies the
 * prompts, the token budget and what makes a file eligible, and never talks to the model or the guard
 * itself. Anything that reaches a model in this package goes through here, which is what keeps the
 * guard impossible to skip.
 */
public abstract with sharing class GoogleFileIntelligenceCommandBase {
	private static final String DEFAULT_EXPORT_MIME_TYPE = 'text/plain';
	private static final String DEFAULT_RESPONSE_MIME_TYPE = 'text/plain';
	private static final Integer DEFAULT_CANDIDATE_COUNT = 1;
	private static final Integer DEFAULT_THINKING_BUDGET = 0;
	private static final Integer INPUT_MARKER_EDGE_LENGTH = 8;

	private final GoogleClientApiProvider googleApiProvider;
	private final GoogleFileVersionContextResolver versionContextResolver;
	private final GoogleMetadataConfigService metadataConfigService;

	public GoogleFileIntelligenceCommandBase() {
		this(new GoogleClientApiProvider(), new GoogleFileVersionContextResolver());
	}

	@TestVisible
	public GoogleFileIntelligenceCommandBase(GoogleClientApiProvider googleApiProvider, GoogleFileVersionContextResolver versionContextResolver) {
		this.googleApiProvider = googleApiProvider == null ? new GoogleClientApiProvider() : googleApiProvider;
		this.versionContextResolver = versionContextResolver == null ? new GoogleFileVersionContextResolver() : versionContextResolver;
		this.metadataConfigService = new GoogleMetadataConfigService();
	}

	/**
	 * Runs the whole operation end to end and always answers with a result rather than throwing, so a
	 * caller reads success, blocked and errorMessage instead of catching.
	 *
	 * @param localGoogleFileVersionId The version being analyzed.
	 * @param providerName The provider name to report back, such as "Gemini" or "Agent Platform".
	 * @param modelName The model to call.
	 * @param genAiClient The client the request goes through.
	 * @param inputText The user input for operations that take one, or null.
	 * @return What happened, including the text when it worked and why not when it did not.
	 */
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

		IGoogleAiPromptSafetyGuard safetyGuard = resolveSafetyGuard();
		GoogleAiPromptContext safetyContext = buildSafetyContext(localGoogleFileVersionId, providerName, modelName, normalizedInput);

		GoogleAiPromptSafetyDecision requestDecision = safetyGuard.inspectRequest(safetyContext);
		if (requestDecision != null && requestDecision.allowed != true) {
			result.blocked = true;
			result.errorMessage = requestDecision.userVisibleMessage;
			logRequestBlocked(requestDecision, safetyContext);
			return result;
		}

		if (requestDecision != null && String.isNotBlank(requestDecision.sanitizedUserInput)) {
			normalizedInput = requestDecision.sanitizedUserInput;
			safetyContext.userInput = normalizedInput;
		}

		try {
			GoogleFileVersion__c localFileVersion = retrieveLocalFileVersion(localGoogleFileVersionId);
			onLocalFileVersionLoaded(localFileVersion);
			if (!isEligible(localFileVersion)) {
				applyIneligibleResult(result);
				return result;
			}

			String documentText = exportDocumentText(localFileVersion);
			if (String.isBlank(documentText)) {
				result.errorMessage = buildExportFailureMessage();
				return result;
			}

			safetyContext.documentText = documentText;
			String effectiveSystemPrompt = safetyGuard.wrapSystemPrompt(safetyContext);

			GenAiResponse response = genAiClient.generate(buildRequest(modelName, normalizedInput, documentText, effectiveSystemPrompt));
			String outcomeReason = response == null ? null : response.outcomeReason();
			result.finishReason = response == null || response.firstCandidate() == null
				? null
				: response.firstCandidate().finishReason;

			GoogleAiResponseSnapshot responseSnapshot = buildResponseSnapshot(response, result.finishReason, outcomeReason);
			GoogleAiResponseSafetyDecision responseDecision = safetyGuard.inspectResponse(safetyContext, responseSnapshot);
			if (responseDecision != null && responseDecision.allowed != true) {
				result.blocked = true;
				result.text = null;
				result.errorMessage = responseDecision.userVisibleMessage;
				logResponseBlocked(responseDecision, safetyContext, result.finishReason);
				return result;
			}

			String responseText = responseDecision != null && String.isNotBlank(responseDecision.sanitizedText)
				? responseDecision.sanitizedText
				: (response == null ? null : response.firstText());

			String outputText = finalizeGeneratedText(normalizeGeneratedText(responseText), result.finishReason);
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

	/**
	 * The operation name that goes into the result and the safety context, such as "SUMMARY", "QUESTION"
	 * or "LABEL".
	 *
	 * @return The operation type of this command.
	 */
	public abstract String getOperationType();
	/**
	 * How this operation is named in the message a user sees when the AI configuration is missing.
	 *
	 * @return A short lower case name such as "summary" or "labeling".
	 */
	public abstract String getConfigurationLabel();
	/**
	 * How this operation is named in the message a user sees when the model returns nothing usable.
	 *
	 * @return A short phrase such as "summary generation".
	 */
	public abstract String getAnalysisContextLabel();
	/**
	 * The system prompt for this operation, normally the one the administrator configured. The guard wraps
	 * it in its own envelope, so never put safety rules here.
	 *
	 * @return The system prompt to send.
	 */
	public abstract String getSystemPrompt();
	/**
	 * Builds the user turn from the document text and whatever the user asked.
	 *
	 * @param normalizedInput The cleaned user input, or null for operations that take none.
	 * @param documentText The exported document content.
	 * @return The user prompt to send.
	 */
	public abstract String buildUserPrompt(String normalizedInput, String documentText);
	/**
	 * How long the answer may be. Declare only the answer budget, the base class adds the thinking budget
	 * on top because Gemini counts thinking against the same limit.
	 *
	 * @return The maximum tokens for the answer.
	 */
	public abstract Integer getMaxOutputTokens();

	/**
	 * How much the model may vary its answer. Zero by default, because these operations want the same
	 * answer for the same document.
	 *
	 * @return The temperature to send.
	 */
	public virtual Double getTemperature() {
		return 0.0;
	}

	/**
	 * How much room the model gets to reason before answering. Zero by default, which turns reasoning off
	 * and is the fastest and cheapest option.
	 *
	 * @return The thinking budget in tokens.
	 */
	public virtual Integer getThinkingBudget() {
		return DEFAULT_THINKING_BUDGET;
	}

	/**
	 * How many answers to ask for. One by default, and there is rarely a reason to change it.
	 *
	 * @return The number of candidates to request.
	 */
	public virtual Integer getCandidateCount() {
		return DEFAULT_CANDIDATE_COUNT;
	}

	/**
	 * The format the document is exported in before it goes to the model. Plain text by default.
	 *
	 * @return The MIME type to export the Workspace copy as.
	 */
	public virtual String getExportMimeType() {
		return DEFAULT_EXPORT_MIME_TYPE;
	}

	/**
	 * The format the answer is expected in. Plain text by default, and the shipped guard envelope forbids
	 * JSON, so asking for JSON here means writing your own guard too.
	 *
	 * @return The response MIME type to request.
	 */
	public virtual String getResponseMimeType() {
		return DEFAULT_RESPONSE_MIME_TYPE;
	}

	/**
	 * Cleans the user input before anything else sees it. Collapses whitespace by default.
	 *
	 * @param inputText The raw input.
	 * @return The cleaned input.
	 */
	public virtual String normalizeInput(String inputText) {
		return normalizePlainText(inputText);
	}

	/**
	 * Checks the input before the model is called. Return a message to refuse with, or null to carry on.
	 *
	 * @param normalizedInput The cleaned input.
	 * @return The reason to refuse, or null when the input is fine.
	 */
	public virtual String validateInput(String normalizedInput) {
		return null;
	}

	/**
	 * Decides whether this version can be analyzed at all. By default it needs a Workspace copy and a size
	 * within the limit, and a subclass narrows it further, for example to skip a file it already handled.
	 *
	 * @param localFileVersion The version loaded with its confidential fields.
	 * @return True when the operation may run on this version.
	 */
	public virtual Boolean isEligible(GoogleFileVersion__c localFileVersion) {
		return supportsInteractiveIntelligence(localFileVersion);
	}

	/**
	 * Hands the loaded version to the subclass, which is how a command that needs the Drive Ids later gets
	 * them without querying twice.
	 *
	 * @param localFileVersion The version that was just loaded.
	 */
	public virtual void onLocalFileVersionLoaded(GoogleFileVersion__c localFileVersion) {}

	/**
	 * Shapes the result when the file is not eligible. Marks it blocked by default, and a subclass adds the
	 * message a user should see.
	 *
	 * @param result The result being returned.
	 */
	public virtual void applyIneligibleResult(GoogleFileAnalysisResultDTO result) {
		result.blocked = true;
	}

	/**
	 * Cleans the model answer. Collapses whitespace by default, which is what makes a two line answer
	 * parseable as one string.
	 *
	 * @param generatedText The raw answer.
	 * @return The cleaned answer.
	 */
	public virtual String normalizeGeneratedText(String generatedText) {
		return normalizePlainText(generatedText);
	}

	/**
	 * Last shaping of the answer before it is returned, which is where a subclass trims to a field length
	 * or marks an answer that was cut short.
	 *
	 * @param generatedText The cleaned answer.
	 * @param finishReason Why the model stopped, such as "STOP" or "MAX_TOKENS".
	 * @return The answer as the user should see it.
	 */
	public virtual String finalizeGeneratedText(String generatedText, String finishReason) {
		return generatedText;
	}

	/**
	 * The message when the model or client is missing, which normally means the provider was never saved.
	 *
	 * @return The message to show.
	 */
	public virtual String buildConfigurationUnavailableMessage() {
		return 'Google AI ' + getConfigurationLabel() + ' configuration is unavailable';
	}

	/**
	 * The message when the document text could not be exported.
	 *
	 * @return The message to show.
	 */
	public virtual String buildExportFailureMessage() {
		return 'Unable to export the document content for analysis';
	}

	/**
	 * The message when the model answered with nothing usable.
	 *
	 * @param outcomeReason What the provider said about it, when it said anything.
	 * @return The message to show.
	 */
	public virtual String buildAnalysisFailureMessage(String outcomeReason) {
		String failureMessage = 'Unable to analyze the document content for ' + getAnalysisContextLabel();
		return String.isBlank(outcomeReason)
			? failureMessage
			: failureMessage + ' (' + outcomeReason + ')';
	}

	/**
	 * Collapses every run of whitespace into a single space and trims the result.
	 *
	 * @param text The text to clean.
	 * @return The cleaned text, or null when there was nothing in it.
	 */
	public String normalizePlainText(String text) {
		return String.isBlank(text)
			? null
			: text.replaceAll('\\s+', ' ').trim();
	}

	/**
	 * Says whether the text ends in a full stop, question mark or exclamation mark, looking past a closing
	 * quote or bracket. Useful for spotting an answer that was cut off mid sentence.
	 *
	 * @param text The text to check.
	 * @return True when it ends like a finished sentence.
	 */
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

	/**
	 * The provider a subclass reaches Drive through. Use this one rather than building another, so the
	 * access token is resolved once for the whole operation.
	 *
	 * @return The provider this command was built with.
	 */
	protected GoogleClientApiProvider getGoogleApiProvider() {
		return this.googleApiProvider;
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
		return new GoogleFileTextExportCommand(this.googleApiProvider).exportWorkspaceCopy(localFileVersion, getExportMimeType());
	}

	private GenAiRequest buildRequest(String modelName, String normalizedInput, String documentText, String effectiveSystemPrompt) {
		return new GenAiRequestBuilder(modelName)
			.withSystemText(effectiveSystemPrompt)
			.addUserText(buildUserPrompt(normalizedInput, documentText))
			.withCandidates(getCandidateCount())
			.withTemperature(getTemperature())
			.withMaxTokens(getMaxOutputTokens() + getThinkingBudget())
			.withProviderOptions(new GenAiGoogleOptions().withThinkingBudget(getThinkingBudget()))
			.withResponseMimeType(getResponseMimeType())
			.build();
	}

	@TestVisible
	protected virtual IGoogleAiPromptSafetyGuard resolveSafetyGuard() {
		return new GoogleAiPromptSafetyGuardFactory().resolve();
	}

	private GoogleAiPromptContext buildSafetyContext(Id localGoogleFileVersionId, String providerName, String modelName, String normalizedInput) {
		GoogleAiPromptContext context = new GoogleAiPromptContext();
		context.operationType = getOperationType();
		context.providerName = providerName;
		context.modelName = modelName;
		context.localFileVersionId = localGoogleFileVersionId;
		context.rawSystemPrompt = getSystemPrompt();
		context.userInput = normalizedInput;
		context.safetyMode = metadataConfigService.getAiSafetyMode();
		return context;
	}

	private GoogleAiResponseSnapshot buildResponseSnapshot(GenAiResponse response, String finishReason, String outcomeReason) {
		GoogleAiResponseSnapshot snapshot = new GoogleAiResponseSnapshot();
		snapshot.finishReason = finishReason;
		snapshot.outcomeReason = outcomeReason;
		snapshot.firstText = response == null ? null : response.firstText();
		return snapshot;
	}

	private void logRequestBlocked(GoogleAiPromptSafetyDecision decision, GoogleAiPromptContext context) {
		Logger.info('AI Safety Guard blocked request: reason=' + decision.reasonCode
			+ '; provider=' + context.providerName
			+ '; operation=' + context.operationType
			+ '; versionId=' + context.localFileVersionId
			+ '; inputLength=' + inputLength(context.userInput)
			+ '; inputMarker=' + inputMarker(context.userInput)).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
		Logger.saveLog();
	}

	private void logResponseBlocked(GoogleAiResponseSafetyDecision decision, GoogleAiPromptContext context, String finishReason) {
		Logger.info('AI Safety Guard blocked response: reason=' + decision.reasonCode
			+ '; provider=' + context.providerName
			+ '; operation=' + context.operationType
			+ '; versionId=' + context.localFileVersionId
			+ '; finishReason=' + finishReason).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
		Logger.saveLog();
	}

	private Integer inputLength(String input) {
		return input == null ? 0 : input.length();
	}

	private String inputMarker(String input) {
		if (String.isBlank(input)) {
			return '';
		}

		if (input.length() <= INPUT_MARKER_EDGE_LENGTH * 2) {
			return input;
		}

		return input.substring(0, INPUT_MARKER_EDGE_LENGTH) + '...' + input.substring(input.length() - INPUT_MARKER_EDGE_LENGTH);
	}
}