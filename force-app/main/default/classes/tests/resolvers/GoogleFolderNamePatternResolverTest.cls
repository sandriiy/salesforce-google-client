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
private class GoogleFolderNamePatternResolverTest {
	private static final Integer MAX_FOLDER_NAME_LENGTH = 255;
	private static final List<String> ALWAYS_CHANGING_FIELDS = new List<String>{
		'LastModifiedDate', 'SystemModstamp', 'LastModifiedById', 'LastActivityDate', 'LastViewedDate', 'LastReferencedDate'
	};

	private static GoogleFile__c buildFileRecord(String recordName, String salesforceFileId) {
		return new GoogleFile__c(Name = recordName, SalesforceFileId__c = salesforceFileId);
	}

	private static String renderOnFile(String pattern, GoogleFile__c record) {
		GoogleFolderNamePatternResolver resolver = new GoogleFolderNamePatternResolver();
		return resolver.render(resolver.compile(GoogleFile__c.SObjectType, pattern), record);
	}

	private static String renderOnVersion(String pattern, GoogleFileVersion__c record) {
		GoogleFolderNamePatternResolver resolver = new GoogleFolderNamePatternResolver();
		return resolver.render(resolver.compile(GoogleFileVersion__c.SObjectType, pattern), record);
	}

	private static Boolean hasProblems(Schema.SObjectType objectType, String pattern) {
		List<String> problems = new GoogleFolderNamePatternResolver().findProblems(objectType, pattern);
		if (problems == null || problems.isEmpty()) return false;

		for (String problem : problems) {
			if (String.isBlank(problem)) return false;
		}

		return true;
	}

	private static Boolean hasWarnings(String pattern, Set<String> referencedFields) {
		List<String> warnings = new GoogleFolderNamePatternResolver().findWarnings(pattern, referencedFields);
		return warnings != null && !warnings.isEmpty();
	}

	@IsTest
	private static void testCompilePositiveBuildsEachFormulaOncePerObjectAndPattern() {
		GoogleFolderNamePatternResolver resolver = new GoogleFolderNamePatternResolver();

		Test.startTest();
		FormulaEval.FormulaInstance firstFormula = resolver.compile(GoogleFile__c.SObjectType, 'Name');
		FormulaEval.FormulaInstance repeatedFormula = resolver.compile(GoogleFile__c.SObjectType, 'Name');
		FormulaEval.FormulaInstance otherObjectFormula = resolver.compile(GoogleFileVersion__c.SObjectType, 'Name');
		Test.stopTest();

		Assert.isNotNull(firstFormula);
		Assert.isTrue(firstFormula === repeatedFormula, 'The same pattern on the same object is compiled once per transaction');
		Assert.isFalse(firstFormula === otherObjectFormula, 'A pattern is compiled against the object it names');
	}

	@IsTest
	private static void testCompileNegativeThrowsForAPatternSalesforceRefuses() {
		Exception compileFailure;

		Test.startTest();
		try {
			new GoogleFolderNamePatternResolver().compile(GoogleFile__c.SObjectType, 'Name & & "x"');
		} catch (Exception ex) {
			compileFailure = ex;
		}
		Test.stopTest();

		Assert.isNotNull(compileFailure, 'A pattern that does not compile must not be used to name a folder');
	}

	@IsTest
	private static void testFindProblemsPositiveAcceptsATextFormula() {
		Test.startTest();
		List<String> fileProblems = new GoogleFolderNamePatternResolver().findProblems(GoogleFile__c.SObjectType, 'Name & " - " & TEXT(Source__c)');
		List<String> versionProblems = new GoogleFolderNamePatternResolver().findProblems(GoogleFileVersion__c.SObjectType, 'GoogleFileId__r.Name & " v" & TEXT(Size__c)');
		Test.stopTest();

		Assert.isTrue(fileProblems == null || fileProblems.isEmpty(), 'A formula returning text from the object\'s own fields is usable');
		Assert.isTrue(versionProblems == null || versionProblems.isEmpty(), 'A related record\'s field can be used too');
	}

	@IsTest
	private static void testFindProblemsNegativeExplainsAnUnknownField() {
		Assert.isTrue(hasProblems(GoogleFile__c.SObjectType, 'Name & Nope__c'), 'A field that does not exist is refused with Salesforce\'s own message');
	}

