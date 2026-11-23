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
private class GoogleDriveFolderNameResolverTest {
	private static final String UPLOAD_FOLDER_ID = 'ROOT_FOLDER_01';
	private static final String RECORD_NAME = 'Acme Brochure';
	private static final String TODAYS_RECORD_FOLDER_NAME = 'GoogleFile__c : Acme Brochure';
	private static final String ERROR_PREFIX = 'ERROR ';

	private static void applyPatterns(List<Map<String, String>> patternRows) {
		GoogleCloudTestFactory.initMocks();
		GoogleClientConfig__mdt config = new GoogleClientConfig__mdt();
		config.DefaultGoogleUploadFolderId__c = UPLOAD_FOLDER_ID;
		config.CustomGoogleUploadFolderStructure__c = '{User}-{Record}';
		config.RecordFolderNamePatterns__c = patternRows == null ? null : JSON.serialize(patternRows);
		GoogleMetadataConfigService.configRecordOverride = config;
	}

	private static Map<String, String> patternRow(String objectApiName, String pattern) {
		return new Map<String, String>{ 'objectApiName' => objectApiName, 'pattern' => pattern };
	}

	private static GoogleFile__c insertRecord(String recordName) {
		return GoogleCloudTestFactory.file().withName(recordName).withSource('Migration').insertRecord();
	}

	private static GoogleFile__c ownedByRunningUser(Id recordId, String recordName) {
		return (GoogleFile__c) JSON.deserialize(JSON.serialize(new Map<String, Object>{
			'attributes' => new Map<String, Object>{ 'type' => 'GoogleFile__c' },
			'Id' => recordId,
			'Name' => recordName,
			'Owner' => new Map<String, Object>{
				'attributes' => new Map<String, Object>{ 'type' => 'User' },
				'Id' => UserInfo.getUserId(),
				'LastName' => UserInfo.getLastName()
			}
		}), GoogleFile__c.class);
	}

	private static String todaysUserFolderName() {
		List<String> nameParts = new List<String>();
		if (String.isNotBlank(UserInfo.getFirstName())) nameParts.add(UserInfo.getFirstName());
		if (String.isNotBlank(UserInfo.getLastName())) nameParts.add(UserInfo.getLastName());
		return 'User : ' + String.join(nameParts, ' ');
	}

	private static List<String> loggedErrors() {
		List<String> errors = new List<String>();
		if (GoogleDriveFolderNameResolver.loggedFailures == null) return errors;

		for (String entry : GoogleDriveFolderNameResolver.loggedFailures) {
			if (entry != null && entry.startsWith(ERROR_PREFIX)) errors.add(entry);
		}

		return errors;
	}

	private static Boolean hasLoggedWarning() {
		if (GoogleDriveFolderNameResolver.loggedFailures == null) return false;

		for (String entry : GoogleDriveFolderNameResolver.loggedFailures) {
			if (entry != null && entry.startsWith('WARN ')) return true;
		}

		return false;
	}

	@IsTest
	private static void testBuildNewRecordFolderNamePositiveKeepsTodaysFormatWithoutAPattern() {
		applyPatterns(null);
		GoogleFile__c record = insertRecord(RECORD_NAME);
		GoogleDriveFolderNameResolver resolver = new GoogleDriveFolderNameResolver();

		Test.startTest();
		String newName = resolver.buildNewRecordFolderName(record.Id);
		String expectedName = resolver.resolveExpectedRecordFolderName(record.Id);
		Test.stopTest();

		Assert.areEqual(TODAYS_RECORD_FOLDER_NAME, newName, 'Without a pattern a folder is named exactly as before');
		Assert.areEqual(TODAYS_RECORD_FOLDER_NAME, expectedName);
	}

	@IsTest
	private static void testBuildNewRecordFolderNamePositiveUnknownRecordForARecordThatIsGone() {
		applyPatterns(null);
		Id missingRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GoogleDriveFolderNameResolver resolver = new GoogleDriveFolderNameResolver();

		Test.startTest();
		String newName = resolver.buildNewRecordFolderName(missingRecordId);
		String expectedName = resolver.resolveExpectedRecordFolderName(missingRecordId);
		Test.stopTest();

		Assert.areEqual('GoogleFile__c : Unknown Record', newName);
		Assert.isNull(expectedName, 'A record that is gone gives no name to rename to');
	}

