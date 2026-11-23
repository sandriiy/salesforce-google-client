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
private class GoogleFileCloudFolderJobTest {
	private static final String ROOT_FOLDER_ID = 'ROOT_FOLDER_01';
	private static final String DESTINATION_FOLDER_ID = 'DEST_FOLDER_01';
	private static final String COPIES_FOLDER_ID = 'COPIES_FOLDER_01';
	private static final Integer TRANSACTION_CALLOUT_LIMIT = 100;

	private static void applyPlacementConfig(Boolean isRenameEnabled, String patternsJson, String copiesFolderId) {
		GoogleClientConfig__mdt config = new GoogleClientConfig__mdt();
		config.DefaultGoogleUploadFolderId__c = ROOT_FOLDER_ID;
		config.CustomGoogleUploadFolderStructure__c = '{Record}';
		config.IsFolderRenameEnabled__c = isRenameEnabled;
		config.RecordFolderNamePatterns__c = patternsJson;
		config.WorkspaceCopyFolderId__c = copiesFolderId;
		GoogleMetadataConfigService.configRecordOverride = config;
	}

	private static GoogleDriveHttpMock buildPlacementMock() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.queryContains('appProperties')
		).thenReturnStatus(200, '{"files":[{"id":"' + DESTINATION_FOLDER_ID + '","name":"GoogleFile__c : Old Name"}]}');
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.endpointContains('/files/GWS_')
		).thenReturnStatus(200, '{"parents":["' + ROOT_FOLDER_ID + '"]}');
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('PATCH')
		).thenReturnStatus(200, '{"id":"MOVED_FILE_01"}');
		return driveMock;
	}

	private static String patternRows(String objectApiName, String pattern) {
		return JSON.serialize(new List<Map<String, String>>{
			new Map<String, String>{ 'objectApiName' => objectApiName, 'pattern' => pattern }
		});
	}

	private static List<GoogleFileRelocationRequestDTO> insertPlacementRequests(String namePrefix, Integer count) {
		GoogleCloudTestFactory.bypassTriggers();
		List<GoogleFile__c> records = new List<GoogleFile__c>();
		List<GoogleFile__c> parentFiles = new List<GoogleFile__c>();
		for (Integer index = 0; index < count; index++) {
			records.add(GoogleCloudTestFactory.file().withName(namePrefix + ' Record ' + index).build());
			parentFiles.add(GoogleCloudTestFactory.file().withName(namePrefix + ' File ' + index).build());
		}
		insert records;
		insert parentFiles;

		List<GoogleFileVersion__c> versions = new List<GoogleFileVersion__c>();
		List<GoogleFileLink__c> links = new List<GoogleFileLink__c>();
		for (Integer index = 0; index < count; index++) {
			versions.add(GoogleCloudTestFactory.version()
				.forFile(parentFiles[index].Id)
				.withName(namePrefix + index + '.docx')
				.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
				.withSize(1024)
				.withDriveId('GD_' + namePrefix + index)
				.withDocsId('GWS_' + namePrefix + index)
				.withFolderId(ROOT_FOLDER_ID)
				.build());
			links.add(GoogleCloudTestFactory.link()
				.forFile(parentFiles[index].Id)
				.withLinkedRecord(records[index].Id)
				.withLinkedType('GoogleFile__c')
				.build());
		}
		insert versions;
		insert links;

		List<GoogleFileRelocationRequestDTO> requests = new List<GoogleFileRelocationRequestDTO>();
		for (Integer index = 0; index < count; index++) {
			requests.add(new GoogleFileRelocationRequestDTO(UserInfo.getUserId(), parentFiles[index].Id, versions[index].Id, links[index].Id));
		}

		return requests;
	}

	private static Set<Id> placedVersionIds(List<GoogleFileRelocationRequestDTO> requests) {
		Set<Id> versionIds = new Set<Id>();
		for (GoogleFileRelocationRequestDTO request : requests) {
			versionIds.add(request.localGoogleFileVersionId);
		}

		return new Map<Id, GoogleFileVersion__c>([
			SELECT Id
			FROM GoogleFileVersion__c
			WHERE Id IN :versionIds AND GoogleDriveFolderId__c = :DESTINATION_FOLDER_ID
		]).keySet();
	}

	private static Integer placedVersionCount(List<GoogleFileRelocationRequestDTO> requests) {
		return placedVersionIds(requests).size();
	}

	private static List<GoogleFileCloudFolderJob> chainedFolderJobs(GQueueableChain chain) {
		List<GoogleFileCloudFolderJob> folderJobs = new List<GoogleFileCloudFolderJob>();
		for (GQueueableJob chainedJob : chain.getJobs()) {
			if (chainedJob instanceof GoogleFileCloudFolderJob) folderJobs.add((GoogleFileCloudFolderJob) chainedJob);
		}

		return folderJobs;
	}

	private static Map<String, Object> serializedJob(GQueueableJob job) {
		return (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(job));
	}

	private static Set<Id> handedOnVersionIds(GoogleFileCloudFolderJob followUpJob) {
		Set<Id> versionIds = new Set<Id>();
		for (Object handedOnRequest : (List<Object>) serializedJob(followUpJob).get('requests')) {
			versionIds.add(Id.valueOf(String.valueOf(((Map<String, Object>) handedOnRequest).get('localGoogleFileVersionId'))));
		}

		return versionIds;
	}

	@IsTest
	private static void testWorkPositiveHandsTheFilesItHasNoRoomForToAFollowUpJob() {
		GoogleCloudTestFactory.initMocks(buildPlacementMock());
		applyPlacementConfig(false, null, null);
		List<GoogleFileRelocationRequestDTO> requests = insertPlacementRequests('FJBUD', 3);
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();
		GoogleCalloutTimeResolver.elapsedMillisOverride = 0L;
		GoogleFileCloudFolderJob.calloutsLeftOverride = 0;

		Test.startTest();
		new GoogleFileCloudFolderJob(requests).work();
		Test.stopTest();

		Assert.areEqual(new Set<Id>{ requests[0].localGoogleFileVersionId }, placedVersionIds(requests), 'The first file always runs, so a job always moves forward');

		List<GoogleFileCloudFolderJob> followUpJobs = chainedFolderJobs(runningChain);
		Assert.areEqual(1, followUpJobs.size(), 'The files left continue in one follow-up job');
		Assert.areEqual(new Set<Id>{ requests[1].localGoogleFileVersionId, requests[2].localGoogleFileVersionId }, handedOnVersionIds(followUpJobs[0]), 'No file is lost between the job and its follow-up');
		Assert.areEqual(1, serializedJob(followUpJobs[0]).get('placementAttempt'), 'A file never tried keeps its attempt');
		Assert.isNull(followUpJobs[0].delay, 'The follow-up starts straight away');
		Assert.isNotNull(followUpJobs[0].priority, 'The follow-up runs straight after, ahead of the jobs queued behind it');
	}

	@IsTest
	private static void testWorkPositiveHandsOnWhenCalloutTimeRunsShort() {
		GoogleCloudTestFactory.initMocks(buildPlacementMock());
		applyPlacementConfig(false, null, null);
		List<GoogleFileRelocationRequestDTO> requests = insertPlacementRequests('FJTIM', 3);
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();
		GoogleCalloutTimeResolver.elapsedMillisOverride = 119000L;

		Test.startTest();
		new GoogleFileCloudFolderJob(requests).work();
		Test.stopTest();

		Assert.areEqual(1, placedVersionCount(requests));
		List<GoogleFileCloudFolderJob> followUpJobs = chainedFolderJobs(runningChain);
		Assert.areEqual(1, followUpJobs.size());
		Assert.areEqual(2, handedOnVersionIds(followUpJobs[0]).size());
	}

	@IsTest
	private static void testWorkPositivePlacesEveryFileWhenThereIsRoom() {
		GoogleCloudTestFactory.initMocks(buildPlacementMock());
		applyPlacementConfig(false, null, null);
		List<GoogleFileRelocationRequestDTO> requests = insertPlacementRequests('FJALL', 3);
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();
		GoogleCalloutTimeResolver.elapsedMillisOverride = 0L;

		Test.startTest();
		new GoogleFileCloudFolderJob(requests).work();
		Test.stopTest();

		Assert.areEqual(3, placedVersionCount(requests));
		Assert.isTrue(chainedFolderJobs(runningChain).isEmpty(), 'A job with room for every file hands nothing on');
	}

	@IsTest
	private static void testWorkPositiveFirstFileIsAlwaysPlaced() {
		GoogleCloudTestFactory.initMocks(buildPlacementMock());
		applyPlacementConfig(false, null, null);
		List<GoogleFileRelocationRequestDTO> requests = insertPlacementRequests('FJONE', 1);
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();
		GoogleCalloutTimeResolver.elapsedMillisOverride = 130000L;
		GoogleFileCloudFolderJob.calloutsLeftOverride = 0;

		Test.startTest();
		new GoogleFileCloudFolderJob(requests).work();
		Test.stopTest();

		Assert.areEqual(1, placedVersionCount(requests), 'Otherwise a follow-up could hand the same file on for ever');
		Assert.isTrue(chainedFolderJobs(runningChain).isEmpty());
	}

	@IsTest
	private static void testWorkPositiveFollowUpOfARetryKeepsItsAttempt() {
		GoogleCloudTestFactory.initMocks(buildPlacementMock());
		applyPlacementConfig(false, null, null);
		List<GoogleFileRelocationRequestDTO> requests = insertPlacementRequests('FJATT', 2);
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();
		GoogleCalloutTimeResolver.elapsedMillisOverride = 0L;
		GoogleFileCloudFolderJob.calloutsLeftOverride = 0;

		Test.startTest();
		new GoogleFileCloudFolderJob(requests, 2).work();
		Test.stopTest();

		List<GoogleFileCloudFolderJob> followUpJobs = chainedFolderJobs(runningChain);
		Assert.areEqual(1, followUpJobs.size());
		Assert.areEqual(2, serializedJob(followUpJobs[0]).get('placementAttempt'), 'A follow-up does not count as an attempt');
	}

	@IsTest
	private static void testWorkPositivePlacesTenFilesOnTenRecordsWithinTheCalloutLimit() {
		GoogleCloudTestFactory.initMocks(buildPlacementMock());
		applyPlacementConfig(true, null, COPIES_FOLDER_ID);
		List<GoogleFileRelocationRequestDTO> requests = insertPlacementRequests('FJTEN', 10);
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();
		GoogleCalloutTimeResolver.elapsedMillisOverride = 0L;

		Exception jobFailure;
		Integer calloutsMade;
		Test.startTest();
		try {
			new GoogleFileCloudFolderJob(requests).work();
		} catch (Exception ex) {
			jobFailure = ex;
		}
		calloutsMade = Limits.getCallouts();
		Test.stopTest();

		Assert.isNull(jobFailure, 'Renaming and the copies folder never push a job past its limits');
		Assert.isTrue(calloutsMade <= TRANSACTION_CALLOUT_LIMIT);

		Set<Id> accountedVersionIds = new Set<Id>(placedVersionIds(requests));
		for (GoogleFileCloudFolderJob followUpJob : chainedFolderJobs(runningChain)) {
			accountedVersionIds.addAll(handedOnVersionIds(followUpJob));
		}
		Assert.areEqual(10, accountedVersionIds.size(), 'Every file is either placed or handed on, never skipped');
	}

	@IsTest
	private static void testWorkPositiveSavesTheLogAfterARecordedError() {
		GoogleCloudTestFactory.initMocks(buildPlacementMock());
		applyPlacementConfig(true, patternRows('GoogleFile__c', 'Name & Nope__c'), null);
		List<GoogleFileRelocationRequestDTO> requests = insertPlacementRequests('FJERR', 1);
		GoogleCloudTestFactory.runningChain();
		GoogleCalloutTimeResolver.elapsedMillisOverride = 0L;

		Test.startTest();
		new GoogleFileCloudFolderJob(requests).work();
		Integer unsavedLogEntries = Logger.getBufferSize();
		Test.stopTest();

		Assert.areEqual(1, placedVersionCount(requests), 'A pattern that no longer works never stops the file being placed');
		Assert.areEqual(0, unsavedLogEntries, 'A run that recorded an error saves its log, even when every file was placed');
	}

	@IsTest
	private static void testWorkPositiveSavesNothingAfterACleanRun() {
		GoogleCloudTestFactory.initMocks(buildPlacementMock());
		applyPlacementConfig(true, null, null);
		List<GoogleFileRelocationRequestDTO> requests = insertPlacementRequests('FJCLN', 1);
		GoogleCloudTestFactory.runningChain();
		GoogleCalloutTimeResolver.elapsedMillisOverride = 0L;

		Test.startTest();
		new GoogleFileCloudFolderJob(requests).work();
		Integer unsavedLogEntries = Logger.getBufferSize();
		Test.stopTest();

		Assert.areEqual(1, placedVersionCount(requests));
		Assert.isTrue(unsavedLogEntries > 0, 'A run without an error saves nothing');
	}

	@IsTest
	private static void testExecutePositiveNullRequest() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock().withDefaultHappyPath();
		GoogleCloudTestFactory.initMocks(driveMock);

		Test.startTest();
		new GoogleFileCloudFolderJob((List<GoogleFileRelocationRequestDTO>) null).work();
		Integer queuedJobs = Limits.getQueueableJobs();
		Test.stopTest();

		Assert.isTrue(driveMock.getCapturedRequests().isEmpty(), 'With nothing to place, Google Drive is never called');
		Assert.areEqual(0, queuedJobs, 'With nothing to place, no retry is scheduled');
	}

	@IsTest
	private static void testExecutePositiveEarlyReturnBlankDriveId() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('FJ1')
			.insertRecord();

		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('V1.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId(null)
			.withDocsId(null)
			.insertRecord();

		GSOQL.mock(GoogleFileVersionSelector.MOCK_ID).thenReturn(new List<SObject>{
			new GoogleFileVersion__c(
				Id = localFileVersion.Id,
				GoogleDriveFileId__c = '',
				GoogleDocsFileId__c = ''
			)
		});

		GoogleFileRelocationRequestDTO relocationRequest = new GoogleFileRelocationRequestDTO(
			UserInfo.getUserId(),
			parentFile.Id,
			localFileVersion.Id,
			null
		);

		Test.startTest();
		new GoogleFileCloudFolderJob(relocationRequest).work();
		Integer calloutsMade = Limits.getCallouts();
		Integer queuedJobs = Limits.getQueueableJobs();
		Test.stopTest();

		Assert.areEqual(0, calloutsMade, 'A version without a Drive file has nothing to move');
		Assert.areEqual(0, queuedJobs, 'A version without a Drive file is settled, not retried');
		Assert.isNull([SELECT GoogleDriveFolderId__c FROM GoogleFileVersion__c WHERE Id = :localFileVersion.Id].GoogleDriveFolderId__c);
	}

	@IsTest
	private static void testExecuteNegativeNullVersionId() {
		GoogleCloudTestFactory.initMocks();

		GoogleFileRelocationRequestDTO relocationRequest = new GoogleFileRelocationRequestDTO(
			UserInfo.getUserId(),
			GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType),
			null,
			GoogleCloudTestFactory.fakeId(GoogleFileLink__c.SObjectType)
		);

		try {
			Test.startTest();
			new GoogleFileCloudFolderJob(relocationRequest).work();
			Test.stopTest();
			Assert.isTrue(false);
		} catch (GoogleFileCloudFolderJob.GoogleFileCloudFolderJobException ex) {
			Assert.isTrue(ex.getMessage().contains('Unable to place the file into a folder'));
		}
	}
}