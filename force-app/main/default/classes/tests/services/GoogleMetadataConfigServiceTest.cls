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
	private static final Id DEPLOY_JOB_ID = '0Af000000000003';
	private static final String PENDING_DEPLOY_STATUS = 'pending';

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

	private class DeployContextStub extends Metadata.DeployCallbackContext {
		private final Id deployJobId;

		private DeployContextStub(Id deployJobId) {
			this.deployJobId = deployJobId;
		}

		public override Id getCallbackJobId() {
			return this.deployJobId;
		}
	}

	private class DeployCallbackOutcome {
		private Boolean isCacheAvailable;
		private Integer unsavedLogEntriesBefore;
		private Integer unsavedLogEntriesAfter;
		private String deployStatus;
		private Exception failure;
	}

	private static GoogleCacheConfigService deployStatusCache() {
		return new GoogleCacheConfigService(new GoogleOrgCacheProvider(GoogleCacheConfigService.PARTITION));
	}

	private static Metadata.DeployResult deployResult(Metadata.DeployStatus status, String errorMessage, List<Metadata.DeployMessage> componentFailures) {
		Metadata.DeployResult result = new Metadata.DeployResult();
		result.status = status;
		result.errorMessage = errorMessage;
		if (componentFailures != null) {
			result.details = new Metadata.DeployDetails();
			result.details.componentFailures = componentFailures;
		}

		return result;
	}

	private static Metadata.DeployMessage componentFailure(String fullName, String problem) {
		Metadata.DeployMessage failure = new Metadata.DeployMessage();
		failure.fullName = fullName;
		failure.problem = problem;
		return failure;
	}

	private static DeployCallbackOutcome handleDeployResult(Metadata.DeployResult result) {
		DeployCallbackOutcome outcome = new DeployCallbackOutcome();
		GoogleCacheConfigService cache = deployStatusCache();
		String statusBefore = cache.get(GoogleMetadataConfigService.DEFAULT_METADATA_DEPLOY_KEY);
		cache.put(GoogleMetadataConfigService.DEFAULT_METADATA_DEPLOY_KEY, PENDING_DEPLOY_STATUS);
		outcome.isCacheAvailable = cache.get(GoogleMetadataConfigService.DEFAULT_METADATA_DEPLOY_KEY) == PENDING_DEPLOY_STATUS;
		Logger.info('Deploy callback test, an entry nobody saved yet').addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
		outcome.unsavedLogEntriesBefore = Logger.getBufferSize();

		Metadata.DeployCallback callback = new GoogleMetadataConfigService.DefaultMetadataCallback();
		try {
			callback.handleResult(result, new DeployContextStub(DEPLOY_JOB_ID));
		} catch (Exception ex) {
			outcome.failure = ex;
		}

		outcome.unsavedLogEntriesAfter = Logger.getBufferSize();
		outcome.deployStatus = cache.get(GoogleMetadataConfigService.DEFAULT_METADATA_DEPLOY_KEY);
		if (statusBefore == null) {
			cache.remove(GoogleMetadataConfigService.DEFAULT_METADATA_DEPLOY_KEY);
		} else {
			cache.put(GoogleMetadataConfigService.DEFAULT_METADATA_DEPLOY_KEY, statusBefore);
		}

		return outcome;
	}

	private static GoogleClientConfig__mdt buildConfig(Boolean isPreviewDisabled) {
		return new GoogleClientConfig__mdt(
			DeveloperName = 'GoogleClient',
			MasterLabel = 'Google Client',
			IsFilePreviewDisabled__c = isPreviewDisabled
		);
	}

	private static GoogleClientConfig__mdt buildSavedConfig(Datetime savedTime) {
		return (GoogleClientConfig__mdt) JSON.deserialize(JSON.serialize(new Map<String, Object>{
			'attributes' => new Map<String, Object>{ 'type' => 'GoogleClientConfig__mdt' },
			'DeveloperName' => 'GoogleClient',
			'MasterLabel' => 'Google Client',
			'SystemModstamp' => savedTime
		}), GoogleClientConfig__mdt.class);
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
		Id nullChangesDeploymentId = svc.saveConfig(null);
		Id emptyChangesDeploymentId = svc.saveConfig(new Map<String, Object>());
		Test.stopTest();

		Assert.isNull(nullChangesDeploymentId, 'With nothing to change no deployment is started');
		Assert.isNull(emptyChangesDeploymentId, 'With nothing to change no deployment is started');
	}

	@IsTest
	private static void testSaveConfigPositiveEnqueue() {
		GoogleMetadataConfigService.configRecordOverride = buildConfig(false);
		CapturingDeployer deployer = new CapturingDeployer();
		GoogleMetadataConfigService svc = new GoogleMetadataConfigService(deployer);

		Map<String, Object> changes = new Map<String, Object>{
			'DefaultGoogleUploadFolderId__c' => 'folder_123',
			'IsFilePreviewDisabled__c' => true
		};

		Test.startTest();
		Id deploymentId = svc.saveConfig(changes);
		Test.stopTest();

		Map<String, Object> savedValues = deployer.capturedValues();
		Assert.isNotNull(deploymentId, 'The deployment Id is handed back to follow');
		Assert.areEqual('folder_123', savedValues.get('DefaultGoogleUploadFolderId__c'));
		Assert.areEqual(true, savedValues.get('IsFilePreviewDisabled__c'));
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
		GoogleMetadataConfigService.resolvedConfigRecord = null;
		GSOQL.mock(GoogleClientConfigSelector.MOCK_ID).thenReturn(new List<GoogleClientConfig__mdt>());

		GoogleMetadataConfigService svc = new GoogleMetadataConfigService();
		GoogleMetadataConfigService.resolvedConfigRecord = null;

		Assert.isNotNull(svc.getConfig());
		Assert.isFalse(svc.hasConfigRecord());
		Assert.areEqual(GoogleMetadataConfigService.DEFAULT_AI_SAFETY_MODE, svc.getAiSafetyMode());
		Assert.areEqual(GoogleMetadataConfigService.DEFAULT_FILE_EXPLORER_COLUMNS.split(';').size(), svc.getFileExplorerColumns().size());
		Assert.areEqual(0, svc.getAllUploadFolderIds().size());
	}

	@IsTest
	private static void testGetLastSavedTimePositiveMovesWithEverySave() {
		GoogleMetadataConfigService.configRecordOverride = buildSavedConfig(Datetime.newInstanceGmt(2026, 11, 23, 5, 10, 36));
		Long savedTimeBeforeSave = new GoogleMetadataConfigService().getLastSavedTime();

		Datetime nextSave = Datetime.newInstanceGmt(2026, 11, 23, 5, 11, 28);
		GoogleMetadataConfigService.configRecordOverride = buildSavedConfig(nextSave);
		Long savedTimeAfterSave = new GoogleMetadataConfigService().getLastSavedTime();

		Assert.areEqual(nextSave.getTime(), savedTimeAfterSave, 'The saved time is the moment the record was last saved');
		Assert.areNotEqual(savedTimeBeforeSave, savedTimeAfterSave, 'A save that landed must show as a different saved time');
	}

	@IsTest
	private static void testGetLastSavedTimeNegativeNothingSaved() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt();
		Long savedTimeOnFreshInstall = new GoogleMetadataConfigService().getLastSavedTime();

		GoogleMetadataConfigService.configRecordOverride = buildConfig(false);
		Long savedTimeWithoutOne = new GoogleMetadataConfigService().getLastSavedTime();

		Assert.isNull(savedTimeOnFreshInstall, 'A fresh install has never been saved');
		Assert.isNull(savedTimeWithoutOne, 'A record that carries no saved time reads as never saved');
	}

	@IsTest
	private static void testGetLastSavedTimePositiveReadsTheRecordItQueried() {
		GoogleMetadataConfigService.configRecordOverride = null;
		GoogleMetadataConfigService.resolvedConfigRecord = null;

		GoogleMetadataConfigService svc = new GoogleMetadataConfigService();
		Long savedTime = svc.getLastSavedTime();
		GoogleMetadataConfigService.resolvedConfigRecord = null;

		Assert.areEqual(svc.hasConfigRecord(), savedTime != null, 'A saved record always carries the time it was saved, and an org without one has none');
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

		Assert.areEqual(new GoogleTransferLimitResolver().largeFileThresholdBytes(), svc.getBigFileSizeInBytes());
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
	private static void testGetDeleteChainSizePositiveZeroOrNegativeFallsBackToTheDefault() {
		GoogleCloudTestFactory.config().withDeleteChainSize(0).apply();
		Integer zeroChainSize = new GoogleMetadataConfigService().getDeleteChainSize();

		GoogleCloudTestFactory.config().withDeleteChainSize(-4).apply();
		Integer negativeChainSize = new GoogleMetadataConfigService().getDeleteChainSize();

		Assert.areEqual(GoogleMetadataConfigService.DEFAULT_MAX_DELETE_CHAIN_SIZE, zeroChainSize, 'A delete job that trashes nothing would chain itself forever');
		Assert.areEqual(GoogleMetadataConfigService.DEFAULT_MAX_DELETE_CHAIN_SIZE, negativeChainSize);
	}

	@IsTest
	private static void testGetDeleteChainSizePositiveAboveTheMaximumCountsAsTheMaximum() {
		GoogleCloudTestFactory.config().withDeleteChainSize(GoogleMetadataConfigService.MAX_DELETE_CHAIN_SIZE + 1).apply();
		Integer overMaximum = new GoogleMetadataConfigService().getDeleteChainSize();

		GoogleCloudTestFactory.config().withDeleteChainSize(GoogleMetadataConfigService.MAX_DELETE_CHAIN_SIZE).apply();
		Integer atMaximum = new GoogleMetadataConfigService().getDeleteChainSize();

		Assert.areEqual(GoogleMetadataConfigService.MAX_DELETE_CHAIN_SIZE, overMaximum, 'A job past the maximum would run out of callouts');
		Assert.areEqual(GoogleMetadataConfigService.MAX_DELETE_CHAIN_SIZE, atMaximum);
	}

	@IsTest
	private static void testGetBigFileSizeInBytesPositiveBlankFollowsTheHeapLimit() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt();
		GoogleMetadataConfigService svc = new GoogleMetadataConfigService();

		GoogleTransferLimitResolver.heapLimitOverride = 6000000;
		Assert.areEqual(GoogleMetadataConfigService.DEFAULT_BIG_FILE_SIZE, svc.getBigFileSizeInBytes(), 'An org whose heap did not grow keeps exactly the shipped size');

		GoogleTransferLimitResolver.heapLimitOverride = 10000000;
		Assert.areEqual(3670016L, svc.getBigFileSizeInBytes(), 'An org whose heap grew gets the larger size without any setting');
	}

	@IsTest
	private static void testGetBigFileSizeInBytesPositiveZeroMeansAutomatic() {
		GoogleTransferLimitResolver.heapLimitOverride = 10000000;
		GoogleCloudTestFactory.config().withBigFileSize(0L).apply();

		Assert.areEqual(3670016L, new GoogleMetadataConfigService().getBigFileSizeInBytes(), 'A cleared setting is stored as 0 and must behave like a blank one');
	}

	@IsTest
	private static void testGetBigFileSizeInBytesPositiveConfiguredValueWins() {
		GoogleTransferLimitResolver.heapLimitOverride = 10000000;
		GoogleCloudTestFactory.config().withBigFileSize(1000L).apply();

		Assert.areEqual(1000L, new GoogleMetadataConfigService().getBigFileSizeInBytes(), 'A size an administrator entered is never outgrown by the org');
	}

	@IsTest
	private static void testSaveConfigPositiveLeavesBlankBigFileSizeBlank() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(
			DeveloperName = 'GoogleClient',
			MasterLabel = 'Google Client'
		);
		CapturingDeployer deployer = new CapturingDeployer();

		Test.startTest();
		new GoogleMetadataConfigService(deployer).saveConfig(new Map<String, Object>{ 'OrganizationalDomain__c' => 'example.com' });
		Test.stopTest();

		Map<String, Object> savedValues = deployer.capturedValues();
		Assert.isFalse(savedValues.containsKey('DefaultBigFileSize__c'), 'A blank size means the org decides, so a save must not pin a number');
		Assert.areEqual(GoogleMetadataConfigService.DEFAULT_MAX_DELETE_CHAIN_SIZE, savedValues.get('MaxDeleteChainSize__c'), 'The other blank numbers still receive their defaults');
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
		new GoogleMetadataConfigService(deployer).saveConfig(new Map<String, Object>{ 'OrganizationalDomain__c' => 'astertrail.com' });
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

	private static Integer toWholeNumber(Object savedValue) {
		return savedValue == null ? null : Decimal.valueOf(String.valueOf(savedValue)).intValue();
	}

	private static GoogleClientConfig__mdt buildUpgradedAiConfig() {
		return new GoogleClientConfig__mdt(
			DeveloperName = 'GoogleClient',
			MasterLabel = 'Google Client',
			IsFileIntelligenceEnabled__c = true,
			CustomAgentProjectId__c = 'project-1',
			CustomAgentLocation__c = 'global',
			CustomModelName__c = 'gemini-3.8-flash',
			CustomSummaryPrompt__c = GoogleMetadataConfigService.DEFAULT_SUMMARY_PROMPT,
			QuestionMaxOutputTokens__c = 1024
		);
	}

	@IsTest
	private static void testGetSummaryMaxOutputTokensPositiveBlankMeansDefault() {
		GoogleMetadataConfigService.configRecordOverride = buildUpgradedAiConfig();

		Assert.areEqual(80, GoogleMetadataConfigService.DEFAULT_SUMMARY_MAX_OUTPUT_TOKENS);
		Assert.areEqual(GoogleMetadataConfigService.DEFAULT_SUMMARY_MAX_OUTPUT_TOKENS, new GoogleMetadataConfigService().getSummaryMaxOutputTokens(), 'An org upgraded with AI already set up has the new field blank and keeps today\'s summary length');
	}

	@IsTest
	private static void testGetSummaryMaxOutputTokensPositiveFreshInstallMeansDefault() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt();

		Assert.areEqual(GoogleMetadataConfigService.DEFAULT_SUMMARY_MAX_OUTPUT_TOKENS, new GoogleMetadataConfigService().getSummaryMaxOutputTokens());
	}

	@IsTest
	private static void testGetSummaryMaxOutputTokensPositiveZeroMeansNoLimit() {
		GoogleClientConfig__mdt config = buildUpgradedAiConfig();
		config.SummaryMaxOutputTokens__c = 0;
		GoogleMetadataConfigService.configRecordOverride = config;

		Assert.areEqual(0, GoogleMetadataConfigService.UNLIMITED_OUTPUT_TOKENS);
		Assert.areEqual(GoogleMetadataConfigService.UNLIMITED_OUTPUT_TOKENS, new GoogleMetadataConfigService().getSummaryMaxOutputTokens(), 'A saved 0 is No limit and must not fall back to the default');
	}

	@IsTest
	private static void testGetSummaryMaxOutputTokensPositiveNegativeMeansDefault() {
		GoogleClientConfig__mdt config = buildUpgradedAiConfig();
		config.SummaryMaxOutputTokens__c = -5;
		GoogleMetadataConfigService.configRecordOverride = config;

		Assert.areEqual(GoogleMetadataConfigService.DEFAULT_SUMMARY_MAX_OUTPUT_TOKENS, new GoogleMetadataConfigService().getSummaryMaxOutputTokens());
	}

	@IsTest
	private static void testGetSummaryMaxOutputTokensPositiveConfiguredValue() {
		GoogleClientConfig__mdt config = buildUpgradedAiConfig();
		config.SummaryMaxOutputTokens__c = 200;
		GoogleMetadataConfigService.configRecordOverride = config;

		Assert.areEqual(200, new GoogleMetadataConfigService().getSummaryMaxOutputTokens());
	}

	@IsTest
	private static void testGetQuestionMaxOutputTokensPositiveZeroMeansNoLimit() {
		GoogleCloudTestFactory.config().withQuestionMaxOutputTokens(0).apply();

		Assert.areEqual(GoogleMetadataConfigService.UNLIMITED_OUTPUT_TOKENS, new GoogleMetadataConfigService().getQuestionMaxOutputTokens());
	}

	@IsTest
	private static void testGetQuestionMaxOutputTokensPositiveNegativeMeansDefault() {
		GoogleCloudTestFactory.config().withQuestionMaxOutputTokens(-5).apply();

		Assert.areEqual(GoogleMetadataConfigService.DEFAULT_QUESTION_MAX_OUTPUT_TOKENS, new GoogleMetadataConfigService().getQuestionMaxOutputTokens(), 'Only 0 means No limit; any other value below it means the default');
	}

	@IsTest
	private static void testSaveConfigPositiveFillsSummaryLimitWhenAiIsOn() {
		GoogleMetadataConfigService.configRecordOverride = buildUpgradedAiConfig();
		CapturingDeployer deployer = new CapturingDeployer();

		Test.startTest();
		new GoogleMetadataConfigService(deployer).saveConfig(new Map<String, Object>{ 'OrganizationalDomain__c' => 'astertrail.com' });
		Test.stopTest();

		Map<String, Object> savedValues = deployer.capturedValues();
		Assert.isTrue(savedValues.containsKey('SummaryMaxOutputTokens__c'), 'A save with AI on writes the default into the blank field, as it does for questions');
		Assert.areEqual(GoogleMetadataConfigService.DEFAULT_SUMMARY_MAX_OUTPUT_TOKENS, toWholeNumber(savedValues.get('SummaryMaxOutputTokens__c')));
	}

	@IsTest
	private static void testSaveConfigPositiveKeepsZeroLimitsForSummaryAndQuestions() {
		GoogleMetadataConfigService.configRecordOverride = buildUpgradedAiConfig();
		CapturingDeployer deployer = new CapturingDeployer();

		Test.startTest();
		new GoogleMetadataConfigService(deployer).saveConfig(new Map<String, Object>{
			'SummaryMaxOutputTokens__c' => 0,
			'QuestionMaxOutputTokens__c' => 0
		});
		Test.stopTest();

		Map<String, Object> savedValues = deployer.capturedValues();
		Assert.areEqual(0, toWholeNumber(savedValues.get('SummaryMaxOutputTokens__c')), 'No limit must survive the save rather than be replaced by the default');
		Assert.areEqual(0, toWholeNumber(savedValues.get('QuestionMaxOutputTokens__c')));
	}

	@IsTest
	private static void testSaveConfigPositiveLeavesSummaryLimitAloneWhileAiIsOff() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(
			DeveloperName = 'GoogleClient',
			MasterLabel = 'Google Client'
		);
		CapturingDeployer deployer = new CapturingDeployer();

		Test.startTest();
		new GoogleMetadataConfigService(deployer).saveConfig(new Map<String, Object>{ 'OrganizationalDomain__c' => 'astertrail.com' });
		Test.stopTest();

		Assert.isFalse(deployer.capturedValues().containsKey('SummaryMaxOutputTokens__c'), 'An org without AI must not have AI settings written for it');
	}

	@IsTest
	private static void testDeactivateAiConfigPositiveClearsSummaryLimit() {
		GoogleClientConfig__mdt config = buildUpgradedAiConfig();
		config.SummaryMaxOutputTokens__c = 0;
		GoogleMetadataConfigService.configRecordOverride = config;
		CapturingDeployer deployer = new CapturingDeployer();

		Test.startTest();
		new GoogleMetadataConfigService(deployer).deactivateAiConfig();
		Test.stopTest();

		Map<String, Object> savedValues = deployer.capturedValues();
		Assert.isTrue(GoogleMetadataConfigService.AI_CONFIGURATION_FIELDS.contains('SummaryMaxOutputTokens__c'));
		Assert.isTrue(savedValues.containsKey('SummaryMaxOutputTokens__c'));
		Assert.isNull(savedValues.get('SummaryMaxOutputTokens__c'));
	}

	private static String patternRowsJson(List<List<String>> objectAndPatternPairs) {
		List<Map<String, String>> rows = new List<Map<String, String>>();
		for (List<String> pair : objectAndPatternPairs) {
			rows.add(new Map<String, String>{ 'objectApiName' => pair[0], 'pattern' => pair[1] });
		}

		return JSON.serialize(rows);
	}

	@IsTest
	private static void testIsFolderRenameEnabledNegativeBlankIsOff() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt();

		Assert.isFalse(new GoogleMetadataConfigService().isFolderRenameEnabled(), 'An upgraded org renames nothing until an administrator switches renaming on');
	}

	@IsTest
	private static void testIsFolderRenameEnabledPositiveReadsTheSwitch() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(IsFolderRenameEnabled__c = true);

		Assert.isTrue(new GoogleMetadataConfigService().isFolderRenameEnabled());
	}

	@IsTest
	private static void testGetRecordFolderNamePatternsPositiveBlankIsEmpty() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt();

		List<GoogleRecordFolderNamePatternDTO> patterns = new GoogleMetadataConfigService().getRecordFolderNamePatterns();

		Assert.isTrue(patterns == null || patterns.isEmpty(), 'Blank means today\'s names for every object');
	}

	@IsTest
	private static void testGetRecordFolderNamePatternsPositiveReadsCompleteRows() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(RecordFolderNamePatterns__c = patternRowsJson(new List<List<String>>{
			new List<String>{ 'GoogleFile__c', 'Name & " - " & TEXT(Source__c)' },
			new List<String>{ 'User', 'LastName & ", " & FirstName' }
		}));

		List<GoogleRecordFolderNamePatternDTO> patterns = new GoogleMetadataConfigService().getRecordFolderNamePatterns();

		Assert.areEqual(2, patterns.size());
		Assert.areEqual('GoogleFile__c', patterns[0].objectApiName);
		Assert.areEqual('Name & " - " & TEXT(Source__c)', patterns[0].pattern, 'A formula keeps its quotes through the stored JSON');
		Assert.areEqual('User', patterns[1].objectApiName);
	}

	@IsTest
	private static void testGetRecordFolderNamePatternsNegativeDropsIncompleteDuplicateAndUnknownRows() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(RecordFolderNamePatterns__c = patternRowsJson(new List<List<String>>{
			new List<String>{ 'GoogleFile__c', 'Name' },
			new List<String>{ '', 'Name' },
			new List<String>{ 'GoogleFileVersion__c', '  ' },
			new List<String>{ 'googlefile__c', 'Name & " again"' },
			new List<String>{ 'NoSuchObject__c', 'Name' },
			new List<String>{ 'User', 'LastName' }
		}));

		List<GoogleRecordFolderNamePatternDTO> patterns = new GoogleMetadataConfigService().getRecordFolderNamePatterns();

		Assert.areEqual(2, patterns.size(), 'Incomplete, duplicate and unknown rows are dropped rather than stopping uploads');
		Assert.areEqual('GoogleFile__c', patterns[0].objectApiName);
		Assert.areEqual('Name', patterns[0].pattern, 'The first row for an object wins');
		Assert.areEqual('User', patterns[1].objectApiName);
	}

	@IsTest
	private static void testGetRecordFolderNamePatternsNegativeUnreadableTextIsIgnored() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(RecordFolderNamePatterns__c = 'not json at all');

		Exception readFailure;
		List<GoogleRecordFolderNamePatternDTO> patterns;
		try {
			patterns = new GoogleMetadataConfigService().getRecordFolderNamePatterns();
		} catch (Exception ex) {
			readFailure = ex;
		}

		Assert.isNull(readFailure, 'A bad save never stops uploads');
		Assert.isTrue(patterns == null || patterns.isEmpty());
	}

	@IsTest
	private static void testGetRecordFolderNamePatternsPositiveStopsAtFifty() {
		List<String> objectApiNames = new List<String>();
		for (Schema.SObjectType objectType : Schema.getGlobalDescribe().values()) {
			objectApiNames.add(objectType.getDescribe().getName());
			if (objectApiNames.size() > 50) break;
		}
		List<List<String>> pairs = new List<List<String>>();
		for (String objectApiName : objectApiNames) {
			pairs.add(new List<String>{ objectApiName, 'Name' });
		}
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(RecordFolderNamePatterns__c = patternRowsJson(pairs));

		List<GoogleRecordFolderNamePatternDTO> patterns = new GoogleMetadataConfigService().getRecordFolderNamePatterns();

		Assert.areEqual(51, objectApiNames.size());
		Assert.areEqual(50, patterns.size(), 'Up to fifty objects can have a pattern');
		Assert.areEqual(objectApiNames[0], patterns[0].objectApiName, 'Rows keep their saved order');
	}

	@IsTest
	private static void testGetRecordFolderNamePatternsPositiveReadsLongTextInFull() {
		GoogleMetadataConfigService.configRecordOverride = null;
		GoogleMetadataConfigService.resolvedConfigRecord = null;
		String longPattern = 'Name & "' + 'x'.repeat(300) + '"';
		GSOQL.mock(GoogleClientConfigSelector.MOCK_ID).thenReturn(new List<GoogleClientConfig__mdt>{
			new GoogleClientConfig__mdt(DeveloperName = 'GoogleClient', RecordFolderNamePatterns__c = patternRowsJson(new List<List<String>>{
				new List<String>{ 'GoogleFile__c', longPattern },
				new List<String>{ 'User', 'LastName' }
			}))
		});

		List<GoogleRecordFolderNamePatternDTO> patterns = new GoogleMetadataConfigService().getRecordFolderNamePatterns();
		GoogleMetadataConfigService.resolvedConfigRecord = null;

		Assert.areEqual(2, patterns.size(), 'Patterns past 255 characters are read whole, never cut by the metadata cache');
		Assert.areEqual(longPattern, patterns[0].pattern);
	}

	@IsTest
	private static void testGetWorkspaceCopyFolderIdPositiveTrimsAndBlankIsNull() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(WorkspaceCopyFolderId__c = '  COPIES_FOLDER_01  ');
		Assert.areEqual('COPIES_FOLDER_01', new GoogleMetadataConfigService().getWorkspaceCopyFolderId());

		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(WorkspaceCopyFolderId__c = '   ');
		Assert.isNull(new GoogleMetadataConfigService().getWorkspaceCopyFolderId(), 'Blank means copies beside the originals');

		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt();
		Assert.isNull(new GoogleMetadataConfigService().getWorkspaceCopyFolderId());
	}

	@IsTest
	private static void testSaveConfigPositiveFillsTheRenameSwitchWhenMissing() {
		GoogleClientConfig__mdt storedConfig = new GoogleClientConfig__mdt(
			DeveloperName = 'GoogleClient',
			MasterLabel = 'Google Client'
		);
		GoogleMetadataConfigService.configRecordOverride = storedConfig;
		CapturingDeployer deployer = new CapturingDeployer();

		Test.startTest();
		new GoogleMetadataConfigService(deployer).saveConfig(new Map<String, Object>{ 'OrganizationalDomain__c' => 'astertrail.com' });
		Test.stopTest();

		Map<String, Object> savedValues = deployer.capturedValues();
		Object switchAfterSave = savedValues.containsKey('IsFolderRenameEnabled__c') ? savedValues.get('IsFolderRenameEnabled__c') : storedConfig.IsFolderRenameEnabled__c;
		Assert.areEqual(false, switchAfterSave, 'A missing switch is saved as off, like the other switches');
		Assert.areEqual(false, GoogleClientConfig__mdt.IsFolderRenameEnabled__c.getDescribe().getDefaultValue(), 'An org that never saved the switch reads it as off');
	}

	@IsTest
	private static void testDeactivateAiConfigPositiveLeavesFolderSettingsAlone() {
		GoogleClientConfig__mdt config = buildUpgradedAiConfig();
		config.IsFolderRenameEnabled__c = true;
		config.RecordFolderNamePatterns__c = patternRowsJson(new List<List<String>>{ new List<String>{ 'GoogleFile__c', 'Name' } });
		config.WorkspaceCopyFolderId__c = 'COPIES_FOLDER_01';
		GoogleMetadataConfigService.configRecordOverride = config;
		CapturingDeployer deployer = new CapturingDeployer();

		Test.startTest();
		new GoogleMetadataConfigService(deployer).deactivateAiConfig();
		Test.stopTest();

		Map<String, Object> savedValues = deployer.capturedValues();
		Assert.isFalse(savedValues.containsKey('IsFolderRenameEnabled__c'), 'Deactivating AI touches no folder setting');
		Assert.isFalse(savedValues.containsKey('RecordFolderNamePatterns__c'));
		Assert.isFalse(savedValues.containsKey('WorkspaceCopyFolderId__c'));
	}

	@IsTest
	private static void testDeactivateAiConfigPositiveSavesNoLogOnSuccess() {
		GoogleMetadataConfigService.configRecordOverride = buildUpgradedAiConfig();
		CapturingDeployer deployer = new CapturingDeployer();

		Test.startTest();
		new GoogleMetadataConfigService(deployer).deactivateAiConfig();
		Integer unsavedLogEntries = Logger.getBufferSize();
		Test.stopTest();

		Assert.isTrue(unsavedLogEntries > 0, 'A deactivation that worked is not saved to the log');
	}

	@IsTest
	private static void testDeployCallbackPositiveSuccessMarksTheSaveDoneAndSavesNoLog() {
		Test.startTest();
		DeployCallbackOutcome outcome = handleDeployResult(deployResult(Metadata.DeployStatus.Succeeded, null, null));
		Test.stopTest();

		Assert.isNull(outcome.failure, 'The deploy callback never throws');
		if (outcome.isCacheAvailable) {
			Assert.areEqual('success', outcome.deployStatus, 'The setup page reads a finished save from the deploy key');
		} else {
			Assert.isNull(outcome.deployStatus, 'Without platform cache nothing is stored');
		}
		Assert.areEqual(outcome.unsavedLogEntriesBefore, outcome.unsavedLogEntriesAfter, 'A save that worked writes nothing to the log and saves nothing');
	}

	@IsTest
	private static void testDeployCallbackNegativeFailureMarksTheSaveFailedAndSavesTheLog() {
		Metadata.DeployResult result = deployResult(
			Metadata.DeployStatus.Failed,
			'Deployment failed',
			new List<Metadata.DeployMessage>{
				componentFailure('GoogleClientConfig__mdt.GoogleClient', 'invalid number: '),
				componentFailure('GoogleClientConfig__mdt.GoogleClient', 'Value too long for field: CustomSummaryPrompt__c')
			}
		);

		Test.startTest();
		DeployCallbackOutcome outcome = handleDeployResult(result);
		Test.stopTest();

		Assert.isNull(outcome.failure, 'The deploy callback never throws, whatever the deploy answered');
		if (outcome.isCacheAvailable) {
			Assert.areEqual('fail', outcome.deployStatus, 'The setup page reads a failed save from the deploy key');
		} else {
			Assert.isNull(outcome.deployStatus, 'Without platform cache nothing is stored');
		}
		Assert.isTrue(outcome.unsavedLogEntriesBefore > 0);
		Assert.areEqual(0, outcome.unsavedLogEntriesAfter, 'A failed save is saved to the log, so its reason can be read later');
	}

	@IsTest
	private static void testDeployCallbackNegativeFailureWithoutAReasonStillSavesTheLog() {
		Test.startTest();
		DeployCallbackOutcome withoutDetails = handleDeployResult(deployResult(Metadata.DeployStatus.Failed, null, null));
		DeployCallbackOutcome withEmptyDetails = handleDeployResult(deployResult(Metadata.DeployStatus.Failed, ' ', new List<Metadata.DeployMessage>()));
		Test.stopTest();

		for (DeployCallbackOutcome outcome : new List<DeployCallbackOutcome>{ withoutDetails, withEmptyDetails }) {
			Assert.isNull(outcome.failure, 'A deploy that gives no reason never makes the callback throw');
			if (outcome.isCacheAvailable) {
				Assert.areEqual('fail', outcome.deployStatus, 'A failed deploy reads as a failed save whatever it said');
			} else {
				Assert.isNull(outcome.deployStatus, 'Without platform cache nothing is stored');
			}
			Assert.isTrue(outcome.unsavedLogEntriesBefore > 0);
			Assert.areEqual(0, outcome.unsavedLogEntriesAfter, 'A failed save is saved to the log even when the deploy gave no reason');
		}
	}
}