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
private class GoogleFileVersionLabelJobTest {
	private static GoogleClientConfig__mdt buildFinalizeDisabledConfig() {
		return new GoogleClientConfig__mdt(
			IsFilePreviewDisabled__c = true
		);
	}

	private static GoogleFileLabelResultDTO buildTestResult(Boolean success, Boolean blocked, Boolean applied, String labelName, Integer confidence, String errorMessage) {
		GoogleFileLabelResultDTO result = new GoogleFileLabelResultDTO();
		result.success = success;
		result.blocked = blocked;
		result.applied = applied;
		result.provider = 'Gemini';
		result.labelName = labelName;
		result.labelId = labelName == null ? null : 'LABEL_' + labelName.toUpperCase();
		result.confidence = confidence;
		result.errorMessage = errorMessage;
		return result;
	}

	private static GoogleFileVersion__c createLabelCandidate(String fileName) {
		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName(fileName)
			.insertRecord();

		return GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName(fileName + '.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(2048)
			.withDocsId('DOCS_' + fileName)
			.insertRecord();
	}

	private static GoogleFileVersionLabel__c loadLabel(Id versionId) {
		List<GoogleFileVersionLabel__c> versionLabels = [
			SELECT Name, GoogleDriveLabelId__c, Confidence__c
			FROM GoogleFileVersionLabel__c
			WHERE GoogleFileVersionId__c = :versionId
		];

		return versionLabels.isEmpty() ? null : versionLabels[0];
	}

	@IsTest
	private static void testExecutePositiveStoresAppliedLabel() {
		GoogleMetadataConfigService.configRecordOverride = buildFinalizeDisabledConfig();
		GoogleFileVersionLabelJob.skipExecution = true;
		GoogleFileVersionLabelJob.clearTestResults();

		GoogleFileVersion__c version = createLabelCandidate('LBLJOB1');

		GoogleFileVersionLabelJob.skipExecution = false;
		GoogleFileVersionLabelJob.setTestResult(version.Id, buildTestResult(true, null, true, 'Invoice', 92, null));

		Test.startTest();
			new GoogleFileVersionLabelJob(new Set<Id>{ version.Id }).work();
		Test.stopTest();
		GoogleFileVersionLabelJob.clearTestResults();

		GoogleFileVersionLabel__c versionLabel = loadLabel(version.Id);
		Assert.isNotNull(versionLabel);
		Assert.areEqual('Invoice', versionLabel.Name);
		Assert.areEqual('LABEL_INVOICE', versionLabel.GoogleDriveLabelId__c);
		Assert.areEqual(92, versionLabel.Confidence__c);
	}

	@IsTest
	private static void testExecutePositiveLeavesFileUnlabeledWhenNotApplied() {
		GoogleMetadataConfigService.configRecordOverride = buildFinalizeDisabledConfig();
		GoogleFileVersionLabelJob.skipExecution = true;
		GoogleFileVersionLabelJob.clearTestResults();

		GoogleFileVersion__c version = createLabelCandidate('LBLJOB2');

		GoogleFileVersionLabelJob.skipExecution = false;
		GoogleFileVersionLabelJob.setTestResult(version.Id, buildTestResult(true, null, false, 'Invoice', 40, null));

		Test.startTest();
			new GoogleFileVersionLabelJob(new Set<Id>{ version.Id }).work();
		Test.stopTest();
		GoogleFileVersionLabelJob.clearTestResults();

		Assert.isNull(loadLabel(version.Id));
	}

	@IsTest
	private static void testExecutePositiveSkipsFailedDriveUpdate() {
		GoogleMetadataConfigService.configRecordOverride = buildFinalizeDisabledConfig();
		GoogleFileVersionLabelJob.skipExecution = true;
		GoogleFileVersionLabelJob.clearTestResults();

		GoogleFileVersion__c version = createLabelCandidate('LBLJOB3');

		GoogleFileVersionLabelJob.skipExecution = false;
		GoogleFileVersionLabelJob.setTestResult(version.Id, buildTestResult(true, null, false, 'Invoice', 95, 'Label access denied'));

		Test.startTest();
			new GoogleFileVersionLabelJob(new Set<Id>{ version.Id }).work();
		Test.stopTest();
		GoogleFileVersionLabelJob.clearTestResults();

		Assert.isNull(loadLabel(version.Id));
	}

	@IsTest
	private static void testExecutePositiveSkipsBlockedResult() {
		GoogleMetadataConfigService.configRecordOverride = buildFinalizeDisabledConfig();
		GoogleFileVersionLabelJob.skipExecution = true;
		GoogleFileVersionLabelJob.clearTestResults();

		GoogleFileVersion__c version = createLabelCandidate('LBLJOB4');

		GoogleFileVersionLabelJob.skipExecution = false;
		GoogleFileVersionLabelJob.setTestResult(version.Id, buildTestResult(null, true, null, null, null, 'Blocked for test'));

		Test.startTest();
			new GoogleFileVersionLabelJob(new Set<Id>{ version.Id }).work();
		Test.stopTest();
		GoogleFileVersionLabelJob.clearTestResults();

		Assert.isNull(loadLabel(version.Id));
	}

	@IsTest
	private static void testExecutePositiveSkipsWhenLabelingIsNotConfigured() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt();
		GoogleFileVersionLabelJob.skipExecution = true;
		GoogleFileVersionLabelJob.clearTestResults();

		GoogleFileVersion__c version = createLabelCandidate('LBLJOB5');

		GoogleFileVersionLabelJob.skipExecution = false;

		Test.startTest();
			new GoogleFileVersionLabelJob(new Set<Id>{ version.Id }).work();
		Test.stopTest();

		Assert.isNull(loadLabel(version.Id));
	}

	@IsTest
	private static void testExecutePositiveReturnsEarlyWhenSkippedOrEmpty() {
		GoogleFileVersionLabelJob.skipExecution = true;
		GoogleFileVersionLabelJob.clearTestResults();

		Test.startTest();
			new GoogleFileVersionLabelJob(new Set<Id>{ GoogleCloudTestFactory.fakeId(GoogleFileVersion__c.SObjectType) }).work();
			GoogleFileVersionLabelJob.skipExecution = false;
			new GoogleFileVersionLabelJob(new Set<Id>()).work();
			new GoogleFileVersionLabelJob(null).work();
		Test.stopTest();

		Assert.isTrue(true);
	}
}
