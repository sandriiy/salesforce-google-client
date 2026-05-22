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
private class GoogleFileVersionSelectorTest {
	@IsTest
	private static void testWithBaseFieldsByParentIdOrdersNewestFirst() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(IsFilePreviewDisabled__c = true);

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('SEL_PARENT_1')
			.insertRecord();

		GoogleFileVersion__c firstVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('SEL_BASE_1.pdf')
			.withType('application/pdf')
			.withSize(10)
			.insertRecord();

		GoogleFileVersion__c secondVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('SEL_BASE_2.pdf')
			.withType('application/pdf')
			.withSize(20)
			.insertRecord();

		List<GoogleFileVersion__c> versions = (List<GoogleFileVersion__c>) GoogleFileVersionSelector.query()
			.withBaseFields()
			.byParentId(parentFile.Id)
			.orderByCreatedDesc()
			.toList();

		Assert.areEqual(2, versions.size());
		Assert.areEqual(new Set<Id>{ firstVersion.Id, secondVersion.Id }, new Map<Id, GoogleFileVersion__c>(versions).keySet());
		Assert.isTrue(versions[0].CreatedDate >= versions[1].CreatedDate);
		Assert.isTrue(String.isNotBlank(versions[0].Name));
		Assert.isTrue(versions[0].Size__c != null);
		Assert.isTrue(String.isNotBlank(versions[0].Type__c));
	}

	@IsTest
	private static void testWithAdvancedFieldsReturnsConfidentialFields() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(IsFilePreviewDisabled__c = true);

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('SEL_PARENT_2')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('SEL_ADV_1.docx')
			.withType('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
			.withSize(30)
			.withDriveId('GD_SEL_ADV_1')
			.withDocsId('DOCS_SEL_ADV_1')
			.insertRecord();

		update new GoogleFileVersion__c(
			Id = version.Id,
			GoogleDriveFolderId__c = 'FOLDER_SEL_ADV_1',
			Summary__c = 'Selector summary text'
		);

		GoogleFileVersion__c queriedVersion = (GoogleFileVersion__c) GoogleFileVersionSelector.query()
			.withAdvancedFields()
			.byId(version.Id)
			.toObject();

		Assert.areEqual('GD_SEL_ADV_1', queriedVersion.GoogleDriveFileId__c);
		Assert.areEqual('DOCS_SEL_ADV_1', queriedVersion.GoogleDocsFileId__c);
		Assert.areEqual('FOLDER_SEL_ADV_1', queriedVersion.GoogleDriveFolderId__c);
		Assert.areEqual('Selector summary text', queriedVersion.Summary__c);
	}

	@IsTest
	private static void testWithSharingFieldsReturnsSharingFields() {
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(IsFilePreviewDisabled__c = true);

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('SEL_PARENT_3')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('SEL_SHARE_1.pdf')
			.withType('application/pdf')
			.withSize(40)
			.insertRecord();

		update new GoogleFileVersion__c(
			Id = version.Id,
			PublicLink__c = 'https://example.com/file',
			PublicLinkPermissionId__c = 'perm_1',
			PublicLinkExpirationDate__c = System.now().addDays(5)
		);

		GoogleFileVersion__c queriedVersion = (GoogleFileVersion__c) GoogleFileVersionSelector.query()
			.withSharingFields()
			.byId(version.Id)
			.toObject();

		Assert.areEqual('https://example.com/file', queriedVersion.PublicLink__c);
		Assert.areEqual('perm_1', queriedVersion.PublicLinkPermissionId__c);
		Assert.isNotNull(queriedVersion.PublicLinkExpirationDate__c);
	}
}