	@IsTest
	private static void testResolveExpectedRecordFolderNameNegativeUnnamedRecordIsUncertain() {
		applyPatterns(null);
		Id unnamedRecordId = GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType);
		GSOQL.mock(GoogleFileLinkedRecordSelector.MOCK_ID).thenReturn(new List<SObject>{ new GoogleFile__c(Id = unnamedRecordId) });
		GoogleDriveFolderNameResolver resolver = new GoogleDriveFolderNameResolver();

		Test.startTest();
		String newName = resolver.buildNewRecordFolderName(unnamedRecordId);
		String expectedName = resolver.resolveExpectedRecordFolderName(unnamedRecordId);
		Test.stopTest();

		Assert.areEqual('GoogleFile__c : Unknown Record', newName);
		Assert.isNull(expectedName, 'A record without a name never renames its folder to "Unknown Record"');
	}

	@IsTest
	private static void testBuildNewRecordFolderNamePositiveUsesTheObjectsPattern() {
		applyPatterns(new List<Map<String, String>>{ patternRow('GoogleFile__c', 'Name & " (" & TEXT(Source__c) & ")"') });
		GoogleFile__c record = insertRecord(RECORD_NAME);
		GoogleDriveFolderNameResolver resolver = new GoogleDriveFolderNameResolver();

		Test.startTest();
		String newName = resolver.buildNewRecordFolderName(record.Id);
		String expectedName = resolver.resolveExpectedRecordFolderName(record.Id);
		Test.stopTest();

		Assert.areEqual('Acme Brochure (Migration)', newName);
		Assert.areEqual(newName, expectedName, 'A folder is renamed to the name it would be given if it were created now');
	}

	@IsTest
	private static void testBuildNewRecordFolderNamePositiveMatchesTheObjectWhateverItsCase() {
		applyPatterns(new List<Map<String, String>>{ patternRow('googlefile__c', 'Name & " (" & TEXT(Source__c) & ")"') });
		GoogleFile__c record = insertRecord(RECORD_NAME);

		Test.startTest();
		String newName = new GoogleDriveFolderNameResolver().buildNewRecordFolderName(record.Id);
		Test.stopTest();

		Assert.areEqual('Acme Brochure (Migration)', newName);
	}

	@IsTest
	private static void testBuildNewRecordFolderNamePositiveReadsARelatedRecordsField() {
		applyPatterns(new List<Map<String, String>>{ patternRow('GoogleFileVersion__c', 'GoogleFileId__r.Name & " - " & Name') });
		GoogleCloudTestFactory.bypassTriggers();
		GoogleFile__c parentFile = insertRecord(RECORD_NAME);
		GoogleFileVersion__c record = GoogleCloudTestFactory.version()
			.forFile(parentFile.Id)
			.withName('v1.pdf')
			.withType('application/pdf')
			.withSize(10)
			.withDriveId('GD_NAME_RESOLVER_1')
			.insertRecord();

		Test.startTest();
		String newName = new GoogleDriveFolderNameResolver().buildNewRecordFolderName(record.Id);
		Test.stopTest();

		Assert.areEqual('Acme Brochure - v1.pdf', newName, 'Every field the formula references is read, related ones included');
	}

	@IsTest
	private static void testBuildNewRecordFolderNamePositiveReadsAnOwnerThatCanAlsoBeAQueue() {
		applyPatterns(new List<Map<String, String>>{ patternRow('GoogleFile__c', 'Name & " - " & Owner:User.LastName') });
		GoogleFile__c record = insertRecord(RECORD_NAME);

		Test.startTest();
		String queriedName = new GoogleDriveFolderNameResolver().buildNewRecordFolderName(record.Id);
		GSOQL.mock(GoogleFileLinkedRecordSelector.MOCK_ID).thenReturn(ownedByRunningUser(record.Id, RECORD_NAME));
		GoogleDriveFolderNameResolver resolver = new GoogleDriveFolderNameResolver();
		String newName = resolver.buildNewRecordFolderName(record.Id);
		String expectedName = resolver.resolveExpectedRecordFolderName(record.Id);
		Test.stopTest();

		Assert.areNotEqual(TODAYS_RECORD_FOLDER_NAME, queriedName, 'Salesforce reads the owner step of a real record, so the pattern names the folder');
		Assert.areEqual(RECORD_NAME + ' - ' + UserInfo.getLastName(), newName, 'Salesforce asks for Owner:User on an owner that can be a queue, and the folder must still get that name');
		Assert.areEqual(newName, expectedName);
		Assert.areEqual(0, loggedErrors().size());
	}

	@IsTest
	private static void testBuildNewRecordFolderNamePositiveOtherObjectsKeepTodaysFormat() {
		applyPatterns(new List<Map<String, String>>{ patternRow('GoogleFileVersion__c', 'Name & " v"') });
		GoogleFile__c record = insertRecord(RECORD_NAME);

		Test.startTest();
		String newName = new GoogleDriveFolderNameResolver().buildNewRecordFolderName(record.Id);
		Test.stopTest();

		Assert.areEqual(TODAYS_RECORD_FOLDER_NAME, newName);
	}

	@IsTest
	private static void testBuildNewRecordFolderNamePositiveBlankResultKeepsTodaysFormat() {
		applyPatterns(new List<Map<String, String>>{ patternRow('GoogleFile__c', '"Folder " & SalesforceFileId__c') });
		GoogleFile__c record = insertRecord(RECORD_NAME);
		GoogleDriveFolderNameResolver resolver = new GoogleDriveFolderNameResolver();

		Test.startTest();
		String newName = resolver.buildNewRecordFolderName(record.Id);
		String expectedName = resolver.resolveExpectedRecordFolderName(record.Id);
		Test.stopTest();

		Assert.areEqual(TODAYS_RECORD_FOLDER_NAME, newName, 'A pattern whose fields are all blank gives today\'s name');
		Assert.areEqual(TODAYS_RECORD_FOLDER_NAME, expectedName);
	}

	@IsTest
	private static void testBuildNewRecordFolderNameNegativeBrokenPatternKeepsTodaysFormatAndLogsOneError() {
		applyPatterns(new List<Map<String, String>>{ patternRow('GoogleFile__c', 'Name & Nope__c') });
		GoogleFile__c firstRecord = insertRecord(RECORD_NAME);
		GoogleFile__c secondRecord = insertRecord('Second Brochure');
		GoogleDriveFolderNameResolver resolver = new GoogleDriveFolderNameResolver();

		Test.startTest();
		String firstName = resolver.buildNewRecordFolderName(firstRecord.Id);
		String secondName = resolver.buildNewRecordFolderName(secondRecord.Id);
		Test.stopTest();

		Assert.areEqual(TODAYS_RECORD_FOLDER_NAME, firstName, 'A pattern that no longer works never stops a new folder from being made');
		Assert.areEqual('GoogleFile__c : Second Brochure', secondName);
		Assert.areEqual(1, loggedErrors().size(), 'One broken pattern is one error line, however many records use it');
		Assert.isFalse(hasLoggedWarning());
	}

	@IsTest
	private static void testResolveExpectedRecordFolderNameNegativeBrokenPatternIsUncertain() {
		applyPatterns(new List<Map<String, String>>{ patternRow('GoogleFile__c', 'Name & Nope__c') });
		GoogleFile__c record = insertRecord(RECORD_NAME);

		Test.startTest();
		String expectedName = new GoogleDriveFolderNameResolver().resolveExpectedRecordFolderName(record.Id);
		Test.stopTest();

		Assert.isNull(expectedName, 'An existing folder is never renamed by a pattern that does not work');
	}

	@IsTest
	private static void testResolveExpectedRecordFolderNamePositiveReadsEachRecordOnce() {
		applyPatterns(new List<Map<String, String>>{ patternRow('GoogleFile__c', 'Name & " (" & TEXT(Source__c) & ")"') });
		GoogleFile__c record = insertRecord(RECORD_NAME);
		GoogleDriveFolderNameResolver resolver = new GoogleDriveFolderNameResolver();

		Test.startTest();
		String firstName = resolver.resolveExpectedRecordFolderName(record.Id);
		Integer queriesAfterFirstName = Limits.getQueries();
		String repeatedName = resolver.resolveExpectedRecordFolderName(record.Id);
		Integer queriesAfterRepeatedName = Limits.getQueries();
		Test.stopTest();

		Assert.areEqual(firstName, repeatedName);
		Assert.areEqual(queriesAfterFirstName, queriesAfterRepeatedName, 'A record is read once per resolver, however many files land on it');
	}

	@IsTest
	private static void testBuildNewUserFolderNamePositiveKeepsTodaysFormat() {
		applyPatterns(null);
		GoogleDriveFolderNameResolver resolver = new GoogleDriveFolderNameResolver();

		Test.startTest();
		String newName = resolver.buildNewUserFolderName(UserInfo.getUserId());
		String expectedName = resolver.resolveExpectedUserFolderName(UserInfo.getUserId());
		Test.stopTest();

		Assert.areEqual(todaysUserFolderName(), newName);
		Assert.areEqual(todaysUserFolderName(), expectedName);
	}

	@IsTest
	private static void testBuildNewUserFolderNamePositiveUnknownUserForAUserThatIsGone() {
		applyPatterns(null);
		Id missingUserId = GoogleCloudTestFactory.otherUserId();
		GoogleDriveFolderNameResolver resolver = new GoogleDriveFolderNameResolver();

		Test.startTest();
		String newName = resolver.buildNewUserFolderName(missingUserId);
		String expectedName = resolver.resolveExpectedUserFolderName(missingUserId);
		Test.stopTest();

		Assert.areEqual('Unknown User', newName);
		Assert.isNull(expectedName);
	}

	@IsTest
	private static void testBuildNewUserFolderNamePositiveUsesTheUserPattern() {
		applyPatterns(new List<Map<String, String>>{ patternRow('User', 'LastName & " team"') });
		GoogleDriveFolderNameResolver resolver = new GoogleDriveFolderNameResolver();

		Test.startTest();
		String newName = resolver.buildNewUserFolderName(UserInfo.getUserId());
		String expectedName = resolver.resolveExpectedUserFolderName(UserInfo.getUserId());
		Test.stopTest();

		Assert.areEqual(UserInfo.getLastName() + ' team', newName, 'A pattern for User names the people\'s folders like any record\'s');
		Assert.areEqual(newName, expectedName);
	}

	@IsTest
	private static void testResolveExpectedUserFolderNameNegativeBrokenUserPatternIsUncertain() {
		applyPatterns(new List<Map<String, String>>{ patternRow('User', 'LastName & Nope__c') });
		GoogleDriveFolderNameResolver resolver = new GoogleDriveFolderNameResolver();

		Test.startTest();
		String newName = resolver.buildNewUserFolderName(UserInfo.getUserId());
		String expectedName = resolver.resolveExpectedUserFolderName(UserInfo.getUserId());
		Test.stopTest();

		Assert.areEqual(todaysUserFolderName(), newName);
		Assert.isNull(expectedName);
		Assert.areEqual(1, loggedErrors().size());
	}

	@IsTest
	private static void testIsSameFolderNamePositiveIgnoresSurroundingSpaces() {
		applyPatterns(null);

		Assert.isTrue(new GoogleDriveFolderNameResolver().isSameFolderName(' ' + TODAYS_RECORD_FOLDER_NAME + ' ', TODAYS_RECORD_FOLDER_NAME));
	}

	@IsTest
	private static void testIsSameFolderNamePositiveComparesPeoplesNamesInEitherOrder() {
		applyPatterns(null);
		GoogleDriveFolderNameResolver resolver = new GoogleDriveFolderNameResolver();

		Assert.isTrue(resolver.isSameFolderName('Contact : Doe Jane', 'Contact : Jane Doe'), 'A name built in another language\'s order is the same person');
		Assert.isTrue(resolver.isSameFolderName('Lead : Doe Jane', 'Lead : Jane Doe'));
	}

	@IsTest
	private static void testIsSameFolderNameNegativeKeepsWordOrderForOtherObjects() {
		applyPatterns(null);

		Assert.isFalse(new GoogleDriveFolderNameResolver().isSameFolderName('Opportunity : Deal Big', 'Opportunity : Big Deal'));
	}

	@IsTest
	private static void testIsSameFolderNameNegativeDifferentPeopleAreDifferent() {
		applyPatterns(null);
		GoogleDriveFolderNameResolver resolver = new GoogleDriveFolderNameResolver();

		Assert.isFalse(resolver.isSameFolderName('Contact : Jane Smith', 'Contact : Jane Doe'));
		Assert.isFalse(resolver.isSameFolderName('Contact : Jane', 'Contact : Jane Doe'), 'A name that lost a word was renamed');
		Assert.isFalse(resolver.isSameFolderName('Lead : Jane Doe', 'Contact : Jane Doe'));
	}

	@IsTest
	private static void testIsSameFolderNameNegativeBlankCurrentNameDiffers() {
		applyPatterns(null);
		GoogleDriveFolderNameResolver resolver = new GoogleDriveFolderNameResolver();

		Assert.isFalse(resolver.isSameFolderName(null, TODAYS_RECORD_FOLDER_NAME));
		Assert.isFalse(resolver.isSameFolderName('', TODAYS_RECORD_FOLDER_NAME));
	}
}
