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
private class GoogleRecordAccessResolverTest {
	@IsTest
	private static void testOverriddenAccessIsReturned() {
		GoogleCloudTestFactory.denyAllRecordAccess();
		Id recordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleCloudTestFactory.grantRecordAccess(recordId, true, true);

		GoogleRecordAccessDTO recordAccess = new GoogleRecordAccessResolver().resolveAccess(UserInfo.getUserId(), recordId);

		Assert.isNotNull(recordAccess);
		Assert.areEqual(recordId, recordAccess.recordId);
		Assert.isTrue(recordAccess.hasReadAccess);
		Assert.isTrue(recordAccess.hasEditAccess);
	}

	@IsTest
	private static void testReadOnlyOverrideDoesNotGrantEdit() {
		GoogleCloudTestFactory.denyAllRecordAccess();
		Id recordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleCloudTestFactory.grantRecordAccess(recordId, true, false);

		GoogleRecordAccessDTO recordAccess = new GoogleRecordAccessResolver().resolveAccess(UserInfo.getUserId(), recordId);

		Assert.isTrue(recordAccess.hasReadAccess);
		Assert.isFalse(recordAccess.hasEditAccess);
	}

	@IsTest
	private static void testUngrantedRecordResolvesToNothing() {
		GoogleCloudTestFactory.denyAllRecordAccess();
		Id recordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);

		GoogleRecordAccessResolver accessResolver = new GoogleRecordAccessResolver();

		Assert.isNull(accessResolver.resolveAccess(UserInfo.getUserId(), recordId));
		Assert.isFalse(accessResolver.hasReadAccess(UserInfo.getUserId(), recordId));
	}

	@IsTest
	private static void testBulkResolutionOnlyReturnsRequestedRecords() {
		GoogleCloudTestFactory.denyAllRecordAccess();
		Id requestedRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		Id unrequestedRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleCloudTestFactory.grantRecordAccess(requestedRecordId, true, false);
		GoogleCloudTestFactory.grantRecordAccess(unrequestedRecordId, true, true);

		Map<Id, GoogleRecordAccessDTO> accessByRecordId = new GoogleRecordAccessResolver()
			.resolveAccess(UserInfo.getUserId(), new Set<Id>{ requestedRecordId });

		Assert.areEqual(1, accessByRecordId.size());
		Assert.isTrue(accessByRecordId.containsKey(requestedRecordId));
	}

	@IsTest
	private static void testEmptyAndNullInputsAreSafe() {
		GoogleRecordAccessResolver accessResolver = new GoogleRecordAccessResolver();

		Assert.areEqual(0, accessResolver.resolveAccess(UserInfo.getUserId(), new Set<Id>()).size());
		Assert.areEqual(0, accessResolver.resolveAccess(null, new Set<Id>{ GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType) }).size());
		Assert.areEqual(0, accessResolver.resolveAccess(UserInfo.getUserId(), (Set<Id>) null).size());
		Assert.isNull(accessResolver.resolveAccess(UserInfo.getUserId(), (Id) null));
	}

	@IsTest
	private static void testRunningUserAlwaysReachesOwnRecord() {
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('Reachable File').insertRecord();

		Test.startTest();
		Boolean canRead = new GoogleRecordAccessResolver().hasReadAccess(UserInfo.getUserId(), localFile.Id);
		Test.stopTest();

		Assert.isTrue(canRead);
	}

	@IsTest
	private static void testResolvesMoreRecordsThanASingleAccessQueryAllows() {
		List<GoogleFile__c> localFiles = new List<GoogleFile__c>();
		for (Integer i = 0; i < 250; i++) {
			localFiles.add(new GoogleFile__c(Name = 'Bulk Access File ' + i, Source__c = 'File Explorer'));
		}
		insert localFiles;

		Set<Id> recordIds = new Map<Id, GoogleFile__c>(localFiles).keySet();

		Test.startTest();
		Map<Id, GoogleRecordAccessDTO> accessByRecordId = new GoogleRecordAccessResolver().resolveAccess(UserInfo.getUserId(), recordIds);
		Test.stopTest();

		Assert.areEqual(250, accessByRecordId.size(), 'UserRecordAccess caps at 200 records per query and must be requested in batches');
		Assert.isTrue(accessByRecordId.values()[0].hasReadAccess);
	}
}
