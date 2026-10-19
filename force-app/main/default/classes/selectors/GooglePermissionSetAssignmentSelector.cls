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
 * Reads which permission sets a user holds, profile included, since every profile has a permission set
 * underneath it. It answers the one question the package has about standard permissions: whether a user
 * may query every Salesforce file, which a migration cannot do without.
 */
public inherited sharing class GooglePermissionSetAssignmentSelector extends GSOQL implements GSOQL.Selector {
	@TestVisible
	private static final String MOCK_ID = 'GooglePermissionSetAssignmentSelector';

	/**
	 * The assignment and the permission set it grants.
	 */
	public static final List<SObjectField> BASE_FIELDS = new List<SObjectField>{
		PermissionSetAssignment.Id,
		PermissionSetAssignment.AssigneeId,
		PermissionSetAssignment.PermissionSetId
	};

	/**
	 * Starts a query over permission set assignments.
	 *
	 * @return A fresh selector to narrow and run.
	 */
	public static GooglePermissionSetAssignmentSelector query() {
		return new GooglePermissionSetAssignmentSelector();
	}

	public GooglePermissionSetAssignmentSelector() {
		super(PermissionSetAssignment.SObjectType);
		systemMode();
		withoutSharing();
		mockId(MOCK_ID);
	}

	/**
	 * Keeps the assignments of one user.
	 *
	 * @param userId The user whose permission sets are wanted.
	 * @return This same instance, so the call chains onto toList().
	 */
	public GooglePermissionSetAssignmentSelector byAssigneeId(Id userId) {
		whereAre(Filter.with(PermissionSetAssignment.AssigneeId).equal(userId));
		return this;
	}

	/**
	 * Keeps the assignments whose permission set grants Query All Files.
	 *
	 * @return This same instance, so the call chains onto toList().
	 */
	public GooglePermissionSetAssignmentSelector grantingQueryAllFiles() {
		whereAre(Filter.with('PermissionSet.PermissionsQueryAllFiles').equal(true));
		return this;
	}

	/**
	 * Selects the assignment and the permission set it grants.
	 *
	 * @return This same instance, so the call chains onto toList().
	 */
	public GooglePermissionSetAssignmentSelector withBaseFields() {
		with(BASE_FIELDS);
		return this;
	}

	/**
	 * Caps how many rows come back.
	 *
	 * @param n The maximum number of assignments.
	 * @return This same instance, so the call chains onto toList().
	 */
	public GooglePermissionSetAssignmentSelector limitTo(Integer n) {
		setLimit(n);
		return this;
	}
}
