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
public with sharing class GoogleFileCloudDeleteJob implements Queueable, Database.AllowsCallouts {
	private final Integer MAX_CALLS_PER_JOB;
    private final List<String> googleFileIds;

	public GoogleFileCloudDeleteJob(List<GoogleFileVersion__c> fileVersions) {
		this.MAX_CALLS_PER_JOB = new GoogleMetadataConfigService().getDeleteChainSize();
        this.googleFileIds = fileVersions == null 
			? new List<String>()
			: extractFileIds(fileVersions);
    }

    public GoogleFileCloudDeleteJob(Set<String> googleFileIds) {
		this.MAX_CALLS_PER_JOB = new GoogleMetadataConfigService().getDeleteChainSize();
        this.googleFileIds = googleFileIds == null 
			? new List<String>()
			: new List<String>(this.googleFileIds);
    }

	public GoogleFileCloudDeleteJob(List<String> googleFileIds) {
		this.MAX_CALLS_PER_JOB = new GoogleMetadataConfigService().getDeleteChainSize();
        this.googleFileIds = googleFileIds == null 
			? new List<String>()
			: googleFileIds;
    }

    public void execute(QueueableContext qc) {
        if (googleFileIds.isEmpty()) return;

        Integer chunkSize = Math.min(MAX_CALLS_PER_JOB, googleFileIds.size());
        List<String> filesBatch = getSlice(googleFileIds, 0, chunkSize);
		List<String> filesRemaining = getSlice(googleFileIds, chunkSize, googleFileIds.size());

        GoogleClientApiProvider remoteFileService = new GoogleClientApiProvider();
        for (String googleDriveId : filesBatch) {
			GoogleDrive removeGoogleDrive = remoteFileService.retrieveGoogleDriveClient();
			removeGoogleDrive.files().trash(googleDriveId)
				.setSupportsAllDrives(true)
				.execute();
        }

        if (!filesRemaining.isEmpty()) {
            System.enqueueJob(new GoogleFileCloudDeleteJob(filesRemaining));
        }
    }

	private List<String> getSlice(List<String> source, Integer fromIndex, Integer toIndex) {
		List<String> result = new List<String>();
		for (Integer i = fromIndex; i < Math.min(toIndex, source.size()); i++) {
			result.add(source[i]);
		}

		return result;
	}

	private List<String> extractFileIds(List<GoogleFileVersion__c> fileVersions) {
		List<String> fileIds = new List<String>();

		for (GoogleFileVersion__c fileVersion : fileVersions) {
			if (fileVersion.isSet('GoogleDriveFileId__c') && String.isNotBlank(fileVersion.GoogleDriveFileId__c)) {
				fileIds.add(fileVersion.GoogleDriveFileId__c);
			}
			
			if (fileVersion.isSet('GoogleDocsFileId__c') && String.isNotBlank(fileVersion.GoogleDocsFileId__c)) {
				fileIds.add(fileVersion.GoogleDocsFileId__c);
			}
		}

		return fileIds;
	}
}