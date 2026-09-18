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
private class GoogleLocalFileVersionLabelServiceTest {
	private static final Integer LABEL_NAME_LENGTH = 80;

	private static GoogleFileVersion__c createVersion(String fileName) {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(IsFilePreviewDisabled__c = true);
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName(fileName)
			.insertRecord();

		return GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName(fileName + '.pdf')
			.withType('application/pdf')
			.withSize(10)
			.insertRecord();
	}

	private static GoogleFileVersionLabel__c addLabel(Id versionId, String labelName) {
		return GoogleCloudTestFactory.versionLabel()
			.forVersion(versionId)
			.withName(labelName)
			.withDriveLabelId('LABEL_' + labelName.left(10).toUpperCase())
			.withConfidence(90)
			.insertRecord();
	}

	private static String loadLabelNames(Id versionId) {
		return [SELECT AiLabels__c FROM GoogleFileVersion__c WHERE Id = :versionId LIMIT 1].AiLabels__c;
	}

	@IsTest
	private static void testSyncLabelNamesPositiveFollowsInsertsAndDeletes() {
		GoogleFileVersion__c version = createVersion('LBLSVC1');

		GoogleFileVersionLabel__c invoiceLabel = addLabel(version.Id, 'Invoice');
		Assert.areEqual('Invoice', loadLabelNames(version.Id));

		GoogleFileVersionLabel__c contractLabel = addLabel(version.Id, 'Contract');
		Assert.areEqual('Invoice; Contract', loadLabelNames(version.Id));

		delete invoiceLabel;
		Assert.areEqual('Contract', loadLabelNames(version.Id));

		delete contractLabel;
		Assert.isNull(loadLabelNames(version.Id));
	}

	@IsTest
	private static void testSyncLabelNamesPositiveFollowsRenamesOnly() {
		GoogleFileVersion__c version = createVersion('LBLSVC7');
		GoogleFileVersionLabel__c versionLabel = addLabel(version.Id, 'Invoice');

		versionLabel.Confidence__c = 55;
		update versionLabel;
		Assert.areEqual('Invoice', loadLabelNames(version.Id));

		versionLabel.Name = 'Receipt';
		update versionLabel;
		Assert.areEqual('Receipt', loadLabelNames(version.Id));
	}

	@IsTest
	private static void testSyncLabelNamesPositiveSurvivesDeletingTheLabeledFile() {
		GoogleFileVersion__c version = createVersion('LBLSVC6');
		addLabel(version.Id, 'Invoice');
		Assert.areEqual('Invoice', loadLabelNames(version.Id));

		Test.startTest();
			delete new GoogleFile__c(Id = version.GoogleFileId__c);
		Test.stopTest();

		Assert.areEqual(0, [SELECT COUNT() FROM GoogleFileVersion__c WHERE Id = :version.Id]);
		Assert.areEqual(0, GoogleFileVersionLabelSelector.query().withBaseFields().byParentId(version.Id).toList().size());
	}

	@IsTest
	private static void testSyncLabelNamesPositiveStopsAtFieldLength() {
		GoogleFileVersion__c version = createVersion('LBLSVC2');

		List<String> labelNames = new List<String>();
		for (Integer index = 0; index < 4; index++) {
			labelNames.add(String.valueOf(index).leftPad(LABEL_NAME_LENGTH, 'x'));
		}

		List<GoogleFileVersionLabel__c> versionLabels = new List<GoogleFileVersionLabel__c>();
		for (String labelName : labelNames) {
			versionLabels.add(GoogleCloudTestFactory.versionLabel().forVersion(version.Id).withName(labelName).build());
		}

		Test.startTest();
			insert versionLabels;
		Test.stopTest();

		String storedNames = loadLabelNames(version.Id);
		Assert.isTrue(storedNames.length() <= 255);
		Assert.areEqual(String.join(new List<String>{ labelNames[0], labelNames[1], labelNames[2] }, '; '), storedNames);
	}

	@IsTest
	private static void testRetrieveLabelsForFilePositive() {
		GoogleFileVersion__c version = createVersion('LBLSVC3');
		GoogleFileVersionLabel__c versionLabel = addLabel(version.Id, 'Invoice');

		List<GoogleFileVersionLabelDTO> labels;
		Test.startTest();
			labels = new GoogleLocalFileVersionLabelService().retrieveLabelsForFile(version.GoogleFileId__c);
		Test.stopTest();

		Assert.areEqual(1, labels.size());
		Assert.areEqual(versionLabel.Id, labels[0].id);
		Assert.areEqual('Invoice', labels[0].name);
		Assert.areEqual(90, labels[0].confidence);
		Assert.areEqual(version.Id, labels[0].versionId);
		Assert.areEqual('LBLSVC3.pdf', labels[0].versionName);
		Assert.isTrue(labels[0].isLatestVersion);
		Assert.isNotNull(labels[0].appliedDate);
	}

	@IsTest
	private static void testRetrieveLabelsForFilePositiveNullId() {
		GoogleCloudTestFactory.initMocks();

		Assert.areEqual(0, new GoogleLocalFileVersionLabelService().retrieveLabelsForFile(null).size());
	}

	@IsTest
	private static void testRetrieveLabelsForFileNegativeNoAccess() {
		GoogleCloudTestFactory.initMocks();

		try {
			new GoogleLocalFileVersionLabelService().retrieveLabelsForFile(GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType));
			Assert.fail('A file the user cannot reach must not expose its labels');
		} catch (GoogleLocalFileVersionLabelService.GoogleLocalFileVersionLabelServiceException ex) {
			Assert.isTrue(ex.getMessage().contains('access'));
		}
	}
}
