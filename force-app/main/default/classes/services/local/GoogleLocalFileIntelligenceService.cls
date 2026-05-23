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
		for (Id versionId : localFileVersionIds) {
			if (versionId == null) continue;
			intelligenceStates.add(buildIntelligenceState(versionId, versionsById.get(versionId), contextResolver));
		}

		return intelligenceStates;
	}

	private GoogleFileIntelligenceStateDTO buildIntelligenceState(Id versionId, GoogleFileVersion__c localFileVersion, GoogleFileVersionContextResolver contextResolver) {
		GoogleFileIntelligenceStateDTO intelligenceState = createDefaultState(versionId);
		intelligenceState.summary = localFileVersion == null ? null : localFileVersion.Summary__c;
		intelligenceState.hasSummary = localFileVersion != null && String.isNotBlank(localFileVersion.Summary__c);
		intelligenceState.isIntelligenceEligible = localFileVersion != null && contextResolver.supportsSummary(localFileVersion);
		return intelligenceState;
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