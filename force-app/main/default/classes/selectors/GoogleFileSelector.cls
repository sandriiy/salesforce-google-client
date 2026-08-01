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
public inherited sharing class GoogleFileSelector extends GSOQL implements GSOQL.Selector {
    @TestVisible
    private static final String MOCK_ID = 'GoogleFileSelector';

    public static final List<SObjectField> BASE_FIELDS = new List<SObjectField>{
        GoogleFile__c.Id,
        GoogleFile__c.CreatedDate,
        GoogleFile__c.LastModifiedDate,
        GoogleFile__c.Source__c
    };

    public static final List<SObjectField> DETAIL_FIELDS = new List<SObjectField>{
        GoogleFile__c.Name,
        GoogleFile__c.Description__c,
        GoogleFile__c.OwnerId,
        GoogleFile__c.CreatedById
    };

	public static final List<SObjectField> ROLL_UP_FIELDS = new List<SObjectField>{
        GoogleFile__c.NumberOfVersions__c,
        GoogleFile__c.NumberOfLinks__c
    };

    public static GoogleFileSelector query() {
        return new GoogleFileSelector();
    }

    public GoogleFileSelector() {
        super(GoogleFile__c.SObjectType);
        systemMode();
        withoutSharing();
        mockId(MOCK_ID);
    }

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

    public GoogleFileSelector bySource(String source) {
        whereAre(Filter.with(GoogleFile__c.Source__c).equal(source));
        return this;
    }

	public GoogleFileSelector byOwner(Id userId) {
        whereAre(Filter.with(GoogleFile__c.OwnerId).equal(userId));
        return this;
    }

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

    public GoogleFileSelector withSpecificFields(List<String> fields) {
        with(String.join(fields, ','));
        return this;
    }

    public GoogleFileSelector withBaseFields() {
        with(BASE_FIELDS);
        return this;
    }

    public GoogleFileSelector withAllFields() {
        with(BASE_FIELDS);
        with(DETAIL_FIELDS);
		with(ROLL_UP_FIELDS);
        with('Owner.Name');
        return this;
    }

    public GoogleFileSelector withVersionsSubquery() {
        GSOQL.SubQuery versions = GSOQL.SubQuery.of('GoogleFileVersions__r')
            .with(GoogleFileVersionSelector.BASE_FIELDS)
            .with('CreatedBy', new List<SObjectField>{ User.Name })
            .orderBy(GoogleFileVersion__c.CreatedDate).sortDesc();

        with(versions);
        return this;
    }

    public GoogleFileSelector withLatestVersionSubquery() {
        return withLatestVersionSubquery(new List<String>());
    }

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

    public GoogleFileSelector orderByCreatedDesc() {
        orderBy(GoogleFile__c.CreatedDate).sortDesc();
        return this;
    }

    public GoogleFileSelector limitTo(Integer n) {
        setLimit(n);
        return this;
    }

    public GoogleFileSelector bySharedToPrincipals(Set<Id> principalIds) {
        whereAre(GSOQL.Filter.id().isIn(
			GSOQL.InnerJoin.of(GoogleFile__Share.SObjectType)
				.with(GoogleFile__Share.ParentId)
				.whereAre(GSOQL.Filter.with(GoogleFile__Share.UserOrGroupId).equal(principalIds))
        ));

        return this;
    }

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

    public GoogleFileSelector withCreatedByName() {
        with('CreatedBy.Name');
        return this;
    }

    public GoogleFileSelector bySearchTerm(String term) {
        if (String.isBlank(term)) return this;
        whereAre(GSOQL.Filter.with(GoogleFile__c.Name).contains(term));
        return this;
    }

    public GoogleFileSelector orderByFieldThenId(String sortPath, String direction) {
        String normalized = 'DESC'.equalsIgnoreCase(direction) ? 'DESC' : 'ASC';
        orderBy(sortPath, normalized);
        orderBy('Id', normalized);
        return this;
    }

    public GoogleFileSelector afterKeyset(String sortPath, Object lastValue, Id lastId, String direction) {
        Boolean descending = 'DESC'.equalsIgnoreCase(direction);
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
}