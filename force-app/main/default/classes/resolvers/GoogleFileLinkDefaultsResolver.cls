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
public without sharing class GoogleFileLinkDefaultsResolver {
	public GoogleFileLink__c applyDefaultValues(GoogleFileLink__c linkRecord) {
		if (linkRecord == null) return null;

		User currentUser = loadCurrentUser();
		Boolean isInternalUser = isInternalUserType(currentUser == null ? null : currentUser.UserType);

		linkRecord.ShareType__c = isInternalUser ? 'Viewer' : 'InferredFromRecord';
		linkRecord.Visibility__c = isInternalUser ? 'InternalUsers' : 'AllUsers';
		return linkRecord;
	}

	private User loadCurrentUser() {
		List<User> users = (List<User>) GoogleUserSelector.query()
			.withTypeFields()
			.byUserId(UserInfo.getUserId())
			.limitTo(1)
			.toList();

		return users.isEmpty() ? null : users[0];
	}

	private Boolean isInternalUserType(String userType) {
		if (userType == null) return true;

		String normalized = userType.toLowerCase();
		if (normalized.contains('guest') ||
			normalized.contains('portal') ||
			normalized.contains('partner') ||
			normalized.contains('customer') ||
			normalized.contains('csn')) {
			return false;
		}

		return true;
	}
}