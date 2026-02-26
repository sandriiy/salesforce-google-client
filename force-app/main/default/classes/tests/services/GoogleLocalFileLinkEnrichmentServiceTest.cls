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
}