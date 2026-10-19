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
private class GoogleCloudMigrationControllerTest {
	private static final Integer COPIED_FILES_COUNTED = 3;

	private static void initMigrationMocks() {
		GoogleCloudTestFactory.config().asPackagedRecord().withUploadFolderId('ROOT_FOLDER').withPreviewDisabled(true).apply();
		GoogleCloudTestFactory.initMocks();
		GoogleFileMigrationJob.skipExecution = true;
	}

	private static void mockNothingActive() {
		GSOQL.mock(GoogleCronTriggerSelector.MOCK_ID).thenReturn(new List<SObject>());
		GSOQL.mock(GoogleAsyncApexJobSelector.MOCK_ID).thenReturn(new List<SObject>());
	}

	@IsTest
	private static void testRetrieveMigrationReadinessPositive() {
		initMigrationMocks();
		GSOQL.mock(GooglePermissionSetAssignmentSelector.MOCK_ID).thenReturn(new List<SObject>{ GoogleCloudTestFactory.queryAllFilesAssignment(UserInfo.getUserId()) });

		Test.startTest();
		GoogleFileMigrationReadinessDTO readiness = GoogleCloudMigrationController.retrieveMigrationReadiness();
		Test.stopTest();

		Assert.isTrue(readiness.blockers.isEmpty(), String.join(readiness.blockers, '; '));
		Assert.areEqual(GoogleCloudConstants.MAX_MIGRATION_FILE_SIZE_BYTES, readiness.maxFileSizeBytes);
	}

	@IsTest
	private static void testPreviewMigrationCriteriaPositive() {
		initMigrationMocks();
		GoogleLocalFileMigrationService.candidateRowsOverride = new List<ContentVersion>{
			GoogleCloudTestFactory.migrationCandidate().withTitle('One').build(),
			GoogleCloudTestFactory.migrationCandidate().withTitle('Two').build()
		};

		Test.startTest();
		GoogleFileMigrationPreviewDTO preview = GoogleCloudMigrationController.previewMigrationCriteria(null);
		Test.stopTest();

		Assert.areEqual(2, preview.totalFiles);
		Assert.areEqual(2, preview.sampleFiles.size());
	}

	@IsTest
	private static void testDescribeMigrationObjectsPositiveAndNegative() {
		Test.startTest();
		List<String> labels = GoogleCloudMigrationController.describeMigrationObjects(new List<String>{ 'GoogleFile__c' });
		Assert.areEqual(GoogleFile__c.SObjectType.getDescribe().getLabel(), labels[0]);

		try {
			GoogleCloudMigrationController.describeMigrationObjects(new List<String>{ 'NoSuchObject__c' });
			Assert.fail('An unknown object must come back as a readable error');
		} catch (AuraHandledException ex) {
			Assert.isNotNull(ex, 'The service message is handed to the screen as an Aura exception');
		}
		Test.stopTest();
	}

	@IsTest
	private static void testStartMigrationPositiveQueuesTheFirstStep() {
		initMigrationMocks();
		mockNothingActive();
		GoogleLocalFileMigrationService.candidateRowsOverride = new List<ContentVersion>{ GoogleCloudTestFactory.migrationCandidate().build() };

		Test.startTest();
		GoogleFileMigrationStartResultDTO result = GoogleCloudMigrationController.startMigration(null, new List<String>(), true);
		Test.stopTest();

		Assert.isNotNull(result.jobId);
		Assert.areEqual(1, result.totalFiles);
	}

	@IsTest
	private static void testStartMigrationNegativeAlreadyRunning() {
		initMigrationMocks();
		GoogleLocalFileMigrationService.candidateRowsOverride = new List<ContentVersion>();
		GSOQL.mock(GoogleCronTriggerSelector.MOCK_ID).thenReturn(new List<SObject>{ GoogleCloudTestFactory.scheduledStep(Datetime.now().addMinutes(1)) });

		Test.startTest();
		try {
			GoogleCloudMigrationController.startMigration(null, null, false);
			Assert.fail('A second run must be refused while one is active');
		} catch (AuraHandledException ex) {
			Assert.isNotNull(ex, 'The refusal reaches the screen as an Aura exception');
		}
		Test.stopTest();
	}

	@IsTest
	private static void testRetrieveMigrationProgressPositive() {
		initMigrationMocks();
		GSOQL.mock(GoogleCronTriggerSelector.MOCK_ID).thenReturn(new List<SObject>());
		GSOQL.mock(GoogleAsyncApexJobSelector.MOCK_ID).thenReturn(new List<SObject>{ GoogleCloudTestFactory.backgroundStep('Processing', null) });
		GSOQL.mock(GoogleAsyncApexJobSelector.MOCK_ID).thenReturn(new List<SObject>{ GoogleCloudTestFactory.backgroundStep('Processing', null) });
		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(COPIED_FILES_COUNTED);

		Test.startTest();
		GoogleFileMigrationProgressDTO progress = GoogleCloudMigrationController.retrieveMigrationProgress(Datetime.now().addHours(-1).getTime());
		Test.stopTest();

		Assert.isTrue(progress.isActive);
		Assert.isTrue(progress.isStepRunning);
		Assert.areEqual(COPIED_FILES_COUNTED, progress.copiedCount);
	}

	@IsTest
	private static void testRetrieveHiddenMigratedFilesPositive() {
		initMigrationMocks();
		GoogleCloudTestFactory.mockInternalUser();
		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(new List<SObject>{
			new GoogleFile__c(Id = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType), OwnerId = GoogleCloudTestFactory.otherUserId(), Source__c = GoogleCloudConstants.FILE_SOURCE_MIGRATION)
		});

		Test.startTest();
		GoogleFileMigrationHiddenFilesDTO hiddenFiles = GoogleCloudMigrationController.retrieveHiddenMigratedFiles();
		Test.stopTest();

		Assert.areEqual(1, hiddenFiles.hiddenCount, 'A migrated file owned by someone else and attached to nothing is hidden');
		Assert.isFalse(hiddenFiles.isAtLeast);
	}

	@IsTest
	private static void testStopMigrationPositive() {
		initMigrationMocks();
		mockNothingActive();

		Test.startTest();
		GoogleCloudMigrationController.stopMigration();
		Test.stopTest();

		Assert.isTrue(true, 'Stopping with nothing running is not an error');
	}
}
