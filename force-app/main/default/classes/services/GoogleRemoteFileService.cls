public without sharing class GoogleRemoteFileService {
	public class GoogleRemoteFileServiceException extends Exception {}

	private final String DEFAULT_TOKEN_CACHE_NAME = 'accessToken';
	private final String DEFAULT_AGENT_NAME = 'Apex Client 1/1';

	@TestVisible
	private static String authorizerClassNameOverride;

	private GoogleCacheConfigService cacheService = new GoogleCacheConfigService();
	private GoogleMetadataConfigService metadataService = new GoogleMetadataConfigService();

	public String validateCustomGoogleAuthorizerClass(String className) {
		GoogleCredential testCredential = new GoogleAuthorizationCodeFlow.Builder()
			.setLocalGoogleAuthorizer(className)
			.build();

		if (String.isBlank(testCredential.accessToken)) {
			return 'Your custom authorization class was executed successfully but did not return an access token';
		} else {
			return 'Your custom authorization class was successfully invoked and returned a valid access token';
		}
	}

	public GoogleFileEntity cloneFileToPreviewableFormat(String fileName, String googleFileId) {
		GoogleCredential googleDriveCredentials = retrieveGoogleCredential();

		try {
			GoogleDrive googleDriveLibrary = new GoogleDrive(googleDriveCredentials, DEFAULT_AGENT_NAME);
			return googleDriveLibrary.files().clone(googleFileId)
				.setFields('id')
				.setFileName(fileName)
				.setSupportsAllDrives(true)
				.setMimeType('application/vnd.google-apps.document')
				.execute();
		} catch (Exception ex) {
			Logger.error('Create File Previewable Format Failed (Remote): ' + ex.getMessage());
			Logger.saveLog();
			throw new GoogleRemoteFileServiceException('Unable to convert the file. Please try again or contact your system administrator.');
		}
	}

	public GoogleFileEntity exportGoogleDocFileAsPdf(String googleDocFileId) {
		GoogleCredential googleDriveCredentials = retrieveGoogleCredential();

		try {
			GoogleDrive googleDriveLibrary = new GoogleDrive(googleDriveCredentials, DEFAULT_AGENT_NAME);
			return googleDriveLibrary.files().retrieve().export(googleDocFileId)
				.setMimeType('application/pdf')
				.setSearchOnAllDrives(true)
				.execute();
		} catch (Exception ex) {
			Logger.error('Export File as PDF Failed (Remote): ' + ex.getMessage());
			Logger.saveLog();
			throw new GoogleRemoteFileServiceException('Unable to export the file. Please try again or contact your system administrator.');
		}
	}

	public GoogleFileEntity exportGoogleFileDetails(String googleDocFileId) {
		GoogleCredential googleDriveCredentials = retrieveGoogleCredential();

		try {
			GoogleDrive googleDriveLibrary = new GoogleDrive(googleDriveCredentials, DEFAULT_AGENT_NAME);
			return googleDriveLibrary.files().retrieve().download(googleDocFileId)
				.setFileDownloadType(GoogleDownloadFileBuilder.DownloadType.METADATA)
				.setSearchOnAllDrives(true)
				.setFields('webViewLink, webContentLink')
				.execute();
		} catch (Exception ex) {
			Logger.error('Export File Details Failed (Remote): ' + ex.getMessage());
			Logger.saveLog();
			throw new GoogleRemoteFileServiceException('Unable to retrieve file details. Please try again or contact your system administrator.');
		}
	}

	public GooglePermissionEntity createFilePublicLink(String googleDocFileId) {
		GoogleCredential googleDriveCredentials = retrieveGoogleCredential();

		try {
			GoogleDrive googleDriveLibrary = new GoogleDrive(googleDriveCredentials, DEFAULT_AGENT_NAME);
			return googleDriveLibrary.permissions().create(googleDocFileId)
				.setSupportsAllDrives(true)
				.setPrincipalType('anyone')
				.setPrincipalRole('reader')
				.execute();
		} catch (Exception ex) {
			Logger.error('Create File Public Link Failed (Remote): ' + ex.getMessage());
			Logger.saveLog();
			throw new GoogleRemoteFileServiceException('Unable to create a public link. Please try again or contact your system administrator.');
		}
	}

	public void removeFilePublicLink(String googleDocFileId, String googlePermissionId) {
		GoogleCredential googleDriveCredentials = retrieveGoogleCredential();

		try {
			GoogleDrive googleDriveLibrary = new GoogleDrive(googleDriveCredentials, DEFAULT_AGENT_NAME);
			googleDriveLibrary.permissions().remove(googleDocFileId, googlePermissionId)
				.setSupportsAllDrives(true)
				.execute();
		} catch (Exception ex) {
			Logger.error('Remove File Public Link Failed (Remote): ' + ex.getMessage());
			Logger.saveLog();
			throw new GoogleRemoteFileServiceException('Unable to remove the public link. Please try again or contact your system administrator.');
		}
	}

	public void deleteFile(String googleFileId) {
		GoogleCredential googleDriveCredentials = retrieveGoogleCredential();

		try {
			GoogleDrive googleDriveLibrary = new GoogleDrive(googleDriveCredentials, DEFAULT_AGENT_NAME);
			googleDriveLibrary.files().trash(googleFileId)
				.setSupportsAllDrives(true)
				.execute();
		} catch (Exception ex) {
			Logger.error('Delete File Failed (Remote): ' + ex.getMessage());
			Logger.saveLog();
			throw new GoogleRemoteFileServiceException('Unable to delete the file. Please try again or contact your system administrator.');
		}
	}

	public GoogleFileEntity uploadFile(String fileName, String contentToUpload) {
		Blob decodedBlob = EncodingUtil.base64Decode(contentToUpload);
		GoogleCredential googleDriveCredentials = retrieveGoogleCredential();

		List<String> parentFolders = metadataService.getTargetFolderResolver().resolveUploadFolderId();

		try {
			GoogleDrive googleDriveLibrary = new GoogleDrive(googleDriveCredentials, DEFAULT_AGENT_NAME);
			return googleDriveLibrary.files().multipartCreate()
				.setFileName(fileName)
				.setBody(contentToUpload)
				.setParentFolders(parentFolders)
				.setSupportsAllDrives(true)
				.setFields('id, name, parents')
				.execute();
		} catch (Exception ex) {
			Logger.error('Upload File Failed (Remote): ' + ex.getMessage());
			Logger.saveLog();
			throw new GoogleRemoteFileServiceException('Unable to upload the file. Please try again or contact your system administrator.');
		}
	}

	public GoogleBigFileEntity uploadBigFilePartial(String fileName, String chunkToUpload, String resumableSessionId, Long startByte, Long totalBytes) {
		Blob decodedBlob = EncodingUtil.base64Decode(chunkToUpload);
		GoogleCredential googleDriveCredentials = retrieveGoogleCredential();

		List<String> parentFolders = metadataService.getTargetFolderResolver().resolveUploadFolderId();

		try {
			GoogleDrive googleDriveLibrary = new GoogleDrive(googleDriveCredentials, DEFAULT_AGENT_NAME);
			return googleDriveLibrary.files().resumableCreate()
				.setExistingSessionUri(resumableSessionId)
				.setFileName(fileName)
				.setParentFolders(parentFolders)
				.setSupportsAllDrives(true)
				.setStartByte(startByte)
				.setTotalBytes(totalBytes)
				.setBody(decodedBlob)
				.execute();
		} catch (Exception ex) {
			Logger.error('Upload Big File Partial Failed (Remote): ' + ex.getMessage());
			Logger.saveLog();
			throw new GoogleRemoteFileServiceException('Unable to upload the file chunk. Please try again or contact your system administrator.');
		}
	}

	public GoogleFileEntity downloadFile(String googleFileId) {
		GoogleCredential googleDriveCredentials = retrieveGoogleCredential();

		try {
			GoogleDrive googleDriveLibrary = new GoogleDrive(googleDriveCredentials, DEFAULT_AGENT_NAME);
			return googleDriveLibrary.files().retrieve().download(googleFileId)
				.setFileDownloadType(GoogleDownloadFileBuilder.DownloadType.CONTENT)
				.setSearchOnAllDrives(true)
				.execute();
		} catch (Exception ex) {
			Logger.error('Download File Failed (Remote): ' + ex.getMessage());
			Logger.saveLog();
			throw new GoogleRemoteFileServiceException('Unable to download the file. Please try again or contact your system administrator.');
		}
	}

	public GoogleFileEntity downloadFile(String googleFileId, Long startByte, Long endByte) {
		GoogleCredential googleDriveCredentials = retrieveGoogleCredential();

		try {
			GoogleDrive googleDriveLibrary = new GoogleDrive(googleDriveCredentials, DEFAULT_AGENT_NAME);
			return googleDriveLibrary.files().retrieve().download(googleFileId)
				.setFileDownloadType(GoogleDownloadFileBuilder.DownloadType.CONTENT)
				.setPartialRange(startByte, endByte)
				.setSearchOnAllDrives(true)
				.execute();
		} catch (Exception ex) {
			Logger.error('Download Big File Failed (Remote): ' + ex.getMessage());
			Logger.saveLog();
			throw new GoogleRemoteFileServiceException('Unable to download the file chunk. Please try again or contact your system administrator.');
		}
	}

	private GoogleCredential retrieveGoogleCredential() {
		String authorizerClassName = authorizerClassNameOverride != null
			? authorizerClassNameOverride
			: metadataService.getGoogleAuthorizerClassName();

		GoogleAuthorizationCodeFlow.Builder builder = new GoogleAuthorizationCodeFlow.Builder()
			.setLocalGoogleAuthorizer(authorizerClassName);

		if (cacheService.getSessionPartition() != null) {
			builder.setLocalPlatformCache(
				cacheService.getSessionPartition(),
				DEFAULT_TOKEN_CACHE_NAME
			);
		} else {
			builder.setLocalPlatformCache(
				cacheService.getOrgPartition(),
				DEFAULT_TOKEN_CACHE_NAME
			);
		}

		return builder.build();
	}
}