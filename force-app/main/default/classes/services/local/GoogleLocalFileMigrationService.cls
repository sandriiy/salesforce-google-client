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
 * Moves Salesforce Files into Google Drive as ordinary Google Client files, a step at a time in the
 * background. Only files attached to at least one record and no larger than the migration size limit are
 * taken; a file already copied, told by the Salesforce file Id on the Google File, is skipped, which is
 * what makes a second run over the same selection a resume. The package keeps no record of a run: what a
 * screen can know comes from the platform's job records and from the files already copied.
 */
public without sharing class GoogleLocalFileMigrationService {
	public class GoogleLocalFileMigrationException extends Exception {}

	private static final Integer CANDIDATE_WINDOW_SIZE = 200;
	private static final Integer MAX_FILES_PER_STEP = 15;
	private static final Integer SAMPLE_SIZE = 10;
	private static final Integer SECONDS_PER_STEP_ESTIMATE = 150;
	private static final Integer COPIED_COUNT_LIMIT = 50000;
	private static final Integer HIDDEN_FILES_SCAN_LIMIT = 2000;
	private static final Integer SHARED_FAILURE_MIN_ATTEMPTS = 3;
	private static final Integer PROGRESS_LOOKBACK_HOURS = 24;
	private static final Integer START_TOLERANCE_SECONDS = 5;
	private static final Integer SINGLE_ROW = 1;
	private static final Integer KEY_PREFIX_LENGTH = 3;
	private static final Map<String, String> LINK_SHARE_TYPE_BY_CONTENT_SHARE_TYPE = new Map<String, String>{
		'V' => 'Viewer',
		'C' => 'Collaborator',
		'I' => 'InferredFromRecord'
	};
	private static final Map<String, String> LINK_VISIBILITY_BY_CONTENT_VISIBILITY = new Map<String, String>{
		'AllUsers' => 'AllUsers',
		'InternalUsers' => 'InternalUsers',
		'SharedUsers' => 'InternalUsers'
	};
	/**
	 * Users, public groups, libraries, Chatter groups and the organization itself: a Salesforce file whose
	 * only attachments are to these is attached to no record.
	 */
	private static final Set<String> NON_RECORD_LINK_KEY_PREFIXES = new Set<String>{ '005', '00G', '058', '0F9', '00D' };

	private static final String QUERY_ALL_FILES_MISSING_MESSAGE = 'You need the Query All Files permission to migrate files. Ask your Salesforce administrator to add it to your profile or to a permission set assigned to you';
	private static final String DRIVE_NOT_CONFIGURED_MESSAGE = 'Google Drive is not connected yet. Finish the Google Drive setup on the Google Client home page first';
	private static final String CONDITION_FAILED_MESSAGE = 'Salesforce could not run this condition: ';
	private static final String UNKNOWN_OBJECT_MESSAGE = 'There is no object with the API name ';
	private static final String ALREADY_RUNNING_MESSAGE = 'A migration is already running. Stop it or wait for it to finish before starting another';
	private static final String START_FAILED_MESSAGE = 'Unable to start the migration. Please try again or contact your system administrator';
	private static final String STOP_FAILED_MESSAGE = 'Unable to stop the migration. Please try again or contact your system administrator';
	private static final String PROGRESS_FAILED_MESSAGE = 'Unable to read the migration progress. Please try again or contact your system administrator';
	private static final String HIDDEN_FILES_FAILED_MESSAGE = 'Unable to count the migrated files you cannot open. Please try again or contact your system administrator';
	private static final String SHARED_FAILURE_MESSAGE = 'Every file in this step failed for the same reason: ';

	@TestVisible
	private static List<ContentVersion> candidateRowsOverride;

	private final GoogleMetadataConfigService metadataService;
	private final GoogleLocalFileTransferService transferService;

	public GoogleLocalFileMigrationService() {
		this(new GoogleLocalFileTransferService());
	}

	@TestVisible
	private GoogleLocalFileMigrationService(GoogleLocalFileTransferService transferService) {
		this.metadataService = new GoogleMetadataConfigService();
		this.transferService = transferService;
	}

	/**
	 * Says whether the running user and the org can migrate at all, and states the facts the screen shows
	 * before anything is chosen.
	 *
	 * @return The blockers, empty when ready, with the size limit and the AI state.
	 */
	public GoogleFileMigrationReadinessDTO retrieveReadiness() {
		GoogleFileMigrationReadinessDTO readiness = new GoogleFileMigrationReadinessDTO();
		readiness.maxFileSizeBytes = GoogleCloudConstants.MAX_MIGRATION_FILE_SIZE_BYTES;
		readiness.isIntelligenceEnabled = metadataService.isFileIntelligenceEnabled();
		readiness.uploadFolderId = metadataService.getDefaultUploadFolderId();

		if (!grantsQueryAllFiles(UserInfo.getUserId())) {
			readiness.blockers.add(QUERY_ALL_FILES_MISSING_MESSAGE);
		}

		if (!isDriveConfigured()) {
			readiness.blockers.add(DRIVE_NOT_CONFIGURED_MESSAGE);
		}

		return readiness;
	}

	/**
	 * Counts the Salesforce files a condition selects within the migration's scope and reads the first few,
	 * without copying anything. One call opens one cursor.
	 *
	 * @param condition A WHERE condition on ContentVersion, without the keyword. Blank means everything.
	 * @return The count, a sample and the pace a run would move at.
	 */
	public GoogleFileMigrationPreviewDTO previewCriteria(String condition) {
		GoogleFileMigrationPreviewDTO preview = new GoogleFileMigrationPreviewDTO();
		preview.filesPerStep = MAX_FILES_PER_STEP;
		preview.secondsPerStep = SECONDS_PER_STEP_ESTIMATE;
		preview.maxFileSizeBytes = GoogleCloudConstants.MAX_MIGRATION_FILE_SIZE_BYTES;

		Database.Cursor cursor = openCandidateCursor(condition);
		preview.totalFiles = countCandidates(cursor);

		for (ContentVersion sampleRow : fetchCandidates(cursor, 0, Math.min(SAMPLE_SIZE, preview.totalFiles))) {
			preview.sampleFiles.add(toSampleFile(sampleRow));
		}

		return preview;
	}

	/**
	 * Resolves object API names to their labels, refusing the first one that does not exist, so a screen can
	 * confirm what an administrator typed before a run depends on it.
	 *
	 * @param objectNames The API names to check.
	 * @return One label per name, in the same order.
	 */
	public List<String> describeObjects(List<String> objectNames) {
		List<String> labels = new List<String>();
		for (Schema.DescribeSObjectResult objectDescribe : describeAll(objectNames)) {
			labels.add(objectDescribe.getLabel());
		}

		return labels;
	}

	/**
	 * Starts a run: counts what the selection holds, opens the cursor the steps walk and queues the first
	 * step right away. Only one run may be active at a time.
	 *
	 * @param request What to migrate and whether to analyze it.
	 * @return When the run started, how many files it set out to copy and the first step's job.
	 */
	public GoogleFileMigrationStartResultDTO start(GoogleFileMigrationRequestDTO request) {
		if (request == null) request = new GoogleFileMigrationRequestDTO();
		if (isMigrationActive()) {
			throw new GoogleLocalFileMigrationException(ALREADY_RUNNING_MESSAGE);
		}

		request.objectNames = normalizeObjectNames(request.objectNames);
		Database.Cursor cursor = openCandidateCursor(request.condition);

		GoogleFileMigrationStartResultDTO result = new GoogleFileMigrationStartResultDTO();
		result.totalFiles = countCandidates(cursor);
		result.startedAt = Datetime.now().addSeconds(-START_TOLERANCE_SECONDS);

		try {
			GAsync.Result enqueued = GAsync.queueable(new GoogleFileMigrationJob(request, cursor, 0, GoogleFileMigrationJob.FIRST_STEP_NUMBER)).enqueue();
			result.jobId = enqueued.salesforceJobId;
		} catch (Exception ex) {
			Logger.error('Start Migration (Local): ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw new GoogleLocalFileMigrationException(START_FAILED_MESSAGE);
		}

		Logger.info('Start Migration --> Total=' + result.totalFiles + ', Condition=' + request.condition + ', Objects=' + String.join(request.objectNames, ', ') + ', SkipIntelligence=' + String.valueOf(request.skipIntelligence)).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
		Logger.saveLog();
		return result;
	}

	/**
	 * Reads where the migration stands from the platform's job records and the files copied so far.
	 *
	 * @param countedSince The moment to count copied files from. Null counts the last day.
	 * @return The state of the steps and the count.
	 */
	public GoogleFileMigrationProgressDTO retrieveProgress(Datetime countedSince) {
		GoogleFileMigrationProgressDTO progress = new GoogleFileMigrationProgressDTO();
		progress.countedSince = countedSince == null ? Datetime.now().addHours(-PROGRESS_LOOKBACK_HOURS) : countedSince;

		try {
			List<CronTrigger> scheduledSteps = loadScheduledSteps();
			List<AsyncApexJob> pendingSteps = loadPendingSteps();
			List<AsyncApexJob> latestSteps = (List<AsyncApexJob>) GoogleAsyncApexJobSelector.query()
				.withBaseFields()
				.byApexClassName(GoogleFileMigrationJob.class.getName())
				.byQueueableType()
				.orderByCreatedDesc()
				.limitTo(SINGLE_ROW)
				.toList();

			progress.isStepRunning = !pendingSteps.isEmpty();
			progress.nextStepAt = scheduledSteps.isEmpty() ? null : scheduledSteps[0].NextFireTime;
			progress.isActive = progress.isStepRunning || progress.nextStepAt != null;

			if (!latestSteps.isEmpty()) {
				AsyncApexJob latestStep = latestSteps[0];
				progress.lastActivityAt = latestStep.CompletedDate;
				progress.lastStepFailed = !progress.isActive && latestStep.Status == GoogleAsyncApexJobSelector.FAILED_STATUS;
				progress.startedByName = latestStep.CreatedBy == null ? null : latestStep.CreatedBy.Name;
			}

			progress.copiedCount = GoogleFileSelector.query()
				.bySource(GoogleCloudConstants.FILE_SOURCE_MIGRATION)
				.byCreatedOnOrAfter(progress.countedSince)
				.limitTo(COPIED_COUNT_LIMIT)
				.toInteger();
			progress.isCopiedCountCapped = progress.copiedCount >= COPIED_COUNT_LIMIT;
		} catch (Exception ex) {
			Logger.error('Retrieve Migration Progress (Local): ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw new GoogleLocalFileMigrationException(PROGRESS_FAILED_MESSAGE);
		}

		return progress;
	}

	/**
	 * Counts the migrated files the running user cannot open, through the same access check every list of
	 * files goes through, so a screen can say how many it leaves out. Only the most recent migrated files are
	 * checked; past that many the count is a floor.
	 *
	 * @return How many migrated files are hidden from the running user, and whether that is a floor.
	 */
	public GoogleFileMigrationHiddenFilesDTO countHiddenMigratedFiles() {
		GoogleFileMigrationHiddenFilesDTO hiddenFiles = new GoogleFileMigrationHiddenFilesDTO();

		try {
			List<GoogleFile__c> migratedFiles = (List<GoogleFile__c>) GoogleFileSelector.query()
				.withSpecificFields(new List<String>{ 'Id', 'OwnerId' })
				.bySource(GoogleCloudConstants.FILE_SOURCE_MIGRATION)
				.orderByCreatedDesc()
				.limitTo(HIDDEN_FILES_SCAN_LIMIT)
				.toList();

			if (migratedFiles.isEmpty()) return hiddenFiles;

			Integer accessibleCount = new GoogleLocalFileService().stripInaccessibleRecords()
				.forFiles(migratedFiles)
				.forUser(UserInfo.getUserId())
				.strip()
				.size();

			hiddenFiles.hiddenCount = migratedFiles.size() - accessibleCount;
			hiddenFiles.isAtLeast = migratedFiles.size() == HIDDEN_FILES_SCAN_LIMIT;
		} catch (Exception ex) {
			Logger.error('Count Hidden Migrated Files (Local): ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw new GoogleLocalFileMigrationException(HIDDEN_FILES_FAILED_MESSAGE);
		}

		return hiddenFiles;
	}

	/**
	 * Cancels the scheduled next step and any step still waiting to run. A step already executing finishes
	 * the files it holds; it schedules no further step when it sees it was cancelled.
	 */
	public void stop() {
		try {
			for (CronTrigger scheduledStep : loadScheduledSteps()) {
				abortQuietly(scheduledStep.Id);
			}

			for (AsyncApexJob pendingStep : loadPendingSteps()) {
				abortQuietly(pendingStep.Id);
			}
		} catch (Exception ex) {
			Logger.error('Stop Migration (Local): ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw new GoogleLocalFileMigrationException(STOP_FAILED_MESSAGE);
		}

		Logger.info('Stop Migration --> Requested by ' + UserInfo.getUserId()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
		Logger.saveLog();
	}

	/**
	 * Says whether a step is queued, running or scheduled.
	 *
	 * @return True while a run is in progress.
	 */
	public Boolean isMigrationActive() {
		return !loadScheduledSteps().isEmpty() || !loadPendingSteps().isEmpty();
	}

	/**
	 * Says whether a step's own job was cancelled while it ran, which is how the step knows not to schedule
	 * the next one.
	 *
	 * @param jobId The step's job Id.
	 * @return True when the job reads as aborted.
	 */
	public Boolean isStepAborted(Id jobId) {
		if (jobId == null) return false;

		List<AsyncApexJob> steps = (List<AsyncApexJob>) GoogleAsyncApexJobSelector.query()
			.withBaseFields()
			.byId(jobId)
			.toList();

		return !steps.isEmpty() && steps[0].Status == GoogleAsyncApexJobSelector.ABORTED_STATUS;
	}

	/**
	 * Opens the cursor over everything a condition selects within scope, oldest file first, so a run can
	 * walk it a window at a time across steps.
	 *
	 * @param condition A WHERE condition on ContentVersion, without the keyword. Blank means everything.
	 * @return The cursor, or null when the candidates are stubbed in a test.
	 */
	public Database.Cursor openCandidateCursor(String condition) {
		if (candidateRowsOverride != null) return null;

		try {
			return buildCandidateQuery(condition).toCursor();
		} catch (QueryException ex) {
			throw new GoogleLocalFileMigrationException(CONDITION_FAILED_MESSAGE + ex.getMessage());
		}
	}

	/**
	 * Runs one step: reads the next window of candidates, drops the ones already in Drive, not attached to
	 * a record, outside the object filter or no longer eligible, copies as many of the rest as the step
	 * size, the heap and the upload time allow, and says where the next step should continue, which is the
	 * first file the step did not get to. A file that fails is logged and
	 * left in Salesforce for the next run; when every file of a step fails the same way the step fails,
	 * so the run stops instead of walking on through an outage.
	 *
	 * @param cursor The cursor opened for the run, reopened here when it has expired.
	 * @param position Where this step starts in the cursor.
	 * @param request What the run was asked to do.
	 * @return The cursor to carry on with, the next position and what happened.
	 */
	public StepResult runStep(Database.Cursor cursor, Integer position, GoogleFileMigrationRequestDTO request) {
		StepResult result = new StepResult();
		result.cursor = cursor;
		result.nextPosition = position;

		CandidateWindow window = fetchWindow(cursor, position, request.condition);
		result.cursor = window.cursor;
		if (window.rows.isEmpty()) {
			result.isExhausted = true;
			return result;
		}

		Set<Id> documentIds = collectDocumentIds(window.rows);
		Set<Id> migratedDocumentIds = loadMigratedDocumentIds(documentIds);
		Map<Id, List<ContentDocumentLink>> recordLinksByDocumentId = loadRecordLinksByDocumentId(documentIds, request.objectNames);

		Set<Id> pendingDocumentIds = new Set<Id>();
		for (ContentVersion row : window.rows) {
			if (migratedDocumentIds.contains(row.ContentDocumentId) || !recordLinksByDocumentId.containsKey(row.ContentDocumentId)) continue;
			pendingDocumentIds.add(row.ContentDocumentId);
		}

		Map<Id, ContentVersion> eligibleVersionsByDocumentId = loadEligibleVersionsByDocumentId(pendingDocumentIds);
		List<StepCandidate> candidates = new List<StepCandidate>();
		Integer stopRowIndex = null;

		for (Integer rowIndex = 0; rowIndex < window.rows.size(); rowIndex++) {
			ContentVersion row = window.rows[rowIndex];
			ContentVersion latestVersion = eligibleVersionsByDocumentId.get(row.ContentDocumentId);
			if (!pendingDocumentIds.contains(row.ContentDocumentId) || latestVersion == null) {
				result.skippedCount++;
				continue;
			}

			if (candidates.size() >= MAX_FILES_PER_STEP) {
				stopRowIndex = rowIndex;
				break;
			}

			candidates.add(new StepCandidate(rowIndex, latestVersion, recordLinksByDocumentId.get(row.ContentDocumentId)));
		}

		List<GoogleFileUploadRequestDTO> uploadRequests = new List<GoogleFileUploadRequestDTO>();
		for (StepCandidate candidate : candidates) {
			uploadRequests.add(buildUploadRequest(candidate, request));
		}

		List<GoogleFileUploadResultDTO> uploads = uploadRequests.isEmpty()
			? new List<GoogleFileUploadResultDTO>()
			: transferService.uploadSalesforceFilesNow(uploadRequests);

		Integer attemptedCount = 0;
		Set<String> failureMessages = new Set<String>();
		for (Integer index = 0; index < uploads.size(); index++) {
			GoogleFileUploadResultDTO upload = uploads[index];
			StepCandidate candidate = candidates[index];

			if (upload.isDeferred == true) {
				if (stopRowIndex == null || candidate.rowIndex < stopRowIndex) stopRowIndex = candidate.rowIndex;
				result.deferredCount++;
				continue;
			}

			attemptedCount++;
			if (upload.googleFileId != null) {
				result.copiedCount++;
				continue;
			}

			result.failedCount++;
			failureMessages.add(upload.errorMessage);
			Logger.warn('Migration File Not Copied --> ContentDocumentId=' + String.valueOf(candidate.latestVersion.ContentDocumentId) + ', Reason=' + upload.errorMessage).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
		}

		result.nextPosition = stopRowIndex == null ? position + window.rows.size() : position + stopRowIndex;
		result.isExhausted = stopRowIndex == null && window.rows.size() < CANDIDATE_WINDOW_SIZE;

		if (attemptedCount >= SHARED_FAILURE_MIN_ATTEMPTS && result.copiedCount == 0 && failureMessages.size() == 1) {
			throw new GoogleLocalFileMigrationException(SHARED_FAILURE_MESSAGE + new List<String>(failureMessages)[0]);
		}

		return result;
	}

	private GoogleContentVersionSelector buildCandidateQuery(String condition) {
		return GoogleContentVersionSelector.query()
			.withMigrationFields()
			.withOwnerDetails()
			.byLatest()
			.byStoredInSalesforce()
			.excludingEnhancedNotes()
			.byMaxSize(GoogleCloudConstants.MAX_MIGRATION_FILE_SIZE_BYTES)
			.byCondition(condition)
			.orderByCreatedThenId();
	}

	private Integer countCandidates(Database.Cursor cursor) {
		if (candidateRowsOverride != null) return candidateRowsOverride.size();
		return cursor == null ? 0 : cursor.getNumRecords();
	}

	private List<ContentVersion> fetchCandidates(Database.Cursor cursor, Integer position, Integer count) {
		List<ContentVersion> rows = new List<ContentVersion>();
		if (count <= 0) return rows;

		if (candidateRowsOverride != null) {
			for (Integer index = position; index < Math.min(position + count, candidateRowsOverride.size()); index++) {
				rows.add(candidateRowsOverride[index]);
			}

			return rows;
		}

		return (List<ContentVersion>) cursor.fetch(position, count);
	}

	private CandidateWindow fetchWindow(Database.Cursor cursor, Integer position, String condition) {
		CandidateWindow window = new CandidateWindow();
		window.cursor = cursor;

		try {
			window.rows = fetchCandidates(window.cursor, position, remainingWindowSize(window.cursor, position));
		} catch (Exception ex) {
			Logger.warn('Migration Candidate Cursor Reopened --> Position=' + position + ', Message=' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			window.cursor = openCandidateCursor(condition);
			window.rows = fetchCandidates(window.cursor, position, remainingWindowSize(window.cursor, position));
		}

		return window;
	}

	private Integer remainingWindowSize(Database.Cursor cursor, Integer position) {
		return Math.min(CANDIDATE_WINDOW_SIZE, Math.max(0, countCandidates(cursor) - position));
	}

	private Set<Id> collectDocumentIds(List<ContentVersion> rows) {
		Set<Id> documentIds = new Set<Id>();
		for (ContentVersion row : rows) {
			if (row.ContentDocumentId != null) documentIds.add(row.ContentDocumentId);
		}

		return documentIds;
	}

	private Set<Id> loadMigratedDocumentIds(Set<Id> documentIds) {
		Set<Id> migratedDocumentIds = new Set<Id>();
		if (documentIds.isEmpty()) return migratedDocumentIds;

		for (GoogleFile__c fileRecord : (List<GoogleFile__c>) GoogleFileSelector.query()
			.withSpecificFields(new List<String>{ 'Id', 'SalesforceFileId__c' })
			.bySalesforceFileIds(documentIds)
			.toList()
		) {
			if (String.isNotBlank(fileRecord.SalesforceFileId__c)) migratedDocumentIds.add((Id) fileRecord.SalesforceFileId__c);
		}

		return migratedDocumentIds;
	}

	private Map<Id, List<ContentDocumentLink>> loadRecordLinksByDocumentId(Set<Id> documentIds, List<String> objectNames) {
		Map<Id, List<ContentDocumentLink>> recordLinksByDocumentId = new Map<Id, List<ContentDocumentLink>>();
		if (documentIds.isEmpty()) return recordLinksByDocumentId;

		Set<String> allowedObjectNames = new Set<String>();
		for (String objectName : objectNames == null ? new List<String>() : objectNames) {
			if (String.isNotBlank(objectName)) allowedObjectNames.add(objectName.trim().toLowerCase());
		}

		for (ContentDocumentLink link : (List<ContentDocumentLink>) GoogleContentDocumentLinkSelector.query()
			.withBaseFields()
			.byContentDocumentIds(documentIds)
			.orderByOldestFirst()
			.toList()
		) {
			if (!isRecordLink(link.LinkedEntityId)) continue;
			if (!allowedObjectNames.isEmpty() && !allowedObjectNames.contains(link.LinkedEntityId.getSObjectType().getDescribe().getName().toLowerCase())) continue;

			if (!recordLinksByDocumentId.containsKey(link.ContentDocumentId)) {
				recordLinksByDocumentId.put(link.ContentDocumentId, new List<ContentDocumentLink>());
			}

			recordLinksByDocumentId.get(link.ContentDocumentId).add(link);
		}

		return recordLinksByDocumentId;
	}

	private Boolean isRecordLink(Id linkedEntityId) {
		if (linkedEntityId == null) return false;
		if (NON_RECORD_LINK_KEY_PREFIXES.contains(String.valueOf(linkedEntityId).left(KEY_PREFIX_LENGTH))) return false;
		return linkedEntityId.getSObjectType() != null;
	}

	private Map<Id, ContentVersion> loadEligibleVersionsByDocumentId(Set<Id> documentIds) {
		Map<Id, ContentVersion> versionsByDocumentId = new Map<Id, ContentVersion>();
		if (documentIds.isEmpty()) return versionsByDocumentId;

		for (ContentVersion latestVersion : (List<ContentVersion>) GoogleContentVersionSelector.query()
			.withMigrationFields()
			.withOwnerDetails()
			.byContentDocumentIds(documentIds)
			.byLatest()
			.byStoredInSalesforce()
			.excludingEnhancedNotes()
			.byMaxSize(GoogleCloudConstants.MAX_MIGRATION_FILE_SIZE_BYTES)
			.toList()
		) {
			versionsByDocumentId.put(latestVersion.ContentDocumentId, latestVersion);
		}

		return versionsByDocumentId;
	}

	private GoogleFileUploadRequestDTO buildUploadRequest(StepCandidate candidate, GoogleFileMigrationRequestDTO request) {
		ContentDocumentLink primaryLink = candidate.recordLinks[0];
		List<Id> additionalRecordIds = new List<Id>();
		for (Integer index = 1; index < candidate.recordLinks.size(); index++) {
			additionalRecordIds.add(candidate.recordLinks[index].LinkedEntityId);
		}

		GoogleFileUploadRequestDTO upload = new GoogleFileUploadRequestDTO();
		upload.salesforceFileId = candidate.latestVersion.Id;
		upload.relatedRecordId = primaryLink.LinkedEntityId;
		upload.additionalRecordIds = additionalRecordIds;
		upload.ownerId = resolveOwnerId(candidate.latestVersion);
		upload.shareType = LINK_SHARE_TYPE_BY_CONTENT_SHARE_TYPE.get(primaryLink.ShareType);
		upload.visibility = LINK_VISIBILITY_BY_CONTENT_VISIBILITY.get(primaryLink.Visibility);
		upload.source = GoogleCloudConstants.FILE_SOURCE_MIGRATION;
		upload.linkSource = GoogleCloudConstants.FILE_SOURCE_NOTES_AND_ATTACHMENTS;
		upload.skipIntelligence = request.skipIntelligence == true;
		return upload;
	}

	private Id resolveOwnerId(ContentVersion latestVersion) {
		Boolean ownerIsActive = latestVersion.Owner != null && latestVersion.Owner.IsActive == true;
		return ownerIsActive ? latestVersion.OwnerId : null;
	}

	private GoogleFileMigrationPreviewDTO.SampleFile toSampleFile(ContentVersion row) {
		GoogleFileMigrationPreviewDTO.SampleFile sample = new GoogleFileMigrationPreviewDTO.SampleFile();
		sample.contentDocumentId = row.ContentDocumentId;
		sample.name = row.Title;
		sample.fileExtension = row.FileExtension;
		sample.size = row.ContentSize;
		sample.ownerName = row.Owner == null ? null : row.Owner.Name;
		sample.createdDate = row.CreatedDate;
		return sample;
	}

	private List<String> normalizeObjectNames(List<String> objectNames) {
		List<String> normalizedNames = new List<String>();
		for (Schema.DescribeSObjectResult objectDescribe : describeAll(objectNames)) {
			normalizedNames.add(objectDescribe.getName());
		}

		return normalizedNames;
	}

	private List<Schema.DescribeSObjectResult> describeAll(List<String> objectNames) {
		List<Schema.DescribeSObjectResult> objectDescribes = new List<Schema.DescribeSObjectResult>();
		if (objectNames == null || objectNames.isEmpty()) return objectDescribes;

		Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
		for (String objectName : objectNames) {
			if (String.isBlank(objectName)) continue;

			Schema.SObjectType objectType = globalDescribe.get(objectName.trim().toLowerCase());
			if (objectType == null) {
				throw new GoogleLocalFileMigrationException(UNKNOWN_OBJECT_MESSAGE + '"' + objectName.trim() + '"');
			}

			objectDescribes.add(objectType.getDescribe());
		}

		return objectDescribes;
	}

	private Boolean grantsQueryAllFiles(Id userId) {
		return !GooglePermissionSetAssignmentSelector.query()
			.withBaseFields()
			.byAssigneeId(userId)
			.grantingQueryAllFiles()
			.limitTo(SINGLE_ROW)
			.toList()
			.isEmpty();
	}

	private Boolean isDriveConfigured() {
		return metadataService.hasConfigRecord() && String.isNotBlank(metadataService.getDefaultUploadFolderId());
	}

	private List<CronTrigger> loadScheduledSteps() {
		return (List<CronTrigger>) GoogleCronTriggerSelector.query()
			.withBaseFields()
			.byJobNamePrefix(GoogleFileMigrationJob.STEP_JOB_NAME_PREFIX)
			.byPendingStates()
			.orderByNextFireTime()
			.toList();
	}

	private List<AsyncApexJob> loadPendingSteps() {
		return (List<AsyncApexJob>) GoogleAsyncApexJobSelector.query()
			.withBaseFields()
			.byApexClassName(GoogleFileMigrationJob.class.getName())
			.byQueueableType()
			.byStatuses(GoogleAsyncApexJobSelector.PENDING_STATUSES)
			.toList();
	}

	private void abortQuietly(Id jobId) {
		try {
			System.abortJob(jobId);
		} catch (Exception ex) {
			Logger.warn('Stop Migration --> Could not cancel ' + String.valueOf(jobId) + ': ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
		}
	}

	/**
	 * What one step did and where the next one continues.
	 */
	public class StepResult {
		/**
		 * The cursor to carry into the next step, which is a new one when the old had expired.
		 */
		public Database.Cursor cursor;
		/**
		 * Where the next step starts.
		 */
		public Integer nextPosition;
		/**
		 * True when there is nothing left to walk.
		 */
		public Boolean isExhausted = false;
		public Integer copiedCount = 0;
		public Integer failedCount = 0;
		public Integer skippedCount = 0;
		public Integer deferredCount = 0;
	}

	private class CandidateWindow {
		private Database.Cursor cursor;
		private List<ContentVersion> rows = new List<ContentVersion>();
	}

	private class StepCandidate {
		private final Integer rowIndex;
		private final ContentVersion latestVersion;
		private final List<ContentDocumentLink> recordLinks;

		private StepCandidate(Integer rowIndex, ContentVersion latestVersion, List<ContentDocumentLink> recordLinks) {
			this.rowIndex = rowIndex;
			this.latestVersion = latestVersion;
			this.recordLinks = recordLinks;
		}
	}
}
