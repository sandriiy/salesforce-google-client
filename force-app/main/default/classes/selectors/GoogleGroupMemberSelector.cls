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
 * Finds the groups a user belongs to, which is how a file shared with a public group reaches them.
 */
public inherited sharing class GoogleGroupMemberSelector extends GSOQL implements GSOQL.Selector {
    @TestVisible
    private static final String MOCK_ID = 'GoogleGroupMemberSelector';

    /**
     * The group types a file can actually be shared with. Role and territory groups exist too but are not
     * something a user picks when sharing.
     */
    public static final Set<String> SHAREABLE_GROUP_TYPES = new Set<String>{ 'Regular', 'Queue' };

    /**
     * Starts a group membership query.
     *
     * @return A fresh selector to narrow and run.
     */
    public static GoogleGroupMemberSelector query() {
        return new GoogleGroupMemberSelector();
    }

    public GoogleGroupMemberSelector() {
        super(GroupMember.SObjectType);
        systemMode();
        withoutSharing();
        mockId(MOCK_ID);
    }

    /**
     * Keeps the memberships of one user or group.
     *
     * @param userOrGroupId The member whose groups are wanted.
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleGroupMemberSelector byMemberId(Id userOrGroupId) {
        whereAre(Filter.with(GroupMember.UserOrGroupId).equal(userOrGroupId));
        return this;
    }

    /**
     * Keeps only the group types a file can be shared with.
     *
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleGroupMemberSelector byShareableGroupTypes() {
        whereAre(Filter.with('Group', Group.Type).isIn(new List<String>(SHAREABLE_GROUP_TYPES)));
        return this;
    }

    /**
     * Selects the group and its type.
     *
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleGroupMemberSelector withGroupFields() {
        with(GroupMember.GroupId);
        with('Group', new List<SObjectField>{ Group.Type });
        return this;
    }
}
