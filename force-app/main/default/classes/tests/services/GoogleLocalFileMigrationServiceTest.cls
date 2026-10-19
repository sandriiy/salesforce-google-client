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
private class GoogleLocalFileMigrationServiceTest {
	private static final Integer FILES_BEYOND_ONE_STEP = 16;
	private static final Integer FILES_PER_STEP = 15;
	private static final Integer SAMPLE_SIZE = 10;
	private static final Integer FILES_BEYOND_THE_SAMPLE = 12;
	private static final Long EMPTY_FILE_SIZE = 0L;
	private static final Integer COPIED_FILES_COUNTED = 7;
	private static final String FAR_FUTURE_CRON = '0 0 0 1 1 ? 2099';
	private static final Integer HIDDEN_FILES_SCAN_LIMIT = 2000;

	private static void initMigrationMocks() {
		GoogleCloudTestFactory.config().withUploadFolderId('ROOT_FOLDER').withPreviewDisabled(true).apply();
		GoogleCloudTestFactory.initMocks();
		GoogleFileCloudFolderJob.skipExecution = true;
	}

	private static GoogleFileMigrationRequestDTO buildRequest(String condition, List<String> objectNames, Boolean skipIntelligence) {
		GoogleFileMigrationRequestDTO request = new GoogleFileMigrationRequestDTO();
		request.condition = condition;
		request.objectNames = objectNames == null ? new List<String>() : objectNames;
		request.skipIntelligence = skipIntelligence;
		return request;
	}

