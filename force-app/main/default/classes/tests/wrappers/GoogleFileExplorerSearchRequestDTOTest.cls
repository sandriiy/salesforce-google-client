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
private class GoogleFileExplorerSearchRequestDTOTest {
	private static GoogleFileExplorerSearchRequestDTO withKeyPhrases(String keyPhrases) {
		return GoogleFileExplorerSearchRequestDTO.of(keyPhrases, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null);
	}

	private static GoogleFileExplorerSearchRequestDTO withExtensions(String fileExtensions) {
		return GoogleFileExplorerSearchRequestDTO.of(null, fileExtensions, null, null, null, null, null, null, null, null, null, null, null, null, null, null);
	}

	private static GoogleFileExplorerSearchRequestDTO withDates(String createdFrom, String createdTo, String modifiedFrom, String modifiedTo) {
		return GoogleFileExplorerSearchRequestDTO.of(null, null, null, null, createdFrom, createdTo, modifiedFrom, modifiedTo, null, null, null, null, null, null, null, null);
	}

	private static GoogleFileExplorerSearchRequestDTO withBounds(Long minSizeBytes, Long maxSizeBytes, Integer minVersions, Integer maxVersions) {
		return GoogleFileExplorerSearchRequestDTO.of(null, null, minSizeBytes, maxSizeBytes, null, null, null, null, minVersions, maxVersions, null, null, null, null, null, null);
	}

	private static GoogleFileExplorerSearchRequestDTO withOwnershipAndLinks(String ownership, String linkState) {
		return GoogleFileExplorerSearchRequestDTO.of(null, null, null, null, null, null, null, null, null, null, ownership, linkState, null, null, null, null);
	}

	private static Datetime startOfDay(Integer year, Integer month, Integer day) {
		return Datetime.newInstance(Date.newInstance(year, month, day), Time.newInstance(0, 0, 0, 0));
	}

	private static Boolean isBlank(List<String> values) {
		return values == null || values.isEmpty();
	}

	private static Boolean isBlank(Set<String> values) {
		return values == null || values.isEmpty();
	}

	@IsTest
	private static void testSearchPhrasesPositiveSplitsWordsAndKeepsQuotedTextWhole() {
		List<String> phrases = withKeyPhrases('"contract renewal" acme 2026').searchPhrases();

		Assert.areEqual(3, phrases.size());
		Assert.areEqual(new Set<String>{ 'contract renewal', 'acme', '2026' }, new Set<String>(phrases));
	}

	@IsTest
	private static void testSearchPhrasesPositiveDropsBlanksAndEmptyQuotes() {
		List<String> phrases = withKeyPhrases('  acme   ""   renewal  ').searchPhrases();

		Assert.areEqual(2, phrases.size());
		Assert.areEqual(new Set<String>{ 'acme', 'renewal' }, new Set<String>(phrases));
	}

	@IsTest
	private static void testSearchPhrasesPositiveIgnoresEveryPhrasePastTheCap() {
		List<String> words = new List<String>();
		for (Integer i = 1; i < GoogleFileExplorerSearchRequestDTO.MAX_SEARCH_PHRASES; i++) {
			words.add('word' + i);
		}
		words.add('"quoted pair"');
		words.add('overflow');

		List<String> phrases = withKeyPhrases(String.join(words, ' ')).searchPhrases();

		Assert.areEqual(GoogleFileExplorerSearchRequestDTO.MAX_SEARCH_PHRASES, phrases.size());
		Assert.isTrue(new Set<String>(phrases).contains('word1'));
		Assert.isTrue(new Set<String>(phrases).contains('quoted pair'), 'A quoted phrase counts once toward the cap');
		Assert.isFalse(new Set<String>(phrases).contains('overflow'), 'Everything past the cap is ignored');
	}

	@IsTest
	private static void testSearchPhrasesPositiveBlankInputMeansNoPhrases() {
		Assert.isTrue(isBlank(withKeyPhrases(null).searchPhrases()));
		Assert.isTrue(isBlank(withKeyPhrases('').searchPhrases()));
		Assert.isTrue(isBlank(withKeyPhrases('    ').searchPhrases()));
		Assert.isTrue(isBlank(withKeyPhrases('""').searchPhrases()));
	}

	@IsTest
	private static void testSearchPhrasesPositiveUnclosedQuoteFollowsTheRule() {
		List<String> phrases = withKeyPhrases('acme "renewal 2026').searchPhrases();

		Assert.areEqual(2, phrases.size());
		Assert.areEqual(new Set<String>{ 'acme', 'renewal 2026' }, new Set<String>(phrases), 'Text after a quote that is never closed is one phrase');
	}

