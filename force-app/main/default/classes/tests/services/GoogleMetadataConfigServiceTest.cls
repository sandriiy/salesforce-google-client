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
@IsTest
private class GoogleMetadataConfigServiceTest {
	private class SuccessDeployer implements IGoogleMetadataDeployer {
		public Id enqueue(Metadata.DeployContainer container) {
			return '0Af000000000001AAA';
		}
	}

	private class NullIdDeployer implements IGoogleMetadataDeployer {
		public Id enqueue(Metadata.DeployContainer container) {
			return null;
		}
	}

	private class ThrowingDeployer implements IGoogleMetadataDeployer {
		public Id enqueue(Metadata.DeployContainer container) {
			throw new CalloutException('boom');
		}
	}

	private class CapturingDeployer implements IGoogleMetadataDeployer {
		private Metadata.DeployContainer capturedContainer;

		public Id enqueue(Metadata.DeployContainer container) {
			this.capturedContainer = container;
			return '0Af000000000002AAA';
		}

		private Map<String, Object> capturedValues() {
			Map<String, Object> valuesByField = new Map<String, Object>();
			Metadata.CustomMetadata record = (Metadata.CustomMetadata) this.capturedContainer.getMetadata()[0];
			for (Metadata.CustomMetadataValue value : record.values) {
				valuesByField.put(value.field, value.value);
			}

			return valuesByField;
		}
	}

	private static GoogleClientConfig__mdt buildConfig(Boolean isPreviewDisabled) {
		return new GoogleClientConfig__mdt(
			DeveloperName = 'GoogleClient',
			MasterLabel = 'Google Client',
			IsFilePreviewDisabled__c = isPreviewDisabled
		);
	}

	@IsTest
	private static void testIsDirectBrowserUploadEnabledNegativeDefaultsToFalse() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt();
		GoogleMetadataConfigService svc = new GoogleMetadataConfigService();

