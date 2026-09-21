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
 * Reads the few user fields this package needs. Each set is separate so a caller asks for the type, the
 * name or the email rather than pulling the whole user record around.
 */
public inherited sharing class GoogleUserSelector extends GSOQL implements GSOQL.Selector {
    @TestVisible
    private static final String MOCK_ID = 'GoogleUserSelector';

    /**
     * The user type, which is what decides internal against Experience Cloud everywhere in the access layer.
     */
    public static final List<SObjectField> TYPE_FIELDS = new List<SObjectField>{
        User.Id,
        User.UserType
    };

    /**
     * The parts of the name the Drive folder for a user is built from.
     */
    public static final List<SObjectField> NAME_FIELDS = new List<SObjectField>{
        User.Id,
        User.FirstName,
        User.LastName
    };

    /**
     * The display name and email, the email being what a Google Drive grant is made out to.
     */
    public static final List<SObjectField> CONTACT_FIELDS = new List<SObjectField>{
        User.Id,
        User.Name,
        User.Email
    };

    /**
     * Starts a user query.
     *
     * @return A fresh selector to narrow and run.
     */
    public static GoogleUserSelector query() {
        return new GoogleUserSelector();
    }

    public GoogleUserSelector() {
        super(User.SObjectType);
        systemMode();
        withoutSharing();
        mockId(MOCK_ID);
    }

    /**
     * Keeps one user.
     *
     * @param userId The user to read.
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleUserSelector byUserId(Id userId) {
        whereAre(Filter.with(User.Id).equal(userId));
        return this;
    }

    /**
     * Keeps several users at once.
     *
     * @param userIds The users to read.
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleUserSelector byUserIds(Set<Id> userIds) {
        whereAre(Filter.with(User.Id).isIn(new List<Id>(userIds)));
        return this;
    }

    /**
     * Selects the user type.
     *
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleUserSelector withTypeFields() {
        with(TYPE_FIELDS);
        return this;
    }

    /**
     * Selects the first and last name.
     *
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleUserSelector withNameFields() {
        with(NAME_FIELDS);
        return this;
    }

    /**
     * Selects the display name and email.
     *
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleUserSelector withContactFields() {
        with(CONTACT_FIELDS);
        return this;
    }

    /**
     * Caps how many rows come back.
     *
     * @param n The maximum number of users.
     * @return This same instance, so the call chains onto toList().
     */
    public GoogleUserSelector limitTo(Integer n) {
        setLimit(n);
        return this;
    }
}
