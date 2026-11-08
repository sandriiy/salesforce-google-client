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
private class GoogleFileSelectorTest {
	private static final Long ONE_MEBIBYTE = 1048576L;
	private static final Long TEN_MEBIBYTES = 10485760L;

	private static void setUpRealRecords() {
		GoogleCloudTestFactory.initMocks();
		GoogleCloudTestFactory.bypassTriggers();
	}

	private static GoogleFile__c insertFile(String fileName) {
		return GoogleCloudTestFactory.file().withName(fileName).insertRecord();
	}

	private static GoogleFile__c insertFileWithLatestVersion(String fileName, String versionName) {
		GoogleFile__c localFile = insertFile(fileName);
		GoogleCloudTestFactory.version().forFile(localFile.Id).withName(versionName).isLatest(true).insertRecord();
		return localFile;
	}

	private static GoogleFile__c insertFileWithType(String versionName, String mimeType) {
		GoogleFile__c localFile = insertFile(versionName);
		GoogleCloudTestFactory.version().forFile(localFile.Id).withName(versionName).withType(mimeType).isLatest(true).insertRecord();
		return localFile;
	}

	private static GoogleFile__c insertFileWithSize(String fileName, Long sizeBytes) {
		GoogleFile__c localFile = insertFile(fileName);
		GoogleCloudTestFactory.version().forFile(localFile.Id).withName(fileName + '.pdf').withSize(sizeBytes).isLatest(true).insertRecord();
		return localFile;
	}

	private static GoogleFile__c insertFileWithVersionCount(String fileName, Integer versionCount) {
		GoogleFile__c localFile = insertFile(fileName);
		List<GoogleFileVersion__c> versions = new List<GoogleFileVersion__c>();
		for (Integer i = 1; i <= versionCount; i++) {
			versions.add(GoogleCloudTestFactory.version().forFile(localFile.Id).withName(fileName + ' v' + i + '.pdf').isLatest(i == versionCount).build());
		}
		insert versions;
		return localFile;
	}

	private static Set<Id> matchedIds(GoogleFileSelector selector) {
		return new Map<Id, GoogleFile__c>((List<GoogleFile__c>) selector.toList()).keySet();
	}

	private static Set<Id> matchedByLatestVersion(GoogleFileSelector.LatestVersionFilter filter) {
		return matchedIds(GoogleFileSelector.query().withBaseFields().byLatestVersion(filter));
	}

	private static GoogleFileSelector.LatestVersionFilter phrases(List<String> searchPhrases) {
		return new GoogleFileSelector.LatestVersionFilter().withPhrases(searchPhrases);
	}

	private static GoogleFileSelector.LatestVersionFilter extensions(Set<String> fileExtensions) {
		return new GoogleFileSelector.LatestVersionFilter().withExtensions(fileExtensions);
	}

	private static GoogleFileSelector.LatestVersionFilter sizeBetween(Decimal minBytes, Decimal maxBytes) {
		return new GoogleFileSelector.LatestVersionFilter().withSizeBetween(minBytes, maxBytes);
	}

	@IsTest
	private static void testByLatestVersionPositiveEveryPhraseMayMatchADifferentField() {
		setUpRealRecords();

		GoogleFile__c spreadFile = insertFile('Spread Match');
		GoogleCloudTestFactory.version()
			.forFile(spreadFile.Id)
			.withName('Quarterly report.pdf')
			.withSummary('Covers the renewal terms')
			.withAiLabels('Finance; Legal')
			.isLatest(true)
			.insertRecord();
		insertFileWithLatestVersion('Name Only', 'Quarterly report two.pdf');

		Set<Id> matched = matchedByLatestVersion(phrases(new List<String>{ 'quarterly', 'renewal', 'finance' }));

		Assert.areEqual(new Set<Id>{ spreadFile.Id }, matched, 'Each phrase may be found in the name, the summary or the labels');
	}

