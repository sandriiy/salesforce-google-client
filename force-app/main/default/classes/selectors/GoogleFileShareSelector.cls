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
public inherited sharing class GoogleFileShareSelector extends GSOQL implements GSOQL.Selector {
    @TestVisible
    private static final String MOCK_ID = 'GoogleFileShareSelector';

    public static final List<SObjectField> BASE_FIELDS = new List<SObjectField>{
        GoogleFile__Share.Id,
        GoogleFile__Share.ParentId,
        GoogleFile__Share.UserOrGroupId,
        GoogleFile__Share.AccessLevel,
        GoogleFile__Share.RowCause
    };

    public static GoogleFileShareSelector query() {
        return new GoogleFileShareSelector();
    }

    public GoogleFileShareSelector() {
        super(GoogleFile__Share.SObjectType);
        systemMode();
        withoutSharing();
        mockId(MOCK_ID);
    }

    public GoogleFileShareSelector byParentId(Id localFileRecordId) {
        whereAre(Filter.with(GoogleFile__Share.ParentId).equal(localFileRecordId));
        return this;
    }

    public GoogleFileShareSelector byParentIds(Set<Id> localFileRecordIds) {
        whereAre(Filter.with(GoogleFile__Share.ParentId).isIn(new List<Id>(localFileRecordIds)));
        return this;
    }

    public GoogleFileShareSelector byPrincipalId(Id userOrGroupId) {
        whereAre(Filter.with(GoogleFile__Share.UserOrGroupId).equal(userOrGroupId));
        return this;
    }

    public GoogleFileShareSelector byPrincipalIds(Set<Id> userOrGroupIds) {
        whereAre(Filter.with(GoogleFile__Share.UserOrGroupId).isIn(new List<Id>(userOrGroupIds)));
        return this;
    }

    public GoogleFileShareSelector excludingPrincipalId(Id userOrGroupId) {
        whereAre(Filter.with(GoogleFile__Share.UserOrGroupId).notEqual(userOrGroupId));
        return this;
    }

    public GoogleFileShareSelector excludingOwnerShares() {
        whereAre(Filter.with(GoogleFile__Share.RowCause).notEqual(Schema.GoogleFile__Share.RowCause.Owner));
        return this;
    }

    public GoogleFileShareSelector withBaseFields() {
        with(BASE_FIELDS);
        return this;
    }

    public GoogleFileShareSelector withPrincipalName() {
        with(BASE_FIELDS);
        with('UserOrGroup', new List<SObjectField>{ User.Name });
        return this;
    }

    public GoogleFileShareSelector limitTo(Integer n) {
        setLimit(n);
        return this;
    }
}
