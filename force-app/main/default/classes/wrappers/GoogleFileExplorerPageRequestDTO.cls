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
public with sharing class GoogleFileExplorerPageRequestDTO {
	@AuraEnabled public String sortField;
	@AuraEnabled public String sortDirection;
	@AuraEnabled public String searchTerm;
	@AuraEnabled public String cursor;
	@AuraEnabled public Integer pageSize;

	private static final String DEFAULT_SORT_FIELD = 'lastModifiedDisplay';
	private static final String DEFAULT_SORT_PATH = 'LastModifiedDate';

	private static final Map<String, String> SORT_PATHS = new Map<String, String>{
		'fileName' => 'Name',
		'createdDateDisplay' => 'CreatedDate',
		'lastModifiedDisplay' => 'LastModifiedDate',
		'fileOwner' => 'Owner.Name',
		'ownerName' => 'CreatedBy.Name',
		'isLinkedLabel' => 'NumberOfLinks__c'
	};

	public static GoogleFileExplorerPageRequestDTO firstPage() {
		GoogleFileExplorerPageRequestDTO request = new GoogleFileExplorerPageRequestDTO();
		request.sortField = DEFAULT_SORT_FIELD;
		request.sortDirection = 'DESC';
		return request;
	}

	public String sortPath() {
		String path = SORT_PATHS.get(sortField);
		return String.isBlank(path) ? DEFAULT_SORT_PATH : path;
	}

	public Integer effectivePageSize() {
		return (pageSize == null || pageSize <= 0) ? GoogleCloudConstants.EXPLORER_PAGE_SIZE : pageSize;
	}

	public Boolean hasCursor() {
		return String.isNotBlank(cursor);
	}

	public Object decodedCursorValue() {
		CursorState state = parseCursor();
		return state == null ? null : decodeValue(state.type, state.value);
	}

	public Id cursorId() {
		CursorState state = parseCursor();
		return state == null ? null : state.recordId;
	}

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

	public class CursorState {
		public String type;
		public String value;
		public Id recordId;
	}
}
