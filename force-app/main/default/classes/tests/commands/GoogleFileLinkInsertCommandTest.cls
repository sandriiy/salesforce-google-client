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
private class GoogleFileLinkInsertCommandTest {
	@IsTest
	private static void testSavePositiveRegistersOneAdditionalLinkPerDistinctRecord() {
		GoogleCloudTestFactory.initMocks();
		GoogleCapturingUnitOfWork capturingUow = new GoogleCapturingUnitOfWork();
		Id fileId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		Id firstRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		Id secondRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);

		Test.startTest();
		List<GoogleFileLink__c> links = new GoogleFileLinkInsertCommand(capturingUow)
			.forFile(fileId)
			.toRecords(new List<Id>{ firstRecordId, secondRecordId, firstRecordId, null })
			.withSource(GoogleCloudConstants.FILE_SOURCE_NOTES_AND_ATTACHMENTS)
			.withShareType('Collaborator')
			.withVisibility('AllUsers')
			.save();
		Test.stopTest();

		Assert.areEqual(2, links.size(), 'A record given twice is linked once and a null is ignored');
		Assert.areEqual(2, capturingUow.registeredNew.size());
		Assert.areEqual(0, capturingUow.commitCount, 'The command never commits');
		Assert.areEqual(fileId, links[0].GoogleFileId__c);
		Assert.areEqual(String.valueOf(firstRecordId), links[0].LinkedObjectId__c);
		Assert.areEqual('GoogleFile__c', links[0].LinkedObjectType__c);
		Assert.isTrue(links[0].IsAdditionalLink__c);
		Assert.areEqual(GoogleCloudConstants.FILE_SOURCE_NOTES_AND_ATTACHMENTS, links[0].Source__c);
		Assert.areEqual('Collaborator', links[0].ShareType__c, 'An explicit share type is kept');
		Assert.areEqual('AllUsers', links[0].Visibility__c);
		Assert.areEqual(String.valueOf(secondRecordId), links[1].LinkedObjectId__c);
	}

	@IsTest
	private static void testSavePositiveFillsDefaultsWhenNothingWasSaid() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.mockInternalUser();
		GoogleCapturingUnitOfWork capturingUow = new GoogleCapturingUnitOfWork();

		Test.startTest();
		List<GoogleFileLink__c> links = new GoogleFileLinkInsertCommand(capturingUow)
			.forFile(GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType))
			.toRecords(new List<Id>{ GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType) })
			.withSource(GoogleCloudConstants.FILE_SOURCE_NOTES_AND_ATTACHMENTS)
			.save();
		Test.stopTest();

		Assert.areEqual(1, links.size());
		Assert.areEqual('Viewer', links[0].ShareType__c, 'An internal user gets the Viewer default');
		Assert.areEqual('InternalUsers', links[0].Visibility__c);
	}

	@IsTest
	private static void testSaveNegativeRequiresAFile() {
		GoogleCloudTestFactory.initMocks();

		Test.startTest();
		try {
			new GoogleFileLinkInsertCommand(new GoogleCapturingUnitOfWork())
				.toRecords(new List<Id>{ GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType) })
				.save();
			Assert.fail('A link without a file cannot be registered');
		} catch (GoogleFileLinkInsertCommand.GoogleFileLinkInsertCommandException ex) {
			Assert.isTrue(ex.getMessage().contains('required'), ex.getMessage());
		}
		Test.stopTest();
	}

	@IsTest
	private static void testSavePositiveNothingToLink() {
		GoogleCloudTestFactory.initMocks();
		GoogleCapturingUnitOfWork capturingUow = new GoogleCapturingUnitOfWork();

		List<GoogleFileLink__c> links = new GoogleFileLinkInsertCommand(capturingUow)
			.forFile(GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType))
			.toRecords(null)
			.save();

		Assert.isTrue(links.isEmpty());
		Assert.isTrue(capturingUow.registeredNew.isEmpty());
	}
}
