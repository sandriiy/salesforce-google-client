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
 * What File Explorer asks for when it loads a page, and the cursor it comes back with. The cursor is the
 * sort value and Id of the last row, encoded, so the next page continues exactly where this one stopped
 * even when files are added while somebody scrolls.
 */
public with sharing class GoogleFileExplorerPageRequestDTO {
	@AuraEnabled public String sortField;
	@AuraEnabled public String sortDirection;
	@AuraEnabled public String searchTerm;
	@AuraEnabled public String cursor;
	@AuraEnabled public Integer pageSize;
	@AuraEnabled public String bucket;

	private static final String DEFAULT_SORT_FIELD = 'lastModifiedDisplay';
	private static final String DEFAULT_SORT_PATH = 'LastModifiedDate';

	private static final Map<String, String> SORT_PATHS = new Map<String, String>{
		'fileName' => 'Name',
		'createdDateDisplay' => 'CreatedDate',
		'lastModifiedDisplay' => 'LastModifiedDate',
		'fileOwner' => 'Owner.Name',
		'createdByName' => 'CreatedBy.Name',
		'isLinkedLabel' => 'NumberOfLinks__c'
	};

	/**
	 * Builds a request from separate values, which is how it arrives from a Lightning component. A custom
	 * Apex type crossing that boundary comes through with every field empty, so the pieces are passed one by
	 * one and put back together here.
	 *
	 * @param sortField The column being sorted on.
	 * @param sortDirection "ASC" or "DESC".
	 * @param searchTerm What the user typed, or null.
	 * @param cursor Where to continue, or null for the first page.
	 * @param pageSize How many rows to return.
	 * @param bucket "owned", "shared", or null for everything.
	 * @return The request the service works from.
	 */
	public static GoogleFileExplorerPageRequestDTO of(String sortField, String sortDirection, String searchTerm, String cursor, Integer pageSize, String bucket) {
		GoogleFileExplorerPageRequestDTO request = new GoogleFileExplorerPageRequestDTO();
		request.sortField = sortField;
		request.sortDirection = sortDirection;
		request.searchTerm = searchTerm;
		request.cursor = cursor;
		request.pageSize = pageSize;
		request.bucket = bucket;
		return request;
	}

	/**
	 * The request the screen opens with: your own files, newest change first.
	 *
	 * @return A first page request.
	 */
	public static GoogleFileExplorerPageRequestDTO firstPage() {
		GoogleFileExplorerPageRequestDTO request = new GoogleFileExplorerPageRequestDTO();
		request.sortField = DEFAULT_SORT_FIELD;
		request.sortDirection = 'DESC';
		request.bucket = GoogleCloudConstants.FILE_EXPLORER_BUCKET_OWNED;
		return request;
	}

	/**
	 * The field the sort column really maps to, falling back to the last modified date.
	 *
	 * @return The field to order by.
	 */
	public String sortPath() {
		String path = SORT_PATHS.get(sortField);
		return String.isBlank(path) ? DEFAULT_SORT_PATH : path;
	}

	/**
	 * The page size that will really be used, falling back to the default and capped at the maximum.
	 *
	 * @return A usable page size.
	 */
	public Integer effectivePageSize() {
		if (pageSize == null || pageSize <= 0) return GoogleCloudConstants.FILE_EXPLORER_PAGE_SIZE;
		return Math.min(pageSize, GoogleCloudConstants.FILE_EXPLORER_MAX_PAGE_SIZE);
	}

	/**
	 * Whether this request continues a previous page.
	 *
	 * @return True when a cursor was supplied.
	 */
	public Boolean hasCursor() {
		return String.isNotBlank(cursor);
	}

	/**
	 * The sort value the cursor stopped at, back in its own type.
	 *
	 * @return The value, or null for the first page or an unreadable cursor.
	 */
	public Object decodedCursorValue() {
		CursorState state = parseCursor();
		return state == null ? null : decodeValue(state.type, state.value);
	}

	/**
	 * The Id the cursor stopped at, which breaks the tie when two files share a sort value.
	 *
	 * @return The Id, or null for the first page or an unreadable cursor.
	 */
	public Id cursorId() {
		CursorState state = parseCursor();
		return state == null ? null : state.recordId;
	}

	/**
	 * Builds the cursor for the next page out of the last row of this one.
	 *
	 * @param lastRow The last file returned.
	 * @return The cursor to hand back to the component.
	 */
	public String encodeCursorFrom(GoogleFile__c lastRow) {
		String path = sortPath();
		String type = fieldType(path);

		CursorState state = new CursorState();
		state.type = type;
		state.value = encodeValue(type, extractSortValue(lastRow, path));
		state.recordId = lastRow.Id;

		return EncodingUtil.base64Encode(Blob.valueOf(JSON.serialize(state)));
	}

	private CursorState parseCursor() {
		if (!hasCursor()) return null;
		
		try {
			String decoded = EncodingUtil.base64Decode(cursor).toString();
			return (CursorState) JSON.deserialize(decoded, CursorState.class);
		} catch (Exception ex) {
			return null;
		}
	}

	private String fieldType(String path) {
		if (path == 'CreatedDate' || path == 'LastModifiedDate') return 'datetime';
		if (path == 'NumberOfLinks__c') return 'number';
		return 'string';
	}

	private Object extractSortValue(GoogleFile__c row, String path) {
		if (path == 'Name') return row.Name;
		if (path == 'CreatedDate') return row.CreatedDate;
		if (path == 'LastModifiedDate') return row.LastModifiedDate;
		if (path == 'NumberOfLinks__c') return row.NumberOfLinks__c;
		if (path == 'Owner.Name') return row.getSObject('Owner') == null ? null : row.getSObject('Owner').get('Name');
		if (path == 'CreatedBy.Name') return row.getSObject('CreatedBy') == null ? null : row.getSObject('CreatedBy').get('Name');
		return null;
	}

	private String encodeValue(String type, Object value) {
		if (value == null) return null;
		if (type == 'datetime') return ((Datetime) value).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
		return String.valueOf(value);
	}

	private Object decodeValue(String type, String value) {
		if (String.isBlank(value)) return null;
		if (type == 'datetime') return (Datetime) JSON.deserialize('"' + value + '"', Datetime.class);
		if (type == 'number') return Decimal.valueOf(value);
		return value;
	}

	/**
	 * What a cursor holds: the sort value, its type so it can be read back, and the Id that breaks ties.
	 */
	public class CursorState {
		public String type;
		public String value;
		public Id recordId;
	}
}
