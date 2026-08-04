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
private class GoogleFileSharingCommandTest {
	private static IGoogleUnitOfWork buildUow() {
		return GoogleCloudTestFactory.unitOfWork();
	}

	private static Id linkedRecordWithAccess() {
		Id linkedRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleCloudTestFactory.grantRecordAccess(linkedRecordId, true, true);
		return linkedRecordId;
	}

	@IsTest
	private static void testApplyWithResultCreatesRecordLink() {
		GoogleCloudTestFactory.initMocks();

		Id relatedRecordId = linkedRecordWithAccess();

		GoogleFile__c localFile = GoogleCloudTestFactory.file()
			.withName('Sharing Result File')
			.insertRecord();

		Test.startTest();
		GoogleFileSharingApplyResultDTO result = new GoogleFileSharingCommand(buildUow())
			.createSharing()
			.forFile(localFile.Id)
			.shareTo('GoogleFile__c', relatedRecordId)
			.withSource('Notes & Attachments')
			.applyWithResult();
		Test.stopTest();

		Assert.isTrue(result.wasCreated);
		Assert.isNotNull(result.recordId);
	}

	@IsTest
	private static void testApplyWithResultReusesExistingRecordLink() {
		GoogleCloudTestFactory.initMocks();

		Id relatedRecordId = linkedRecordWithAccess();

		GoogleFile__c localFile = GoogleCloudTestFactory.file()
			.withName('Existing Sharing Result File')
			.insertRecord();

		GoogleFileLink__c existingLink = GoogleCloudTestFactory.link()
			.forFile(localFile.Id)
			.withLinkedRecord(relatedRecordId)
			.withLinkedType('GoogleFile__c')
			.insertRecord();

		Test.startTest();
		GoogleFileSharingApplyResultDTO result = new GoogleFileSharingCommand(buildUow())
			.createSharing()
			.forFile(localFile.Id)
			.shareTo('GoogleFile__c', relatedRecordId)
			.withSource('Notes & Attachments')
			.applyWithResult();
		Test.stopTest();

		Assert.isFalse(result.wasCreated);
		Assert.areEqual(existingLink.Id, result.recordId);
	}

	@IsTest
	private static void testApplyKeepsReturningCreatedId() {
		GoogleCloudTestFactory.initMocks();

		Id relatedRecordId = linkedRecordWithAccess();

		GoogleFile__c localFile = GoogleCloudTestFactory.file()
			.withName('Apply Compatibility File')
			.insertRecord();

		Test.startTest();
		Id linkId = new GoogleFileSharingCommand(buildUow())
			.createSharing()
			.forFile(localFile.Id)
			.shareTo('GoogleFile__c', relatedRecordId)
			.withSource('Notes & Attachments')
			.apply();
		Test.stopTest();

		Assert.isNotNull(linkId);
	}
}