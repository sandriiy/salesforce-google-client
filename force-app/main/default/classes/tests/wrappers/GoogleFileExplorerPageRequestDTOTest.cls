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
@IsTest
private class GoogleFileExplorerPageRequestDTOTest {
	private static final List<String> SORT_FIELDS = new List<String>{
		'fileName', 'createdDateDisplay', 'lastModifiedDisplay', 'fileOwner', 'createdByName', 'isLinkedLabel'
	};

	private static GoogleFile__c loadSortableRow(Id fileId) {
		return [
			SELECT Id, Name, CreatedDate, LastModifiedDate, NumberOfLinks__c, OwnerId, Owner.Name, CreatedById, CreatedBy.Name
			FROM GoogleFile__c
			WHERE Id = :fileId
		];
	}

	@IsTest
	private static void testEncodeCursorFromPositiveCarriesOnlyTheIdAndType() {
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('Confidential Merger Plan').insertRecord();
		GoogleFile__c row = loadSortableRow(localFile.Id);
		String createdDay = row.CreatedDate.formatGmt('yyyy-MM-dd');

		for (String sortField : SORT_FIELDS) {
			GoogleFileExplorerPageRequestDTO request = new GoogleFileExplorerPageRequestDTO();
			request.sortField = sortField;
			request.sortDirection = 'ASC';

			String cursor = request.encodeCursorFrom(row);
			String decodedCursor = EncodingUtil.base64Decode(cursor).toString();

			Assert.isFalse(decodedCursor.contains('Confidential'), 'The cursor must not carry the file name, sorted by ' + sortField);
			Assert.isFalse(decodedCursor.contains(UserInfo.getName()), 'The cursor must not carry a person\'s name, sorted by ' + sortField);
			Assert.isFalse(decodedCursor.contains(createdDay), 'The cursor must not carry a date, sorted by ' + sortField);

			GoogleFileExplorerPageRequestDTO next = new GoogleFileExplorerPageRequestDTO();
			next.sortField = sortField;
			next.sortDirection = 'ASC';
			next.cursor = cursor;

			Assert.isTrue(next.hasCursor());
			Assert.areEqual(row.Id, next.cursorId(), 'The cursor still identifies its row, sorted by ' + sortField);
			Assert.isNull(next.decodedCursorValue(), 'The cursor carries no sort value, sorted by ' + sortField);
		}
	}

	@IsTest
	private static void testSortValueOfPositiveReadsTheRequestedSortField() {
		GoogleFile__c localFile = GoogleCloudTestFactory.file().withName('Sort Value File').insertRecord();
		GoogleFile__c row = loadSortableRow(localFile.Id);
		GoogleFileExplorerPageRequestDTO request = new GoogleFileExplorerPageRequestDTO();

		request.sortField = 'fileName';
		Assert.areEqual(row.Name, request.sortValueOf(row));

		request.sortField = 'createdDateDisplay';
		Assert.areEqual(row.CreatedDate, request.sortValueOf(row));

		request.sortField = 'lastModifiedDisplay';
		Assert.areEqual(row.LastModifiedDate, request.sortValueOf(row));

		request.sortField = 'isLinkedLabel';
		Assert.areEqual(row.NumberOfLinks__c, request.sortValueOf(row));

		request.sortField = 'fileOwner';
		Assert.areEqual(row.Owner.Name, request.sortValueOf(row));

		request.sortField = 'createdByName';
		Assert.areEqual(row.CreatedBy.Name, request.sortValueOf(row));

		request.sortField = 'notAColumn';
		Assert.areEqual(row.LastModifiedDate, request.sortValueOf(row), 'An unknown column sorts by the last modified date');
	}

	@IsTest
	private static void testDecodedCursorValueNegativeUnreadableCursorIsTheFirstPage() {
		GoogleFileExplorerPageRequestDTO request = new GoogleFileExplorerPageRequestDTO();
		request.sortField = 'fileName';
		request.cursor = 'not a cursor';

		Assert.isNull(request.cursorId());
		Assert.isNull(request.decodedCursorValue());
	}
}