	@IsTest
	private static void testByLatestVersionNegativeAMissingPhraseExcludesTheFile() {
		setUpRealRecords();

		GoogleFile__c reportFile = insertFileWithLatestVersion('Report', 'Quarterly report.pdf');
		GoogleFile__c reviewFile = insertFileWithLatestVersion('Review', 'Quarterly review.pdf');

		Assert.areEqual(new Set<Id>{ reportFile.Id, reviewFile.Id }, matchedByLatestVersion(phrases(new List<String>{ 'quarterly' })));
		Assert.isTrue(matchedByLatestVersion(phrases(new List<String>{ 'quarterly', 'absentword' })).isEmpty(), 'Every phrase must be found');
	}

	@IsTest
	private static void testByLatestVersionPositiveQuotedPhraseMatchesOnlyAsAWhole() {
		setUpRealRecords();

		GoogleFile__c exactOrder = insertFileWithLatestVersion('Exact Order', 'Contract Renewal 2026.pdf');
		GoogleFile__c otherOrder = insertFileWithLatestVersion('Other Order', 'Renewal of contract.pdf');

		Assert.areEqual(new Set<Id>{ exactOrder.Id }, matchedByLatestVersion(phrases(new List<String>{ 'contract renewal' })));
		Assert.areEqual(new Set<Id>{ exactOrder.Id, otherOrder.Id }, matchedByLatestVersion(phrases(new List<String>{ 'contract', 'renewal' })));
	}

	@IsTest
	private static void testByLatestVersionPositiveIgnoresCase() {
		setUpRealRecords();

		GoogleFile__c localFile = insertFile('Case File');
		GoogleCloudTestFactory.version().forFile(localFile.Id).withName('ACME Contract.pdf').withSummary('Signed by the BOARD').isLatest(true).insertRecord();

		Assert.areEqual(new Set<Id>{ localFile.Id }, matchedByLatestVersion(phrases(new List<String>{ 'acme', 'board' })));
		Assert.areEqual(new Set<Id>{ localFile.Id }, matchedByLatestVersion(phrases(new List<String>{ 'Acme', 'Board' })));
	}

	@IsTest
	private static void testByLatestVersionNegativeWildcardsMatchOnlyThemselves() {
		setUpRealRecords();

		GoogleFile__c percentFile = insertFileWithLatestVersion('Percent', 'Save 50% now.pdf');
		insertFileWithLatestVersion('Digits', 'Save 500 now.pdf');
		GoogleFile__c underscoreFile = insertFileWithLatestVersion('Underscore', 'plan_a.pdf');
		insertFileWithLatestVersion('Letter', 'planxa.pdf');
		GoogleFile__c backslashFile = insertFileWithLatestVersion('Backslash', 'back\\slash.pdf');
		insertFileWithLatestVersion('No Backslash', 'backslash.pdf');

		Assert.areEqual(new Set<Id>{ percentFile.Id }, matchedByLatestVersion(phrases(new List<String>{ '50%' })));
		Assert.areEqual(new Set<Id>{ underscoreFile.Id }, matchedByLatestVersion(phrases(new List<String>{ 'plan_a' })));
		Assert.areEqual(new Set<Id>{ backslashFile.Id }, matchedByLatestVersion(phrases(new List<String>{ 'k\\s' })));
	}

	@IsTest
	private static void testByLatestVersionNegativeAnOlderVersionDoesNotCount() {
		setUpRealRecords();

		GoogleFile__c localFile = insertFile('Versioned');
		insert new List<GoogleFileVersion__c>{
			GoogleCloudTestFactory.version().forFile(localFile.Id).withName('Budget draft.pdf').isLatest(false).build(),
			GoogleCloudTestFactory.version().forFile(localFile.Id).withName('Final figures.pdf').isLatest(true).build()
		};

		Assert.isTrue(matchedByLatestVersion(phrases(new List<String>{ 'budget' })).isEmpty(), 'Only the current version is searched');
		Assert.areEqual(new Set<Id>{ localFile.Id }, matchedByLatestVersion(phrases(new List<String>{ 'final' })));
	}

