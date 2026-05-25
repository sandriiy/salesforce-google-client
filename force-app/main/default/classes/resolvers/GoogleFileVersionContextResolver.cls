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
public with sharing class GoogleFileVersionContextResolver {
    public Set<Id> collectParentFileIds(List<GoogleFileVersion__c> fileVersions) {
        Set<Id> parentFileIds = new Set<Id>();
        if (fileVersions == null) return parentFileIds;

        for (GoogleFileVersion__c fileVersion : fileVersions) {
            if (fileVersion != null && fileVersion.GoogleFileId__c != null) {
                parentFileIds.add(fileVersion.GoogleFileId__c);
            }
        }

        return parentFileIds;
    }

    public Set<Id> collectParentFileIds(List<GoogleFileVersion__c> newFileVersions, List<GoogleFileVersion__c> oldFileVersions) {
        Set<Id> parentFileIds = new Set<Id>();
        parentFileIds.addAll(collectParentFileIds(newFileVersions));
        parentFileIds.addAll(collectParentFileIds(oldFileVersions));
        return parentFileIds;
    }

    public Map<Id, Id> resolveLatestLinkIdsByFileId(Set<Id> parentFileIds) {
        Map<Id, Id> latestLinkIdsByFileId = new Map<Id, Id>();
        if (parentFileIds == null || parentFileIds.isEmpty()) return latestLinkIdsByFileId;

        List<GoogleFileLink__c> fileLinks = (List<GoogleFileLink__c>) GoogleFileLinkSelector.query()
            .withBaseFields()
            .byParentIds(parentFileIds)
            .orderByCreatedDesc()
            .toList();

        for (GoogleFileLink__c fileLink : fileLinks) {
            if (fileLink == null || fileLink.GoogleFileId__c == null || latestLinkIdsByFileId.containsKey(fileLink.GoogleFileId__c)) continue;
            latestLinkIdsByFileId.put(fileLink.GoogleFileId__c, fileLink.Id);
        }

        return latestLinkIdsByFileId;
    }

    public Set<Id> collectGoogleWorkspaceVersionIds(List<GoogleFileVersion__c> fileVersions, Boolean previewDisabled) {
        Set<Id> googleWorkspaceVersionIds = new Set<Id>();
        if (previewDisabled || fileVersions == null) return googleWorkspaceVersionIds;

        for (GoogleFileVersion__c fileVersion : fileVersions) {
            if (requiresGoogleWorkspaceFile(fileVersion)) {
                googleWorkspaceVersionIds.add(fileVersion.Id);
            }
        }

        return googleWorkspaceVersionIds;
    }

    public Set<Id> collectSummaryCandidateVersionIds(List<GoogleFileVersion__c> fileVersions) {
        Set<Id> summaryCandidateVersionIds = new Set<Id>();
        if (fileVersions == null) return summaryCandidateVersionIds;

        for (GoogleFileVersion__c fileVersion : fileVersions) {
            if (supportsSummary(fileVersion)) {
                summaryCandidateVersionIds.add(fileVersion.Id);
            }
        }

        return summaryCandidateVersionIds;
    }

    public List<GoogleFileRelocationRequestDTO> buildRelocationRequests(List<GoogleFileVersion__c> fileVersions, Map<Id, Id> linkIdsByFileId) {
        List<GoogleFileRelocationRequestDTO> relocationRequests = new List<GoogleFileRelocationRequestDTO>();
        if (fileVersions == null) return relocationRequests;

        for (GoogleFileVersion__c fileVersion : fileVersions) {
            if (fileVersion == null || fileVersion.Id == null || fileVersion.GoogleFileId__c == null) continue;

            relocationRequests.add(new GoogleFileRelocationRequestDTO(
                UserInfo.getUserId(),
                fileVersion.GoogleFileId__c,
                fileVersion.Id,
                linkIdsByFileId == null ? null : linkIdsByFileId.get(fileVersion.GoogleFileId__c)
            ));
        }

        return relocationRequests;
    }

    public List<List<GoogleFileVersion__c>> partition(List<GoogleFileVersion__c> fileVersions, Integer batchSize) {
        List<List<GoogleFileVersion__c>> partitions = new List<List<GoogleFileVersion__c>>();
        if (fileVersions == null || fileVersions.isEmpty()) return partitions;

        Integer effectiveBatchSize = batchSize == null || batchSize <= 0
            ? fileVersions.size()
            : batchSize;

        List<GoogleFileVersion__c> currentPartition = new List<GoogleFileVersion__c>();
        for (GoogleFileVersion__c fileVersion : fileVersions) {
            currentPartition.add(fileVersion);

            if (currentPartition.size() == effectiveBatchSize) {
                partitions.add(currentPartition);
                currentPartition = new List<GoogleFileVersion__c>();
            }
        }

        if (!currentPartition.isEmpty()) {
            partitions.add(currentPartition);
        }

        return partitions;
    }

    private Boolean requiresGoogleWorkspaceFile(GoogleFileVersion__c fileVersion) {
        return fileVersion != null
            && fileVersion.Id != null
            && fileVersion.IsPreviewableFile__c
            && !String.isBlank(fileVersion.GoogleDriveFileId__c)
            && String.isBlank(fileVersion.GoogleDocsFileId__c)
            && GoogleCloudConstants.FILE_EXTENSION_TO_PREVIEW_TYPE.containsKey(fileVersion.Type__c);
    }

    public Boolean supportsInteractiveIntelligence(GoogleFileVersion__c fileVersion) {
        return fileVersion != null
            && fileVersion.Id != null
            && fileVersion.Size__c != null
            && fileVersion.Size__c <= GoogleCloudConstants.MAX_SUMMARY_FILE_SIZE_BYTES
            && String.isNotBlank(fileVersion.GoogleDocsFileId__c);
    }

    public Boolean supportsSummary(GoogleFileVersion__c fileVersion) {
        return fileVersion != null
            && fileVersion.Id != null
            && fileVersion.Size__c != null
            && fileVersion.Size__c <= GoogleCloudConstants.MAX_SUMMARY_FILE_SIZE_BYTES
            && (
                supportsInteractiveIntelligence(fileVersion)
                || requiresGoogleWorkspaceFile(fileVersion)
            );
    }
}