	@IsTest
	private static void testFindProblemsNegativeExplainsASyntaxError() {
		Assert.isTrue(hasProblems(GoogleFile__c.SObjectType, 'Name & & "x"'));
	}

	@IsTest
	private static void testFindProblemsNegativeRefusesTheRunningUser() {
		Assert.isTrue(hasProblems(GoogleFile__c.SObjectType, 'Name & $User.FirstName'), 'A name must never depend on who uploads');
	}

	@IsTest
	private static void testFindProblemsNegativeRefusesAResultThatIsNotText() {
		Assert.isTrue(hasProblems(GoogleFileVersion__c.SObjectType, 'Size__c'), 'A folder name must be text');
	}

	@IsTest
	private static void testFindProblemsNegativeRefusesABlankPattern() {
		Assert.isTrue(hasProblems(GoogleFile__c.SObjectType, '   '));
	}

	@IsTest
	private static void testFindWarningsPositiveWarnsForFunctionsThatChangeByThemselves() {
		Set<String> referencedFields = new Set<String>{ 'Name' };

		Assert.isTrue(hasWarnings('Name & " " & TEXT(TODAY())', referencedFields));
		Assert.isTrue(hasWarnings('Name & " " & TEXT(NOW())', referencedFields));
		Assert.isTrue(hasWarnings('Name & " " & TEXT(TIMENOW())', referencedFields));
	}

	@IsTest
	private static void testFindWarningsPositiveIgnoresLetterCase() {
		Assert.isTrue(hasWarnings('Name & " " & TEXT(today())', new Set<String>{ 'Name' }), 'Formulas ignore letter case, so the warning must too');
	}

	@IsTest
	private static void testFindWarningsPositiveWarnsForFieldsThatChangeOnEverySave() {
		for (String alwaysChangingField : ALWAYS_CHANGING_FIELDS) {
			Assert.isTrue(
				hasWarnings('Name & " " & TEXT(' + alwaysChangingField + ')', new Set<String>{ 'Name', alwaysChangingField }),
				alwaysChangingField + ' changes on every save and must ask for confirmation'
			);
		}
	}

	@IsTest
	private static void testFindWarningsPositiveWarnsForARelatedRecordsAlwaysChangingField() {
		Assert.isTrue(
			hasWarnings('Name & " " & TEXT(GoogleFileId__r.LastModifiedDate)', new Set<String>{ 'Name', 'GoogleFileId__r.LastModifiedDate' }),
			'A related record that changes on every save renames the folder by itself as well'
		);
	}

	@IsTest
	private static void testFindWarningsPositiveStaysQuietForAStablePattern() {
		Assert.isFalse(hasWarnings('Name & "_" & TEXT(CreatedDate)', new Set<String>{ 'Name', 'CreatedDate' }));
		Assert.isFalse(hasWarnings('Name & Snowfall__c', new Set<String>{ 'Name', 'Snowfall__c' }), 'A field whose name merely contains "now" is not the NOW() function');
	}

	@IsTest
	private static void testRenderPositiveWritesTheFormulaResult() {
		Assert.areEqual('Acme Brochure - 069000000000001AAA', renderOnFile('Name & " - " & SalesforceFileId__c', buildFileRecord('Acme Brochure', '069000000000001AAA')));
	}

	@IsTest
	private static void testRenderPositiveWritesDatesAndTimesInGmt() {
		GoogleFile__c record = (GoogleFile__c) JSON.deserialize(
			'{"attributes":{"type":"GoogleFile__c"},"Name":"Acme Brochure","CreatedDate":"2026-10-24T23:30:00.000+0000"}',
			GoogleFile__c.class
		);

		Assert.areEqual('2026-10-24|2026-10-24 23:30:00Z', renderOnFile('TEXT(DATEVALUE(CreatedDate)) & "|" & TEXT(CreatedDate)', record), 'Dates and times are written the same way whoever uploads, in any time zone');
	}

	@IsTest
	private static void testRenderPositiveWritesNumbersWithoutGrouping() {
		Assert.areEqual('10042.5', renderOnVersion('TEXT(Size__c)', new GoogleFileVersion__c(Size__c = 10042.5)));
		Assert.areEqual('1234567', renderOnVersion('TEXT(Size__c)', new GoogleFileVersion__c(Size__c = 1234567)));
	}