	@IsTest
	private static void testExtensionsPositiveNormalizesCaseAndLeadingDot() {
		Set<String> extensions = withExtensions('PDF;.docx;Xlsx;7z;mp4;abcdefghij').extensions();

		Assert.areEqual(new Set<String>{ 'pdf', 'docx', 'xlsx', '7z', 'mp4', 'abcdefghij' }, extensions);
	}

	@IsTest
	private static void testExtensionsNegativeDropsAnythingButLettersAndDigits() {
		Set<String> extensions = withExtensions('pdf\' OR Name LIKE \'%;dw g;%;_;tar.gz;abcdefghijk;docé;txt').extensions();

		Assert.areEqual(new Set<String>{ 'txt' }, extensions);
	}

	@IsTest
	private static void testExtensionsPositiveCapsTheList() {
		List<String> requested = new List<String>();
		for (Integer i = 1; i <= GoogleFileExplorerSearchRequestDTO.MAX_SEARCH_EXTENSIONS + 1; i++) {
			requested.add('e' + i);
		}

		Set<String> extensions = withExtensions(String.join(requested, ';')).extensions();

		Assert.areEqual(GoogleFileExplorerSearchRequestDTO.MAX_SEARCH_EXTENSIONS, extensions.size());
	}

	@IsTest
	private static void testExtensionsPositiveEveryInvalidEntryMeansNoTypeFilter() {
		Assert.isTrue(isBlank(withExtensions('%;dw g;tar.gz').extensions()));
		Assert.isTrue(isBlank(withExtensions(null).extensions()));
		Assert.isTrue(isBlank(withExtensions('').extensions()));
	}

	@IsTest
	private static void testDatesPositiveReadWholeDaysInTheUsersTimeZone() {
		GoogleFileExplorerSearchRequestDTO request = withDates('2025-03-01', '2025-03-05', '2025-04-10', '2025-04-10');

		Assert.areEqual(startOfDay(2025, 3, 1), request.createdFrom());
		Assert.areEqual(startOfDay(2025, 3, 6), request.createdBefore(), 'The to day is included, so the bound is the start of the next day');
		Assert.areEqual(startOfDay(2025, 4, 10), request.modifiedFrom());
		Assert.areEqual(startOfDay(2025, 4, 11), request.modifiedBefore());

		GoogleFileExplorerSearchRequestDTO yearEnd = withDates(null, '2025-12-31', '2025-12-31', null);

		Assert.isNull(yearEnd.createdFrom());
		Assert.areEqual(startOfDay(2026, 1, 1), yearEnd.createdBefore());
		Assert.areEqual(startOfDay(2025, 12, 31), yearEnd.modifiedFrom());
		Assert.isNull(yearEnd.modifiedBefore());
	}

	@IsTest
	private static void testDatesNegativeIgnoreUnreadableValues() {
		GoogleFileExplorerSearchRequestDTO request = withDates('not a date', 'next week', '', null);

		Assert.isNull(request.createdFrom());
		Assert.isNull(request.createdBefore());
		Assert.isNull(request.modifiedFrom());
		Assert.isNull(request.modifiedBefore());
	}

	@IsTest
	private static void testBoundsPositiveSizeAndVersionLimitsFollowTheRule() {
		GoogleFileExplorerSearchRequestDTO request = withBounds(1048576L, 10485760L, 2, 4);

		Assert.isTrue(request.minSizeBytes() == 1048576);
		Assert.isTrue(request.maxSizeBytes() == 10485760);
		Assert.areEqual(2, request.minVersionCount());
		Assert.areEqual(4, request.maxVersionCount());

		GoogleFileExplorerSearchRequestDTO zero = withBounds(0L, null, 1, 1);

		Assert.isTrue(zero.minSizeBytes() == 0, 'Zero is a size, not a negative number');
		Assert.isNull(zero.maxSizeBytes());
		Assert.areEqual(1, zero.minVersionCount());
		Assert.areEqual(1, zero.maxVersionCount());
	}

	@IsTest
	private static void testBoundsNegativeIgnoresNegativeNumbers() {
		GoogleFileExplorerSearchRequestDTO request = withBounds(-1L, -5L, -2, -1);

		Assert.isNull(request.minSizeBytes());
		Assert.isNull(request.maxSizeBytes());
		Assert.isNull(request.minVersionCount());
		Assert.isNull(request.maxVersionCount());
	}

