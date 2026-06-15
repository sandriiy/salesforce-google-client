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
		for (Id versionId : localFileVersionIds) {
			if (versionId == null) continue;
			intelligenceStates.add(buildIntelligenceState(versionId, versionsById.get(versionId), contextResolver, isIntelligenceConfigured));
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

	private GoogleFileIntelligenceStateDTO buildIntelligenceState(Id versionId, GoogleFileVersion__c localFileVersion, GoogleFileVersionContextResolver contextResolver, Boolean isIntelligenceConfigured) {
		GoogleFileIntelligenceStateDTO intelligenceState = createDefaultState(versionId);
		intelligenceState.summary = localFileVersion == null ? null : localFileVersion.Summary__c;
		intelligenceState.hasSummary = localFileVersion != null && String.isNotBlank(localFileVersion.Summary__c);
		intelligenceState.isIntelligenceEligible = isIntelligenceConfigured == true
			&& localFileVersion != null
			&& contextResolver.supportsInteractiveIntelligence(localFileVersion);
		return intelligenceState;
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