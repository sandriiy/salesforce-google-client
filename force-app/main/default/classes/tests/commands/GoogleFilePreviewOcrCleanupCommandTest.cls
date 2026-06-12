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
private class GoogleFilePreviewOcrCleanupCommandTest {
	@IsTest
	private static void testCleanupPreviewPositiveDeletesTextRangesInReverseOrder() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.endpointContains('/v1/documents/')
		).thenReturnStatus(200, buildDocumentPayloadWithImageAndOcr());
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('POST')
				.endpointContains(':batchUpdate')
		).thenReturnStatus(200, '{"replies":[]}');

		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(IsImageOcrEnabled__c = false);
		GoogleFileVersion__c localFileVersion = new GoogleFileVersion__c(Type__c = 'image/png', GoogleDriveFileId__c = 'GD_IMG_001');

		Test.startTest();
		new GoogleFilePreviewOcrCleanupCommand().cleanupPreview(localFileVersion, 'DOC_PREVIEW_001');
		Test.stopTest();

		GoogleDriveHttpMock.CapturedRequest batchUpdateRequest = null;
		for (GoogleDriveHttpMock.CapturedRequest capturedRequest : driveMock.getCapturedRequests()) {
			if (capturedRequest.endpoint != null && capturedRequest.endpoint.contains(':batchUpdate')) {
				batchUpdateRequest = capturedRequest;
				break;
			}
		}

		Assert.isNotNull(batchUpdateRequest);

		Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(batchUpdateRequest.body);
		List<Object> requests = (List<Object>) payload.get('requests');

		Assert.areEqual(4, requests.size());
		Assert.areEqual(25, extractStartIndex(requests[0]));
		Assert.areEqual(17, extractStartIndex(requests[1]));
		Assert.areEqual(16, extractStartIndex(requests[2]));
		Assert.areEqual(5, extractStartIndex(requests[3]));
	}

	@IsTest
	private static void testCleanupPreviewPositiveSkipsWhenImageOcrEnabled() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock();

		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(IsImageOcrEnabled__c = true);
		GoogleFileVersion__c localFileVersion = new GoogleFileVersion__c(Type__c = 'image/png', GoogleDriveFileId__c = 'GD_IMG_002');

		Test.startTest();
		new GoogleFilePreviewOcrCleanupCommand().cleanupPreview(localFileVersion, 'DOC_PREVIEW_002');
		Test.stopTest();

		Assert.areEqual(0, driveMock.getCapturedRequests().size());
	}

	@IsTest
	private static void testCleanupPreviewPositiveSkipsWhenImageNotFound() {
		GoogleDriveHttpMock driveMock = new GoogleDriveHttpMock();
		driveMock.whenRequestMatches(
			new GoogleDriveHttpMock.RequestMatcher()
				.withMethod('GET')
				.endpointContains('/v1/documents/')
		).thenReturnStatus(200, buildTextOnlyDocumentPayload());

		GoogleCloudTestFactory.initMocks(driveMock);
		GoogleMetadataConfigService.configRecordOverride = new GoogleClientConfig__mdt(IsImageOcrEnabled__c = false);
		GoogleFileVersion__c localFileVersion = new GoogleFileVersion__c(Type__c = 'image/png', GoogleDriveFileId__c = 'GD_IMG_003');

		Test.startTest();
		new GoogleFilePreviewOcrCleanupCommand().cleanupPreview(localFileVersion, 'DOC_PREVIEW_003');
		Test.stopTest();

		Assert.areEqual(1, driveMock.getCapturedRequests().size());
	}

	private static Integer extractStartIndex(Object requestItem) {
		Map<String, Object> request = (Map<String, Object>) requestItem;
		Map<String, Object> deleteContentRange = (Map<String, Object>) request.get('deleteContentRange');
		Map<String, Object> range = (Map<String, Object>) deleteContentRange.get('range');
		return Integer.valueOf(String.valueOf(range.get('startIndex')));
	}

	private static String buildDocumentPayloadWithImageAndOcr() {
		List<Object> content = new List<Object>{
			buildParagraph(1, 5, new List<Object>{
				buildInlineObjectElement(1, 4, 'img_001'),
				buildTextRunElement(4, 5, 'NL1')
			}),
			buildParagraph(5, 17, new List<Object>{
				buildTextRunElement(5, 16, 'OCR line 1'),
				buildTextRunElement(16, 17, 'NL2')
			}),
			buildParagraph(17, 26, new List<Object>{
				buildTextRunElement(17, 25, 'OCR line 2'),
				buildTextRunElement(25, 26, 'NL3')
			}),
			buildParagraph(26, 31, new List<Object>{
				buildInlineObjectElement(26, 30, 'img_002'),
				buildTextRunElement(30, 31, 'NL4')
			})
		};

		return JSON.serialize(new Map<String, Object>{
			'body' => new Map<String, Object>{
				'content' => content
			}
		});
	}

	private static String buildTextOnlyDocumentPayload() {
		return JSON.serialize(new Map<String, Object>{
			'body' => new Map<String, Object>{
				'content' => new List<Object>{
					buildParagraph(1, 6, new List<Object>{
						buildTextRunElement(1, 5, 'Text'),
						buildTextRunElement(5, 6, 'NL')
					})
				}
			}
		});
	}

	private static Map<String, Object> buildParagraph(Integer startIndex, Integer endIndex, List<Object> elements) {
		return new Map<String, Object>{
			'startIndex' => startIndex,
			'endIndex' => endIndex,
			'paragraph' => new Map<String, Object>{
				'elements' => elements
			}
		};
	}

	private static Map<String, Object> buildInlineObjectElement(Integer startIndex, Integer endIndex, String inlineObjectId) {
		return new Map<String, Object>{
			'startIndex' => startIndex,
			'endIndex' => endIndex,
			'inlineObjectElement' => new Map<String, Object>{
				'inlineObjectId' => inlineObjectId
			}
		};
	}

	private static Map<String, Object> buildTextRunElement(Integer startIndex, Integer endIndex, String content) {
		return new Map<String, Object>{
			'startIndex' => startIndex,
			'endIndex' => endIndex,
			'textRun' => new Map<String, Object>{
				'content' => content
			}
		};
	}
}