	@IsTest
	private static void testByLatestVersionPositiveExtensionMatchesNameOrStoredType() {
		setUpRealRecords();

		GoogleFile__c upperCaseName = insertFileWithType('Scan.PDF', 'application/octet-stream');
		GoogleFile__c renamedWithoutExtension = insertFileWithType('Signed scan', GoogleCloudConstants.MIME_TYPE_PDF);
		GoogleFile__c docxFile = insertFileWithType('Brief.docx', GoogleCloudConstants.FILE_EXTENSION_TO_MIME_TYPE.get('docx'));
		insertFileWithType('report.pdf.txt', GoogleCloudConstants.MIME_TYPE_TEXT);
		insertFileWithType('pdf-guide.txt', GoogleCloudConstants.MIME_TYPE_TEXT);

		Assert.areEqual(
			new Set<Id>{ upperCaseName.Id, renamedWithoutExtension.Id },
			matchedByLatestVersion(extensions(new Set<String>{ 'pdf' })),
			'A PDF is found by the end of its name or by its stored type, and nothing else is'
		);
		Assert.areEqual(
			new Set<Id>{ upperCaseName.Id, renamedWithoutExtension.Id, docxFile.Id },
			matchedByLatestVersion(extensions(new Set<String>{ 'pdf', 'docx' })),
			'Any listed extension matches'
		);
	}

	@IsTest
	private static void testByLatestVersionPositiveUnmappedExtensionMatchesByNameOnly() {
		setUpRealRecords();

		GoogleFile__c drawing = insertFileWithType('Site plan.dwg', 'application/octet-stream');
		insertFileWithType('Site plan', 'application/octet-stream');
		insertFileWithType('drawing.dwgx', 'application/octet-stream');

		Assert.areEqual(new Set<Id>{ drawing.Id }, matchedByLatestVersion(extensions(new Set<String>{ 'dwg' })));
	}

	@IsTest
	private static void testByLatestVersionPositiveSizeBoundsFollowTheRule() {
		setUpRealRecords();

		GoogleFile__c justUnder = insertFileWithSize('Just Under', ONE_MEBIBYTE - 1);
		GoogleFile__c exactlyOne = insertFileWithSize('Exactly One', ONE_MEBIBYTE);
		GoogleFile__c justUnderTen = insertFileWithSize('Just Under Ten', TEN_MEBIBYTES - 1);
		GoogleFile__c exactlyTen = insertFileWithSize('Exactly Ten', TEN_MEBIBYTES);

		Assert.areEqual(
			new Set<Id>{ exactlyOne.Id, justUnderTen.Id },
			matchedByLatestVersion(sizeBetween(ONE_MEBIBYTE, TEN_MEBIBYTES)),
			'A range includes its lower limit and stops just before its upper one'
		);
		Assert.areEqual(new Set<Id>{ justUnder.Id }, matchedByLatestVersion(sizeBetween(null, ONE_MEBIBYTE)));
		Assert.areEqual(new Set<Id>{ exactlyTen.Id }, matchedByLatestVersion(sizeBetween(TEN_MEBIBYTES, null)));
	}

	@IsTest
	private static void testByLatestVersionPositiveBlankFilterAddsNothing() {
		setUpRealRecords();

		GoogleFile__c withVersion = insertFileWithLatestVersion('With Version', 'With version.pdf');
		GoogleFile__c withoutVersion = insertFile('Without Version');
		Set<Id> everyFile = new Set<Id>{ withVersion.Id, withoutVersion.Id };

		Assert.areEqual(everyFile, matchedByLatestVersion(new GoogleFileSelector.LatestVersionFilter()));
		Assert.areEqual(
			everyFile,
			matchedByLatestVersion(new GoogleFileSelector.LatestVersionFilter()
				.withPhrases(new List<String>())
				.withExtensions(new Set<String>())
				.withSizeBetween(null, null)),
			'A blank filter must not narrow to files that have a current version'
		);
	}