	@IsTest
	private static void testRenderPositiveWritesThePicklistsStoredValue() {
		GoogleFile__c record = new GoogleFile__c(Name = 'Acme Brochure', Source__c = 'Migration');

		Assert.areEqual('Acme Brochure (Migration)', renderOnFile('Name & " (" & TEXT(Source__c) & ")"', record));
	}

	@IsTest
	private static void testRenderPositiveReadsARelatedRecordsField() {
		GoogleFileVersion__c record = (GoogleFileVersion__c) JSON.deserialize(
			'{"attributes":{"type":"GoogleFileVersion__c"},"Name":"v1.pdf","GoogleFileId__r":{"attributes":{"type":"GoogleFile__c"},"Name":"Acme Brochure"}}',
			GoogleFileVersion__c.class
		);

		Assert.areEqual('Acme Brochure / v1.pdf', renderOnVersion('GoogleFileId__r.Name & " / " & Name', record));
	}

	@IsTest
	private static void testRenderPositiveCollapsesLineBreaksAndSpaces() {
		Assert.areEqual('Line one Line two', renderOnFile('Name', buildFileRecord('  Line one\r\n\n  Line   two  ', null)));
	}

	@IsTest
	private static void testRenderPositiveCutsTheNameAt255Characters() {
		String rendered = renderOnFile('Name & "' + 'x'.repeat(300) + '"', buildFileRecord('A', null));

		Assert.areEqual(MAX_FOLDER_NAME_LENGTH, rendered.length());
		Assert.isTrue(rendered.startsWith('Ax'));
	}

	@IsTest
	private static void testRenderPositiveKeepsUnusualCharacters() {
		String recordName = 'R&D: "Q4" / 50% #1';

		Assert.areEqual(recordName, renderOnFile('Name', buildFileRecord(recordName, null)));
	}

	@IsTest
	private static void testRenderPositiveBlankResultIsBlank() {
		Assert.isTrue(String.isBlank(renderOnFile('Name', buildFileRecord(null, null))));
	}

	@IsTest
	private static void testRenderPositiveEveryReferencedFieldBlankIsBlank() {
		Assert.isTrue(String.isBlank(renderOnFile('"Folder " & SalesforceFileId__c', buildFileRecord('Acme Brochure', null))), 'Literal text alone must not name every such record\'s folder the same');
	}

	@IsTest
	private static void testRenderPositiveOneFilledFieldKeepsTheName() {
		Assert.areEqual('Acme Brochure_', renderOnFile('Name & "_" & SalesforceFileId__c', buildFileRecord('Acme Brochure', null)));
	}

	@IsTest
	private static void testRenderPositiveReadsAnOwnerThatCanAlsoBeAQueue() {
		GoogleFile__c record = (GoogleFile__c) JSON.deserialize(
			'{"attributes":{"type":"GoogleFile__c"},"Name":"Acme Brochure","Owner":{"attributes":{"type":"User"},"LastName":"Doe"}}',
			GoogleFile__c.class
		);

		Assert.areEqual('Folder Doe', renderOnFile('"Folder " & Owner:User.LastName', record), 'An owner field is a value like any other, so it alone keeps the name');
	}

	@IsTest
	private static void testToQueriedFieldsPositiveQueriesAnOwnerStepWithoutItsType() {
		List<String> queriedFields = new GoogleFolderNamePatternResolver().toQueriedFields(new Set<String>{ 'Id', 'Name', 'Owner:User.LastName', 'Owner:Queue.Name', 'GoogleFileId__r.Name' });

		Assert.areEqual(4, queriedFields.size());
		Assert.areEqual(new Set<String>{ 'Name', 'Owner.LastName', 'Owner.Name', 'GoogleFileId__r.Name' }, new Set<String>(queriedFields), 'A query cannot name the owner\'s type, and the Id is always selected anyway');
	}

	@IsTest
	private static void testToQueriedFieldsPositiveLeavesOutRepeats() {
		List<String> queriedFields = new GoogleFolderNamePatternResolver().toQueriedFields(new Set<String>{ 'Owner:User.LastName', 'Owner:Queue.LastName' });

		Assert.areEqual(new List<String>{ 'Owner.LastName' }, queriedFields);
	}

	@IsTest
	private static void testToQueriedFieldsNegativeNothingReferencedQueriesNothing() {
		Assert.isTrue(new GoogleFolderNamePatternResolver().toQueriedFields(null).isEmpty());
	}
}