	private static GoogleFile__c migratedCopyOf(Id contentDocumentId) {
		return new GoogleFile__c(Id = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType), SalesforceFileId__c = String.valueOf(contentDocumentId));
	}

	private static void mockNoMigratedCopies() {
		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(new List<SObject>());
	}

	private static void mockCandidateVersions(List<ContentVersion> eligibleVersions) {
		GSOQL.mock(GoogleContentVersionSelector.MOCK_ID).thenReturn(eligibleVersions);
		GSOQL.mock(GoogleContentVersionSelector.MOCK_ID).thenReturn(eligibleVersions);
	}

	private static void mockNothingActive() {
		GSOQL.mock(GoogleCronTriggerSelector.MOCK_ID).thenReturn(new List<SObject>());
		GSOQL.mock(GoogleAsyncApexJobSelector.MOCK_ID).thenReturn(new List<SObject>());
	}

	private static GoogleFile__c migratedFileOwnedBy(Id ownerId) {
		return new GoogleFile__c(Id = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType), OwnerId = ownerId, Source__c = GoogleCloudConstants.FILE_SOURCE_MIGRATION);
	}

	private static GoogleFileLink__c viewerLink(Id fileId, Id recordId) {
		return (GoogleFileLink__c) JSON.deserialize(
			JSON.serialize(new Map<String, Object>{
				'attributes' => new Map<String, Object>{ 'type' => 'GoogleFileLink__c' },
				'Id' => GoogleCloudTestFactory.fakeId(GoogleFileLink__c.SObjectType),
				'Name' => 'Link',
				'GoogleFileId__c' => fileId,
				'LinkedObjectId__c' => String.valueOf(recordId),
				'LinkedObjectName__c' => 'Linked record',
				'LinkedObjectType__c' => 'GoogleFile__c',
				'ShareType__c' => 'Viewer',
				'Visibility__c' => 'AllUsers'
			}),
			GoogleFileLink__c.class
		);
	}

	@IsTest
	private static void testRunStepPositiveCopiesEligibleFilesAndSkipsTheRest() {
		initMigrationMocks();
		Id recordA = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		Id recordD1 = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		Id recordD2 = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);

		ContentVersion fileA = GoogleCloudTestFactory.migrationCandidate().withTitle('Alpha').build();
		ContentVersion fileB = GoogleCloudTestFactory.migrationCandidate().withTitle('Beta').build();
		ContentVersion fileC = GoogleCloudTestFactory.migrationCandidate().withTitle('Gamma').build();
		ContentVersion fileD = GoogleCloudTestFactory.migrationCandidate().withTitle('Delta').build();
		GoogleLocalFileMigrationService.candidateRowsOverride = new List<ContentVersion>{ fileA, fileB, fileC, fileD };

		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(new List<SObject>{ migratedCopyOf(fileB.ContentDocumentId) });
		GSOQL.mock(GoogleContentDocumentLinkSelector.MOCK_ID).thenReturn(new List<SObject>{
			GoogleCloudTestFactory.contentDocumentLink(fileA.ContentDocumentId, recordA, 'V', 'AllUsers'),
			GoogleCloudTestFactory.contentDocumentLink(fileB.ContentDocumentId, recordA, 'V', 'AllUsers'),
			GoogleCloudTestFactory.contentDocumentLink(fileC.ContentDocumentId, UserInfo.getUserId(), 'I', 'AllUsers'),
			GoogleCloudTestFactory.contentDocumentLink(fileD.ContentDocumentId, recordD1, 'C', 'SharedUsers'),
			GoogleCloudTestFactory.contentDocumentLink(fileD.ContentDocumentId, recordD2, 'V', 'InternalUsers')
		});
		mockCandidateVersions(new List<ContentVersion>{ fileA, fileD });

		Test.startTest();
		GoogleLocalFileMigrationService.StepResult step = new GoogleLocalFileMigrationService().runStep(null, 0, buildRequest(null, null, false));
		Test.stopTest();

		Assert.areEqual(2, step.copiedCount, 'Alpha and Delta are attached to records and not yet in Drive');
		Assert.areEqual(2, step.skippedCount, 'Beta is already in Drive and Gamma is attached to no record');
		Assert.areEqual(0, step.failedCount);
		Assert.areEqual(0, step.deferredCount);
		Assert.areEqual(4, step.nextPosition, 'Every row of the window was consumed');
		Assert.isTrue(step.isExhausted, 'A window smaller than the window size ends the walk');

		List<GoogleFile__c> copies = [SELECT Name, Source__c, SalesforceFileId__c, OwnerId FROM GoogleFile__c ORDER BY Name];
		Assert.areEqual(2, copies.size());
		Assert.areEqual('Alpha', copies[0].Name);
		Assert.areEqual(GoogleCloudConstants.FILE_SOURCE_MIGRATION, copies[0].Source__c);
		Assert.areEqual(String.valueOf(fileA.ContentDocumentId), copies[0].SalesforceFileId__c);
		Assert.areEqual(UserInfo.getUserId(), copies[0].OwnerId);
		Assert.areEqual('Delta', copies[1].Name);

		List<GoogleFileLink__c> deltaLinks = [SELECT LinkedObjectId__c, Source__c, ShareType__c, Visibility__c, IsAdditionalLink__c FROM GoogleFileLink__c WHERE GoogleFileId__c = :copies[1].Id ORDER BY IsAdditionalLink__c];
		Assert.areEqual(2, deltaLinks.size(), 'A file attached to two records gets two links');
		Assert.areEqual(String.valueOf(recordD1), deltaLinks[0].LinkedObjectId__c, 'The oldest attachment is the primary record');
		Assert.isFalse(deltaLinks[0].IsAdditionalLink__c);
		Assert.areEqual(GoogleCloudConstants.FILE_SOURCE_NOTES_AND_ATTACHMENTS, deltaLinks[0].Source__c, 'Links show under Notes and Attachments while the file keeps the Migration source');
		Assert.areEqual('Collaborator', deltaLinks[0].ShareType__c);
		Assert.areEqual('InternalUsers', deltaLinks[0].Visibility__c, 'SharedUsers becomes InternalUsers');
		Assert.areEqual(String.valueOf(recordD2), deltaLinks[1].LinkedObjectId__c);
		Assert.isTrue(deltaLinks[1].IsAdditionalLink__c);
		Assert.areEqual(1, [SELECT COUNT() FROM GoogleFileLink__c WHERE GoogleFileId__c = :copies[0].Id]);
	}

	@IsTest
	private static void testRunStepPositiveKeepsTheOwnerOnTheCopy() {
		initMigrationMocks();
		GoogleCapturingUnitOfWork capturingUow = new GoogleCapturingUnitOfWork();
		Id ownerId = GoogleCloudTestFactory.otherUserId();
		Id recordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);

		ContentVersion ownedFile = GoogleCloudTestFactory.migrationCandidate().withTitle('Owned').withOwner(ownerId, true).build();
		GoogleLocalFileMigrationService.candidateRowsOverride = new List<ContentVersion>{ ownedFile };
		mockNoMigratedCopies();
		GSOQL.mock(GoogleContentDocumentLinkSelector.MOCK_ID).thenReturn(new List<SObject>{
			GoogleCloudTestFactory.contentDocumentLink(ownedFile.ContentDocumentId, recordId, 'C', 'AllUsers')
		});
		mockCandidateVersions(new List<ContentVersion>{ ownedFile });

		Test.startTest();
		new GoogleLocalFileMigrationService(new GoogleLocalFileTransferService(capturingUow)).runStep(null, 0, buildRequest(null, null, false));
		Test.stopTest();

		GoogleFile__c registeredFile;
		GoogleFileLink__c registeredLink;
		for (SObject registered : capturingUow.registeredNew) {
			if (registered instanceof GoogleFile__c) registeredFile = (GoogleFile__c) registered;
			if (registered instanceof GoogleFileLink__c) registeredLink = (GoogleFileLink__c) registered;
		}

		Assert.isNotNull(registeredFile);
		Assert.areEqual(ownerId, registeredFile.OwnerId, 'An active owner keeps the copy');
		Assert.areEqual(String.valueOf(ownedFile.ContentDocumentId), registeredFile.SalesforceFileId__c);
		Assert.isNotNull(registeredLink);
		Assert.areEqual('Collaborator', registeredLink.ShareType__c);
		Assert.areEqual('AllUsers', registeredLink.Visibility__c);
	}

	@IsTest
	private static void testRunStepPositiveInactiveOwnerFallsBackToTheRunningUser() {
		initMigrationMocks();
		Id recordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);

		ContentVersion orphanedFile = GoogleCloudTestFactory.migrationCandidate().withTitle('Orphaned').withOwner(GoogleCloudTestFactory.otherUserId(), false).build();
		GoogleLocalFileMigrationService.candidateRowsOverride = new List<ContentVersion>{ orphanedFile };
		mockNoMigratedCopies();
		GSOQL.mock(GoogleContentDocumentLinkSelector.MOCK_ID).thenReturn(new List<SObject>{
			GoogleCloudTestFactory.contentDocumentLink(orphanedFile.ContentDocumentId, recordId, 'V', 'AllUsers')
		});
		mockCandidateVersions(new List<ContentVersion>{ orphanedFile });

		Test.startTest();
		GoogleLocalFileMigrationService.StepResult step = new GoogleLocalFileMigrationService().runStep(null, 0, buildRequest(null, null, false));
		Test.stopTest();

		Assert.areEqual(1, step.copiedCount);
		Assert.areEqual(UserInfo.getUserId(), [SELECT OwnerId FROM GoogleFile__c LIMIT 1].OwnerId, 'A file whose owner is inactive is owned by whoever ran the migration');
	}

	@IsTest
	private static void testRunStepPositiveHonoursTheObjectFilter() {
		initMigrationMocks();
		ContentVersion onFile = GoogleCloudTestFactory.migrationCandidate().withTitle('On a file').build();
		ContentVersion onVersion = GoogleCloudTestFactory.migrationCandidate().withTitle('On a version').build();
		GoogleLocalFileMigrationService.candidateRowsOverride = new List<ContentVersion>{ onFile, onVersion };
		mockNoMigratedCopies();
		GSOQL.mock(GoogleContentDocumentLinkSelector.MOCK_ID).thenReturn(new List<SObject>{
			GoogleCloudTestFactory.contentDocumentLink(onFile.ContentDocumentId, GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType), 'V', 'AllUsers'),
			GoogleCloudTestFactory.contentDocumentLink(onVersion.ContentDocumentId, GoogleCloudTestFactory.fakeId(GoogleFileVersion__c.SObjectType), 'V', 'AllUsers')
		});
		mockCandidateVersions(new List<ContentVersion>{ onFile });

		Test.startTest();
		GoogleLocalFileMigrationService.StepResult step = new GoogleLocalFileMigrationService().runStep(null, 0, buildRequest(null, new List<String>{ 'googlefile__c' }, false));
		Test.stopTest();

		Assert.areEqual(1, step.copiedCount, 'Only the file attached to the chosen object is copied');
		Assert.areEqual(1, step.skippedCount);
		Assert.areEqual('On a file', [SELECT Name FROM GoogleFile__c LIMIT 1].Name);
	}

	@IsTest
	private static void testRunStepPositiveStopsAtTheStepSizeAndContinuesFromThere() {
		initMigrationMocks();
		Id recordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		List<ContentVersion> candidates = new List<ContentVersion>();
		List<SObject> links = new List<SObject>();
		for (Integer index = 0; index < FILES_BEYOND_ONE_STEP; index++) {
			ContentVersion candidate = GoogleCloudTestFactory.migrationCandidate().withTitle('File ' + index).build();
			candidates.add(candidate);
			links.add(GoogleCloudTestFactory.contentDocumentLink(candidate.ContentDocumentId, recordId, 'V', 'AllUsers'));
		}
		GoogleLocalFileMigrationService.candidateRowsOverride = candidates;
		mockNoMigratedCopies();
		GSOQL.mock(GoogleContentDocumentLinkSelector.MOCK_ID).thenReturn(links);
		mockCandidateVersions(candidates);

		Test.startTest();
		GoogleLocalFileMigrationService.StepResult step = new GoogleLocalFileMigrationService().runStep(null, 0, buildRequest(null, null, true));
		Test.stopTest();

		Assert.areEqual(FILES_PER_STEP, step.copiedCount, 'One step copies at most the step size');
		Assert.areEqual(FILES_PER_STEP, step.nextPosition, 'The next step starts at the first file this one did not take');
		Assert.isFalse(step.isExhausted);
		Assert.areEqual(FILES_PER_STEP, [SELECT COUNT() FROM GoogleFile__c]);
		Assert.isTrue(GoogleFileInsertFinalizeCommand.intelligenceSkipped, 'Skipping AI analysis travels with the upload');
	}

	@IsTest
	private static void testRunStepPositiveLeavesWhatTheUploadTimeCannotCoverForTheNextStep() {
		initMigrationMocks();
		Id recordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);

		ContentVersion alpha = GoogleCloudTestFactory.migrationCandidate().withTitle('Alpha').build();
		ContentVersion unattached = GoogleCloudTestFactory.migrationCandidate().withTitle('Unattached').build();
		ContentVersion gamma = GoogleCloudTestFactory.migrationCandidate().withTitle('Gamma').build();
		ContentVersion delta = GoogleCloudTestFactory.migrationCandidate().withTitle('Delta').build();
		GoogleLocalFileMigrationService.candidateRowsOverride = new List<ContentVersion>{ alpha, unattached, gamma, delta };

		mockNoMigratedCopies();
		GSOQL.mock(GoogleContentDocumentLinkSelector.MOCK_ID).thenReturn(new List<SObject>{
			GoogleCloudTestFactory.contentDocumentLink(alpha.ContentDocumentId, recordId, 'V', 'AllUsers'),
			GoogleCloudTestFactory.contentDocumentLink(unattached.ContentDocumentId, UserInfo.getUserId(), 'I', 'AllUsers'),
			GoogleCloudTestFactory.contentDocumentLink(gamma.ContentDocumentId, recordId, 'V', 'AllUsers'),
			GoogleCloudTestFactory.contentDocumentLink(delta.ContentDocumentId, recordId, 'V', 'AllUsers')
		});
		mockCandidateVersions(new List<ContentVersion>{ alpha, gamma, delta });
		GoogleLocalFileTransferService.uploadTimeBudgetMillisOverride = 0L;

		Test.startTest();
		GoogleLocalFileMigrationService.StepResult step = new GoogleLocalFileMigrationService().runStep(null, 0, buildRequest(null, null, false));
		Test.stopTest();

		Assert.areEqual(1, step.copiedCount, 'Only the first file is sent once the upload time is spent');
		Assert.areEqual(2, step.deferredCount, 'Gamma and Delta wait for the next step');
		Assert.areEqual(0, step.failedCount, 'A file left for the next step is not a failure');
		Assert.areEqual(1, step.skippedCount, 'The file attached to no record is skipped as before');
		Assert.areEqual(2, step.nextPosition, 'The next step starts at Gamma, the first file this one did not get to');
		Assert.isFalse(step.isExhausted, 'Files left for the next step keep the walk going');

		List<GoogleFile__c> copies = [SELECT Name FROM GoogleFile__c];
		Assert.areEqual(1, copies.size());
		Assert.areEqual('Alpha', copies[0].Name);
	}

	@IsTest
	private static void testRunStepPositiveTheNextStepCopiesWhatTheUploadTimeLeftBehind() {
		initMigrationMocks();
		Id recordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		List<ContentVersion> candidates = new List<ContentVersion>();
		List<SObject> links = new List<SObject>();
		for (String title : new List<String>{ 'Alpha', 'Beta', 'Gamma' }) {
			ContentVersion candidate = GoogleCloudTestFactory.migrationCandidate().withTitle(title).build();
			candidates.add(candidate);
			links.add(GoogleCloudTestFactory.contentDocumentLink(candidate.ContentDocumentId, recordId, 'V', 'AllUsers'));
		}
		GoogleLocalFileMigrationService.candidateRowsOverride = candidates;
		mockNoMigratedCopies();
		GSOQL.mock(GoogleContentDocumentLinkSelector.MOCK_ID).thenReturn(links);
		mockCandidateVersions(candidates);
		GoogleFileMigrationRequestDTO request = buildRequest(null, null, false);

		GoogleLocalFileTransferService.uploadTimeBudgetMillisOverride = 0L;
		GoogleLocalFileMigrationService.StepResult firstStep = new GoogleLocalFileMigrationService().runStep(null, 0, request);
		GoogleLocalFileTransferService.uploadTimeBudgetMillisOverride = null;

		Test.startTest();
		GoogleLocalFileMigrationService.StepResult secondStep = new GoogleLocalFileMigrationService().runStep(firstStep.cursor, firstStep.nextPosition, request);
		Test.stopTest();

		Assert.areEqual(1, firstStep.copiedCount);
		Assert.areEqual(1, firstStep.nextPosition, 'The first step stops at Beta');
		Assert.areEqual(2, secondStep.copiedCount, 'The next step sends what the first one left');
		Assert.areEqual(0, secondStep.deferredCount);
		Assert.areEqual(candidates.size(), secondStep.nextPosition);
		Assert.isTrue(secondStep.isExhausted);

		List<GoogleFile__c> copies = [SELECT Name FROM GoogleFile__c ORDER BY Name];
		Assert.areEqual(candidates.size(), copies.size(), 'Every file is copied exactly once across the two steps');
		Assert.areEqual('Alpha', copies[0].Name);
		Assert.areEqual('Beta', copies[1].Name);
		Assert.areEqual('Gamma', copies[2].Name);
	}

	@IsTest
	private static void testRunStepNegativeEveryFileFailingTheSameWayStopsTheRun() {
		initMigrationMocks();
		Id recordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		List<ContentVersion> candidates = new List<ContentVersion>();
		List<SObject> links = new List<SObject>();
		for (Integer index = 0; index < 3; index++) {
			ContentVersion candidate = GoogleCloudTestFactory.migrationCandidate().withTitle('Empty ' + index).withSize(EMPTY_FILE_SIZE).build();
			candidates.add(candidate);
			links.add(GoogleCloudTestFactory.contentDocumentLink(candidate.ContentDocumentId, recordId, 'V', 'AllUsers'));
		}
		GoogleLocalFileMigrationService.candidateRowsOverride = candidates;
		mockNoMigratedCopies();
		GSOQL.mock(GoogleContentDocumentLinkSelector.MOCK_ID).thenReturn(links);
		mockCandidateVersions(candidates);

		Test.startTest();
		try {
			new GoogleLocalFileMigrationService().runStep(null, 0, buildRequest(null, null, false));
			Assert.fail('A step whose every file fails the same way must end the run');
		} catch (GoogleLocalFileMigrationService.GoogleLocalFileMigrationException ex) {
			Assert.isTrue(ex.getMessage().contains('Every file in this step failed'), ex.getMessage());
		}
		Test.stopTest();

		Assert.areEqual(0, [SELECT COUNT() FROM GoogleFile__c]);
	}

	@IsTest
	private static void testPreviewCriteriaPositiveCountsAndSamples() {
		initMigrationMocks();
		List<ContentVersion> candidates = new List<ContentVersion>();
		for (Integer index = 0; index < FILES_BEYOND_THE_SAMPLE; index++) {
			candidates.add(GoogleCloudTestFactory.migrationCandidate().withTitle('Sample ' + index).build());
		}
		GoogleLocalFileMigrationService.candidateRowsOverride = candidates;

		Test.startTest();
		GoogleFileMigrationPreviewDTO preview = new GoogleLocalFileMigrationService().previewCriteria(null);
		Test.stopTest();

		Assert.areEqual(FILES_BEYOND_THE_SAMPLE, preview.totalFiles);
		Assert.areEqual(SAMPLE_SIZE, preview.sampleFiles.size(), 'Only the first few files are shown');
		Assert.areEqual('Sample 0', preview.sampleFiles[0].name);
		Assert.areEqual('File Owner', preview.sampleFiles[0].ownerName);
		Assert.areEqual(GoogleCloudConstants.MAX_MIGRATION_FILE_SIZE_BYTES, preview.maxFileSizeBytes);
		Assert.areEqual(FILES_PER_STEP, preview.filesPerStep, 'The page estimates with the step size the run uses');
		Assert.isTrue(preview.secondsPerStep > 0);
	}

	@IsTest
	private static void testCountHiddenMigratedFilesPositiveCountsTheFilesTheUserCannotOpen() {
		initMigrationMocks();
		GoogleCloudTestFactory.denyAllRecordAccess();
		GoogleCloudTestFactory.mockInternalUser();
		Id readableRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		Id unreadableRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleCloudTestFactory.grantRecordAccess(readableRecordId, true, false);

		GoogleFile__c ownedFile = migratedFileOwnedBy(UserInfo.getUserId());
		GoogleFile__c onReadableRecord = migratedFileOwnedBy(GoogleCloudTestFactory.otherUserId());
		GoogleFile__c onUnreadableRecord = migratedFileOwnedBy(GoogleCloudTestFactory.otherUserId());
		GoogleFile__c onNoRecord = migratedFileOwnedBy(GoogleCloudTestFactory.otherUserId());
		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(new List<SObject>{ ownedFile, onReadableRecord, onUnreadableRecord, onNoRecord });
		GSOQL.mock(GoogleFileLinkSelector.MOCK_ID).thenReturn(new List<SObject>{
			viewerLink(onReadableRecord.Id, readableRecordId),
			viewerLink(onUnreadableRecord.Id, unreadableRecordId)
		});

		Test.startTest();
		GoogleFileMigrationHiddenFilesDTO hiddenFiles = new GoogleLocalFileMigrationService().countHiddenMigratedFiles();
		Test.stopTest();

		Assert.areEqual(2, hiddenFiles.hiddenCount, 'The file on a record the user cannot read and the file on no record are hidden');
		Assert.isFalse(hiddenFiles.isAtLeast, 'Fewer files than the scan limit give an exact count');
	}

	@IsTest
	private static void testCountHiddenMigratedFilesPositiveIsAFloorOnceTheScanLimitIsReached() {
		initMigrationMocks();
		GoogleCloudTestFactory.mockInternalUser();
		List<SObject> migratedFiles = new List<SObject>();
		for (Integer index = 0; index < HIDDEN_FILES_SCAN_LIMIT; index++) {
			migratedFiles.add(migratedFileOwnedBy(UserInfo.getUserId()));
		}
		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(migratedFiles);

		Test.startTest();
		GoogleFileMigrationHiddenFilesDTO hiddenFiles = new GoogleLocalFileMigrationService().countHiddenMigratedFiles();
		Test.stopTest();

		Assert.areEqual(0, hiddenFiles.hiddenCount, 'Files the user owns are never hidden');
		Assert.isTrue(hiddenFiles.isAtLeast, 'Older migrated files past the scan limit were not checked');
	}

	@IsTest
	private static void testStartNegativeRefusesWhileARunIsActive() {
		initMigrationMocks();
		GoogleLocalFileMigrationService.candidateRowsOverride = new List<ContentVersion>();
		GSOQL.mock(GoogleCronTriggerSelector.MOCK_ID).thenReturn(new List<SObject>{ GoogleCloudTestFactory.scheduledStep(Datetime.now().addMinutes(1)) });

		Test.startTest();
		try {
			new GoogleLocalFileMigrationService().start(buildRequest(null, null, false));
			Assert.fail('Only one migration may run at a time');
		} catch (GoogleLocalFileMigrationService.GoogleLocalFileMigrationException ex) {
			Assert.isTrue(ex.getMessage().contains('already running'), ex.getMessage());
		}
		Test.stopTest();
	}

	@IsTest
	private static void testStartPositiveQueuesTheFirstStep() {
		initMigrationMocks();
		GoogleFileMigrationJob.skipExecution = true;
		GoogleLocalFileMigrationService.candidateRowsOverride = new List<ContentVersion>{ GoogleCloudTestFactory.migrationCandidate().build() };
		mockNothingActive();

		Test.startTest();
		GoogleFileMigrationStartResultDTO result = new GoogleLocalFileMigrationService().start(buildRequest(null, new List<String>{ 'GoogleFile__c' }, false));
		Test.stopTest();

		Assert.isNotNull(result.jobId, 'The first step is queued right away');
		Assert.areEqual(1, result.totalFiles);
		Assert.isNotNull(result.startedAt);
	}

	@IsTest
	private static void testStartNegativeUnknownObject() {
		initMigrationMocks();
		GoogleLocalFileMigrationService.candidateRowsOverride = new List<ContentVersion>();
		mockNothingActive();

		Test.startTest();
		try {
			new GoogleLocalFileMigrationService().start(buildRequest(null, new List<String>{ 'NoSuchObject__c' }, false));
			Assert.fail('An object that does not exist must be refused before anything is queued');
		} catch (GoogleLocalFileMigrationService.GoogleLocalFileMigrationException ex) {
			Assert.isTrue(ex.getMessage().contains('NoSuchObject__c'), ex.getMessage());
		}
		Test.stopTest();
	}

	@IsTest
	private static void testRetrieveProgressPositiveDerivesTheStateFromJobsAndFiles() {
		initMigrationMocks();
		Datetime nextStepAt = Datetime.now().addMinutes(5);
		GSOQL.mock(GoogleCronTriggerSelector.MOCK_ID).thenReturn(new List<SObject>{ GoogleCloudTestFactory.scheduledStep(nextStepAt) });
		GSOQL.mock(GoogleAsyncApexJobSelector.MOCK_ID).thenReturn(new List<SObject>());
		GSOQL.mock(GoogleAsyncApexJobSelector.MOCK_ID).thenReturn(new List<SObject>{ GoogleCloudTestFactory.backgroundStep('Completed', Datetime.now()) });
		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(COPIED_FILES_COUNTED);

		Test.startTest();
		GoogleFileMigrationProgressDTO progress = new GoogleLocalFileMigrationService().retrieveProgress(Datetime.now().addHours(-1));
		Test.stopTest();

		Assert.isTrue(progress.isActive, 'A scheduled step means the run is still going');
		Assert.isFalse(progress.isStepRunning);
		Assert.areEqual(nextStepAt, progress.nextStepAt);
		Assert.isFalse(progress.lastStepFailed);
		Assert.areEqual(COPIED_FILES_COUNTED, progress.copiedCount);
		Assert.isFalse(progress.isCopiedCountCapped);
		Assert.areEqual('Migration Admin', progress.startedByName);
		Assert.isNotNull(progress.lastActivityAt);
	}

	@IsTest
	private static void testRetrieveProgressPositiveReportsAFailedLastStep() {
		initMigrationMocks();
		GSOQL.mock(GoogleCronTriggerSelector.MOCK_ID).thenReturn(new List<SObject>());
		GSOQL.mock(GoogleAsyncApexJobSelector.MOCK_ID).thenReturn(new List<SObject>());
		GSOQL.mock(GoogleAsyncApexJobSelector.MOCK_ID).thenReturn(new List<SObject>{ GoogleCloudTestFactory.backgroundStep('Failed', Datetime.now()) });
		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(0);

		Test.startTest();
		GoogleFileMigrationProgressDTO progress = new GoogleLocalFileMigrationService().retrieveProgress(null);
		Test.stopTest();

		Assert.isFalse(progress.isActive);
		Assert.isTrue(progress.lastStepFailed, 'A failed last step with nothing scheduled reads as stopped unexpectedly');
		Assert.areEqual(0, progress.copiedCount);
		Assert.isNotNull(progress.countedSince, 'Without a start the last day is counted');
	}

	@IsTest
	private static void testStopPositiveCancelsTheScheduledStep() {
		initMigrationMocks();
		GSOQL.mock(GoogleAsyncApexJobSelector.MOCK_ID).thenReturn(new List<SObject>());
		Id scheduledStepId = System.schedule(GoogleFileMigrationJob.STEP_JOB_NAME_PREFIX + '/9/test', FAR_FUTURE_CRON, new GoogleFileMigrationStepSchedulable(null));

		Test.startTest();
		new GoogleLocalFileMigrationService().stop();
		Test.stopTest();

		Assert.areEqual(0, [SELECT COUNT() FROM CronTrigger WHERE Id = :scheduledStepId], 'Stop cancels the scheduled step');
	}

	@IsTest
	private static void testIsMigrationActivePositiveSeesAPendingStep() {
		initMigrationMocks();
		GSOQL.mock(GoogleCronTriggerSelector.MOCK_ID).thenReturn(new List<SObject>());
		GSOQL.mock(GoogleAsyncApexJobSelector.MOCK_ID).thenReturn(new List<SObject>{ GoogleCloudTestFactory.backgroundStep('Queued', null) });

		Assert.isTrue(new GoogleLocalFileMigrationService().isMigrationActive());
	}

	@IsTest
	private static void testIsStepAbortedPositiveReadsTheJobState() {
		initMigrationMocks();
		GSOQL.mock(GoogleAsyncApexJobSelector.MOCK_ID).thenReturn(new List<SObject>{ GoogleCloudTestFactory.backgroundStep('Aborted', null) });

		GoogleLocalFileMigrationService migrationService = new GoogleLocalFileMigrationService();
		Assert.isTrue(migrationService.isStepAborted(GoogleCloudTestFactory.fakeId(AsyncApexJob.SObjectType)));
		Assert.isFalse(migrationService.isStepAborted(null));
	}

	@IsTest
	private static void testRetrieveReadinessNegativeListsEveryBlocker() {
		GoogleCloudTestFactory.config().apply();
		GoogleCloudTestFactory.initMocks();
		GSOQL.mock(GooglePermissionSetAssignmentSelector.MOCK_ID).thenReturn(new List<SObject>());

		Test.startTest();
		GoogleFileMigrationReadinessDTO readiness = new GoogleLocalFileMigrationService().retrieveReadiness();
		Test.stopTest();

		Assert.areEqual(2, readiness.blockers.size(), 'Query All Files and the Drive setup are both missing');
		Assert.isTrue(readiness.blockers[0].contains('Query All Files'), readiness.blockers[0]);
		Assert.isTrue(readiness.blockers[1].contains('Google Drive'), readiness.blockers[1]);
		Assert.areEqual(GoogleCloudConstants.MAX_MIGRATION_FILE_SIZE_BYTES, readiness.maxFileSizeBytes);
	}

	@IsTest
	private static void testRetrieveReadinessPositiveReadyWhenPermittedAndConfigured() {
		GoogleCloudTestFactory.config().asPackagedRecord().withUploadFolderId('ROOT_FOLDER').withFileIntelligence(true).withGeminiApiKey('key').withAiModel('gemini').apply();
		GoogleCloudTestFactory.initMocks();
		GSOQL.mock(GooglePermissionSetAssignmentSelector.MOCK_ID).thenReturn(new List<SObject>{ GoogleCloudTestFactory.queryAllFilesAssignment(UserInfo.getUserId()) });

		Test.startTest();
		GoogleFileMigrationReadinessDTO readiness = new GoogleLocalFileMigrationService().retrieveReadiness();
		Test.stopTest();

		Assert.isTrue(readiness.blockers.isEmpty(), String.join(readiness.blockers, '; '));
		Assert.isTrue(readiness.isIntelligenceEnabled);
		Assert.areEqual('ROOT_FOLDER', readiness.uploadFolderId);
	}

	@IsTest
	private static void testDescribeObjectsPositiveResolvesLabelsAndRefusesUnknownNames() {
		GoogleLocalFileMigrationService migrationService = new GoogleLocalFileMigrationService();

		List<String> labels = migrationService.describeObjects(new List<String>{ 'googlefile__c' });
		Assert.areEqual(1, labels.size());
		Assert.areEqual(GoogleFile__c.SObjectType.getDescribe().getLabel(), labels[0]);

		try {
			migrationService.describeObjects(new List<String>{ 'NoSuchObject__c' });
			Assert.fail('An unknown object must be refused');
		} catch (GoogleLocalFileMigrationService.GoogleLocalFileMigrationException ex) {
			Assert.isTrue(ex.getMessage().contains('NoSuchObject__c'), ex.getMessage());
		}
	}
}
