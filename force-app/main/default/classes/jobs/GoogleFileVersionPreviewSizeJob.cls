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
 * Measures the Google Workspace copy a moment after it was made. Drive answers with a placeholder size
 * until the conversion is really finished, so this waits a minute, asks again, and tries up to three
 * times before leaving the size blank. A blank one simply means previews and AI analysis fall back to
 * judging by the uploaded size. This is the first moment the copy size is known, so a version whose copy
 * fits the analysis limit while its upload did not gets its summary and label chained from here.
 */
public with sharing class GoogleFileVersionPreviewSizeJob extends GQueueableJob.AllowsCallouts {
	public class GoogleFilePreviewSizeJobException extends Exception {}

	private static final Integer FIRST_MEASUREMENT_ATTEMPT = 1;
	private static final Integer MAX_MEASUREMENT_ATTEMPTS = 3;
	private static final Integer MEASUREMENT_DELAY_MINUTES = 1;
	private static final Long CONVERSION_PENDING_SIZE_BYTES = 1L;
	private static final String PREVIEW_SIZE_FIELDS = 'id, size';

	@TestVisible
	private static Boolean skipExecution = false;

	private final Set<Id> versionIds;
	private final Integer measurementAttempt;
	private final Boolean chainIntelligence;

	/**
	 * Builds the job for a first attempt.
	 *
	 * @param versionIds The versions whose Workspace copy should be measured.
	 */
	public GoogleFileVersionPreviewSizeJob(Set<Id> versionIds) {
		this(versionIds, FIRST_MEASUREMENT_ATTEMPT);
	}

	/**
	 * Builds the job for a later attempt.
	 *
	 * @param versionIds The versions still to measure.
	 * @param measurementAttempt Which attempt this is, counting from one.
	 */
	public GoogleFileVersionPreviewSizeJob(Set<Id> versionIds, Integer measurementAttempt) {
		this(versionIds, measurementAttempt, true);
	}

	private GoogleFileVersionPreviewSizeJob(Set<Id> versionIds, Integer measurementAttempt, Boolean chainIntelligence) {
		this.versionIds = versionIds == null
			? new Set<Id>()
			: new Set<Id>(versionIds);
		this.measurementAttempt = measurementAttempt == null || measurementAttempt < FIRST_MEASUREMENT_ATTEMPT
			? FIRST_MEASUREMENT_ATTEMPT
			: measurementAttempt;
		this.chainIntelligence = chainIntelligence != false;
	}

	/**
	 * Queues the measurement a minute out, which is the normal way to start it.
	 *
	 * @param versionIds The versions to measure.
	 */
	public static void schedule(Set<Id> versionIds) {
		schedule(versionIds, true);
	}

	/**
	 * Queues the measurement a minute out and carries the caller's decision on AI analysis through every
	 * attempt, since each one runs in a later transaction.
	 *
	 * @param versionIds The versions to measure.
	 * @param chainIntelligence False to measure only, without the summary and label a fitting copy would
	 * otherwise get. Null counts as true.
	 */
	public static void schedule(Set<Id> versionIds, Boolean chainIntelligence) {
		schedule(versionIds, FIRST_MEASUREMENT_ATTEMPT, chainIntelligence);
	}

	/**
	 * Reads the size of each Workspace copy, stores the ones Drive has finished converting and reschedules
	 * for the rest. A stored size that admits a version to AI analysis chains its summary and label ahead of
	 * the next attempt; when nothing is admitted, or AI is not configured, nothing extra is queued.
	 */
	public override void work() {
		if (skipExecution) return;
		if (this.versionIds.isEmpty()) return;

		Logger.info('Queueable Job to measure Google Workspace previews for: ' + String.join(this.versionIds, ', ') + ', Attempt=' + String.valueOf(this.measurementAttempt)).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

		List<GoogleFileVersion__c> localFileVersions = (List<GoogleFileVersion__c>) GoogleFileVersionSelector.query()
			.withAdvancedFields()
			.byIds(this.versionIds)
			.toList();

		IGoogleUnitOfWork uow = new GoogleCloudUnitOfWork(GoogleCloudConstants.DEFAULT_WRITE_ORDER);
		GoogleClientApiProvider remoteFileService = new GoogleClientApiProvider();
		Set<Id> unmeasuredVersionIds = new Set<Id>();
		List<GoogleFileVersion__c> measuredVersions = new List<GoogleFileVersion__c>();

		for (GoogleFileVersion__c localFileVersion : localFileVersions) {
			if (String.isBlank(localFileVersion.GoogleDocsFileId__c) || localFileVersion.GoogleDocsFileSize__c != null) continue;

			Long previewSizeInBytes = measurePreviewSize(remoteFileService, localFileVersion);
			if (previewSizeInBytes == null) {
				unmeasuredVersionIds.add(localFileVersion.Id);
				continue;
			}

			uow.registerDirty(new GoogleFileVersion__c(
				Id = localFileVersion.Id,
				GoogleDocsFileSize__c = previewSizeInBytes
			));
			localFileVersion.GoogleDocsFileSize__c = previewSizeInBytes;
			measuredVersions.add(localFileVersion);
		}

		if (!measuredVersions.isEmpty() && commitMeasuredSizes(uow)) {
			chainAnalysisAdmittedByWorkspaceCopy(measuredVersions);
		}

		rescheduleUnmeasured(unmeasuredVersionIds);
	}

	private Long measurePreviewSize(GoogleClientApiProvider remoteFileService, GoogleFileVersion__c localFileVersion) {
		try {
			GoogleDrive remoteGoogleDrive = remoteFileService.retrieveGoogleDriveClient();
			GoogleFileEntity previewFile = remoteGoogleDrive.files().retrieve().download(localFileVersion.GoogleDocsFileId__c)
				.setFileDownloadType(GoogleDownloadFileBuilder.DownloadType.METADATA)
				.setSearchOnAllDrives(true)
				.setFields(PREVIEW_SIZE_FIELDS)
				.execute();

			return resolveMeasuredSize(previewFile);
		} catch (Exception ex) {
			Logger.error('Preview Size Measurement Failed --> VersionId=' + String.valueOf(localFileVersion.Id) + ', GoogleDocsFileId=' + localFileVersion.GoogleDocsFileId__c + ', Message=' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			return null;
		}
	}

	private Long resolveMeasuredSize(GoogleFileEntity previewFile) {
		if (previewFile == null || String.isBlank(previewFile.size) || !previewFile.size.isNumeric()) return null;

		Long sizeInBytes = Long.valueOf(previewFile.size);
		return sizeInBytes > CONVERSION_PENDING_SIZE_BYTES ? sizeInBytes : null;
	}

	private Boolean commitMeasuredSizes(IGoogleUnitOfWork uow) {
		try {
			GTriggerHandler.setBypass('GoogleFileVersionTriggerHandler', true);
			uow.commitWork(true);
			return true;
		} catch (Exception ex) {
			Logger.error('Google File Version preview size update failed (Local): ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			return false;
		} finally {
			GTriggerHandler.clearAllBypasses();
		}
	}

	private void chainAnalysisAdmittedByWorkspaceCopy(List<GoogleFileVersion__c> measuredVersions) {
		if (this.chainIntelligence == false) return;

		Set<Id> admittedVersionIds = new GoogleFileVersionContextResolver().collectSummaryCandidatesAdmittedByWorkspaceCopy(measuredVersions);
		if (admittedVersionIds.isEmpty()) return;

		GoogleFileIntelligenceFactory intelligenceFactory = new GoogleFileIntelligenceFactory();
		if (!intelligenceFactory.isConfigured()) return;

		GQueueableBuilder analysisChainer = GAsync.queueable()
			.chain(new GoogleFileVersionSummaryJob(admittedVersionIds))
			.deepClone();

		if (intelligenceFactory.isLabelingConfigured()) {
			analysisChainer.chain(new GoogleFileVersionLabelJob(admittedVersionIds)).deepClone();
		}

		Logger.info('Preview Size Measurement --> AI analysis chained for versions admitted by their Workspace copy: ' + String.join(admittedVersionIds, ', ')).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
		Logger.saveLog();
		analysisChainer.enqueue();
	}

	private void rescheduleUnmeasured(Set<Id> unmeasuredVersionIds) {
		if (unmeasuredVersionIds.isEmpty()) return;

		if (this.measurementAttempt >= MAX_MEASUREMENT_ATTEMPTS) {
			Logger.info('Preview Size Measurement --> Attempts exhausted, the uploaded file size stays in use for: ' + String.join(unmeasuredVersionIds, ', ')).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			return;
		}

		Logger.info('Preview Size Measurement --> Rescheduling, Unmeasured=' + String.valueOf(unmeasuredVersionIds.size()) + ', NextAttempt=' + String.valueOf(this.measurementAttempt + 1)).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
		schedule(unmeasuredVersionIds, this.measurementAttempt + 1, this.chainIntelligence != false);
	}

	private static void schedule(Set<Id> versionIds, Integer measurementAttempt, Boolean chainIntelligence) {
		if (versionIds == null || versionIds.isEmpty()) return;

		GAsync.queueable()
			.chain(new GoogleFileVersionPreviewSizeJob(versionIds, measurementAttempt, chainIntelligence))
			.deepClone()
			.delay(MEASUREMENT_DELAY_MINUTES)
			.enqueue();
	}
}
