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
/**
 * What the Search view of File Explorer asks for: key phrases and filters on top of the sort, cursor and
 * page size every page has. Each value is read leniently, so one the search cannot read is ignored rather
 * than refused, and what comes out of the accessors is typed and bounded before it gets near a query.
 */
public with sharing class GoogleFileExplorerSearchRequestDTO {
	/**
	 * How many words or quoted phrases a search counts. Anything past them is ignored.
	 */
	public static final Integer MAX_SEARCH_PHRASES = 10;
	/**
	 * How many file extensions a search counts. Anything past them is ignored.
	 */
	public static final Integer MAX_SEARCH_EXTENSIONS = 50;

	private static final Pattern SEARCH_PHRASE_PATTERN = Pattern.compile('"([^"]*)"?|([^\\s"]+)');
	private static final Pattern FILE_EXTENSION_PATTERN = Pattern.compile('[a-z0-9]{1,10}');
	private static final String FILE_EXTENSION_SEPARATOR = ';';
	private static final String OWNERSHIP_MINE = 'mine';
	private static final String OWNERSHIP_OTHERS = 'others';
	private static final String LINK_STATE_LINKED = 'linked';
	private static final String LINK_STATE_UNLINKED = 'unlinked';

	private String keyPhrases;
	private String fileExtensions;
	private Long minimumSize;
	private Long maximumSize;
	private String createdFromDay;
	private String createdToDay;
	private String modifiedFromDay;
	private String modifiedToDay;
	private Integer minVersions;
	private Integer maxVersions;
	private String ownership;
	private String linkState;
	private GoogleFileExplorerPageRequestDTO explorerPageRequest;

	/**
	 * Builds a search from separate values, which is how it arrives from a Lightning component, since a
	 * custom Apex type crossing that boundary comes through with every field empty. Days are "YYYY-MM-DD"
	 * and are read as whole days in the running user's time zone.
	 *
	 * @param keyPhrases What the user typed. Words are matched one by one, text in double quotes as a whole.
	 * @param fileExtensions Extensions separated by semicolons, such as "pdf;docx".
	 * @param minSizeBytes The smallest size to include, in bytes.
	 * @param maxSizeBytes The size to stop just before, in bytes.
	 * @param createdFrom The first day of creation to include.
	 * @param createdTo The last day of creation to include.
	 * @param modifiedFrom The first day of the last change to include.
	 * @param modifiedTo The last day of the last change to include.
	 * @param minVersions The fewest versions a file may have.
	 * @param maxVersions The most versions a file may have.
	 * @param ownership "mine", "others", the Id of the user or queue owning the files, or anything else for every owner.
	 * @param linkState "linked", "unlinked", or anything else for both.
	 * @param sortField The column being sorted on.
	 * @param sortDirection "ASC" or "DESC".
	 * @param cursor Where to continue, or null for the first page.
	 * @param pageSize How many rows to return.
	 * @return The search the service works from.
	 */
	public static GoogleFileExplorerSearchRequestDTO of(String keyPhrases, String fileExtensions, Long minSizeBytes, Long maxSizeBytes, String createdFrom, String createdTo, String modifiedFrom, String modifiedTo, Integer minVersions, Integer maxVersions, String ownership, String linkState, String sortField, String sortDirection, String cursor, Integer pageSize) {
		GoogleFileExplorerSearchRequestDTO request = new GoogleFileExplorerSearchRequestDTO();
		request.keyPhrases = keyPhrases;
		request.fileExtensions = fileExtensions;
		request.minimumSize = minSizeBytes;
		request.maximumSize = maxSizeBytes;
		request.createdFromDay = createdFrom;
		request.createdToDay = createdTo;
		request.modifiedFromDay = modifiedFrom;
		request.modifiedToDay = modifiedTo;
		request.minVersions = minVersions;
		request.maxVersions = maxVersions;
		request.ownership = ownership;
		request.linkState = linkState;
		request.explorerPageRequest = GoogleFileExplorerPageRequestDTO.of(sortField, sortDirection, null, cursor, pageSize, null);
		return request;
	}

	/**
	 * The sort, cursor and page size of this search as an ordinary page request, so paging works exactly
	 * as it does in the other views.
	 *
	 * @return The page request, with no search term and no bucket.
	 */
	public GoogleFileExplorerPageRequestDTO pageRequest() {
		return explorerPageRequest;
	}

	/**
	 * The words and phrases every matching file must contain. Text in double quotes is one phrase, text after
	 * a quote that is never closed is one phrase too, and blanks and repeats are dropped.
	 *
	 * @return At most MAX_SEARCH_PHRASES phrases, in the order they were typed.
	 */
	public List<String> searchPhrases() {
		List<String> phrases = new List<String>();
		if (String.isBlank(keyPhrases)) return phrases;

		Set<String> seenPhrases = new Set<String>();
		Matcher phraseMatcher = SEARCH_PHRASE_PATTERN.matcher(keyPhrases);

		while (phrases.size() < MAX_SEARCH_PHRASES && phraseMatcher.find()) {
			String quotedPhrase = phraseMatcher.group(1);
			String phrase = (quotedPhrase == null ? phraseMatcher.group(2) : quotedPhrase).normalizeSpace();

			if (String.isNotBlank(phrase) && seenPhrases.add(phrase.toLowerCase())) {
				phrases.add(phrase);
			}
		}

		return phrases;
	}

	/**
	 * The file extensions to keep, lower case and without a leading dot. Only letters and digits up to ten
	 * characters count, so an empty set means the search has no type filter at all.
	 *
	 * @return At most MAX_SEARCH_EXTENSIONS extensions.
	 */
	public Set<String> extensions() {
		Set<String> normalizedExtensions = new Set<String>();
		if (String.isBlank(fileExtensions)) return normalizedExtensions;

		for (String requestedExtension : fileExtensions.split(FILE_EXTENSION_SEPARATOR)) {
			if (normalizedExtensions.size() >= MAX_SEARCH_EXTENSIONS) break;

			String extension = requestedExtension.trim().toLowerCase().removeStart('.');
			if (FILE_EXTENSION_PATTERN.matcher(extension).matches()) {
				normalizedExtensions.add(extension);
			}
		}

		return normalizedExtensions;
	}

	/**
	 * The smallest size to include, in bytes.
	 *
	 * @return The size, or null when none was given or it was negative.
	 */
	public Decimal minSizeBytes() {
		return nonNegativeSize(minimumSize);
	}

	/**
	 * The size to stop just before, in bytes, so a range never counts its upper limit.
	 *
	 * @return The size, or null when none was given or it was negative.
	 */
	public Decimal maxSizeBytes() {
		return nonNegativeSize(maximumSize);
	}

	/**
	 * The start of the first day of creation to include.
	 *
	 * @return The moment, or null when no day was given or it could not be read.
	 */
	public Datetime createdFrom() {
		return startOfDay(createdFromDay, 0);
	}

	/**
	 * The start of the day after the last day of creation, so that day is included whole.
	 *
	 * @return The moment to stop before, or null when no day was given or it could not be read.
	 */
	public Datetime createdBefore() {
		return startOfDay(createdToDay, 1);
	}

	/**
	 * The start of the first day of the last change to include.
	 *
	 * @return The moment, or null when no day was given or it could not be read.
	 */
	public Datetime modifiedFrom() {
		return startOfDay(modifiedFromDay, 0);
	}

	/**
	 * The start of the day after the last day of the last change, so that day is included whole.
	 *
	 * @return The moment to stop before, or null when no day was given or it could not be read.
	 */
	public Datetime modifiedBefore() {
		return startOfDay(modifiedToDay, 1);
	}

	/**
	 * The fewest versions a file may have.
	 *
	 * @return The count, or null when none was given or it was negative.
	 */
	public Integer minVersionCount() {
		return nonNegativeCount(minVersions);
	}

	/**
	 * The most versions a file may have.
	 *
	 * @return The count, or null when none was given or it was negative.
	 */
	public Integer maxVersionCount() {
		return nonNegativeCount(maxVersions);
	}

	/**
	 * Whose files to keep. The owner is the file's owner in Salesforce, never whoever uploaded it.
	 *
	 * @return OwnedByUser for "mine", NotOwnedByUser for "others", AnyOwner otherwise.
	 */
	public GoogleFileAccessResolver.OwnershipScope ownershipScope() {
		if (OWNERSHIP_MINE.equalsIgnoreCase(ownership)) return GoogleFileAccessResolver.OwnershipScope.OwnedByUser;
		if (OWNERSHIP_OTHERS.equalsIgnoreCase(ownership)) return GoogleFileAccessResolver.OwnershipScope.NotOwnedByUser;
		return GoogleFileAccessResolver.OwnershipScope.AnyOwner;
	}

	/**
	 * The one owner whose files to keep, when the search names a user or a queue rather than "mine" or
	 * "others". Naming an owner only narrows the list; every file still passes the access check.
	 *
	 * @return The owner, or null when the search names none or the value is not a user or queue Id.
	 */
	public Id ownerId() {
		if (String.isBlank(ownership)) return null;

		try {
			Id candidateOwnerId = Id.valueOf(ownership.trim());
			Schema.SObjectType ownerType = candidateOwnerId.getSObjectType();
			return (ownerType == User.SObjectType || ownerType == Group.SObjectType) ? candidateOwnerId : null;
		} catch (Exception ex) {
			return null;
		}
	}

	/**
	 * Whether to keep files linked to at least one record, or files linked to none.
	 *
	 * @return True for "linked", false for "unlinked", null for both.
	 */
	public Boolean linkedToRecord() {
		if (LINK_STATE_LINKED.equalsIgnoreCase(linkState)) return true;
		if (LINK_STATE_UNLINKED.equalsIgnoreCase(linkState)) return false;
		return null;
	}

	private Datetime startOfDay(String day, Integer daysLater) {
		if (String.isBlank(day)) return null;

		try {
			return Datetime.newInstance(Date.valueOf(day.trim()).addDays(daysLater), Time.newInstance(0, 0, 0, 0));
		} catch (Exception ex) {
			return null;
		}
	}

	private Decimal nonNegativeSize(Long sizeBytes) {
		return (sizeBytes == null || sizeBytes < 0) ? null : Decimal.valueOf(sizeBytes);
	}

	private Integer nonNegativeCount(Integer count) {
		return (count == null || count < 0) ? null : count;
	}
}
