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
 * Works out what a batch of new versions still needs: a Workspace copy for previews, a summary, a move
 * into the record folder. The trigger and the finalizer both ask here so the rules live in one place
 * instead of being repeated per job.
 */
public with sharing class GoogleFileVersionContextResolver {
    /**
     * Collects the files the given versions belong to.
     *
     * @param fileVersions The versions to look at.
     * @return The parent GoogleFile__c Ids.
     */
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

    /**
     * Collects the parent files of both sides of a trigger, which is what an update or a delete needs.
     *
     * @param newFileVersions The versions after the change, or null.
     * @param oldFileVersions The versions before the change, or null.
     * @return The parent GoogleFile__c Ids of both.
     */
    public Set<Id> collectParentFileIds(List<GoogleFileVersion__c> newFileVersions, List<GoogleFileVersion__c> oldFileVersions) {
        Set<Id> parentFileIds = new Set<Id>();
        parentFileIds.addAll(collectParentFileIds(newFileVersions));
        parentFileIds.addAll(collectParentFileIds(oldFileVersions));
        return parentFileIds;
    }

    /**
     * Finds the most recent link of each file, which is the record a newly uploaded version is placed
     * against.
     *
     * @param parentFileIds The files to look up.
     * @return The latest link Id per file Id.
     */
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

    /**
     * Picks the versions that still need a Google Workspace copy made for previews.
     *
     * @param fileVersions The versions to look at.
     * @param previewDisabled True when previews are turned off for the org, which empties the answer.
     * @return The versions to clone in Drive.
     */
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

    /**
     * Picks the versions worth sending to the model, including the ones whose Workspace copy is only about
     * to be created, since the summary job runs after that.
     *
     * @param fileVersions The versions to look at.
     * @return The versions the AI jobs should consider.
     */
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

    /**
     * Turns versions into the requests the folder job works from.
     *
     * @param fileVersions The versions to place.
     * @param linkIdsByFileId The link each file was uploaded against.
     * @return One request per version that can be placed.
     */
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

    /**
     * Loads versions asked for either way at once: by their own Id, or by file when the caller wants
     * whichever version is current. The answer is keyed by whatever was asked for, so look a file up by its
     * file Id and a version by its version Id.
     *
     * @param versionIds The versions wanted by their own Id.
     * @param fileIds The files whose latest version is wanted.
     * @return The versions with their confidential fields, keyed by the Id they were requested with.
     */
    public Map<Id, GoogleFileVersion__c> resolveVersionsByIdOrFileId(Set<Id> versionIds, Set<Id> fileIds) {
        Map<Id, GoogleFileVersion__c> versionsByRequestedId = new Map<Id, GoogleFileVersion__c>();

        if (versionIds != null && !versionIds.isEmpty()) {
            for (GoogleFileVersion__c fileVersion : (List<GoogleFileVersion__c>) GoogleFileVersionSelector.query()
                .withAdvancedFields()
                .byIds(versionIds)
                .toList()
            ) {
                versionsByRequestedId.put(fileVersion.Id, fileVersion);
            }
        }

        if (fileIds != null && !fileIds.isEmpty()) {
            for (GoogleFileVersion__c fileVersion : (List<GoogleFileVersion__c>) GoogleFileVersionSelector.query()
                .withAdvancedFields()
                .byParentIds(fileIds)
                .byLatest()
                .orderByCreatedDesc()
                .toList()
            ) {
                if (versionsByRequestedId.containsKey(fileVersion.GoogleFileId__c)) continue;
                versionsByRequestedId.put(fileVersion.GoogleFileId__c, fileVersion);
            }
        }

        return versionsByRequestedId;
    }

    /**
     * Splits versions into chunks so each chunk gets its own callout budget in its own job.
     *
     * @param fileVersions The versions to split.
     * @param batchSize How many per chunk. Zero or null keeps them together.
     * @return The chunks, in the original order.
     */
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

    /**
     * Says whether a user can ask about this version right now, which needs a Workspace copy that already
     * exists and a size within the limit.
     *
     * @param fileVersion The version to check.
     * @return True when summaries and questions can run against it.
     */
    public Boolean supportsInteractiveIntelligence(GoogleFileVersion__c fileVersion) {
        return fileVersion != null
            && fileVersion.Id != null
            && fileVersion.Size__c != null
            && fileVersion.Size__c <= GoogleCloudConstants.MAX_SUMMARY_FILE_SIZE_BYTES
            && String.isNotBlank(fileVersion.GoogleDocsFileId__c);
    }

    /**
     * Says whether this version is worth summarizing, which also covers a file whose Workspace copy is
     * about to be made.
     *
     * @param fileVersion The version to check.
     * @return True when the summary job should consider it.
     */
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