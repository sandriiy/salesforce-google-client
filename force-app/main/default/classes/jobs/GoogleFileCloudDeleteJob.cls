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

        GoogleRemoteFileService remoteFileService = new GoogleRemoteFileService();
        for (String googleDriveId : filesBatch) {
            remoteFileService.deleteFile(googleDriveId);
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