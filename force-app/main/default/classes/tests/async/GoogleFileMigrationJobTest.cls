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
private class GoogleFileMigrationJobTest {
	private static final Integer FILES_BEYOND_ONE_STEP = 16;
	private static final Integer FILES_PER_STEP = 15;
	private static final Long EMPTY_FILE_SIZE = 0L;
	private static final String STEP_NAME_PATTERN = GoogleFileMigrationJob.STEP_JOB_NAME_PREFIX + '/%';
	private static final String ONE_MINUTE_AHEAD_CRON_SUFFIX = ' * * ?';

	private static void initMigrationMocks() {
		GoogleCloudTestFactory.config().withUploadFolderId('ROOT_FOLDER').withPreviewDisabled(true).apply();
		GoogleCloudTestFactory.initMocks();
		GoogleFileCloudFolderJob.skipExecution = true;
		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(new List<SObject>());
	}

	private static GoogleFileMigrationRequestDTO buildRequest() {
		GoogleFileMigrationRequestDTO request = new GoogleFileMigrationRequestDTO();
		request.condition = null;
		request.objectNames = new List<String>();
		request.skipIntelligence = true;
		return request;
	}

	private static List<ContentVersion> mockCandidates(Integer count, Long contentSize) {
		Id recordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		List<ContentVersion> candidates = new List<ContentVersion>();
		List<SObject> links = new List<SObject>();
		for (Integer index = 0; index < count; index++) {
			ContentVersion candidate = GoogleCloudTestFactory.migrationCandidate().withTitle('File ' + index).withSize(contentSize).build();
			candidates.add(candidate);
			links.add(GoogleCloudTestFactory.contentDocumentLink(candidate.ContentDocumentId, recordId, 'V', 'AllUsers'));
		}

		GoogleLocalFileMigrationService.candidateRowsOverride = candidates;
		GSOQL.mock(GoogleContentDocumentLinkSelector.MOCK_ID).thenReturn(links);
		GSOQL.mock(GoogleContentVersionSelector.MOCK_ID).thenReturn(candidates);
		GSOQL.mock(GoogleContentVersionSelector.MOCK_ID).thenReturn(candidates);
		return candidates;
	}

	private static Set<Id> loadScheduledStepIds() {
		return new Set<Id>(new Map<Id, CronTrigger>([SELECT Id FROM CronTrigger WHERE CronJobDetail.Name LIKE :STEP_NAME_PATTERN AND State IN ('WAITING', 'ACQUIRED', 'EXECUTING')]).keySet());
	}

	private static Integer countStepsScheduledSince(Set<Id> alreadyScheduledIds) {
		Set<Id> scheduledIds = loadScheduledStepIds();
		scheduledIds.removeAll(alreadyScheduledIds);
		return scheduledIds.size();
	}

	@IsTest
	private static void testWorkPositiveSchedulesTheNextStepWhenFilesRemain() {
		initMigrationMocks();
		mockCandidates(FILES_BEYOND_ONE_STEP, 1024L);
		Set<Id> alreadyScheduledIds = loadScheduledStepIds();

		Test.startTest();
		new GoogleFileMigrationJob(buildRequest(), null, 0, GoogleFileMigrationJob.FIRST_STEP_NUMBER).work();
		Integer scheduledSteps = countStepsScheduledSince(alreadyScheduledIds);
		Test.stopTest();

		Assert.areEqual(FILES_PER_STEP, [SELECT COUNT() FROM GoogleFile__c], 'The step copies what one step holds');
		Assert.areEqual(1, scheduledSteps, 'The next step is scheduled rather than chained');
	}

	@IsTest
	private static void testWorkPositiveSchedulesNothingWhenTheWalkIsOver() {
		initMigrationMocks();
		mockCandidates(2, 1024L);
		Set<Id> alreadyScheduledIds = loadScheduledStepIds();

		Test.startTest();
		new GoogleFileMigrationJob(buildRequest(), null, 0, GoogleFileMigrationJob.FIRST_STEP_NUMBER).work();
		Integer scheduledSteps = countStepsScheduledSince(alreadyScheduledIds);
		Test.stopTest();

		Assert.areEqual(2, [SELECT COUNT() FROM GoogleFile__c]);
		Assert.areEqual(0, scheduledSteps, 'Nothing is scheduled once every file has been walked');
	}

	@IsTest
	private static void testWorkNegativeFailureIsLoggedAndRethrown() {
		initMigrationMocks();
		mockCandidates(3, EMPTY_FILE_SIZE);
		Set<Id> alreadyScheduledIds = loadScheduledStepIds();

		Test.startTest();
		try {
			new GoogleFileMigrationJob(buildRequest(), null, 0, GoogleFileMigrationJob.FIRST_STEP_NUMBER).work();
			Assert.fail('A step that fails must fail the job so the platform records it');
		} catch (GoogleFileMigrationJob.GoogleFileMigrationJobException ex) {
			Assert.isTrue(ex.getMessage().contains('Run the migration again'), ex.getMessage());
		}
		Test.stopTest();

		Assert.areEqual(0, countStepsScheduledSince(alreadyScheduledIds), 'A failed step schedules no next step');
	}

	@IsTest
	private static void testWorkPositiveSkipsWhenAsked() {
		initMigrationMocks();
		GoogleFileMigrationJob.skipExecution = true;
		mockCandidates(1, 1024L);

		Test.startTest();
		new GoogleFileMigrationJob(buildRequest(), null, 0, GoogleFileMigrationJob.FIRST_STEP_NUMBER).work();
		Test.stopTest();

		Assert.areEqual(0, [SELECT COUNT() FROM GoogleFile__c]);
	}

	@IsTest
	private static void testStepSchedulablePositiveQueuesTheStepAndRemovesItself() {
		initMigrationMocks();
		GoogleFileMigrationJob.skipExecution = true;
		Datetime fireAt = Datetime.now().addMinutes(1);
		String cron = fireAt.second() + ' ' + fireAt.minute() + ' ' + fireAt.hour() + ONE_MINUTE_AHEAD_CRON_SUFFIX;

		Test.startTest();
		Id scheduledStepId = System.schedule(
			GoogleFileMigrationJob.STEP_JOB_NAME_PREFIX + '/2/test',
			cron,
			new GoogleFileMigrationStepSchedulable(new GoogleFileMigrationJob(buildRequest(), null, 0, 2))
		);
		Test.stopTest();

		Assert.areEqual(1, [SELECT COUNT() FROM AsyncApexJob WHERE ApexClass.Name = 'GoogleFileMigrationJob' AND JobType = 'Queueable'], 'The hand over queues the step');
		Assert.areEqual(0, [SELECT COUNT() FROM CronTrigger WHERE Id = :scheduledStepId AND State IN ('WAITING', 'ACQUIRED', 'EXECUTING')], 'The hand over removes its own entry');
	}
}
