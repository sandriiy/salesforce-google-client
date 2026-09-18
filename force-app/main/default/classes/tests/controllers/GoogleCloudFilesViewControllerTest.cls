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
private class GoogleCloudFilesViewControllerTest {
	@IsTest
	private static void testFetchFileHeaderDetailsPositiveNullId() {
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		GoogleFileHeaderInfoDTO headerInfo = GoogleCloudFilesViewController.fetchFileHeaderDetails(null);
		Test.stopTest();

		Assert.areNotEqual(null, headerInfo);
		Assert.areEqual(null, headerInfo.name);
		Assert.areNotEqual(null, headerInfo.compactFields);
		Assert.areEqual(0, headerInfo.compactFields.size());
	}

	@IsTest
	private static void testFetchFileHeaderDetailsPositiveMissing() {
		GoogleCloudTestFactory.initMocks();

		try {
			Test.startTest();
			GoogleCloudFilesViewController.fetchFileHeaderDetails('a0B000000000001AAA');
			Test.stopTest();
			Assert.isTrue(false);
		} catch (Exception ex) {
			Assert.isTrue(String.isNotBlank(ex.getMessage()));
		}
	}

	@IsTest
	private static void testFetchFileHeaderDetailsPositive() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c localFile = GoogleCloudTestFactory.file()
			.withName('HDR1')
			.withDescription('D')
			.insertRecord();

		GSOQL.mock(GoogleFileSelector.MOCK_ID).thenReturn(new List<SObject>{
			new GoogleFile__c(Id = localFile.Id, Name = localFile.Name, OwnerId = UserInfo.getUserId())
		});

		Test.startTest();
		GoogleFileHeaderInfoDTO headerInfo = GoogleCloudFilesViewController.fetchFileHeaderDetails(localFile.Id);
		Test.stopTest();

		Assert.areNotEqual(null, headerInfo);
	}

	@IsTest
	private static void testRetrieveLocalGoogleFileVersionsPositive() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('VER_PARENT')
			.withDescription('D')
			.insertRecord();

		GoogleFileVersion__c firstVersion = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('V1.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId('GD1')
			.withDocsId('DOCS1')
			.insertRecord();

		GSOQL.mock(GoogleFileVersionSelector.MOCK_ID).thenReturn(new List<SObject>{
			new GoogleFileVersion__c(Id = firstVersion.Id, Name = firstVersion.Name, GoogleFileId__c = parentFile.Id)
		});

		Test.startTest();
		List<GoogleFileVersion__c> fileVersions = GoogleCloudFilesViewController.retrieveLocalGoogleFileVersions(parentFile.Id);
		Test.stopTest();

		Assert.areNotEqual(null, fileVersions);
		Assert.areEqual(1, fileVersions.size());
		Assert.areEqual(firstVersion.Id, fileVersions[0].Id);
	}

	@IsTest
	private static void testRetrieveLocalGoogleFileLabelsPositive() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c parentFile = GoogleCloudTestFactory.file()
			.withName('VIEWLBL1')
			.insertRecord();
		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('VIEWLBL1.pdf')
			.withType('application/pdf')
			.withSize(10)
			.insertRecord();
		GoogleCloudTestFactory.versionLabel()
			.forVersion(version.Id)
			.withName('Invoice')
			.withDriveLabelId('LABEL_INVOICE')
			.withConfidence(95)
			.insertRecord();

		List<GoogleFileVersionLabelDTO> labels;
		Test.startTest();
			labels = GoogleCloudFilesViewController.retrieveLocalGoogleFileLabels(parentFile.Id);
		Test.stopTest();

		Assert.areEqual(1, labels.size());
		Assert.areEqual('Invoice', labels[0].name);
		Assert.areEqual(95, labels[0].confidence);
		Assert.areEqual('VIEWLBL1.pdf', labels[0].versionName);
	}

	@IsTest
	private static void testRetrieveLocalGoogleFileLabelsNegativeNoAccess() {
		GoogleCloudTestFactory.initMocks();

		try {
			Test.startTest();
			GoogleCloudFilesViewController.retrieveLocalGoogleFileLabels('a08000000000001AAA');
			Test.stopTest();
			Assert.fail('Labels of an unreachable file must not be returned');
		} catch (Exception ex) {
			Assert.isTrue(String.isNotBlank(ex.getMessage()));
		}
	}

	@IsTest
	private static void testRetrieveLocalGoogleFileVersionsNegativeNoAccess() {
		GoogleCloudTestFactory.initMocks();

		try {
			Test.startTest();
			GoogleCloudFilesViewController.retrieveLocalGoogleFileVersions('a0B000000000001AAA');
			Test.stopTest();
			Assert.isTrue(false);
		} catch (Exception ex) {
			Assert.isTrue(String.isNotBlank(ex.getMessage()));
		}
	}
}