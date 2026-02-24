public without sharing class GoogleRemoteFileUploader {
	public class GoogleRemoteFileUploaderException extends Exception {}

	private GoogleMetadataConfigService metadataService = new GoogleMetadataConfigService();
	private final GoogleDrive remoteGoogleDrive;
	
	public GoogleRemoteFileUploader() {
		GoogleDriveApiProvider remoteFileService = new GoogleDriveApiProvider();
		this.remoteGoogleDrive = remoteFileService.retrieveGoogleDriveClient();
	}

    public GoogleFileEntity uploadFile(String fileName, String contentToUpload) {
		Blob decodedBlob = EncodingUtil.base64Decode(contentToUpload);
		List<String> parentFolders = metadataService.getTargetFolderResolver().resolveUploadFolderId();

		try {
			return this.remoteGoogleDrive.files().multipartCreate()
				.setFileName(fileName)
				.setBody(contentToUpload)
				.setParentFolders(parentFolders)
				.setSupportsAllDrives(true)
				.setFields('id, name, parents')
				.execute();
		} catch (Exception ex) {
			throw new GoogleRemoteFileUploaderException('Unable to upload the file. Please try again or contact your system administrator.');
		}
	}

	public GoogleBigFileEntity uploadBigFilePartial(String fileName, String chunkToUpload, String resumableSessionId, Long startByte, Long totalBytes) {
		Blob decodedBlob = EncodingUtil.base64Decode(chunkToUpload);
		List<String> parentFolders = metadataService.getTargetFolderResolver().resolveUploadFolderId();

		try {
			return this.remoteGoogleDrive.files().resumableCreate()
				.setExistingSessionUri(resumableSessionId)
				.setFileName(fileName)
				.setParentFolders(parentFolders)
				.setSupportsAllDrives(true)
				.setStartByte(startByte)
				.setTotalBytes(totalBytes)
				.setBody(decodedBlob)
				.execute();
		} catch (Exception ex) {
			throw new GoogleRemoteFileUploaderException('Unable to upload the file chunk. Please try again or contact your system administrator.');
		}
	}
}