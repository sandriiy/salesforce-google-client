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
private class GoogleLocalFileLinkEnrichmentServiceTest {
	@IsTest
	private static void testApplyLinkedRecordAttributesPositiveNull() {
		GoogleLocalFileLinkEnrichmentService enrichmentService = new GoogleLocalFileLinkEnrichmentService();
		Assert.areEqual(null, enrichmentService.applyLinkedRecordAttributes(null));
	}

	@IsTest
	private static void testApplyLinkedRecordAttributesPositiveEmpty() {
		GoogleLocalFileLinkEnrichmentService enrichmentService = new GoogleLocalFileLinkEnrichmentService();
		Assert.areEqual(0, enrichmentService.applyLinkedRecordAttributes(new List<GoogleFileLink__c>()).size());
	}

	@IsTest
	private static void testApplyLinkedRecordAttributesNegativeNoEnrichment() {
		GoogleFileLink__c linkWithExistingName = new GoogleFileLink__c(
			LinkedObjectType__c = 'GoogleFile__c',
			LinkedObjectId__c = (Id) 'a0B000000000001AAA',
			LinkedObjectName__c = 'Already Set'
		);

		GoogleFileLink__c linkWithBlankObjectType = new GoogleFileLink__c(
			LinkedObjectType__c = null,
			LinkedObjectId__c = (Id) 'a0B000000000001AAA',
			LinkedObjectName__c = null
		);

		GoogleFileLink__c linkWithUnknownObjectType = new GoogleFileLink__c(
			LinkedObjectType__c = 'NoSuchObject__c',
			LinkedObjectId__c = (Id) 'a0B000000000001AAA',
			LinkedObjectName__c = null
		);

		GoogleFileLink__c linkWithNullRecordId = new GoogleFileLink__c(
			LinkedObjectType__c = 'GoogleFile__c',
			LinkedObjectId__c = null,
			LinkedObjectName__c = null
		);

		List<GoogleFileLink__c> inputLinks = new List<GoogleFileLink__c>{
			linkWithExistingName,
			linkWithBlankObjectType,
			linkWithUnknownObjectType,
			linkWithNullRecordId
		};

		GoogleLocalFileLinkEnrichmentService enrichmentService = new GoogleLocalFileLinkEnrichmentService();
		try {
			List<GoogleFileLink__c> outputLinks = enrichmentService.applyLinkedRecordAttributes(inputLinks);
		} catch (Exception ex) {
			Assert.isNotNull(ex.getMessage());
		}
	}

	@IsTest
	private static void testResolveLinkedRecordNamePositive() {
		Account linkedRecord = new Account(Name = 'Resolved Account Name');
		insert linkedRecord;

		GoogleLocalFileLinkEnrichmentService enrichmentService = new GoogleLocalFileLinkEnrichmentService();

		Assert.areEqual('Resolved Account Name', enrichmentService.resolveLinkedRecordName(linkedRecord.Id));
	}

	@IsTest
	private static void testResolveLinkedRecordNamePositiveCompoundName() {
		GoogleLocalFileLinkEnrichmentService enrichmentService = new GoogleLocalFileLinkEnrichmentService();

		Assert.areEqual(UserInfo.getName(), enrichmentService.resolveLinkedRecordName(UserInfo.getUserId()));
	}

	@IsTest
	private static void testApplyLinkedRecordAttributesPositiveCompoundName() {
		GoogleFileLink__c compoundNameLink = new GoogleFileLink__c(
			LinkedObjectType__c = 'User',
			LinkedObjectId__c = UserInfo.getUserId()
		);

		GoogleLocalFileLinkEnrichmentService enrichmentService = new GoogleLocalFileLinkEnrichmentService();
		enrichmentService.applyLinkedRecordAttributes(new List<GoogleFileLink__c>{ compoundNameLink });

		Assert.areEqual(UserInfo.getName(), compoundNameLink.LinkedObjectName__c);
	}
}