	@IsTest
	private static void testByLatestVersionPositiveCombinesWithEveryFilePredicateInOneQuery() {
		setUpRealRecords();

		GoogleFile__c match = insertFile('Combined Match');
		insert new List<GoogleFileVersion__c>{
			GoogleCloudTestFactory.version().forFile(match.Id).withName('Old draft.pdf').isLatest(false).build(),
			GoogleCloudTestFactory.version().forFile(match.Id).withName('Combined renewal.pdf').withSize(2 * ONE_MEBIBYTE).isLatest(true).build()
		};
		GoogleCloudTestFactory.link().forFile(match.Id).insertRecord();
		Datetime now = Datetime.now();
		GoogleFileSelector.query().withBaseFields().byOwner(UserInfo.getUserId()).toList();

		Integer queriesBefore = Limits.getQueries();
		List<GoogleFile__c> matched = (List<GoogleFile__c>) GoogleFileSelector.query()
			.withAllFields()
			.withCreatedByName()
			.withLatestVersionSubquery()
			.byLatestVersion(new GoogleFileSelector.LatestVersionFilter()
				.withPhrases(new List<String>{ 'combined', 'renewal' })
				.withExtensions(new Set<String>{ 'pdf', 'docx' })
				.withSizeBetween(ONE_MEBIBYTE, TEN_MEBIBYTES))
			.byAccessibleCandidates(UserInfo.getUserId(), new Set<Id>{ GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType) })
			.byOwner(UserInfo.getUserId())
			.byCreatedOnOrAfter(now.addDays(-1))
			.byCreatedBefore(now.addDays(1))
			.byLastModifiedOnOrAfter(now.addDays(-1))
			.byLastModifiedBefore(now.addDays(1))
			.byVersionCountAtLeast(2)
			.byVersionCountAtMost(3)
			.byLinkedToRecords()
			.orderByFieldThenId('Name', 'ASC')
			.limitTo(51)
			.toList();

