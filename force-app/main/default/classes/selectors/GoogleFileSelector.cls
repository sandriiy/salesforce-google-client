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
 * Every query against GoogleFile__c starts here. It runs in system mode without sharing on purpose,
 * because who may see a file is decided by GoogleFileAccessResolver and not by the sharing model, so a
 * row coming out of here is a candidate and not yet something a user is allowed to see.
 */
public inherited sharing class GoogleFileSelector extends GSOQL implements GSOQL.Selector {
    @TestVisible
    private static final String MOCK_ID = 'GoogleFileSelector';

    /**
     * The fields every file query brings back. A mocked row missing one of these fails the test it is
     * mocked into, so add a field here and the inline queries in the tests have to follow.
     */
    public static final List<SObjectField> BASE_FIELDS = new List<SObjectField>{
        GoogleFile__c.Id,
        GoogleFile__c.CreatedDate,
        GoogleFile__c.LastModifiedDate,
        GoogleFile__c.Source__c
    };

    /**
     * The fields a screen showing a file needs on top of the base ones.
     */
    public static final List<SObjectField> DETAIL_FIELDS = new List<SObjectField>{
        GoogleFile__c.Name,
        GoogleFile__c.Description__c,
        GoogleFile__c.OwnerId,
        GoogleFile__c.CreatedById
    };

	/**
	 * The counts of versions and links, which File Explorer reads and paging filters on.
	 */
	public static final List<SObjectField> ROLL_UP_FIELDS = new List<SObjectField>{
        GoogleFile__c.NumberOfVersions__c,
        GoogleFile__c.NumberOfLinks__c
    };

    /**
     * Where the owner's Id sits in a row grouped by groupedByOwner().
     */
    public static final String OWNER_ID_KEY = 'OwnerId';
    /**
     * Where the owner's name sits in a row grouped by groupedByOwner(). SOQL names a grouped relationship
     * field after the field alone, without the relationship.
     */
    public static final String OWNER_NAME_KEY = 'Name';

    private static final String OWNER_NAME_PATH = 'Owner.Name';

    /**
     * Starts a file query.
     *
     * @return A fresh selector to narrow and run.
     */
    public static GoogleFileSelector query() {
        return new GoogleFileSelector();
    }

    public GoogleFileSelector() {
        super(GoogleFile__c.SObjectType);
        systemMode();
        withoutSharing();
        mockId(MOCK_ID);
    }

    /**
     * Keeps the files linked to one record.
     *
     * @param relatedId The record the files are attached to.
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileSelector byRelatedRecordId(Id relatedId) {
        whereAre(
            GSOQL.Filter.id().isIn(
                GSOQL.InnerJoin.of(GoogleFileLink__c.SObjectType)
                    .with(GoogleFileLink__c.GoogleFileId__c)
                    .whereAre(
                        GSOQL.Filter.with(GoogleFileLink__c.LinkedObjectId__c).equal(relatedId)
                    )
            )
        );

        return this;
    }

    /**
     * Keeps the files whose source matches, which is where they were first uploaded from.
     *
     * @param source A value of the Source picklist.
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileSelector bySource(String source) {
        whereAre(Filter.with(GoogleFile__c.Source__c).equal(source));
        return this;
    }

	/**
	 * Keeps the files owned by one user.
	 *
	 * @param userId The owner to match.
	 * @return This same instance, so the call chains onto toList().
	 */
	public GoogleFileSelector byOwner(Id userId) {
        whereAre(Filter.with(GoogleFile__c.OwnerId).equal(userId));
        return this;
    }

    /**
     * Keeps the files copied from any of those Salesforce files, which is how a migration knows a file is
     * already in Google Drive.
     *
     * @param salesforceFileIds The Content Document Ids to match.
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileSelector bySalesforceFileIds(Set<Id> salesforceFileIds) {
        List<String> salesforceFileIdValues = new List<String>();
        for (Id salesforceFileId : salesforceFileIds) {
            salesforceFileIdValues.add(String.valueOf(salesforceFileId));
        }

        whereAre(Filter.with(GoogleFile__c.SalesforceFileId__c).isIn(salesforceFileIdValues));
        return this;
    }

    /**
     * Keeps the files created at or after a moment, which is how a migration counts what it has copied so far.
     *
     * @param createdOnOrAfter The earliest creation moment to include.
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileSelector byCreatedOnOrAfter(Datetime createdOnOrAfter) {
        whereAre(Filter.with(GoogleFile__c.CreatedDate).greaterOrEqual(createdOnOrAfter));
        return this;
    }

    /**
     * Keeps the files created before a moment. Paired with byCreatedOnOrAfter() it makes a range that
     * leaves out its end, so a range of whole days ends on the start of the day after the last one.
     *
     * @param createdBefore The first creation moment to leave out.
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileSelector byCreatedBefore(Datetime createdBefore) {
        whereAre(Filter.with(GoogleFile__c.CreatedDate).lessThan(createdBefore));
        return this;
    }

    /**
     * Keeps the files last changed at or after a moment. This is the file's own date, the one File
     * Explorer sorts by, not the date of its current version.
     *
     * @param modifiedOnOrAfter The earliest change to include.
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileSelector byLastModifiedOnOrAfter(Datetime modifiedOnOrAfter) {
        whereAre(Filter.with(GoogleFile__c.LastModifiedDate).greaterOrEqual(modifiedOnOrAfter));
        return this;
    }

    /**
     * Keeps the files last changed before a moment, leaving that moment out.
     *
     * @param modifiedBefore The first change moment to leave out.
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileSelector byLastModifiedBefore(Datetime modifiedBefore) {
        whereAre(Filter.with(GoogleFile__c.LastModifiedDate).lessThan(modifiedBefore));
        return this;
    }

    /**
     * Keeps the files with at least this many versions.
     *
     * @param minVersionCount The fewest versions to include.
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileSelector byVersionCountAtLeast(Integer minVersionCount) {
        whereAre(Filter.with(GoogleFile__c.NumberOfVersions__c).greaterOrEqual(minVersionCount));
        return this;
    }

    /**
     * Keeps the files with at most this many versions.
     *
     * @param maxVersionCount The most versions to include.
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileSelector byVersionCountAtMost(Integer maxVersionCount) {
        whereAre(Filter.with(GoogleFile__c.NumberOfVersions__c).lessOrEqual(maxVersionCount));
        return this;
    }

    /**
     * Keeps the files linked to at least one record. Any link counts, including one that grants nothing,
     * which is the same rule as the Is Linked? column.
     *
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileSelector byLinkedToRecords() {
        whereAre(Filter.with(GoogleFile__c.NumberOfLinks__c).greaterThan(0));
        return this;
    }

    /**
     * Keeps the files linked to no record at all.
     *
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileSelector byNotLinkedToRecords() {
        whereAre(Filter.with(GoogleFile__c.NumberOfLinks__c).equal(0));
        return this;
    }

    /**
     * Keeps the files whose links derive their access from the linked record, which is how a user reaches a
     * file nobody shared with them directly.
     *
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileSelector byInferredRecordLinks() {
        whereAre(
            GSOQL.Filter.id().isIn(
                GSOQL.InnerJoin.of(GoogleFileLink__c.SObjectType)
                    .with(GoogleFileLink__c.GoogleFileId__c)
                    .whereAre(
                        GSOQL.FilterGroup
                            .add(GSOQL.Filter.with(GoogleFileLink__c.ShareType__c).equal('InferredFromRecord'))
                            .add(GSOQL.Filter.with(GoogleFileLink__c.Visibility__c).equal(new List<String>{ 'AllUsers', 'InternalUsers' }))
                            .conditionLogic('1 AND 2')
                    )
            )
        );

        return this;
    }

    /**
     * Selects exactly the fields you name, for a caller that knows what it needs.
     *
     * @param fields The field API names to select.
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileSelector withSpecificFields(List<String> fields) {
        with(String.join(fields, ','));
        return this;
    }

    /**
     * Selects the fields every file query needs.
     *
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileSelector withBaseFields() {
        with(BASE_FIELDS);
        return this;
    }

    /**
     * Selects just the Id and the owner, which is all an access check needs.
     *
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileSelector withOwnerOnly() {
        with(GoogleFile__c.Id, GoogleFile__c.OwnerId);
        return this;
    }

    /**
     * Selects everything a screen shows, including the owner name, which is the only way to get it right
     * for a file owned by a group or a queue.
     *
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileSelector withAllFields() {
        with(BASE_FIELDS);
        with(DETAIL_FIELDS);
		with(ROLL_UP_FIELDS);
        with('Owner.Name');
        return this;
    }

    /**
     * Brings back every version of each file, newest first.
     *
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileSelector withVersionsSubquery() {
        GSOQL.SubQuery versions = GSOQL.SubQuery.of('GoogleFileVersions__r')
            .with(GoogleFileVersionSelector.BASE_FIELDS)
            .with('CreatedBy', new List<SObjectField>{ User.Name })
            .orderBy(GoogleFileVersion__c.CreatedDate).sortDesc();

        with(versions);
        return this;
    }

    /**
     * Brings back only the current version of each file, which is what a list needs.
     *
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileSelector withLatestVersionSubquery() {
        return withLatestVersionSubquery(new List<String>());
    }

    /**
     * Brings back the current version with extra fields on top, which is how an administrator gets a custom
     * column into File Explorer.
     *
     * @param additionalFields Extra GoogleFileVersion__c field API names.
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileSelector withLatestVersionSubquery(List<String> additionalFields) {
        GSOQL.SubQuery latestVersion = GSOQL.SubQuery.of('GoogleFileVersions__r')
            .with(GoogleFileVersionSelector.BASE_FIELDS)
            .with('CreatedBy', new List<SObjectField>{ User.Name })
            .orderBy(GoogleFileVersion__c.CreatedDate).sortDesc()
            .setLimit(1);

        if (additionalFields != null && !additionalFields.isEmpty()) {
            latestVersion.with(String.join(additionalFields, ','));
        }

        with(latestVersion);
        return this;
    }

    /**
     * Newest file first.
     *
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileSelector orderByCreatedDesc() {
        orderBy(GoogleFile__c.CreatedDate).sortDesc();
        return this;
    }

    /**
     * Caps how many rows come back.
     *
     * @param n The maximum number of files.
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileSelector limitTo(Integer n) {
        setLimit(n);
        return this;
    }

    /**
     * Keeps the files shared with any of those users or groups.
     *
     * @param principalIds The users and groups to match.
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileSelector bySharedToPrincipals(Set<Id> principalIds) {
        whereAre(GSOQL.Filter.id().isIn(
			GSOQL.InnerJoin.of(GoogleFile__Share.SObjectType)
				.with(GoogleFile__Share.ParentId)
				.whereAre(GSOQL.Filter.with(GoogleFile__Share.UserOrGroupId).equal(principalIds))
        ));

        return this;
    }

   	/**
   	 * Keeps the files shared with any of those users or groups.
   	 *
   	 * @param userAndGroupIds The users and groups to match.
   	 * @return This same instance, so the call chains onto toList().
   	 */
   	public GoogleFileSelector bySharedToUserOrGroups(Set<Id> userAndGroupIds) {
        whereAre(
            GSOQL.Filter.id().isIn(
                GSOQL.InnerJoin.of(GoogleFile__Share.SObjectType)
                    .with(GoogleFile__Share.ParentId)
                    .whereAre(
                        GSOQL.Filter.with(GoogleFile__Share.UserOrGroupId).equal(userAndGroupIds)
                    )
            )
        );
        return this;
    }

    /**
     * Keeps the files a link grants outright, rather than by way of the record.
     *
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileSelector byDirectLinkForInternalVisibility() {
        whereAre(
            GSOQL.Filter.id().isIn(
                GSOQL.InnerJoin.of(GoogleFileLink__c.SObjectType)
                    .with(GoogleFileLink__c.GoogleFileId__c)
                    .whereAre(
                        GSOQL.FilterGroup
                            .add(GSOQL.Filter.with(GoogleFileLink__c.ShareType__c).equal(new List<String>{ 'Viewer', 'Collaborator' }))
                            .add(GSOQL.Filter.with(GoogleFileLink__c.Visibility__c).equal(new List<String>{ 'AllUsers', 'InternalUsers' }))
                            .conditionLogic('1 AND 2')
                    )
            )
        );
        return this;
    }

    /**
     * Adds the name of whoever uploaded the file.
     *
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileSelector withCreatedByName() {
        with('CreatedBy.Name');
        return this;
    }

    /**
     * Keeps the files whose current version matches the search, by name, summary or label. The term is
     * escaped, because a user typing a percent sign should not match everything.
     *
     * @param term What the user typed. Blank changes nothing.
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileSelector bySearchTerm(String term) {
        if (String.isBlank(term)) return this;

        String escapedTerm = escapeLikePattern(term);
        whereAre(
            GSOQL.Filter.id().isIn(
                GSOQL.InnerJoin.of(GoogleFileVersion__c.SObjectType)
                    .with(GoogleFileVersion__c.GoogleFileId__c)
                    .whereAre(
                        GSOQL.FilterGroup
                            .add(GSOQL.Filter.with(GoogleFileVersion__c.IsLatestFile__c).isTrue())
                            .add(
                                GSOQL.FilterGroup.anyConditionMatching()
                                    .add(GSOQL.Filter.with(GoogleFileVersion__c.Name).contains(escapedTerm))
                                    .add(GSOQL.Filter.with(GoogleFileVersion__c.Summary__c).contains(escapedTerm))
                                    .add(GSOQL.Filter.with(GoogleFileVersion__c.AiLabels__c).contains(escapedTerm))
                            )
                    )
            )
        );

        return this;
    }

    /**
     * Keeps the files whose current version passes the whole filter. Everything about the version goes
     * into this one subquery, because SOQL will not OR a semi join and limits how many a query may hold,
     * so do not combine it with bySearchTerm(); add the term as one more phrase instead. A blank filter
     * changes nothing, not even to files that have a current version.
     *
     * @param versionFilter The phrases, extensions and size the current version must match.
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileSelector byLatestVersion(LatestVersionFilter versionFilter) {
        if (versionFilter == null || versionFilter.isBlank()) return this;

        GSOQL.FilterGroup versionConditions = GSOQL.FilterGroup
            .add(GSOQL.Filter.with(GoogleFileVersion__c.IsLatestFile__c).isTrue());

        for (String phrase : versionFilter.phrases) {
            versionConditions.add(matchingPhrase(escapeLikePattern(phrase)));
        }

        if (!versionFilter.extensions.isEmpty()) {
            versionConditions.add(matchingExtension(versionFilter.extensions));
        }

        if (versionFilter.minSizeBytes != null) {
            versionConditions.add(GSOQL.Filter.with(GoogleFileVersion__c.Size__c).greaterOrEqual(versionFilter.minSizeBytes));
        }

        if (versionFilter.maxSizeBytes != null) {
            versionConditions.add(GSOQL.Filter.with(GoogleFileVersion__c.Size__c).lessThan(versionFilter.maxSizeBytes));
        }

        whereAre(
            GSOQL.Filter.id().isIn(
                GSOQL.InnerJoin.of(GoogleFileVersion__c.SObjectType)
                    .with(GoogleFileVersion__c.GoogleFileId__c)
                    .whereAre(versionConditions)
            )
        );

        return this;
    }

    /**
     * Narrows to the files a user could plausibly reach before access is resolved properly. Only plain field
     * predicates are used here, because SOQL will not OR a semi join, and a shared file therefore arrives as
     * a bound set of Ids rather than a subquery.
     *
     * @param targetUserId The user whose files are wanted.
     * @param sharedFileIds Files already known to be shared with them.
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileSelector byAccessibleCandidates(Id targetUserId, Set<Id> sharedFileIds) {
        GSOQL.FilterGroup candidateSources = GSOQL.FilterGroup.anyConditionMatching()
            .add(GSOQL.Filter.with(GoogleFile__c.OwnerId).equal(targetUserId))
            .add(GSOQL.Filter.with(GoogleFile__c.NumberOfLinks__c).greaterThan(0));

        if (sharedFileIds != null && !sharedFileIds.isEmpty()) {
            candidateSources.add(GSOQL.Filter.id().isIn(new List<Id>(sharedFileIds)));
        }

        whereAre(candidateSources);
        return this;
    }

    /**
     * Keeps the files somebody else owns, which is the shared with me half of File Explorer.
     *
     * @param userId The owner to exclude.
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileSelector byOwnerOtherThan(Id userId) {
        whereAre(GSOQL.Filter.with(GoogleFile__c.OwnerId).notEqual(userId));
        return this;
    }

    /**
     * Turns the query into one row per user or queue owning at least one file, with its name, sorted by name.
     * Read the rows through toAggregatedProxy() with OWNER_ID_KEY and OWNER_NAME_KEY. Each row counts once
     * against the query row limit, however many files that owner has.
     *
     * @return This same instance, so the call chains onto toAggregatedProxy().
     */
    public GoogleFileSelector groupedByOwner() {
        with(GoogleFile__c.OwnerId);
        with(OWNER_NAME_PATH);
        count(GoogleFile__c.Id);
        groupBy(GoogleFile__c.OwnerId);
        groupBy(OWNER_NAME_PATH);
        orderBy(OWNER_NAME_PATH);
        return this;
    }

    private String escapeLikePattern(String term) {
        return term.replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_');
    }

    private GSOQL.FilterGroup matchingPhrase(String escapedPhrase) {
        return GSOQL.FilterGroup.anyConditionMatching()
            .add(GSOQL.Filter.with(GoogleFileVersion__c.Name).contains(escapedPhrase))
            .add(GSOQL.Filter.with(GoogleFileVersion__c.Summary__c).contains(escapedPhrase))
            .add(GSOQL.Filter.with(GoogleFileVersion__c.AiLabels__c).contains(escapedPhrase));
    }

    private GSOQL.FilterGroup matchingExtension(Set<String> extensions) {
        GSOQL.FilterGroup extensionConditions = GSOQL.FilterGroup.anyConditionMatching();
        Set<String> mimeTypes = new Set<String>();

        for (String extension : extensions) {
            extensionConditions.add(GSOQL.Filter.with(GoogleFileVersion__c.Name).endsWith('.' + escapeLikePattern(extension)));

            String mimeType = GoogleCloudConstants.FILE_EXTENSION_TO_MIME_TYPE.get(extension);
            if (String.isNotBlank(mimeType)) mimeTypes.add(mimeType);
        }

        if (!mimeTypes.isEmpty()) {
            extensionConditions.add(GSOQL.Filter.with(GoogleFileVersion__c.Type__c).isIn(new List<String>(mimeTypes)));
        }

        return extensionConditions;
    }

    /**
     * Sorts by a field and then by Id, which is what makes paging stable when two files share a value.
     *
     * @param sortPath The field to sort by.
     * @param direction "ASC" or "DESC". Anything else is treated as ascending.
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileSelector orderByFieldThenId(String sortPath, String direction) {
        String normalized = 'DESC'.equalsIgnoreCase(direction) ? 'DESC' : 'ASC';
        orderBy(sortPath, normalized);
        nullsLast();
        orderBy('Id', normalized);
        nullsLast();
        return this;
    }

    /**
     * Continues after the last row of the previous page. It handles a null sort value as its own group, so
     * files with nothing in that field are neither repeated nor skipped.
     *
     * @param sortPath The field the page is sorted by.
     * @param lastValue That field on the last row of the previous page.
     * @param lastId The Id of the last row of the previous page.
     * @param direction The direction the page is sorted in.
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileSelector afterKeyset(String sortPath, Object lastValue, Id lastId, String direction) {
        Boolean descending = 'DESC'.equalsIgnoreCase(direction);

        if (lastValue == null) {
            whereAre(
                GSOQL.FilterGroup
                    .add(GSOQL.Filter.with(sortPath).equal(null))
                    .add(descending ? GSOQL.Filter.id().lessThan(lastId) : GSOQL.Filter.id().greaterThan(lastId))
            );

            return this;
        }

        GSOQL.Filter primary = descending
            ? GSOQL.Filter.with(sortPath).lessThan(lastValue)
            : GSOQL.Filter.with(sortPath).greaterThan(lastValue);
        GSOQL.Filter tieBreaker = descending
            ? GSOQL.Filter.id().lessThan(lastId)
            : GSOQL.Filter.id().greaterThan(lastId);
        whereAre(
            GSOQL.FilterGroup.anyConditionMatching()
                .add(primary)
                .add(GSOQL.FilterGroup.add(GSOQL.Filter.with(sortPath).equal(lastValue)).add(tieBreaker))
        );

        return this;
    }

    /**
     * What the current version of a file must match for byLatestVersion(). Each with... call chains, and a
     * filter nothing was added to is blank and narrows nothing.
     */
    public class LatestVersionFilter {
        public List<String> phrases { get; private set; }
        public Set<String> extensions { get; private set; }
        public Decimal minSizeBytes { get; private set; }
        public Decimal maxSizeBytes { get; private set; }

        public LatestVersionFilter() {
            phrases = new List<String>();
            extensions = new Set<String>();
        }

        /**
         * Adds phrases that must each appear in the name, the summary or the labels, in any case. A percent
         * sign, an underscore or a backslash matches only itself.
         *
         * @param searchPhrases The phrases to add. Blanks are skipped and null adds nothing.
         * @return This same filter, so the call chains on.
         */
        public LatestVersionFilter withPhrases(List<String> searchPhrases) {
            if (searchPhrases == null) return this;

            for (String phrase : searchPhrases) {
                if (String.isNotBlank(phrase)) phrases.add(phrase);
            }

            return this;
        }

        /**
         * Adds extensions of which any one must match, by the end of the version name or, for the types
         * GoogleCloudConstants.FILE_EXTENSION_TO_MIME_TYPE knows, by the stored type, so a file renamed
         * without its extension is still found.
         *
         * @param fileExtensions Extensions without the leading dot. Blanks are skipped and null adds nothing.
         * @return This same filter, so the call chains on.
         */
        public LatestVersionFilter withExtensions(Set<String> fileExtensions) {
            if (fileExtensions == null) return this;

            for (String extension : fileExtensions) {
                if (String.isNotBlank(extension)) extensions.add(extension.toLowerCase());
            }

            return this;
        }

        /**
         * Keeps sizes from the lower bound up to just before the upper one, so ranges placed end to end never
         * count a file twice.
         *
         * @param minBytes The smallest size to include, or null to leave it open.
         * @param maxBytes The size to stop just before, or null to leave it open.
         * @return This same filter, so the call chains on.
         */
        public LatestVersionFilter withSizeBetween(Decimal minBytes, Decimal maxBytes) {
            minSizeBytes = minBytes;
            maxSizeBytes = maxBytes;
            return this;
        }

        /**
         * Whether nothing was added to the filter.
         *
         * @return True when it has no phrase, no extension and no size bound.
         */
        public Boolean isBlank() {
            return phrases.isEmpty() && extensions.isEmpty() && minSizeBytes == null && maxSizeBytes == null;
        }
    }
}