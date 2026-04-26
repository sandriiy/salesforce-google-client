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
private class GoogleLocalFileVersionPublicLinkServTest {
	@IsTest
	private static void testApplyPublicLinkSharingPositive() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('PL1')
			.withDescription('D')
			.insertRecord();

		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('V1.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId('GD_PL_1')
			.withDocsId('DOCS_PL_1')
			.insertRecord();

		Datetime expirationDate = System.now().addDays(1);

		Test.startTest();
		List<GoogleFileVersion__c> updatedVersions = new GoogleLocalFileVersionPublicLinkService()
			.applyPublicLinkSharing(localFileVersion.Id, expirationDate, false);
		Test.stopTest();

		Assert.areEqual(1, updatedVersions.size());
		Assert.isTrue(String.isNotBlank(updatedVersions[0].PublicLink__c));
		Assert.areEqual(expirationDate, updatedVersions[0].PublicLinkExpirationDate__c);
		Assert.isTrue(String.isNotBlank(updatedVersions[0].PublicLinkPermissionId__c));
		Assert.areEqual('Active', updatedVersions[0].PublicLinkStatus__c);
	}

	@IsTest
	private static void testApplyPublicLinkSharingPositiveSkipDomain() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('PL2')
			.withDescription('D')
			.insertRecord();

		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('V2.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId('GD_PL_2')
			.withDocsId('DOCS_PL_2')
			.insertRecord();

		Test.startTest();
		List<GoogleFileVersion__c> updatedVersions = new GoogleLocalFileVersionPublicLinkService()
			.applyPublicLinkSharing(localFileVersion.Id, null, true);
		Test.stopTest();

		Assert.areEqual(1, updatedVersions.size());
		Assert.areEqual('Active', updatedVersions[0].PublicLinkStatus__c);
	}

	@IsTest
	private static void testRemovePublicLinkSharingPositive() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('PL3')
			.withDescription('D')
			.insertRecord();

		GoogleFileVersion__c localFileVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('V3.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId('GD_PL_3')
			.withDocsId('DOCS_PL_3')
			.insertRecord();

		Datetime expirationDate = System.now().addDays(1);

		localFileVersion.PublicLink__c = 'https://example.com/view';
		localFileVersion.PublicLinkExpirationDate__c = expirationDate;
		localFileVersion.PublicLinkPermissionId__c = 'PERM_123';
		localFileVersion.PublicLinkStatus__c = 'Active';
		update localFileVersion;

		Test.startTest();
		List<GoogleFileVersion__c> updatedVersions =
			new GoogleLocalFileVersionPublicLinkService().removePublicLinkSharing(localFileVersion.Id);
		Test.stopTest();

		Assert.areEqual(1, updatedVersions.size());
		Assert.areEqual(null, updatedVersions[0].PublicLink__c);
		Assert.areEqual(null, updatedVersions[0].PublicLinkExpirationDate__c);
		Assert.areEqual(null, updatedVersions[0].PublicLinkPermissionId__c);
		Assert.areEqual('None', updatedVersions[0].PublicLinkStatus__c);
	}
}