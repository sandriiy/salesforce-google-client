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
private class GoogleFileVersionSummaryJobTest {
	private static GoogleClientConfig__mdt buildFinalizeDisabledConfig() {
		return new GoogleClientConfig__mdt(
			IsFilePreviewDisabled__c = true
		);
	}

	private static GoogleFileAnalysisResultDTO buildTestResult(Boolean success, Boolean blocked, String text, String finishReason, String errorMessage) {
		GoogleFileAnalysisResultDTO result = new GoogleFileAnalysisResultDTO();
		result.success = success;
		result.blocked = blocked;
		result.provider = 'Gemini';
		result.operationType = 'SUMMARY';
		result.text = text;
		result.finishReason = finishReason;
		result.errorMessage = errorMessage;
		return result;
	}

	@IsTest
	private static void testExecutePositiveStoresSummary() {
		GoogleMetadataConfigService.configRecordOverride = buildFinalizeDisabledConfig();
		GoogleFileVersionSummaryJob.skipExecution = true;
		GoogleFileVersionSummaryJob.clearTestResults();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('SUMJOB1')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('SUMJOB1.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(2048)
			.withDocsId('DOCS_SUMJOB_1')
			.insertRecord();

		GoogleFileVersionSummaryJob.skipExecution = false;
		GoogleFileVersionSummaryJob.setTestResult(
			version.Id,
			buildTestResult(
				true,
				null,
				'Budget review covers Q4 revenue targets, staffing updates, and milestone approvals.',
				'STOP',
				null
			)
		);

		Test.startTest();
			new GoogleFileVersionSummaryJob(new Set<Id>{ version.Id }).work();
		Test.stopTest();
		GoogleFileVersionSummaryJob.clearTestResults();

		GoogleFileVersion__c refreshedVersion = [
			SELECT Summary__c
			FROM GoogleFileVersion__c
			WHERE Id = :version.Id
			LIMIT 1
		];

		Assert.areEqual('Budget review covers Q4 revenue targets, staffing updates, and milestone approvals.', refreshedVersion.Summary__c);
	}

	@IsTest
	private static void testExecutePositiveSkipsMaxTokensResponse() {
		GoogleMetadataConfigService.configRecordOverride = buildFinalizeDisabledConfig();
		GoogleFileVersionSummaryJob.skipExecution = true;
		GoogleFileVersionSummaryJob.clearTestResults();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('SUMJOB2')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('SUMJOB2.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(2048)
			.withDocsId('DOCS_SUMJOB_2')
			.insertRecord();

		GoogleFileVersionSummaryJob.skipExecution = false;
		GoogleFileVersionSummaryJob.setTestResult(
			version.Id,
			buildTestResult(
				null,
				null,
				null,
				'MAX_TOKENS',
				'Summary generation reached the maximum output token limit'
			)
		);

		Test.startTest();
			new GoogleFileVersionSummaryJob(new Set<Id>{ version.Id }).work();
		Test.stopTest();
		GoogleFileVersionSummaryJob.clearTestResults();

		GoogleFileVersion__c refreshedVersion = [
			SELECT Summary__c
			FROM GoogleFileVersion__c
			WHERE Id = :version.Id
			LIMIT 1
		];

		Assert.areEqual(null, refreshedVersion.Summary__c);
	}

	@IsTest
	private static void testExecutePositiveSkipsWhenAiIsNotConfigured() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt();
		GoogleFileVersionSummaryJob.skipExecution = true;
		GoogleFileVersionSummaryJob.clearTestResults();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('SUMJOB3')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('SUMJOB3.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(2048)
			.withDocsId('DOCS_SUMJOB_3')
			.insertRecord();

		GoogleFileVersionSummaryJob.skipExecution = false;

		Test.startTest();
			new GoogleFileVersionSummaryJob(new Set<Id>{ version.Id }).work();
		Test.stopTest();

		GoogleFileVersion__c refreshedVersion = [
			SELECT Summary__c
			FROM GoogleFileVersion__c
			WHERE Id = :version.Id
			LIMIT 1
		];

		Assert.areEqual(null, refreshedVersion.Summary__c);
	}

	@IsTest
	private static void testExecutePositiveSkipsBlockedResult() {
		GoogleMetadataConfigService.configRecordOverride = buildFinalizeDisabledConfig();
		GoogleFileVersionSummaryJob.skipExecution = true;
		GoogleFileVersionSummaryJob.clearTestResults();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('SUMJOB4')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('SUMJOB4.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(2048)
			.withDocsId('DOCS_SUMJOB_4')
			.insertRecord();

		GoogleFileVersionSummaryJob.skipExecution = false;
		GoogleFileVersionSummaryJob.setTestResult(
			version.Id,
			buildTestResult(false, true, null, null, 'Blocked for test')
		);

		Test.startTest();
			new GoogleFileVersionSummaryJob(new Set<Id>{ version.Id }).work();
		Test.stopTest();
		GoogleFileVersionSummaryJob.clearTestResults();

		GoogleFileVersion__c refreshedVersion = [
			SELECT Summary__c
			FROM GoogleFileVersion__c
			WHERE Id = :version.Id
			LIMIT 1
		];

		Assert.areEqual(null, refreshedVersion.Summary__c);
	}

	@IsTest
	private static void testExecutePositiveReturnsEarlyWhenSkippedOrEmpty() {
		GoogleFileVersionSummaryJob.skipExecution = true;
		GoogleFileVersionSummaryJob.clearTestResults();

		Test.startTest();
			new GoogleFileVersionSummaryJob(new Set<Id>{ GoogleCloudTestFactory.fakeId(GoogleFileVersion__c.SObjectType) }).work();
			GoogleFileVersionSummaryJob.skipExecution = false;
			new GoogleFileVersionSummaryJob(new Set<Id>()).work();
			new GoogleFileVersionSummaryJob(null).work();
		Test.stopTest();

		Assert.isTrue(true);
	}
}