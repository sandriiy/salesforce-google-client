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
private class GoogleFileUpdateCommandTest {
	@IsTest
	private static void testBuildPositiveRenameFile() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c file = GoogleCloudTestFactory.file()
			.withName('Old.pdf')
			.withDescription('desc')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(file.Id)
			.withName('Old.pdf')
			.withDriveId('GD_UP_1')
			.insertRecord();

		Test.startTest();
		GoogleFileUpdateCommand.GoogleFileUpdateResult result = new GoogleFileUpdateCommand(file, version)
			.changeFileNameTo('New')
			.changeFileVersionNameTo('Old')
			.build();
		Test.stopTest();

		Assert.isNotNull(result.localGoogleFileToUpdate);
		Assert.areEqual('New.pdf', result.localGoogleFileToUpdate.Name);
		Assert.isNull(result.localGoogleFileVersionToUpdate);
	}

	@IsTest
	private static void testBuildPositiveRenameVersion() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c file = GoogleCloudTestFactory.file()
			.withName('Same.pdf')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(file.Id)
			.withName('Old.pdf')
			.withDriveId('GD_UP_2')
			.insertRecord();

		Test.startTest();
		GoogleFileUpdateCommand.GoogleFileUpdateResult result = new GoogleFileUpdateCommand(file, version)
			.changeFileVersionNameTo('New')
			.build();
		Test.stopTest();

		Assert.isNotNull(result.localGoogleFileVersionToUpdate);
		Assert.areEqual('New.pdf', result.localGoogleFileVersionToUpdate.Name);
	}

	@IsTest
	private static void testBuildPositiveChangeDescription() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c file = GoogleCloudTestFactory.file()
			.withName('F.pdf')
			.withDescription('old')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(file.Id)
			.withName('F.pdf')
			.withDriveId('GD_UP_3')
			.insertRecord();

		Test.startTest();
		GoogleFileUpdateCommand.GoogleFileUpdateResult result = new GoogleFileUpdateCommand(file, version)
			.changeFileDescriptionTo('new desc')
			.build();
		Test.stopTest();

		Assert.isNotNull(result.localGoogleFileToUpdate);
		Assert.areEqual('new desc', result.localGoogleFileToUpdate.Description__c);
	}

	@IsTest
	private static void testBuildPositiveNoChanges() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c file = GoogleCloudTestFactory.file()
			.withName('Same.pdf')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(file.Id)
			.withName('Same.pdf')
			.withDriveId('GD_UP_4')
			.insertRecord();

		Test.startTest();
		GoogleFileUpdateCommand.GoogleFileUpdateResult result = new GoogleFileUpdateCommand(file, version)
			.changeFileNameTo('Same')
			.changeFileVersionNameTo('Same')
			.build();
		Test.stopTest();

		Assert.isNull(result.localGoogleFileToUpdate);
		Assert.isNull(result.localGoogleFileVersionToUpdate);
	}

	@IsTest
	private static void testBuildPositiveBlankName() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c file = GoogleCloudTestFactory.file()
			.withName('F.pdf')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(file.Id)
			.withName('F.pdf')
			.withDriveId('GD_UP_5')
			.insertRecord();

		Test.startTest();
		GoogleFileUpdateCommand.GoogleFileUpdateResult result = new GoogleFileUpdateCommand(file, version)
			.changeFileNameTo('')
			.changeFileVersionNameTo('  ')
			.build();
		Test.stopTest();

		Assert.isNotNull(result.localGoogleFileToUpdate);
		Assert.areEqual(GoogleCloudConstants.DEFAULT_FILE_NAME + '.pdf', result.localGoogleFileToUpdate.Name);
	}

	@IsTest
	private static void testBuildPositiveLongName() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c file = GoogleCloudTestFactory.file()
			.withName('F.pdf')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(file.Id)
			.withName('F.pdf')
			.withDriveId('GD_UP_6')
			.insertRecord();

		String longName = '';
		for (Integer i = 0; i < 100; i++) longName += 'A';

		Test.startTest();
		GoogleFileUpdateCommand.GoogleFileUpdateResult result = new GoogleFileUpdateCommand(file, version)
			.changeFileNameTo(longName)
			.build();
		Test.stopTest();

		Assert.isNotNull(result.localGoogleFileToUpdate);
		Assert.isTrue(result.localGoogleFileToUpdate.Name.length() <= 80);
		Assert.isTrue(result.localGoogleFileToUpdate.Name.endsWith('.pdf'));
	}

	@IsTest
	private static void testBuildPositiveNoExtension() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c file = GoogleCloudTestFactory.file()
			.withName('NoExt')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(file.Id)
			.withName('NoExt')
			.withDriveId('GD_UP_7')
			.insertRecord();

		Test.startTest();
		GoogleFileUpdateCommand.GoogleFileUpdateResult result = new GoogleFileUpdateCommand(file, version)
			.changeFileNameTo('Renamed')
			.build();
		Test.stopTest();

		Assert.isNotNull(result.localGoogleFileToUpdate);
		Assert.areEqual('Renamed', result.localGoogleFileToUpdate.Name);
	}

	@IsTest
	private static void testBuildPositiveNameWithDifferentExtension() {
		GoogleCloudTestFactory.initMocks();

		GoogleFile__c file = GoogleCloudTestFactory.file()
			.withName('File.pdf')
			.insertRecord();

		GoogleFileVersion__c version = GoogleCloudTestFactory.version()
			.forFile(file.Id)
			.withName('File.pdf')
			.withDriveId('GD_UP_8')
			.insertRecord();

		Test.startTest();
		GoogleFileUpdateCommand.GoogleFileUpdateResult result = new GoogleFileUpdateCommand(file, version)
			.changeFileNameTo('File.xlsx')
			.changeFileVersionNameTo('File')
			.build();
		Test.stopTest();

		Assert.isNull(result.localGoogleFileToUpdate);
		Assert.isNull(result.localGoogleFileVersionToUpdate);
	}
}