		Assert.areEqual(1, Limits.getQueries() - queriesBefore, 'Every criterion together is still one query');
		Assert.areEqual(1, matched.size());
		Assert.areEqual(match.Id, matched[0].Id);
	}

	@IsTest
	private static void testByCreatedBeforePositiveExcludesTheBoundary() {
		setUpRealRecords();

		GoogleFile__c earlier = insertFile('Earlier');
		GoogleFile__c lastMinute = insertFile('Last Minute');
		GoogleFile__c midnight = insertFile('Midnight');
		Test.setCreatedDate(earlier.Id, Datetime.newInstance(2025, 3, 4, 12, 0, 0));
		Test.setCreatedDate(lastMinute.Id, Datetime.newInstance(2025, 3, 5, 23, 59, 59));
		Test.setCreatedDate(midnight.Id, Datetime.newInstance(2025, 3, 6, 0, 0, 0));
		Datetime nextDay = Datetime.newInstance(2025, 3, 6, 0, 0, 0);

		Assert.areEqual(
			new Set<Id>{ earlier.Id, lastMinute.Id },
			matchedIds(GoogleFileSelector.query().withBaseFields().byCreatedBefore(nextDay)),
			'The bound itself is excluded'
		);
		Assert.areEqual(
			new Set<Id>{ lastMinute.Id },
			matchedIds(GoogleFileSelector.query().withBaseFields().byCreatedOnOrAfter(Datetime.newInstance(2025, 3, 5, 0, 0, 0)).byCreatedBefore(nextDay))
		);
	}

	@IsTest
	private static void testByLastModifiedPositiveBoundsAroundNow() {
		setUpRealRecords();

		GoogleFile__c earlierFile = insertFile('Earlier Modified');
		GoogleFile__c laterFile = insertFile('Later Modified');
		Set<Id> bothFiles = new Set<Id>{ earlierFile.Id, laterFile.Id };
		Datetime now = Datetime.now();

		Assert.areEqual(bothFiles, matchedIds(GoogleFileSelector.query().withBaseFields().byLastModifiedOnOrAfter(now.addHours(-1))));
		Assert.isTrue(matchedIds(GoogleFileSelector.query().withBaseFields().byLastModifiedOnOrAfter(now.addHours(1))).isEmpty());
		Assert.areEqual(bothFiles, matchedIds(GoogleFileSelector.query().withBaseFields().byLastModifiedBefore(now.addHours(1))));
		Assert.isTrue(matchedIds(GoogleFileSelector.query().withBaseFields().byLastModifiedBefore(now.addHours(-1))).isEmpty());
	}

	@IsTest
	private static void testByVersionCountPositiveAtLeastAndAtMost() {
		setUpRealRecords();

		GoogleFile__c single = insertFileWithVersionCount('Single', 1);
		GoogleFile__c pair = insertFileWithVersionCount('Pair', 2);
		GoogleFile__c five = insertFileWithVersionCount('Five', 5);

		Assert.areEqual(new Set<Id>{ single.Id }, matchedIds(GoogleFileSelector.query().withBaseFields().byVersionCountAtMost(1)));
		Assert.areEqual(new Set<Id>{ pair.Id, five.Id }, matchedIds(GoogleFileSelector.query().withBaseFields().byVersionCountAtLeast(2)));
		Assert.areEqual(new Set<Id>{ five.Id }, matchedIds(GoogleFileSelector.query().withBaseFields().byVersionCountAtLeast(5)));
		Assert.areEqual(new Set<Id>{ pair.Id }, matchedIds(GoogleFileSelector.query().withBaseFields().byVersionCountAtLeast(2).byVersionCountAtMost(4)));
	}

	@IsTest
	private static void testByLinkedToRecordsPositiveSplitsOnTheLinkCount() {
		setUpRealRecords();

		GoogleFile__c viewerLinked = insertFile('Viewer Linked');
		GoogleFile__c traceOnlyLinked = insertFile('Trace Only Linked');
		GoogleFile__c neverLinked = insertFile('Never Linked');
		GoogleFile__c unlinkedAgain = insertFile('Unlinked Again');

		GoogleCloudTestFactory.link().forFile(viewerLinked.Id).withShareType('Viewer').insertRecord();
		GoogleCloudTestFactory.link().forFile(traceOnlyLinked.Id).withShareType('None').insertRecord();
		GoogleFileLink__c removedLink = GoogleCloudTestFactory.link().forFile(unlinkedAgain.Id).insertRecord();
		delete removedLink;

		Assert.areEqual(
			new Set<Id>{ viewerLinked.Id, traceOnlyLinked.Id },
			matchedIds(GoogleFileSelector.query().withBaseFields().byLinkedToRecords()),
			'Any link counts, the same rule as the Is Linked? column'
		);
		Assert.areEqual(
			new Set<Id>{ neverLinked.Id, unlinkedAgain.Id },
			matchedIds(GoogleFileSelector.query().withBaseFields().byNotLinkedToRecords())
		);
	}

	@IsTest
	private static void testGroupedByOwnerPositiveOneRowPerOwnerWithTheirName() {
		setUpRealRecords();

		insert new List<GoogleFile__c>{
			GoogleCloudTestFactory.file().withName('First Owned').build(),
			GoogleCloudTestFactory.file().withName('Second Owned').build(),
			GoogleCloudTestFactory.file().withName('Third Owned').build()
		};
		String runningUserName = [SELECT Name FROM User WHERE Id = :UserInfo.getUserId()].Name;

		List<GSOQL.AggregateResultProxy> ownerRows = GoogleFileSelector.query()
			.groupedByOwner()
			.limitTo(200)
			.toAggregatedProxy();

		Assert.areEqual(1, ownerRows.size(), 'One row per owner, however many files they own');
		Assert.areEqual(UserInfo.getUserId(), (Id) ownerRows[0].get(GoogleFileSelector.OWNER_ID_KEY));
		Assert.areEqual(runningUserName, (String) ownerRows[0].get(GoogleFileSelector.OWNER_NAME_KEY));
	}
}
