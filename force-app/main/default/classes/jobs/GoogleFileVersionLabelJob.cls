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
public with sharing class GoogleFileVersionLabelJob extends GQueueableJob.AllowsCallouts {
	public class GoogleFileVersionLabelJobException extends Exception {}

	@TestVisible
	private static Boolean skipExecution = false;

	@TestVisible
	private static Map<Id, GoogleFileLabelResultDTO> testResultsByVersionId = new Map<Id, GoogleFileLabelResultDTO>();

	private final Set<Id> versionIds;
	private final Map<Id, GoogleFileLabelResultDTO> capturedTestResultsByVersionId;

	public GoogleFileVersionLabelJob(Set<Id> versionIds) {
		this.versionIds = versionIds == null ? new Set<Id>() : new Set<Id>(versionIds);
		this.capturedTestResultsByVersionId = captureTestResultsByVersionId();
	}

	public override GQueueableJob cloneForDeepCopy() {
		return (GQueueableJob) JSON.deserialize(JSON.serialize(this), GoogleFileVersionLabelJob.class);
	}

	public override void work() {
		if (skipExecution) return;
		if (this.versionIds.isEmpty()) return;

		Logger.info('Queueable Job to assign labels for: ' + String.join(this.versionIds, ', ')).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

		IGoogleFileLabelingStrategy labelingStrategy = null;
		if (this.capturedTestResultsByVersionId.isEmpty()) {
			GoogleFileIntelligenceFactory intelligenceFactory = new GoogleFileIntelligenceFactory();
			if (!intelligenceFactory.isLabelingConfigured()) {
				Logger.info('File Label Job Skipped --> AI labeling is not configured for: ' + String.join(this.versionIds, ', ')).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
				Logger.saveLog();
				return;
			}

			try {
				labelingStrategy = intelligenceFactory.createForLabeling();
			} catch (Exception ex) {
				Logger.error('File Label Job Failed --> Labeling strategy unavailable, Message=' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
				Logger.saveLog();
				return;
			}
		}

		IGoogleUnitOfWork uow = new GoogleCloudUnitOfWork(GoogleCloudConstants.DEFAULT_WRITE_ORDER);
		Boolean hasUpdates = false;

		for (Id versionId : this.versionIds) {
			if (versionId == null) continue;

			try {
				GoogleFileLabelResultDTO labelResult = resolveLabelResult(versionId, labelingStrategy);
				if (labelResult == null || labelResult.blocked == true) continue;

				if (labelResult.applied == true && String.isNotBlank(labelResult.labelName)) {
					uow.registerNew(new GoogleFileVersionLabel__c(
						Name = labelResult.labelName,
						GoogleFileVersionId__c = versionId,
						GoogleDriveLabelId__c = labelResult.labelId,
						Confidence__c = labelResult.confidence
					));

					hasUpdates = true;
					continue;
				}

				if (labelResult.success == true && String.isBlank(labelResult.errorMessage)) {
					Logger.info(buildUnlabeledMessage(versionId, labelResult)).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
					Logger.saveLog();
					continue;
				}

				Logger.error(buildSkippedLabelMessage(versionId, labelResult)).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
				Logger.saveLog();
			} catch (Exception ex) {
				Logger.error('File Label Job Failed --> VersionId=' + versionId + ', Message=' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
				Logger.saveLog();
			}
		}

		if (!hasUpdates) return;

		try {
			uow.commitWork(true);
		} catch (Exception ex) {
			Logger.error('Google File Label update failed (Local): ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw new GoogleFileVersionLabelJobException('Unable to save assigned document labels. Please try again or contact your system administrator');
		}
	}

	@TestVisible
	private static void setTestResult(Id versionId, GoogleFileLabelResultDTO testResult) {
		if (versionId == null || testResult == null) return;
		testResultsByVersionId.put(versionId, testResult);
	}

	@TestVisible
	private static void clearTestResults() {
		testResultsByVersionId.clear();
	}

	private Map<Id, GoogleFileLabelResultDTO> captureTestResultsByVersionId() {
		if (testResultsByVersionId == null || testResultsByVersionId.isEmpty()) {
			return new Map<Id, GoogleFileLabelResultDTO>();
		}

		return new Map<Id, GoogleFileLabelResultDTO>(testResultsByVersionId);
	}

	private GoogleFileLabelResultDTO resolveLabelResult(Id versionId, IGoogleFileLabelingStrategy labelingStrategy) {
		if (this.capturedTestResultsByVersionId.containsKey(versionId)) {
			return this.capturedTestResultsByVersionId.get(versionId);
		}

		return labelingStrategy == null ? null : labelingStrategy.label(versionId);
	}

	private String buildUnlabeledMessage(Id versionId, GoogleFileLabelResultDTO labelResult) {
		return 'File Label Not Assigned --> VersionId=' + String.valueOf(versionId)
			+ ', Provider=' + String.valueOf(labelResult.provider)
			+ ', SuggestedLabel=' + String.valueOf(labelResult.labelName)
			+ ', Confidence=' + String.valueOf(labelResult.confidence);
	}

	private String buildSkippedLabelMessage(Id versionId, GoogleFileLabelResultDTO labelResult) {
		return 'File Label Skipped --> VersionId=' + String.valueOf(versionId)
			+ ', Provider=' + String.valueOf(labelResult.provider)
			+ ', FinishReason=' + String.valueOf(labelResult.finishReason)
			+ ', Message=' + String.valueOf(labelResult.errorMessage);
	}
}