	@IsTest
	private static void testOwnershipPositiveMapsMineOthersAndAnythingElse() {
		Assert.areEqual(GoogleFileAccessResolver.OwnershipScope.OwnedByUser, withOwnershipAndLinks('mine', null).ownershipScope());
		Assert.areEqual(GoogleFileAccessResolver.OwnershipScope.NotOwnedByUser, withOwnershipAndLinks('others', null).ownershipScope());
		Assert.areEqual(GoogleFileAccessResolver.OwnershipScope.AnyOwner, withOwnershipAndLinks(null, null).ownershipScope());
		Assert.areEqual(GoogleFileAccessResolver.OwnershipScope.AnyOwner, withOwnershipAndLinks('', null).ownershipScope());
		Assert.areEqual(GoogleFileAccessResolver.OwnershipScope.AnyOwner, withOwnershipAndLinks('everyone', null).ownershipScope());
	}

	@IsTest
	private static void testOwnerIdPositiveReadsAUserOrQueueIdTrimmed() {
		Id userOwnerId = GoogleCloudTestFactory.fakeId(User.SObjectType);
		Id queueOwnerId = GoogleCloudTestFactory.fakeId('00G');

		Assert.areEqual(userOwnerId, withOwnershipAndLinks(String.valueOf(userOwnerId), null).ownerId());
		Assert.areEqual(userOwnerId, withOwnershipAndLinks('  ' + userOwnerId + '  ', null).ownerId(), 'Spaces around the Id are trimmed');
		Assert.areEqual(queueOwnerId, withOwnershipAndLinks(String.valueOf(queueOwnerId), null).ownerId(), 'A queue owns files too');
		Assert.areEqual(queueOwnerId, withOwnershipAndLinks(' ' + queueOwnerId + ' ', null).ownerId());
	}

	@IsTest
	private static void testOwnerIdNegativeNullForAnythingButAUserOrQueueId() {
		Assert.isNull(withOwnershipAndLinks('mine', null).ownerId());
		Assert.isNull(withOwnershipAndLinks('others', null).ownerId());
		Assert.isNull(withOwnershipAndLinks('', null).ownerId());
		Assert.isNull(withOwnershipAndLinks('   ', null).ownerId());
		Assert.isNull(withOwnershipAndLinks(null, null).ownerId());
		Assert.isNull(withOwnershipAndLinks('Dana Reyes', null).ownerId(), 'Text that is not an Id names no owner');
		Assert.isNull(withOwnershipAndLinks('005notAnId', null).ownerId(), 'Text that only looks like an Id names no owner');
		Assert.isNull(withOwnershipAndLinks(String.valueOf(GoogleCloudTestFactory.fakeId(GoogleFile__c.SObjectType)), null).ownerId(), 'An Id of another object names no owner');
	}

	@IsTest
	private static void testLinkedToRecordPositiveMapsLinkedUnlinkedAndBlank() {
		Assert.areEqual(true, withOwnershipAndLinks(null, 'linked').linkedToRecord());
		Assert.areEqual(false, withOwnershipAndLinks(null, 'unlinked').linkedToRecord());
		Assert.isNull(withOwnershipAndLinks(null, null).linkedToRecord());
		Assert.isNull(withOwnershipAndLinks(null, '').linkedToRecord());
		Assert.isNull(withOwnershipAndLinks(null, 'both').linkedToRecord());
	}

	@IsTest
	private static void testOfPositiveKeepsSortCursorAndPageSize() {
		GoogleFileExplorerSearchRequestDTO request = GoogleFileExplorerSearchRequestDTO.of(null, null, null, null, null, null, null, null, null, null, null, null, 'fileName', 'ASC', 'cursor-token', 25);
		GoogleFileExplorerPageRequestDTO pageRequest = request.pageRequest();

		Assert.areEqual('fileName', pageRequest.sortField);
		Assert.areEqual('Name', pageRequest.sortPath());
		Assert.areEqual('ASC', pageRequest.sortDirection);
		Assert.areEqual('cursor-token', pageRequest.cursor);
		Assert.areEqual(25, pageRequest.effectivePageSize());

		GoogleFileExplorerPageRequestDTO defaults = withKeyPhrases(null).pageRequest();

		Assert.isNotNull(defaults);
		Assert.areEqual('LastModifiedDate', defaults.sortPath());
		Assert.areEqual(GoogleCloudConstants.FILE_EXPLORER_PAGE_SIZE, defaults.effectivePageSize());
		Assert.isFalse(defaults.hasCursor());
	}
}
