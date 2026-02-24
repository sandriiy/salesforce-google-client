@IsTest
private class GoogleLocalFileLinkEnrichmentServiceTest {
	@IsTest
	private static void testApplyLinkedRecordAttributesPositiveNull() {
		GoogleLocalFileLinkEnrichmentService enrichmentService = new GoogleLocalFileLinkEnrichmentService();
		System.assertEquals(null, enrichmentService.applyLinkedRecordAttributes(null));
	}

	@IsTest
	private static void testApplyLinkedRecordAttributesPositiveEmpty() {
		GoogleLocalFileLinkEnrichmentService enrichmentService = new GoogleLocalFileLinkEnrichmentService();
		System.assertEquals(0, enrichmentService.applyLinkedRecordAttributes(new List<GoogleFileLink__c>()).size());
	}

	@IsTest
	private static void testApplyLinkedRecordAttributesPositivePopulate() {
		Integer maxLinkedObjectNameLength = GoogleFileLink__c.LinkedObjectName__c.getDescribe().getLength();

		Account firstAccount = new Account(Name = 'Account Alpha');
		insert firstAccount;

		String veryLongName = '';
		while (veryLongName.length() <= (maxLinkedObjectNameLength + 10)) veryLongName += 'A';

		Account secondAccount = new Account(Name = veryLongName);
		insert secondAccount;

		GoogleFileLink__c accountLink = new GoogleFileLink__c(
			LinkedObjectType__c = 'Account',
			LinkedObjectId__c = firstAccount.Id,
			LinkedObjectName__c = null
		);
		GoogleFileLink__c accountLinkLongName = new GoogleFileLink__c(
			LinkedObjectType__c = 'Account',
			LinkedObjectId__c = secondAccount.Id,
			LinkedObjectName__c = null
		);
		GoogleFileLink__c linkWithExistingName = new GoogleFileLink__c(
			LinkedObjectType__c = 'Account',
			LinkedObjectId__c = firstAccount.Id,
			LinkedObjectName__c = 'Already Set'
		);
		GoogleFileLink__c linkWithBlankObjectType = new GoogleFileLink__c(
			LinkedObjectType__c = null,
			LinkedObjectId__c = firstAccount.Id,
			LinkedObjectName__c = null
		);
		GoogleFileLink__c linkWithUnknownObjectType = new GoogleFileLink__c(
			LinkedObjectType__c = 'NoSuchObject__c',
			LinkedObjectId__c = firstAccount.Id,
			LinkedObjectName__c = null
		);
		GoogleFileLink__c linkWithNullRecordId = new GoogleFileLink__c(
			LinkedObjectType__c = 'Account',
			LinkedObjectId__c = null,
			LinkedObjectName__c = null
		);

		List<GoogleFileLink__c> inputLinks = new List<GoogleFileLink__c>{
			accountLink,
			accountLinkLongName,
			linkWithExistingName,
			linkWithBlankObjectType,
			linkWithUnknownObjectType,
			linkWithNullRecordId
		};

		GoogleLocalFileLinkEnrichmentService enrichmentService = new GoogleLocalFileLinkEnrichmentService();
		List<GoogleFileLink__c> outputLinks = enrichmentService.applyLinkedRecordAttributes(inputLinks);

		System.assertEquals(inputLinks, outputLinks);

		System.assertEquals('Account Alpha', accountLink.LinkedObjectName__c);
		System.assertEquals(maxLinkedObjectNameLength, accountLinkLongName.LinkedObjectName__c.length());
		System.assertEquals('Already Set', linkWithExistingName.LinkedObjectName__c);
		System.assertEquals(null, linkWithBlankObjectType.LinkedObjectName__c);
		System.assertEquals(null, linkWithUnknownObjectType.LinkedObjectName__c);
		System.assertEquals(null, linkWithNullRecordId.LinkedObjectName__c);
	}
}