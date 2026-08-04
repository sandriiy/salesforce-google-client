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
public without sharing class GoogleFileLinkPlacementResolver {
	public List<GoogleFileLink__c> resolveLinks(Id relatedRecordId, String source) {
		if (relatedRecordId == null) {
			return new List<GoogleFileLink__c>();
		}

		List<GoogleFileLink__c> fileLinks = (List<GoogleFileLink__c>) GoogleFileLinkSelector.query()
			.byLinkedObjectId(relatedRecordId)
			.withBaseFields()
			.withPlacementFields()
			.toList();

		if (fileLinks.isEmpty() || String.isBlank(source)) {
			return fileLinks;
		}

		Map<Id, String> primarySourceByFileId = loadPrimarySourceByFileId(collectFileIdsMissingPlacementSource(fileLinks));
		List<GoogleFileLink__c> matchingLinks = new List<GoogleFileLink__c>();

		for (GoogleFileLink__c fileLink : fileLinks) {
			String effectiveSource = fileLink.Source__c;
			if (String.isBlank(effectiveSource)) {
				effectiveSource = primarySourceByFileId.get(fileLink.GoogleFileId__c);
			}

			if (effectiveSource == source) {
				matchingLinks.add(fileLink);
			}
		}

		return matchingLinks;
	}

	public Set<Id> resolveFileIds(Id relatedRecordId, String source) {
		return collectFileIds(resolveLinks(relatedRecordId, source));
	}

	private Set<Id> collectFileIds(List<GoogleFileLink__c> fileLinks) {
		Set<Id> fileIds = new Set<Id>();

		for (GoogleFileLink__c fileLink : fileLinks) {
			if (fileLink != null && fileLink.GoogleFileId__c != null) {
				fileIds.add(fileLink.GoogleFileId__c);
			}
		}

		return fileIds;
	}

	private Set<Id> collectFileIdsMissingPlacementSource(List<GoogleFileLink__c> fileLinks) {
		Set<Id> fileIds = new Set<Id>();

		for (GoogleFileLink__c fileLink : fileLinks) {
			if (fileLink == null || fileLink.GoogleFileId__c == null) {
				continue;
			}

			if (String.isBlank(fileLink.Source__c)) {
				fileIds.add(fileLink.GoogleFileId__c);
			}
		}

		return fileIds;
	}

	private Map<Id, String> loadPrimarySourceByFileId(Set<Id> fileIds) {
		Map<Id, String> primarySourceByFileId = new Map<Id, String>();

		if (fileIds.isEmpty()) {
			return primarySourceByFileId;
		}

		for (GoogleFile__c fileRecord : (List<GoogleFile__c>) GoogleFileSelector.query()
			.withBaseFields()
			.byIds(fileIds)
			.toList()) {
			primarySourceByFileId.put(fileRecord.Id, fileRecord.Source__c);
		}

		return primarySourceByFileId;
	}
}