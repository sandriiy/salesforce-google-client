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
 * Creates folders in Google Drive for automation, and returns the folder a record already owns. Give it
 * a name and it creates one, give it only a record and it hands back that record's own folder, which
 * needs a configured structure that keeps folders per record.
 */
public without sharing class GoogleLocalFolderService {
	public class GoogleLocalFolderException extends Exception {}

	private static final String MISSING_REQUEST_MESSAGE = 'Enter a folder name, or provide a record Id to use the record’s own folder';
	private static final String RECORD_FOLDER_UNAVAILABLE_MESSAGE = 'Google Client is not set up to keep a folder per record. Enter a folder name to create one, or choose a folder structure with {Record} under Google Drive settings';
	private static final String RECORD_FOLDER_UNRESOLVED_MESSAGE = 'The record folder could not be resolved in Google Drive. Please try again or contact your system administrator';
	private static final String MISSING_UPLOAD_FOLDER_MESSAGE = 'No Google Drive upload folder is configured. Set one under Google Drive settings or provide a parent folder Id';
	private static final String CREATE_FAILED_MESSAGE = 'Unable to create the folder in Google Drive. Please try again or contact your system administrator';

	private final GoogleMetadataConfigService metadataService;

	public GoogleLocalFolderService() {
		this.metadataService = new GoogleMetadataConfigService();
	}

	/**
	 * Creates or finds one folder. Where the folder goes is decided in that order: the parent you named, the
	 * record's folder, then the default upload folder.
	 *
	 * @param request The name, the parent, the record and whether an existing folder may be reused.
	 * @return The folder with its Id and link, and whether this call created it.
	 */
	public GoogleFolderCreateResultDTO createFolder(GoogleFolderCreateRequestDTO request) {
		if (request == null || (String.isBlank(request.folderName) && request.relatedRecordId == null)) {
			throw new GoogleLocalFolderException(MISSING_REQUEST_MESSAGE);
		}

		try {
			GoogleFolderCreateCommand.GoogleFolderCreateResult result = String.isBlank(request.folderName)
				? resolveRecordFolder(request.relatedRecordId)
				: new GoogleFolderCreateCommand()
					.named(request.folderName)
					.under(resolveParentFolderId(request))
					.reuseExisting(request.reuseExistingFolder != false)
					.execute();

			return toResultDto(result);
		} catch (GoogleLocalFolderException ex) {
			throw ex;
		} catch (Exception ex) {
			Logger.error('Create Google Drive Folder (Local/Remote): ' + String.valueOf(request.folderName) + ', record: ' + String.valueOf(request.relatedRecordId) + ', message: ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw new GoogleLocalFolderException(CREATE_FAILED_MESSAGE);
		}
	}

	private GoogleFolderCreateCommand.GoogleFolderCreateResult resolveRecordFolder(Id relatedRecordId) {
		if (!metadataService.requiresRecordFolder()) {
			throw new GoogleLocalFolderException(RECORD_FOLDER_UNAVAILABLE_MESSAGE);
		}

		GoogleFileFolderStructureCommand folderStructureCommand = new GoogleFileFolderStructureCommand();
		String existingFolderId = folderStructureCommand.findExistingFolder(UserInfo.getUserId(), relatedRecordId);
		String folderId = String.isNotBlank(existingFolderId) ? existingFolderId : folderStructureCommand.ensureFolder(relatedRecordId);

		if (String.isBlank(folderId)) {
			throw new GoogleLocalFolderException(RECORD_FOLDER_UNRESOLVED_MESSAGE);
		}

		return new GoogleFolderCreateCommand().retrieve(folderId, String.isBlank(existingFolderId));
	}

	private String resolveParentFolderId(GoogleFolderCreateRequestDTO request) {
		if (String.isNotBlank(request.parentFolderId)) return request.parentFolderId.trim();

		if (request.relatedRecordId != null && String.isNotBlank(metadataService.getGoogleDriveFolderStructure())) {
			String recordFolderId = new GoogleFileFolderStructureCommand().ensureFolder(request.relatedRecordId);
			if (String.isNotBlank(recordFolderId)) return recordFolderId;
		}

		String defaultFolderId = metadataService.getDefaultUploadFolderId();
		if (String.isBlank(defaultFolderId)) {
			throw new GoogleLocalFolderException(MISSING_UPLOAD_FOLDER_MESSAGE);
		}

		return defaultFolderId;
	}

	private GoogleFolderCreateResultDTO toResultDto(GoogleFolderCreateCommand.GoogleFolderCreateResult result) {
		GoogleFolderCreateResultDTO dto = new GoogleFolderCreateResultDTO();
		dto.folderId = result.folderId;
		dto.folderName = result.folderName;
		dto.parentFolderId = result.parentFolderId;
		dto.folderUrl = result.webViewLink;
		dto.wasCreated = result.wasCreated;
		return dto;
	}
}
