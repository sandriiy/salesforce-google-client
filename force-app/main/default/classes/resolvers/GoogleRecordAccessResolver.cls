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
 * Answers what a user may do with ordinary Salesforce records, which is how a file linked to a record
 * borrows that record's access. Always go through here rather than querying UserRecordAccess yourself,
 * because that object takes at most 200 record Ids per query and this batches around it.
 */
public without sharing class GoogleRecordAccessResolver {
	@TestVisible
	private static final String MOCK_ID = 'GoogleRecordAccessResolver';

	private static final Integer MAX_RECORD_IDS_PER_QUERY = 200;

	@TestVisible
	private static Map<Id, GoogleRecordAccessDTO> accessOverrideByRecordId;

	/**
	 * Resolves access to many records at once. Records the user cannot reach at all are simply missing from
	 * the map rather than present with everything false.
	 *
	 * @param userId The user whose access is being resolved.
	 * @param recordIds The records to check, in any number and of any object.
	 * @return What the user may do, keyed by record Id.
	 */
	public Map<Id, GoogleRecordAccessDTO> resolveAccess(Id userId, Set<Id> recordIds) {
		Map<Id, GoogleRecordAccessDTO> accessByRecordId = new Map<Id, GoogleRecordAccessDTO>();
		if (userId == null || recordIds == null || recordIds.isEmpty()) {
			return accessByRecordId;
		}

		if (accessOverrideByRecordId != null) {
			for (Id recordId : recordIds) {
				GoogleRecordAccessDTO overriddenAccess = accessOverrideByRecordId.get(recordId);
				if (overriddenAccess != null) accessByRecordId.put(recordId, overriddenAccess);
			}

			return accessByRecordId;
		}

		for (Set<Id> recordIdBatch : batchRecordIds(recordIds)) {
			for (UserRecordAccess userAccess : loadUserRecordAccess(userId, recordIdBatch)) {
				accessByRecordId.put(
					userAccess.RecordId,
					new GoogleRecordAccessDTO(userAccess.RecordId, userAccess.HasReadAccess, userAccess.HasEditAccess)
				);
			}
		}

		return accessByRecordId;
	}

	/**
	 * Resolves access to one record.
	 *
	 * @param userId The user whose access is being resolved.
	 * @param recordId The record to check.
	 * @return What the user may do, or null when the record is out of reach.
	 */
	public GoogleRecordAccessDTO resolveAccess(Id userId, Id recordId) {
		if (recordId == null) return null;
		return resolveAccess(userId, new Set<Id>{ recordId }).get(recordId);
	}

	/**
	 * Says whether the user can read the record, which is the usual question before letting them near a
	 * file attached to it.
	 *
	 * @param userId The user whose access is being resolved.
	 * @param recordId The record to check.
	 * @return True when the user can read it.
	 */
	public Boolean hasReadAccess(Id userId, Id recordId) {
		GoogleRecordAccessDTO recordAccess = resolveAccess(userId, recordId);
		return recordAccess != null && recordAccess.hasReadAccess == true;
	}

	private List<Set<Id>> batchRecordIds(Set<Id> recordIds) {
		List<Set<Id>> batches = new List<Set<Id>>();
		Set<Id> currentBatch = new Set<Id>();

		for (Id recordId : recordIds) {
			currentBatch.add(recordId);

			if (currentBatch.size() == MAX_RECORD_IDS_PER_QUERY) {
				batches.add(currentBatch);
				currentBatch = new Set<Id>();
			}
		}

		if (!currentBatch.isEmpty()) batches.add(currentBatch);
		return batches;
	}

	private List<UserRecordAccess> loadUserRecordAccess(Id userId, Set<Id> recordIds) {
		return (List<UserRecordAccess>) GSOQL.of(UserRecordAccess.SObjectType)
			.with(UserRecordAccess.RecordId, UserRecordAccess.HasReadAccess, UserRecordAccess.HasEditAccess)
			.whereAre(GSOQL.Filter.with(UserRecordAccess.UserId).equal(userId))
			.whereAre(GSOQL.Filter.with(UserRecordAccess.RecordId).isIn(recordIds))
			.systemMode()
			.withoutSharing()
			.mockId(MOCK_ID)
			.toList();
	}
}
