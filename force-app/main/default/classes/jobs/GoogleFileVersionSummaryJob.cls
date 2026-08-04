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
public with sharing class GoogleFileVersionSummaryJob extends GQueueableJob.AllowsCallouts {
	public class GoogleFileVersionSummaryJobException extends Exception {}

	@TestVisible
	private static Boolean skipExecution = false;

	@TestVisible
	private static Map<Id, GoogleFileAnalysisResultDTO> testResultsByVersionId = new Map<Id, GoogleFileAnalysisResultDTO>();

	private final Set<Id> versionIds;
	private final Map<Id, GoogleFileAnalysisResultDTO> capturedTestResultsByVersionId;

	public GoogleFileVersionSummaryJob(Set<Id> versionIds) {
		this.versionIds = versionIds == null ? new Set<Id>() : new Set<Id>(versionIds);
		this.capturedTestResultsByVersionId = captureTestResultsByVersionId();
	}

	public override GQueueableJob cloneForDeepCopy() {
		return (GQueueableJob) JSON.deserialize(JSON.serialize(this), GoogleFileVersionSummaryJob.class);
	}

	public override void work() {
		if (skipExecution) return;
		if (this.versionIds.isEmpty()) return;

		Logger.info('Queueable Job to generate summaries for: ' + String.join(this.versionIds, ', ')).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

		IGoogleFileIntelligenceStrategy intelligenceStrategy = null;
		if (this.capturedTestResultsByVersionId.isEmpty()) {
			try {
				intelligenceStrategy = new GoogleFileIntelligenceFactory().create();
			} catch (Exception ex) {
				return;
			}
		}

		IGoogleUnitOfWork uow = new GoogleCloudUnitOfWork(GoogleCloudConstants.DEFAULT_WRITE_ORDER);
		
		Boolean hasUpdates = false;

		for (Id versionId : this.versionIds) {
			if (versionId == null) continue;

			try {
				GoogleFileAnalysisResultDTO summaryResult = resolveSummaryResult(versionId, intelligenceStrategy);
				if (summaryResult == null || summaryResult.blocked == true) continue;
				
				if (summaryResult.success == true && String.isNotBlank(summaryResult.text)) {
					uow.registerDirty(new GoogleFileVersion__c(
						Id = versionId,
						Summary__c = summaryResult.text
					));

					hasUpdates = true;
					continue;
				}

				Logger.error(buildSkippedSummaryMessage(versionId, summaryResult)).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
				Logger.saveLog();
			} catch (Exception ex) {
				Logger.error('File Summary Job Failed --> VersionId=' + versionId + ', Message=' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
				Logger.saveLog();
			}
		}

		if (!hasUpdates) return;

		try {
			uow.commitWork(true);
		} catch (Exception ex) {
			Logger.error('Google File Summary update failed (Local): ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw new GoogleFileVersionSummaryJobException('Unable to save generated document summaries. Please try again or contact your system administrator');
		}
	}

	@TestVisible
	private static void setTestResult(Id versionId, GoogleFileAnalysisResultDTO testResult) {
		if (versionId == null || testResult == null) return;
		testResultsByVersionId.put(versionId, testResult);
	}

	@TestVisible
	private static void clearTestResults() {
		testResultsByVersionId.clear();
	}

	private Map<Id, GoogleFileAnalysisResultDTO> captureTestResultsByVersionId() {
		if (testResultsByVersionId == null || testResultsByVersionId.isEmpty()) {
			return new Map<Id, GoogleFileAnalysisResultDTO>();
		}

		return new Map<Id, GoogleFileAnalysisResultDTO>(testResultsByVersionId);
	}

	private GoogleFileAnalysisResultDTO resolveSummaryResult(Id versionId, IGoogleFileIntelligenceStrategy intelligenceStrategy) {
		if (this.capturedTestResultsByVersionId.containsKey(versionId)) {
			return this.capturedTestResultsByVersionId.get(versionId);
		}

		return intelligenceStrategy == null ? null : intelligenceStrategy.summarize(versionId);
	}

	private String buildSkippedSummaryMessage(Id versionId, GoogleFileAnalysisResultDTO summaryResult) {
		return 'File Summary Skipped --> VersionId=' + String.valueOf(versionId)
			+ ', Provider=' + String.valueOf(summaryResult == null ? null : summaryResult.provider)
			+ ', FinishReason=' + String.valueOf(summaryResult == null ? null : summaryResult.finishReason)
			+ ', Message=' + String.valueOf(summaryResult == null ? null : summaryResult.errorMessage);
	}
}