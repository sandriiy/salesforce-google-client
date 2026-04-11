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
private class GoogleFileEditDetailsActionTest {
	@IsTest
	private static void testEditDetailsPositive() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c localFile = GoogleCloudTestFactory.file()
			.withName('ED1.pdf')
			.withDescription('D')
			.insertRecord();

		GoogleFileVersion__c localVersion = GoogleCloudTestFactory.version()
			.forFile(localFile.Id)
			.withName('V1.pdf')
			.withType('application/pdf')
			.withSize(1)
			.withDriveId('GD_ED_1')
			.withDocsId('DOCS_ED_1')
			.insertRecord();

		GoogleFileEditDetailsAction.Input input = new GoogleFileEditDetailsAction.Input();
		input.localFileRecord = localFile;
		input.localFileVersionRecord = localVersion;
		input.newFileName = 'Renamed';
		input.newFileVersionName = 'Renamed.pdf';
		input.newFileDescription = 'Updated description';

		Test.startTest();
		GoogleFileEditDetailsAction.editDetails(new List<GoogleFileEditDetailsAction.Input>{ input });
		Test.stopTest();

		GoogleFile__c updatedFile = [SELECT Name, Description__c FROM GoogleFile__c WHERE Id = :localFile.Id];
		Assert.areEqual('Renamed.pdf', updatedFile.Name);
		Assert.areEqual('Updated description', updatedFile.Description__c);
	}

	@IsTest
	private static void testEditDetailsPositiveNullInputs() {
		Test.startTest();
		GoogleFileEditDetailsAction.editDetails(null);
		Test.stopTest();

		Assert.isTrue(true);
	}

	@IsTest
	private static void testEditDetailsPositiveEmptyInputs() {
		Test.startTest();
		GoogleFileEditDetailsAction.editDetails(new List<GoogleFileEditDetailsAction.Input>());
		Test.stopTest();

		Assert.isTrue(true);
	}
}
