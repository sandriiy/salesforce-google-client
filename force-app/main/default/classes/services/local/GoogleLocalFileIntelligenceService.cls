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
public without sharing class GoogleLocalFileIntelligenceService {
	public GoogleFileIntelligenceStateDTO retrieveIntelligenceState(Id localFileVersionId) {
		if (localFileVersionId == null) {
			return createDefaultState(null);
		}

		List<GoogleFileIntelligenceStateDTO> intelligenceStates = retrieveIntelligenceStates(
			new List<Id>{ localFileVersionId }
		);

		if (intelligenceStates.isEmpty()) {
			return createDefaultState(localFileVersionId);
		}

		return intelligenceStates[0];
	}

	public List<GoogleFileIntelligenceStateDTO> retrieveIntelligenceStates(List<Id> localFileVersionIds) {
		List<GoogleFileIntelligenceStateDTO> intelligenceStates = new List<GoogleFileIntelligenceStateDTO>();
		if (localFileVersionIds == null || localFileVersionIds.isEmpty()) {
			return intelligenceStates;
		}

		Set<Id> versionIds = new Set<Id>();
		for (Id versionId : localFileVersionIds) {
			if (versionId != null) {
				versionIds.add(versionId);
			}
		}

		if (versionIds.isEmpty()) {
			return intelligenceStates;
		}

		Map<Id, GoogleFileVersion__c> versionsById = new Map<Id, GoogleFileVersion__c>(
			(List<GoogleFileVersion__c>) GoogleFileVersionSelector.query()
				.withAdvancedFields()
				.byIds(versionIds)
				.toList()
		);

		GoogleFileVersionContextResolver contextResolver = new GoogleFileVersionContextResolver();
		Boolean isIntelligenceConfigured = new GoogleFileIntelligenceFactory().isConfigured();
		IGoogleAiPromptSafetyGuard safetyGuard = new GoogleAiPromptSafetyGuardFactory().resolve();
		String safetyMode = new GoogleMetadataConfigService().getAiSafetyMode();
		for (Id versionId : localFileVersionIds) {
			if (versionId == null) continue;
			intelligenceStates.add(buildIntelligenceState(versionId, versionsById.get(versionId), contextResolver, isIntelligenceConfigured, safetyGuard, safetyMode));
		}

		return intelligenceStates;
	}

	public GoogleFileAnalysisResultDTO answerQuestion(Id localFileVersionId, String question) {
		if (localFileVersionId == null) {
			return null;
		}

		try {
			return new GoogleFileIntelligenceFactory().create().answerQuestion(localFileVersionId, question);
		} catch (GoogleFileIntelligenceFactory.GoogleFileIntelligenceFactoryException ex) {
			return buildBlockedQuestionResult(ex.getMessage());
		}
	}

	private GoogleFileIntelligenceStateDTO buildIntelligenceState(Id versionId, GoogleFileVersion__c localFileVersion, GoogleFileVersionContextResolver contextResolver, Boolean isIntelligenceConfigured, IGoogleAiPromptSafetyGuard safetyGuard, String safetyMode) {
		GoogleFileIntelligenceStateDTO intelligenceState = createDefaultState(versionId);
		String storedSummary = localFileVersion == null ? null : localFileVersion.Summary__c;
		Boolean hasStoredSummary = String.isNotBlank(storedSummary);

		if (hasStoredSummary && !isHistoricalSummaryAllowed(safetyGuard, safetyMode, versionId, storedSummary)) {
			storedSummary = null;
			hasStoredSummary = false;
		}

		intelligenceState.summary = storedSummary;
		intelligenceState.hasSummary = hasStoredSummary;
		intelligenceState.isIntelligenceEligible = isIntelligenceConfigured == true
			&& localFileVersion != null
			&& contextResolver.supportsInteractiveIntelligence(localFileVersion);
		return intelligenceState;
	}

	private Boolean isHistoricalSummaryAllowed(IGoogleAiPromptSafetyGuard safetyGuard, String safetyMode, Id versionId, String storedSummary) {
		if (safetyGuard == null) {
			return true;
		}

		GoogleAiPromptContext context = new GoogleAiPromptContext();
		context.operationType = GoogleAiPromptContext.OPERATION_SUMMARY;
		context.localFileVersionId = versionId;
		context.safetyMode = safetyMode;

		GoogleAiResponseSnapshot snapshot = new GoogleAiResponseSnapshot();
		snapshot.finishReason = 'STOP';
		snapshot.firstText = storedSummary;

		GoogleAiResponseSafetyDecision decision = safetyGuard.inspectResponse(context, snapshot);
		if (decision != null && decision.allowed != true) {
			Logger.info('AI Safety Guard hid historical summary: reason=' + decision.reasonCode + '; versionId=' + versionId).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			return false;
		}

		return true;
	}

	private GoogleFileAnalysisResultDTO buildBlockedQuestionResult(String errorMessage) {
		GoogleFileAnalysisResultDTO result = new GoogleFileAnalysisResultDTO();
		result.blocked = true;
		result.operationType = 'QUESTION';
		result.errorMessage = errorMessage;
		return result;
	}

	private GoogleFileIntelligenceStateDTO createDefaultState(Id versionId) {
		GoogleFileIntelligenceStateDTO intelligenceState = new GoogleFileIntelligenceStateDTO();
		intelligenceState.versionId = versionId;
		intelligenceState.summary = null;
		intelligenceState.hasSummary = false;
		intelligenceState.isIntelligenceEligible = false;
		return intelligenceState;
	}
}