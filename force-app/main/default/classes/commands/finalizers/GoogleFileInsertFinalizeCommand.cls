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
 * Queues everything that has to happen after new versions are committed: the Workspace preview copy,
 * the summary, the folder placement and the label. All of it needs a Drive callout, which cannot follow
 * uncommitted DML, which is why it is chained rather than done inline. Versions are handled in chunks of
 * ten so each chunk gets its own callout budget.
 */
public with sharing class GoogleFileInsertFinalizeCommand {
    private static final Integer MAX_CHAIN_BATCH_SIZE = 10;

    @TestVisible
    private static Boolean intelligenceSkipped = false;

    private final GoogleMetadataConfigService googleConfig;
    private final GoogleFileVersionContextResolver versionContextResolver;

    /**
     * Leaves the AI summary and label out of every version committed in the rest of this transaction,
     * keeping the preview copy and the folder placement. The migration asks for this before it commits;
     * an upload never does.
     */
    public static void skipIntelligenceForThisTransaction() {
        intelligenceSkipped = true;
    }

    public GoogleFileInsertFinalizeCommand() {
        this(new GoogleMetadataConfigService(), new GoogleFileVersionContextResolver());
    }

    /**
     * Builds the command on services the caller already holds, which saves resolving the configuration
     * again in a trigger context.
     *
     * @param googleConfig The configuration to read. A null gets a fresh one.
     * @param versionContextResolver The resolver that decides what each version needs. A null gets a fresh one.
     */
    public GoogleFileInsertFinalizeCommand(GoogleMetadataConfigService googleConfig, GoogleFileVersionContextResolver versionContextResolver) {
        this.googleConfig = googleConfig == null ? new GoogleMetadataConfigService() : googleConfig;
        this.versionContextResolver = versionContextResolver == null ? new GoogleFileVersionContextResolver() : versionContextResolver;
    }

    /**
     * Works out what the new versions need and chains the jobs in order, folder placement ahead of the
     * label, so a slow AI call never holds a file in the wrong folder.
     *
     * @param newFileVersions The versions that were just inserted.
     */
    public void execute(List<GoogleFileVersion__c> newFileVersions) {
        if (newFileVersions == null || newFileVersions.isEmpty()) return;

        Boolean previewDisabled = this.googleConfig.isPreviewDisabled();
        Boolean folderPlacementEnabled = !String.isBlank(this.googleConfig.getGoogleDriveFolderStructure());
        if (previewDisabled && !folderPlacementEnabled) return;

        Boolean analyzeVersions = !intelligenceSkipped;
        Set<Id> parentFileIds = this.versionContextResolver.collectParentFileIds(newFileVersions);
        Map<Id, Id> linkIdsByFileId = folderPlacementEnabled == true
            ? this.versionContextResolver.resolveLatestLinkIdsByFileId(parentFileIds)
            : new Map<Id, Id>();
        Map<Id, Id> delegatedOwnerIdsByFileId = folderPlacementEnabled == true
            ? this.versionContextResolver.resolveDelegatedOwnerIdsByFileId(parentFileIds)
            : new Map<Id, Id>();

        for (List<GoogleFileVersion__c> versionChunk : this.versionContextResolver.partition(newFileVersions, MAX_CHAIN_BATCH_SIZE)) {
            GQueueableBuilder jobsChainer = GAsync.queueable();
            Boolean hasJobs = false;

            Set<Id> previewableVersionIds = this.versionContextResolver.collectGoogleWorkspaceVersionIds(versionChunk, previewDisabled);
            if (!previewableVersionIds.isEmpty()) {
                jobsChainer.chain(new GoogleFileVersionPreviewJob(previewableVersionIds, analyzeVersions)).deepClone();
                hasJobs = true;
            }

			Set<Id> summaryCandidateVersionIds = analyzeVersions
				? this.versionContextResolver.collectSummaryCandidateVersionIds(versionChunk)
				: new Set<Id>();
			if (!summaryCandidateVersionIds.isEmpty()) {
				jobsChainer.chain(new GoogleFileVersionSummaryJob(summaryCandidateVersionIds)).deepClone();
				hasJobs = true;
			}

            if (folderPlacementEnabled) {
                List<GoogleFileRelocationRequestDTO> relocationRequests = this.versionContextResolver.buildRelocationRequests(versionChunk, linkIdsByFileId, delegatedOwnerIdsByFileId);
                if (!relocationRequests.isEmpty()) {
                    jobsChainer.chain(new GoogleFileCloudFolderJob(relocationRequests)).deepClone();
                    hasJobs = true;
                }
            }

			if (!summaryCandidateVersionIds.isEmpty() && new GoogleFileIntelligenceFactory().isLabelingConfigured()) {
				jobsChainer.chain(new GoogleFileVersionLabelJob(summaryCandidateVersionIds)).deepClone();
			}

            if (hasJobs) {
                jobsChainer.enqueue();
            }
        }
    }
}