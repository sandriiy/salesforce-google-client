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
public without sharing class GoogleFilePreviewOcrCleanupCommand {
	public class GoogleFilePreviewOcrCleanupCommandException extends Exception {}

	private static final String DOCS_API_BASE_URL = 'https://docs.googleapis.com/v1/documents/';
	private static final String JSON_CONTENT_TYPE = 'application/json';
	private static final Integer DEFAULT_TIMEOUT_MS = 120000;

	private final GoogleClientApiProvider googleApiProvider;
	private final GoogleMetadataConfigService metadataService;
	private final Http httpClient;

	public GoogleFilePreviewOcrCleanupCommand() {
		this(new GoogleClientApiProvider(), new GoogleMetadataConfigService(), new Http());
	}

	@TestVisible
	private GoogleFilePreviewOcrCleanupCommand(GoogleClientApiProvider googleApiProvider, GoogleMetadataConfigService metadataService, Http httpClient) {
		this.googleApiProvider = googleApiProvider == null ? new GoogleClientApiProvider() : googleApiProvider;
		this.metadataService = metadataService == null ? new GoogleMetadataConfigService() : metadataService;
		this.httpClient = httpClient == null ? new Http() : httpClient;
	}

	public void cleanupPreview(GoogleFileVersion__c localFileVersion, String googleWorkspaceFileId) {
		try {
			Boolean shouldSkip = shouldSkipCleanup(localFileVersion, googleWorkspaceFileId);
			if (shouldSkip) return;

			removeOcrText(googleWorkspaceFileId);
		} catch (Exception ex) {
			Logger.error(buildCleanupFailureMessage(localFileVersion, googleWorkspaceFileId, ex)).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
		}
	}

	private void removeOcrText(String googleWorkspaceFileId) {
		String authorizationHeader = buildAuthorizationHeader();
		Map<String, Object> document = retrieveDocument(googleWorkspaceFileId, authorizationHeader);
		List<DeleteRange> deleteRanges = collectDeleteRanges(document);

		if (deleteRanges.isEmpty()) return;

		deleteTextRanges(googleWorkspaceFileId, deleteRanges, authorizationHeader);
	}

	private Boolean shouldSkipCleanup(GoogleFileVersion__c localFileVersion, String googleWorkspaceFileId) {
		return localFileVersion == null
			|| String.isBlank(localFileVersion.Type__c)
			|| String.isBlank(googleWorkspaceFileId)
			|| !localFileVersion.Type__c.toLowerCase().startsWith('image/')
			|| this.metadataService.isImageOcrEnabled();
	}

	private String buildCleanupFailureMessage(GoogleFileVersion__c localFileVersion, String googleWorkspaceFileId, Exception ex) {
		return 'Image Preview OCR Cleanup Failed --> Operation=Google Docs OCR Cleanup'
			+ ', PreviewGoogleFileId=' + String.valueOf(googleWorkspaceFileId)
			+ ', SourceGoogleFileId=' + String.valueOf(localFileVersion == null ? null : localFileVersion.GoogleDriveFileId__c)
			+ ', IsImageOcrEnabled=' + safeImageOcrEnabledValue()
			+ ', ErrorType=' + String.valueOf(ex == null ? null : ex.getTypeName())
			+ ', Error=' + String.valueOf(ex == null ? null : ex.getMessage());
	}

	private String buildAuthorizationHeader() {
		GoogleCredential googleCredential = this.googleApiProvider.retrieveGoogleClientCreds();
		if (googleCredential == null || String.isBlank(googleCredential.accessToken)) {
			throw new GoogleFilePreviewOcrCleanupCommandException('Google Docs authorization failed. Access token was not returned');
		}

		return googleCredential.tokenType + ' ' + googleCredential.accessToken;
	}

	private Map<String, Object> retrieveDocument(String googleWorkspaceFileId, String authorizationHeader) {
		HttpRequest request = buildRequest(
			'GET',
			buildDocumentEndpoint(googleWorkspaceFileId),
			authorizationHeader,
			null
		);

		HttpResponse response = this.httpClient.send(request);
		validateResponse(response, 'Google Docs get document');
		String responseBody = response == null ? null : response.getBody();
		if (String.isBlank(responseBody)) {
			throw new GoogleFilePreviewOcrCleanupCommandException('Google Docs get document failed. Empty response body was returned');
		}

		return (Map<String, Object>) JSON.deserializeUntyped(responseBody);
	}

	private void deleteTextRanges(String googleWorkspaceFileId, List<DeleteRange> deleteRanges, String authorizationHeader) {
		List<Object> requests = new List<Object>();
		for (Integer idx = deleteRanges.size() - 1; idx >= 0; idx--) {
			DeleteRange deleteRange = deleteRanges[idx];
			requests.add(new Map<String, Object>{
				'deleteContentRange' => new Map<String, Object>{
					'range' => new Map<String, Object>{
						'startIndex' => deleteRange.startIndex,
						'endIndex' => deleteRange.endIndex
					}
				}
			});
		}

		HttpRequest request = buildRequest(
			'POST',
			buildDocumentEndpoint(googleWorkspaceFileId) + ':batchUpdate',
			authorizationHeader,
			JSON.serialize(new Map<String, Object>{ 'requests' => requests })
		);

		HttpResponse response = this.httpClient.send(request);
		validateResponse(response, 'Google Docs batch update');
	}

	private HttpRequest buildRequest(String methodName, String endpoint, String authorizationHeader, String requestBody) {
		HttpRequest request = new HttpRequest();
		request.setMethod(methodName);
		request.setEndpoint(endpoint);
		request.setTimeout(DEFAULT_TIMEOUT_MS);
		request.setHeader('Authorization', authorizationHeader);
		request.setHeader('Accept', JSON_CONTENT_TYPE);

		if (requestBody != null) {
			request.setHeader('Content-Type', JSON_CONTENT_TYPE);
			request.setBody(requestBody);
		}

		return request;
	}

	private String buildDocumentEndpoint(String googleWorkspaceFileId) {
		return DOCS_API_BASE_URL + EncodingUtil.urlEncode(googleWorkspaceFileId, 'UTF-8');
	}

	private void validateResponse(HttpResponse response, String operationName) {
		Integer statusCode = response == null ? null : response.getStatusCode();
		if (statusCode != null && statusCode >= 200 && statusCode < 300) return;

		throw new GoogleFilePreviewOcrCleanupCommandException(
			operationName + ' failed. StatusCode=' + String.valueOf(statusCode) + ', Response=' + String.valueOf(response == null ? null : response.getBody())
		);
	}

	private String safeImageOcrEnabledValue() {
		try {
			return String.valueOf(this.metadataService.isImageOcrEnabled());
		} catch (Exception ex) {
			return 'UNAVAILABLE';
		}
	}

	private List<DeleteRange> collectDeleteRanges(Map<String, Object> document) {
		List<Object> content = extractDocumentContent(document);
		List<DeleteRange> deleteRanges = new List<DeleteRange>();

		if (content.isEmpty()) return deleteRanges;

		Integer imageBoundaryIndex = findImageBoundaryIndex(content);
		Integer documentEndIndex = findDocumentEndIndex(content);
		Integer maxDeleteIndex = documentEndIndex == null ? null : documentEndIndex - 1;

		if (imageBoundaryIndex == null || maxDeleteIndex == null || maxDeleteIndex <= imageBoundaryIndex) {
			return deleteRanges;
		}

		collectDeleteRangesFromContent(content, imageBoundaryIndex, maxDeleteIndex, deleteRanges);
		return deleteRanges;
	}

	private List<Object> extractDocumentContent(Map<String, Object> document) {
		Map<String, Object> body = document == null ? null : (Map<String, Object>) document.get('body');
		List<Object> content = body == null ? null : (List<Object>) body.get('content');
		return content == null ? new List<Object>() : content;
	}

	private Integer findImageBoundaryIndex(List<Object> content) {
		if (content == null) return null;

		for (Object contentItem : content) {
			Map<String, Object> structuralElement = (Map<String, Object>) contentItem;
			if (structuralElement == null) continue;

			Map<String, Object> paragraph = (Map<String, Object>) structuralElement.get('paragraph');
			if (paragraph != null && containsInlineObject(paragraph)) {
				return toInteger(structuralElement.get('endIndex'));
			}

			Map<String, Object> tableOfContents = (Map<String, Object>) structuralElement.get('tableOfContents');
			if (tableOfContents != null) {
				Integer nestedIndex = findImageBoundaryIndex((List<Object>) tableOfContents.get('content'));
				if (nestedIndex != null) return nestedIndex;
			}

			Map<String, Object> table = (Map<String, Object>) structuralElement.get('table');
			if (table != null) {
				Integer nestedIndex = findImageBoundaryIndexInTable(table);
				if (nestedIndex != null) return nestedIndex;
			}
		}

		return null;
	}

	private Integer findImageBoundaryIndexInTable(Map<String, Object> table) {
		List<Object> tableRows = table == null ? null : (List<Object>) table.get('tableRows');
		if (tableRows == null) return null;

		for (Object tableRowItem : tableRows) {
			Map<String, Object> tableRow = (Map<String, Object>) tableRowItem;
			List<Object> tableCells = tableRow == null ? null : (List<Object>) tableRow.get('tableCells');
			if (tableCells == null) continue;

			for (Object tableCellItem : tableCells) {
				Map<String, Object> tableCell = (Map<String, Object>) tableCellItem;
				Integer nestedIndex = findImageBoundaryIndex((List<Object>) (tableCell == null ? null : tableCell.get('content')));
				if (nestedIndex != null) return nestedIndex;
			}
		}

		return null;
	}

	private Integer findDocumentEndIndex(List<Object> content) {
		if (content == null || content.isEmpty()) return null;

		Map<String, Object> lastElement = (Map<String, Object>) content[content.size() - 1];
		return lastElement == null ? null : toInteger(lastElement.get('endIndex'));
	}

	private Boolean containsInlineObject(Map<String, Object> paragraph) {
		List<Object> paragraphElements = paragraph == null ? null : (List<Object>) paragraph.get('elements');
		if (paragraphElements == null) return false;

		for (Object paragraphElementItem : paragraphElements) {
			Map<String, Object> paragraphElement = (Map<String, Object>) paragraphElementItem;
			if (paragraphElement != null && paragraphElement.containsKey('inlineObjectElement')) return true;
		}

		return false;
	}

	private void collectDeleteRangesFromContent(List<Object> content, Integer imageBoundaryIndex, Integer maxDeleteIndex, List<DeleteRange> deleteRanges) {
		if (content == null) return;

		for (Object contentItem : content) {
			Map<String, Object> structuralElement = (Map<String, Object>) contentItem;
			if (structuralElement == null) continue;

			Map<String, Object> paragraph = (Map<String, Object>) structuralElement.get('paragraph');
			if (paragraph != null) {
				collectDeleteRangesFromParagraph(paragraph, imageBoundaryIndex, maxDeleteIndex, deleteRanges);
			}

			Map<String, Object> tableOfContents = (Map<String, Object>) structuralElement.get('tableOfContents');
			if (tableOfContents != null) {
				collectDeleteRangesFromContent((List<Object>) tableOfContents.get('content'), imageBoundaryIndex, maxDeleteIndex, deleteRanges);
			}

			Map<String, Object> table = (Map<String, Object>) structuralElement.get('table');
			if (table != null) {
				collectDeleteRangesFromTable(table, imageBoundaryIndex, maxDeleteIndex, deleteRanges);
			}
		}
	}

	private void collectDeleteRangesFromTable(Map<String, Object> table, Integer imageBoundaryIndex, Integer maxDeleteIndex, List<DeleteRange> deleteRanges) {
		List<Object> tableRows = table == null ? null : (List<Object>) table.get('tableRows');
		if (tableRows == null) return;

		for (Object tableRowItem : tableRows) {
			Map<String, Object> tableRow = (Map<String, Object>) tableRowItem;
			List<Object> tableCells = tableRow == null ? null : (List<Object>) tableRow.get('tableCells');
			if (tableCells == null) continue;

			for (Object tableCellItem : tableCells) {
				Map<String, Object> tableCell = (Map<String, Object>) tableCellItem;
				collectDeleteRangesFromContent((List<Object>) (tableCell == null ? null : tableCell.get('content')), imageBoundaryIndex, maxDeleteIndex, deleteRanges);
			}
		}
	}

	private void collectDeleteRangesFromParagraph(Map<String, Object> paragraph, Integer imageBoundaryIndex, Integer maxDeleteIndex, List<DeleteRange> deleteRanges) {
		List<Object> paragraphElements = paragraph == null ? null : (List<Object>) paragraph.get('elements');
		if (paragraphElements == null) return;

		for (Object paragraphElementItem : paragraphElements) {
			Map<String, Object> paragraphElement = (Map<String, Object>) paragraphElementItem;
			if (paragraphElement == null || !paragraphElement.containsKey('textRun')) continue;

			Integer startIndex = normalizeStartIndex(toInteger(paragraphElement.get('startIndex')), imageBoundaryIndex);
			Integer endIndex = normalizeEndIndex(toInteger(paragraphElement.get('endIndex')), maxDeleteIndex);
			if (startIndex == null || endIndex == null || endIndex <= startIndex) continue;

			deleteRanges.add(new DeleteRange(startIndex, endIndex));
		}
	}

	private Integer normalizeStartIndex(Integer value, Integer imageBoundaryIndex) {
		if (value == null) return null;
		return value < imageBoundaryIndex ? imageBoundaryIndex : value;
	}

	private Integer normalizeEndIndex(Integer value, Integer maxDeleteIndex) {
		if (value == null) return null;
		return value > maxDeleteIndex ? maxDeleteIndex : value;
	}

	private Integer toInteger(Object value) {
		if (value == null) return null;

		try {
			return Integer.valueOf(String.valueOf(value));
		} catch (Exception ex) {
			return null;
		}
	}

	private class DeleteRange {
		public Integer startIndex;
		public Integer endIndex;

		public DeleteRange(Integer startIndex, Integer endIndex) {
			this.startIndex = startIndex;
			this.endIndex = endIndex;
		}
	}
}