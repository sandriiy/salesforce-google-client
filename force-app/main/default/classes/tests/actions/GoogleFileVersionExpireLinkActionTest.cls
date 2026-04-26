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
private class GoogleFileVersionExpireLinkActionTest {
	@IsTest
	private static void testExpireLinkPositive() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('EL1')
			.withDescription('D')
			.insertRecord();

		GoogleFileVersion__c localVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('V1.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId('GD_EL_1')
			.withDocsId('DOCS_EL_1')
			.insertRecord();

		localVersion.PublicLink__c = 'https://example.com/view';
		localVersion.PublicLinkExpirationDate__c = System.now().addDays(1);
		localVersion.PublicLinkPermissionId__c = 'PERM_EL';
		localVersion.PublicLinkStatus__c = 'Active';
		update localVersion;

		GoogleFileVersionExpireLinkAction.Input input = new GoogleFileVersionExpireLinkAction.Input();
		input.localFileRecordId = localVersion.Id;

		Test.startTest();
		GoogleFileVersionExpireLinkAction.expireLink(new List<GoogleFileVersionExpireLinkAction.Input>{ input });
		Test.stopTest();

		GoogleFileVersion__c reloaded = [
			SELECT PublicLink__c, PublicLinkStatus__c
			FROM GoogleFileVersion__c
			WHERE Id = :localVersion.Id
			LIMIT 1
		];
		Assert.areEqual(null, reloaded.PublicLink__c);
		Assert.areEqual('None', reloaded.PublicLinkStatus__c);
	}

	@IsTest
	private static void testExpireLinkPositiveNullInputs() {
		Test.startTest();
		GoogleFileVersionExpireLinkAction.expireLink(null);
		Test.stopTest();

		Assert.isTrue(true);
	}

	@IsTest
	private static void testExpireLinkPositiveEmptyInputs() {
		Test.startTest();
		GoogleFileVersionExpireLinkAction.expireLink(new List<GoogleFileVersionExpireLinkAction.Input>());
		Test.stopTest();

		Assert.isTrue(true);
	}
}