		Assert.isFalse(svc.isDirectBrowserUploadEnabled(), 'A field that is empty after an upgrade must keep the standard upload path');
	}

	@IsTest
	private static void testIsDirectBrowserUploadEnabledPositiveWhenOptedIn() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(
			DeveloperName = 'GoogleClient',
			MasterLabel = 'Google Client',
			IsDirectBrowserUploadEnabled__c = true
		);

		Assert.isTrue(new GoogleMetadataConfigService().isDirectBrowserUploadEnabled());
	}

	@IsTest
	private static void testConstructorPositiveConfigExists() {
		GoogleMetadataConfigService.configRecordOverride = buildConfig(false);
		GoogleMetadataConfigService svc = new GoogleMetadataConfigService();
		Assert.areNotEqual(null, svc.getConfig());
	}

	@IsTest
	private static void testSaveConfigPositiveNoOps() {
		GoogleMetadataConfigService.configRecordOverride = buildConfig(false);
		GoogleMetadataConfigService svc = new GoogleMetadataConfigService(new ThrowingDeployer());

		Test.startTest();
		svc.saveConfig(null);
		svc.saveConfig(new Map<String, Object>());
		Test.stopTest();

		Assert.isTrue(true);
	}

	@IsTest
	private static void testSaveConfigPositiveEnqueue() {
		GoogleMetadataConfigService.configRecordOverride = buildConfig(false);
		GoogleMetadataConfigService svc = new GoogleMetadataConfigService(new SuccessDeployer());

		Map<String, Object> changes = new Map<String, Object>{
			'DefaultGoogleUploadFolderId__c' => 'folder_123',
			'IsFilePreviewDisabled__c' => true
		};

		Test.startTest();
		svc.saveConfig(changes);
		Test.stopTest();

		Assert.isTrue(true);
	}

	@IsTest
	private static void testSaveConfigNegativeEnqueueThrows() {
		GoogleMetadataConfigService.configRecordOverride = buildConfig(false);
		GoogleMetadataConfigService svc = new GoogleMetadataConfigService(new ThrowingDeployer());

		Map<String, Object> changes = new Map<String, Object>{
			'DefaultGoogleUploadFolderId__c' => 'folder_123'
		};

		Test.startTest();
		try {
			svc.saveConfig(changes);
			Assert.isTrue(false);
		} catch (GoogleMetadataConfigService.GoogleMetadataConfigException ex) {
			Assert.isTrue(ex.getMessage().contains('Failed to save Google Client configuration'));
		}
		Test.stopTest();
	}

	@IsTest
	private static void testSaveConfigPositiveCreatesRecordWhenNotExists() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt();

		GoogleMetadataConfigService svc = new GoogleMetadataConfigService(new SuccessDeployer());

		Map<String, Object> changes = new Map<String, Object>{
			'CustomGoogleCertificate__c' => 'MyCert',
			'CustomGoogleServiceAccount__c' => 'sa@project.iam.gserviceaccount.com'
		};

		Test.startTest();
		Id result = svc.saveConfig(changes);
		Test.stopTest();

		Assert.areNotEqual(null, result, 'Should return a deployment Id when creating a new record');
	}

	@IsTest
	private static void testGettersPositiveValues() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(
			IsFilePreviewDisabled__c = false,
			DefaultBigFileSize__c = 2097152,
			MaxDeleteChainSize__c = 3
		);
		GoogleMetadataConfigService svc = new GoogleMetadataConfigService();
		Assert.areNotEqual(null, svc.isPreviewDisabled());
		Assert.areNotEqual(null, svc.getBigFileSizeInBytes());
		Assert.areNotEqual(null, svc.getDeleteChainSize());
	}

	@IsTest
	private static void testGetAdditionalUploadFolderIdsPositiveEmpty() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(
			AdditionalGoogleUploadFolderIds__c = null
		);
		GoogleMetadataConfigService svc = new GoogleMetadataConfigService();

		Assert.areEqual(0, svc.getAdditionalUploadFolderIds().size());
	}

	@IsTest
	private static void testGetAdditionalUploadFolderIdsPositiveBlank() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(
			AdditionalGoogleUploadFolderIds__c = '   '
		);
		GoogleMetadataConfigService svc = new GoogleMetadataConfigService();

		Assert.areEqual(0, svc.getAdditionalUploadFolderIds().size());
	}

	@IsTest
	private static void testGetAdditionalUploadFolderIdsPositiveTrimsAndDropsBlanks() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(
			AdditionalGoogleUploadFolderIds__c = ' folder_a ;;folder_b; ;folder_c '
		);
		GoogleMetadataConfigService svc = new GoogleMetadataConfigService();

		List<String> ids = svc.getAdditionalUploadFolderIds();
		Assert.areEqual(3, ids.size());
		Assert.areEqual('folder_a', ids[0]);
		Assert.areEqual('folder_b', ids[1]);
		Assert.areEqual('folder_c', ids[2]);
	}

	@IsTest
	private static void testGetAllUploadFolderIdsPositiveOrderedAndDeduped() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(
			DefaultGoogleUploadFolderId__c = 'primary_folder',
			AdditionalGoogleUploadFolderIds__c = 'secondary_folder;primary_folder;third_folder'
		);
		GoogleMetadataConfigService svc = new GoogleMetadataConfigService();

		List<String> ordered = svc.getAllUploadFolderIds();
		Assert.areEqual(3, ordered.size());
		Assert.areEqual('primary_folder', ordered[0]);
		Assert.areEqual('secondary_folder', ordered[1]);
		Assert.areEqual('third_folder', ordered[2]);
	}

	@IsTest
	private static void testGetAllUploadFolderIdsPositivePrimaryOnly() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(
			DefaultGoogleUploadFolderId__c = 'primary_folder',
			AdditionalGoogleUploadFolderIds__c = null
		);
		GoogleMetadataConfigService svc = new GoogleMetadataConfigService();

		List<String> ordered = svc.getAllUploadFolderIds();
		Assert.areEqual(1, ordered.size());
		Assert.areEqual('primary_folder', ordered[0]);
	}

	@IsTest
	private static void testGetAllUploadFolderIdsPositiveNoPrimary() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(
			DefaultGoogleUploadFolderId__c = null,
			AdditionalGoogleUploadFolderIds__c = 'secondary_folder;third_folder'
		);
		GoogleMetadataConfigService svc = new GoogleMetadataConfigService();

		List<String> ordered = svc.getAllUploadFolderIds();
		Assert.areEqual(2, ordered.size());
		Assert.areEqual('secondary_folder', ordered[0]);
		Assert.areEqual('third_folder', ordered[1]);
	}

	@IsTest
	private static void testGetAllUploadFolderIdsPositiveAllBlank() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(
			DefaultGoogleUploadFolderId__c = null,
			AdditionalGoogleUploadFolderIds__c = null
		);
		GoogleMetadataConfigService svc = new GoogleMetadataConfigService();

		Assert.areEqual(0, svc.getAllUploadFolderIds().size());
	}

	@IsTest
	private static void testGetFileExplorerColumnsPositiveBlankUsesDefault() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(
			FileExplorerColumns__c = null
		);
		GoogleMetadataConfigService svc = new GoogleMetadataConfigService();

		List<String> columns = svc.getFileExplorerColumns();
		Assert.areEqual(5, columns.size());
		Assert.areEqual('title', columns[0]);
		Assert.areEqual('isLinked', columns[1]);
		Assert.areEqual('access', columns[2]);
		Assert.areEqual('owner', columns[3]);
		Assert.areEqual('lastModified', columns[4]);
	}

	@IsTest
	private static void testGetFileExplorerColumnsPositiveParsesConfigured() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(
			FileExplorerColumns__c = ' title ;summary;; type ; '
		);
		GoogleMetadataConfigService svc = new GoogleMetadataConfigService();

		List<String> columns = svc.getFileExplorerColumns();
		Assert.areEqual(3, columns.size());
		Assert.areEqual('title', columns[0]);
		Assert.areEqual('summary', columns[1]);
		Assert.areEqual('type', columns[2]);
	}

	@IsTest
	private static void testResolveConfigRecordNeverReturnsNull() {
		GoogleMetadataConfigService.configRecordOverride = null;
		GoogleMetadataConfigService svc = new GoogleMetadataConfigService();

		Assert.isNotNull(svc.getConfig());
		Assert.isNotNull(svc.getAiSafetyMode());
		Assert.isNotNull(svc.getFileExplorerColumns());
		Assert.isNotNull(svc.getAllUploadFolderIds());
	}

	@IsTest
	private static void testFreshInstallEmptyConfigUsesDefaults() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt();
		GoogleMetadataConfigService svc = new GoogleMetadataConfigService();

		Assert.isFalse(svc.hasConfigRecord());
		Assert.isFalse(svc.isPreviewDisabled());
		Assert.isFalse(svc.isDirectBrowserUploadEnabled());
		Assert.isFalse(svc.isFileIntelligenceEnabled());
		Assert.isFalse(svc.requiresRecordFolder());

		Assert.areEqual(GoogleMetadataConfigService.DEFAULT_BIG_FILE_SIZE, svc.getBigFileSizeInBytes());
		Assert.areEqual(GoogleMetadataConfigService.DEFAULT_MAX_DELETE_CHAIN_SIZE, svc.getDeleteChainSize());
		Assert.areEqual(GoogleMetadataConfigService.DEFAULT_AUTH_CLASS_NAME, svc.getGoogleDriveAuthorizerClassName());
		Assert.areEqual(GoogleMetadataConfigService.DEFAULT_AI_SAFETY_MODE, svc.getAiSafetyMode());
		Assert.areEqual(GoogleMetadataConfigService.DEFAULT_SUMMARY_PROMPT, svc.getSummaryPrompt());
		Assert.areEqual(GoogleMetadataConfigService.DEFAULT_QUESTION_PROMPT, svc.getQuestionPrompt());
		Assert.areEqual(GoogleMetadataConfigService.DEFAULT_QUESTION_MAX_OUTPUT_TOKENS, svc.getQuestionMaxOutputTokens());
		Assert.areEqual(5, svc.getFileExplorerColumns().size());
		Assert.areEqual(0, svc.getAllUploadFolderIds().size());
	}

	@IsTest
	private static void testBlankFieldsFallBackToDefaults() {
		GoogleCloudTestFactory.config()
			.asPackagedRecord()
			.withUploadFolderId('')
			.withAiSafetyMode('')
			.withSummaryPrompt('')
			.withFileExplorerColumns('')
			.apply();

		GoogleMetadataConfigService svc = new GoogleMetadataConfigService();

		Assert.isTrue(svc.hasConfigRecord());
		Assert.areEqual(GoogleMetadataConfigService.DEFAULT_AI_SAFETY_MODE, svc.getAiSafetyMode());
		Assert.areEqual(GoogleMetadataConfigService.DEFAULT_SUMMARY_PROMPT, svc.getSummaryPrompt());
		Assert.areEqual(GoogleMetadataConfigService.DEFAULT_FILE_EXPLORER_COLUMNS.split(';').size(), svc.getFileExplorerColumns().size());
		Assert.areEqual(0, svc.getAllUploadFolderIds().size());
	}

	@IsTest
	private static void testUnsupportedSafetyModeFallsBackToDefault() {
		GoogleCloudTestFactory.config().withAiSafetyMode('Paranoid').apply();

		Assert.areEqual(GoogleMetadataConfigService.DEFAULT_AI_SAFETY_MODE, new GoogleMetadataConfigService().getAiSafetyMode());
	}

	@IsTest
	private static void testConfiguredNumericFieldsAreReadWithoutCastErrors() {
		GoogleCloudTestFactory.config()
			.withBigFileSize(5242880L)
			.withDeleteChainSize(7)
			.withQuestionMaxOutputTokens(2048)
			.apply();

		GoogleMetadataConfigService svc = new GoogleMetadataConfigService();

		Assert.areEqual(5242880L, svc.getBigFileSizeInBytes());
		Assert.areEqual(7, svc.getDeleteChainSize());
		Assert.areEqual(2048, svc.getQuestionMaxOutputTokens());
	}

	@IsTest
	private static void testOptionalFeaturesAreOffUntilExplicitlyEnabled() {
		GoogleCloudTestFactory.config().apply();
		GoogleMetadataConfigService disabled = new GoogleMetadataConfigService();

		Assert.isFalse(disabled.isDirectBrowserUploadEnabled());
		Assert.isFalse(disabled.isFileIntelligenceEnabled());

		GoogleCloudTestFactory.config()
			.withDirectBrowserUpload(true)
			.withFileIntelligence(true)
			.apply();
		GoogleMetadataConfigService enabled = new GoogleMetadataConfigService();

		Assert.isTrue(enabled.isDirectBrowserUploadEnabled());
		Assert.isTrue(enabled.isFileIntelligenceEnabled());
	}

	@IsTest
	private static void testAiLabelingIsOffWithSafeDefaultsAfterUpgrade() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt();
		GoogleMetadataConfigService svc = new GoogleMetadataConfigService();

		Assert.isFalse(svc.isAiLabelingEnabled());
		Assert.areEqual(GoogleMetadataConfigService.DEFAULT_LABELING_PROMPT, svc.getLabelingPrompt());
		Assert.areEqual(GoogleMetadataConfigService.DEFAULT_AI_LABELING_MIN_CONFIDENCE, svc.getAiLabelingMinConfidence());
		Assert.areEqual(GoogleMetadataConfigService.DEFAULT_AI_LABELING_THINKING_BUDGET, svc.getAiLabelingThinkingBudget());
		Assert.areEqual(0, svc.getAiLabelDefinitions().size());
	}

	@IsTest
	private static void testAiLabelingRequiresFileIntelligence() {
		GoogleCloudTestFactory.config().withAiLabeling(true).apply();
		Assert.isFalse(new GoogleMetadataConfigService().isAiLabelingEnabled());

		GoogleCloudTestFactory.config().withAiLabeling(true).withFileIntelligence(true).apply();
		Assert.isTrue(new GoogleMetadataConfigService().isAiLabelingEnabled());
	}

	@IsTest
	private static void testAiLabelingMinConfidenceIsClampedToPercent() {
		GoogleCloudTestFactory.config().withAiLabelingMinConfidence(150).apply();
		Assert.areEqual(100, new GoogleMetadataConfigService().getAiLabelingMinConfidence());

		GoogleCloudTestFactory.config().withAiLabelingMinConfidence(-5).apply();
		Assert.areEqual(0, new GoogleMetadataConfigService().getAiLabelingMinConfidence());

		GoogleCloudTestFactory.config().withAiLabelingThinkingBudget(-1).apply();
		Assert.areEqual(GoogleMetadataConfigService.DEFAULT_AI_LABELING_THINKING_BUDGET, new GoogleMetadataConfigService().getAiLabelingThinkingBudget());
	}

	@IsTest
	private static void testGetAiLabelDefinitionsKeepsOnlyCompleteUniqueEntries() {
		GoogleCloudTestFactory.config()
			.withAiLabelDefinitions('['
				+ '{"name":"Invoice","labelId":"LABEL_INVOICE","description":"A bill requesting payment"},'
				+ '{"name":"","labelId":"LABEL_BLANK","description":"Missing name"},'
				+ '{"name":"invoice","labelId":"LABEL_DUP","description":"Duplicate name"},'
				+ '{"name":"Contract","description":"Missing label id"},'
				+ '{"name":"' + 'N'.repeat(81) + '","labelId":"LABEL_LONG","description":"Name longer than a label record allows"},'
				+ '{"name":"Receipt","labelId":"LABEL_RECEIPT","fieldId":"IGNORED_KEY","description":"Proof of payment"}'
				+ ']')
			.apply();

		List<GoogleAiLabelDefinitionDTO> definitions = new GoogleMetadataConfigService().getAiLabelDefinitions();

		Assert.areEqual(2, definitions.size());
		Assert.areEqual('Invoice', definitions[0].name);
		Assert.areEqual('LABEL_INVOICE', definitions[0].labelId);
		Assert.areEqual('Receipt', definitions[1].name);
		Assert.areEqual('LABEL_RECEIPT', definitions[1].labelId);
	}

	@IsTest
	private static void testResolveConfigRecordPositiveReadsLongTextInFull() {
		GoogleMetadataConfigService.configRecordOverride = null;
		GoogleMetadataConfigService.resolvedConfigRecord = null;
		String longPrompt = 'Summarize the document in one sentence. '.repeat(10);
		GSOQL.mock(GoogleClientConfigSelector.MOCK_ID).thenReturn(new List<GoogleClientConfig__mdt>{
			new GoogleClientConfig__mdt(DeveloperName = 'GoogleClient', CustomSummaryPrompt__c = longPrompt)
		});

		String resolvedPrompt = new GoogleMetadataConfigService().getSummaryPrompt();
		GoogleMetadataConfigService.resolvedConfigRecord = null;

		Assert.isTrue(longPrompt.length() > 255);
		Assert.areEqual(longPrompt, resolvedPrompt);
	}

	@IsTest
	private static void testGetAiLabelDefinitionsIgnoresUnreadableValue() {
		GoogleCloudTestFactory.config().withAiLabelDefinitions('not json at all').apply();

		Assert.areEqual(0, new GoogleMetadataConfigService().getAiLabelDefinitions().size());
	}

	@IsTest
	private static void testSaveConfigAppliesLabelingDefaultsOnlyWhenEnabled() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(
			DeveloperName = 'GoogleClient',
			MasterLabel = 'Google Client',
			IsFileIntelligenceEnabled__c = true
		);
		CapturingDeployer deployer = new CapturingDeployer();

		Test.startTest();
		new GoogleMetadataConfigService(deployer).saveConfig(new Map<String, Object>{ 'IsAiLabelingEnabled__c' => true });
		Test.stopTest();

		Map<String, Object> savedValues = deployer.capturedValues();
		Assert.areEqual(GoogleMetadataConfigService.DEFAULT_LABELING_PROMPT, savedValues.get('CustomLabelingPrompt__c'));
		Assert.areEqual(GoogleMetadataConfigService.DEFAULT_AI_LABELING_MIN_CONFIDENCE, savedValues.get('AiLabelingMinConfidence__c'));
		Assert.areEqual(GoogleMetadataConfigService.DEFAULT_AI_LABELING_THINKING_BUDGET, savedValues.get('AiLabelingThinkingBudget__c'));
	}

	@IsTest
	private static void testSaveConfigLeavesLabelingFieldsAloneWhenDisabled() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(
			DeveloperName = 'GoogleClient',
			MasterLabel = 'Google Client'
		);
		CapturingDeployer deployer = new CapturingDeployer();

		Test.startTest();
		new GoogleMetadataConfigService(deployer).saveConfig(new Map<String, Object>{ 'OrganizationalDomain__c' => 'cloudrylabs.com' });
		Test.stopTest();

		Map<String, Object> savedValues = deployer.capturedValues();
		Assert.isFalse(savedValues.containsKey('CustomLabelingPrompt__c'));
		Assert.isFalse(savedValues.containsKey('AiLabelingMinConfidence__c'));
	}

	@IsTest
	private static void testDeactivateAiConfigClearsEveryAiSettingAndTurnsAnalysisOff() {
		GoogleCloudTestFactory.config()
			.asPackagedRecord()
			.withUploadFolderId('PRIMARY')
			.withFileIntelligence(true)
			.withAiLabeling(true)
			.withGeminiApiKey('api-key-1')
			.withAiModel('gemini-2.0-flash')
			.withAgentProjectId('project-1')
			.withAgentLocation('global')
			.withSummaryPrompt('Summarize')
			.withQuestionPrompt('Answer')
			.withQuestionMaxOutputTokens(512)
			.withAiSafetyMode('Strict')
			.withAiPromptSafetyGuardClass('MyGuard')
			.withLabelingPrompt('Label')
			.withAiLabelingMinConfidence(90)
			.withAiLabelingThinkingBudget(1024)
			.withAiLabelDefinitions('[{"name":"Invoice","labelId":"L1","description":"Bills"}]')
			.apply();
		CapturingDeployer deployer = new CapturingDeployer();

		Test.startTest();
		Id deploymentId = new GoogleMetadataConfigService(deployer).deactivateAiConfig();
		Test.stopTest();

		Assert.isNotNull(deploymentId, 'Deactivation must be sent to the Metadata API like any other save');
		Map<String, Object> savedValues = deployer.capturedValues();
		for (String fieldApiName : GoogleMetadataConfigService.AI_CONFIGURATION_FIELDS) {
			Assert.isTrue(savedValues.containsKey(fieldApiName), fieldApiName + ' must be part of the deactivation');
			Assert.isNull(savedValues.get(fieldApiName), fieldApiName + ' must be cleared');
		}
		for (String fieldApiName : GoogleMetadataConfigService.AI_FEATURE_FLAG_FIELDS) {
			Assert.areEqual(false, savedValues.get(fieldApiName), fieldApiName + ' must be switched off');
		}
		Assert.isFalse(savedValues.containsKey('DefaultGoogleUploadFolderId__c'), 'Google Drive settings must stay untouched');
		Assert.isFalse(savedValues.containsKey('CustomGoogleServiceAccount__c'), 'Google Drive settings must stay untouched');
	}

	@IsTest
	private static void testDeactivateAiConfigDoesNotReapplyPromptDefaults() {
		GoogleCloudTestFactory.config()
			.asPackagedRecord()
			.withFileIntelligence(true)
			.withGeminiApiKey('api-key-1')
			.withAiModel('gemini-2.0-flash')
			.apply();
		CapturingDeployer deployer = new CapturingDeployer();

		Test.startTest();
		new GoogleMetadataConfigService(deployer).deactivateAiConfig();
		Test.stopTest();

		Map<String, Object> savedValues = deployer.capturedValues();
		Assert.isNull(savedValues.get('CustomSummaryPrompt__c'), 'Turning analysis off must not bring the shipped prompt back');
		Assert.isNull(savedValues.get('QuestionMaxOutputTokens__c'));
		Assert.isNull(savedValues.get('AiSafetyMode__c'));
	}

	@IsTest
	private static void testAdditionalUploadFoldersArePreservedInOrder() {
		GoogleCloudTestFactory.config()
			.withUploadFolderId('PRIMARY')
			.withAdditionalUploadFolderIds(' SECOND ;;THIRD; PRIMARY ')
			.apply();

		List<String> folderIds = new GoogleMetadataConfigService().getAllUploadFolderIds();

		Assert.areEqual(3, folderIds.size());
		Assert.areEqual('PRIMARY', folderIds[0]);
		Assert.areEqual('SECOND', folderIds[1]);
		Assert.areEqual('THIRD', folderIds[2]);
	}
}