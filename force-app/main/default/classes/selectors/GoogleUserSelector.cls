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
public inherited sharing class GoogleUserSelector extends GSOQL implements GSOQL.Selector {
    @TestVisible
    private static final String MOCK_ID = 'GoogleUserSelector';

    public static final List<SObjectField> TYPE_FIELDS = new List<SObjectField>{
        User.Id,
        User.UserType
    };

    public static final List<SObjectField> NAME_FIELDS = new List<SObjectField>{
        User.Id,
        User.FirstName,
        User.LastName
    };

    public static final List<SObjectField> CONTACT_FIELDS = new List<SObjectField>{
        User.Id,
        User.Name,
        User.Email
    };

    public static GoogleUserSelector query() {
        return new GoogleUserSelector();
    }

    public GoogleUserSelector() {
        super(User.SObjectType);
        systemMode();
        withoutSharing();
        mockId(MOCK_ID);
    }

    public GoogleUserSelector byUserId(Id userId) {
        whereAre(Filter.with(User.Id).equal(userId));
        return this;
    }

    public GoogleUserSelector byUserIds(Set<Id> userIds) {
        whereAre(Filter.with(User.Id).isIn(new List<Id>(userIds)));
        return this;
    }

    public GoogleUserSelector withTypeFields() {
        with(TYPE_FIELDS);
        return this;
    }

    public GoogleUserSelector withNameFields() {
        with(NAME_FIELDS);
        return this;
    }

    public GoogleUserSelector withContactFields() {
        with(CONTACT_FIELDS);
        return this;
    }

    public GoogleUserSelector limitTo(Integer n) {
        setLimit(n);
        return this;
    }
}
