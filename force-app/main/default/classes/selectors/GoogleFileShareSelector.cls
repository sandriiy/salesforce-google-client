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
 * Reads the GoogleFile__Share rows behind direct sharing. Shares cannot be created in a test, since that
 * needs a second real user, so anything asserting on them mocks this selector or captures the unit of
 * work instead.
 */
public inherited sharing class GoogleFileShareSelector extends GSOQL implements GSOQL.Selector {
    @TestVisible
    private static final String MOCK_ID = 'GoogleFileShareSelector';

    /**
     * What a share needs to be understood: who it is for, what it grants and why it exists.
     */
    public static final List<SObjectField> BASE_FIELDS = new List<SObjectField>{
        GoogleFile__Share.Id,
        GoogleFile__Share.ParentId,
        GoogleFile__Share.UserOrGroupId,
        GoogleFile__Share.AccessLevel,
        GoogleFile__Share.RowCause
    };

    /**
     * Starts a share query.
     *
     * @return A fresh selector to narrow and run.
     */
    public static GoogleFileShareSelector query() {
        return new GoogleFileShareSelector();
    }

    public GoogleFileShareSelector() {
        super(GoogleFile__Share.SObjectType);
        systemMode();
        withoutSharing();
        mockId(MOCK_ID);
    }

    /**
     * Keeps the shares of one file.
     *
     * @param localFileRecordId The shared GoogleFile__c.
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileShareSelector byParentId(Id localFileRecordId) {
        whereAre(Filter.with(GoogleFile__Share.ParentId).equal(localFileRecordId));
        return this;
    }

    /**
     * Keeps the shares of several files at once.
     *
     * @param localFileRecordIds The shared files.
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileShareSelector byParentIds(Set<Id> localFileRecordIds) {
        whereAre(Filter.with(GoogleFile__Share.ParentId).isIn(new List<Id>(localFileRecordIds)));
        return this;
    }

    /**
     * Keeps the shares granted to one user or group.
     *
     * @param userOrGroupId The user or group to match.
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileShareSelector byPrincipalId(Id userOrGroupId) {
        whereAre(Filter.with(GoogleFile__Share.UserOrGroupId).equal(userOrGroupId));
        return this;
    }

    /**
     * Keeps the shares granted to any of those users or groups, which is how a user's group memberships are
     * taken into account.
     *
     * @param userOrGroupIds The users and groups to match.
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileShareSelector byPrincipalIds(Set<Id> userOrGroupIds) {
        whereAre(Filter.with(GoogleFile__Share.UserOrGroupId).isIn(new List<Id>(userOrGroupIds)));
        return this;
    }

    /**
     * Drops the shares of one user or group, normally the owner, whose access nobody granted.
     *
     * @param userOrGroupId The user or group to leave out.
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileShareSelector excludingPrincipalId(Id userOrGroupId) {
        whereAre(Filter.with(GoogleFile__Share.UserOrGroupId).notEqual(userOrGroupId));
        return this;
    }

    /**
     * Drops the automatic owner share, so what is left is what somebody actually shared.
     *
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileShareSelector excludingOwnerShares() {
        whereAre(Filter.with(GoogleFile__Share.RowCause).notEqual(Schema.GoogleFile__Share.RowCause.Owner));
        return this;
    }

    /**
     * Selects the fields describing the share.
     *
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileShareSelector withBaseFields() {
        with(BASE_FIELDS);
        return this;
    }

    /**
     * Adds the name of whoever the file is shared with, so a list can show a person instead of an Id.
     *
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileShareSelector withPrincipalName() {
        with(BASE_FIELDS);
        with('UserOrGroup', new List<SObjectField>{ User.Name });
        return this;
    }

    /**
     * Caps how many rows come back.
     *
     * @param n The maximum number of shares.
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleFileShareSelector limitTo(Integer n) {
        setLimit(n);
        return this;
    }
}
