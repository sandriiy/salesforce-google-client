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
private class GoogleFileVersionLabelSelectorTest {
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

	@IsTest
	private static void testWithBaseFieldsByParentIdReturnsLabelsOfThatVersionOnly() {
		GoogleFileVersion__c labeledVersion = createVersion('SEL_LBL_1');
		GoogleFileVersion__c otherVersion = createVersion('SEL_LBL_2');

		GoogleFileVersionLabel__c versionLabel = GoogleCloudTestFactory.versionLabel()
			.forVersion(labeledVersion.Id)
			.withName('Invoice')
			.withDriveLabelId('LABEL_INVOICE')
			.withConfidence(92)
			.insertRecord();
		GoogleCloudTestFactory.versionLabel()
			.forVersion(otherVersion.Id)
			.withName('Contract')
			.withDriveLabelId('LABEL_CONTRACT')
			.withConfidence(85)
			.insertRecord();

		List<GoogleFileVersionLabel__c> versionLabels = (List<GoogleFileVersionLabel__c>) GoogleFileVersionLabelSelector.query()
			.withBaseFields()
			.byParentId(labeledVersion.Id)
			.toList();

		Assert.areEqual(1, versionLabels.size());
		Assert.areEqual(versionLabel.Id, versionLabels[0].Id);
		Assert.areEqual('Invoice', versionLabels[0].Name);
		Assert.areEqual('LABEL_INVOICE', versionLabels[0].GoogleDriveLabelId__c);
		Assert.areEqual(92, versionLabels[0].Confidence__c);
		Assert.areEqual(labeledVersion.Id, versionLabels[0].GoogleFileVersionId__c);
	}

	@IsTest
	private static void testByParentIdsOrdersNewestFirstAndHonorsLimit() {
		GoogleFileVersion__c firstVersion = createVersion('SEL_LBL_3');
		GoogleFileVersion__c secondVersion = createVersion('SEL_LBL_4');

		GoogleCloudTestFactory.versionLabel().forVersion(firstVersion.Id).withName('Invoice').insertRecord();
		GoogleCloudTestFactory.versionLabel().forVersion(secondVersion.Id).withName('Contract').insertRecord();

		List<GoogleFileVersionLabel__c> versionLabels = (List<GoogleFileVersionLabel__c>) GoogleFileVersionLabelSelector.query()
			.withBaseFields()
			.byParentIds(new Set<Id>{ firstVersion.Id, secondVersion.Id })
			.orderByCreatedDesc()
			.toList();

		Assert.areEqual(2, versionLabels.size());
		Assert.isTrue(versionLabels[0].CreatedDate >= versionLabels[1].CreatedDate);

		List<GoogleFileVersionLabel__c> limitedLabels = (List<GoogleFileVersionLabel__c>) GoogleFileVersionLabelSelector.query()
			.withBaseFields()
			.byParentIds(new Set<Id>{ firstVersion.Id, secondVersion.Id })
			.limitTo(1)
			.toList();

		Assert.areEqual(1, limitedLabels.size());
	}

	@IsTest
	private static void testDeletingTheVersionRemovesItsLabels() {
		GoogleFileVersion__c version = createVersion('SEL_LBL_5');
		GoogleCloudTestFactory.versionLabel().forVersion(version.Id).withName('Invoice').insertRecord();

		delete version;

		Assert.areEqual(0, GoogleFileVersionLabelSelector.query().withBaseFields().byParentId(version.Id).toList().size());
	}
}
