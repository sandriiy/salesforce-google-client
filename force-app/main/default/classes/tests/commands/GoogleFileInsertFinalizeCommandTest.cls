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
private class GoogleFileInsertFinalizeCommandTest {
	private static final String DOCX_MIME_TYPE = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
	private static final String LABEL_DEFINITIONS = '[{"name":"Invoice","labelId":"LABEL_INVOICE","description":"A bill requesting payment for goods or services"}]';
	private static final String PREVIEW = 'Preview';
	private static final String FOLDER = 'Folder';
	private static final String SUMMARY = 'Summary';
	private static final String LABEL = 'Label';

	private static void applyAnalysisConfig(String folderStructure) {
		GoogleCloudTestFactory.config()
			.withFolderStructure(folderStructure)
			.withFileIntelligence(true)
			.withGeminiApiKey('api-key-1')
			.withAiModel('gemini-2.0-flash')
			.withAiLabeling(true)
			.withAiLabelDefinitions(LABEL_DEFINITIONS)
			.apply();
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();
	}

	private static List<GoogleFileVersion__c> createNewVersions(String namePrefix, Integer count) {
		List<GoogleFile__c> parentFiles = new List<GoogleFile__c>();
		for (Integer index = 0; index < count; index++) {
			parentFiles.add(GoogleCloudTestFactory.file().withName(namePrefix + index).build());
		}
		insert parentFiles;

		List<GoogleFileVersion__c> versions = new List<GoogleFileVersion__c>();
		for (Integer index = 0; index < count; index++) {
			versions.add(GoogleCloudTestFactory.version()
				.forFile(parentFiles[index].Id)
				.withName(namePrefix + index + '.docx')
				.withType(DOCX_MIME_TYPE)
				.withSize(2048)
				.withDriveId('GD_' + namePrefix + index)
				.build());
		}
		insert versions;
		Formula.recalculateFormulas(versions);
		return versions;
	}

	private static List<String> describeChain(GQueueableChain chain) {
		List<String> jobNames = new List<String>();
		for (GQueueableJob chainedJob : chain.getJobs()) {
			if (chainedJob instanceof GoogleFileVersionPreviewJob) jobNames.add(PREVIEW);
			else if (chainedJob instanceof GoogleFileCloudFolderJob) jobNames.add(FOLDER);
			else if (chainedJob instanceof GoogleFileVersionSummaryJob) jobNames.add(SUMMARY);
			else if (chainedJob instanceof GoogleFileVersionLabelJob) jobNames.add(LABEL);
			else jobNames.add(chainedJob.className);
		}

		return jobNames;
	}

	@IsTest
	private static void testExecutePositiveChainsFolderBeforeSummary() {
		applyAnalysisConfig('{User}');
		List<GoogleFileVersion__c> versions = createNewVersions('FINORD', 1);
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Test.startTest();
		new GoogleFileInsertFinalizeCommand().execute(versions);
		Test.stopTest();

		List<String> jobNames = describeChain(runningChain);
		Assert.areEqual(new List<String>{ PREVIEW, FOLDER, SUMMARY, LABEL }, jobNames, 'A file reaches its folder before any AI call, so a slow or retried summary never holds it in the wrong place');
	}

	@IsTest
	private static void testExecutePositiveChainsLabelLast() {
		applyAnalysisConfig('{User}');
		List<GoogleFileVersion__c> versions = createNewVersions('FINLBL', 1);
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Test.startTest();
		new GoogleFileInsertFinalizeCommand().execute(versions);
		Test.stopTest();

		List<String> jobNames = describeChain(runningChain);
		Assert.isFalse(jobNames.isEmpty());
		Assert.areEqual(LABEL, jobNames[jobNames.size() - 1]);
		Assert.isTrue(jobNames.indexOf(SUMMARY) < jobNames.indexOf(LABEL));
	}

	@IsTest
	private static void testExecutePositiveWithoutFolderStructureKeepsTheAnalysisOrder() {
		applyAnalysisConfig(null);
		List<GoogleFileVersion__c> versions = createNewVersions('FINNOF', 1);
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Test.startTest();
		new GoogleFileInsertFinalizeCommand().execute(versions);
		Test.stopTest();

		Assert.areEqual(new List<String>{ PREVIEW, SUMMARY, LABEL }, describeChain(runningChain));
	}

	@IsTest
	private static void testExecutePositiveSkippedAnalysisChainsNoSummaryOrLabel() {
		applyAnalysisConfig('{User}');
		List<GoogleFileVersion__c> versions = createNewVersions('FINSKP', 1);
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Test.startTest();
		GoogleFileInsertFinalizeCommand.skipIntelligenceForThisTransaction();
		new GoogleFileInsertFinalizeCommand().execute(versions);
		Test.stopTest();

		Assert.areEqual(new List<String>{ PREVIEW, FOLDER }, describeChain(runningChain), 'A migrated file keeps its copy and folder and is never analyzed');
		GoogleFileVersionPreviewJob previewJob = (GoogleFileVersionPreviewJob) runningChain.getJobs()[0];
		Assert.areEqual(false, previewJob.chainIntelligence);
	}

	@IsTest
	private static void testExecutePositiveElevenVersionsChainInTwoChunks() {
		applyAnalysisConfig('{User}');
		List<GoogleFileVersion__c> versions = createNewVersions('FINCHK', 11);
		GQueueableChain runningChain = GoogleCloudTestFactory.runningChain();

		Test.startTest();
		new GoogleFileInsertFinalizeCommand().execute(versions);
		Test.stopTest();

		Assert.areEqual(new List<String>{ PREVIEW, FOLDER, SUMMARY, LABEL, PREVIEW, FOLDER, SUMMARY, LABEL }, describeChain(runningChain), 'Every chunk of ten keeps the same order');
		GoogleFileVersionPreviewJob firstPreviewJob = (GoogleFileVersionPreviewJob) runningChain.getJobs()[0];
		GoogleFileVersionPreviewJob secondPreviewJob = (GoogleFileVersionPreviewJob) runningChain.getJobs()[4];
		Assert.areEqual(10, firstPreviewJob.versionIds.size());
		Assert.areEqual(1, secondPreviewJob.versionIds.size());
		GoogleFileVersionSummaryJob firstSummaryJob = (GoogleFileVersionSummaryJob) runningChain.getJobs()[2];
		Assert.areEqual(1, firstSummaryJob.attempt, 'An upload starts its analysis at the first attempt');
	}
}
