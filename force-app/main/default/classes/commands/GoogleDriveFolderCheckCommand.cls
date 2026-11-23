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
 * Reads one Google Drive folder and says whether Google Client can put new files in it: it must exist, be
 * out of the trash, be a folder and accept new files from the service account. One read, and it never
 * throws, so a caller can fall back when the answer is no. Whether the folder is full only shows when a file
 * is refused.
 */
public without sharing class GoogleDriveFolderCheckCommand {
	public class GoogleDriveFolderCheckCommandException extends Exception {}

	private static final String FOLDER_FIELDS = 'id, name, mimeType, trashed, capabilities(canAddChildren)';
	private static final String BLANK_FOLDER_MESSAGE = 'Enter the ID of a Google Drive folder.';
	private static final String UNREACHABLE_MESSAGE = 'Google Client can\'t reach this folder. Share it with the service account as Content manager and try again.';
	private static final String TRASHED_MESSAGE = 'This folder is in the trash. Restore it or choose another folder.';
	private static final String NOT_A_FOLDER_MESSAGE = 'This is not a folder. Enter the ID of a Google Drive folder.';
	private static final String READ_ONLY_MESSAGE = 'Google Client can\'t add files to this folder. Give the service account Content manager access and try again.';

	private final GoogleDrive remoteGoogleDrive;

	public GoogleDriveFolderCheckCommand() {
		this(new GoogleClientApiProvider().retrieveGoogleDriveClient());
	}

	/**
	 * Builds the command on a Drive client the caller already holds, which saves a token look-up in a job
	 * that makes other Drive calls.
	 *
	 * @param remoteGoogleDrive The client from GoogleClientApiProvider.
	 */
	public GoogleDriveFolderCheckCommand(GoogleDrive remoteGoogleDrive) {
		this.remoteGoogleDrive = remoteGoogleDrive;
	}

	/**
	 * Checks one folder.
	 *
	 * @param folderId The Google Drive folder Id.
	 * @return Whether it is usable, its name, and the reason in an administrator's words when it is not; the
	 * raw Drive answer, when there was one, is in failureDetail for the log.
	 */
	public GoogleDriveFolderCheckDTO check(String folderId) {
		GoogleDriveFolderCheckDTO result = new GoogleDriveFolderCheckDTO();
		result.isUsable = false;

		if (String.isBlank(folderId)) {
			result.message = BLANK_FOLDER_MESSAGE;
			return result;
		}

		GoogleFileEntity folder;
		try {
			folder = this.remoteGoogleDrive.files().retrieve().download(folderId.trim())
				.setFileDownloadType(GoogleDownloadFileBuilder.DownloadType.METADATA)
				.setSearchOnAllDrives(true)
				.setFields(FOLDER_FIELDS)
				.execute();
		} catch (Exception ex) {
			result.message = UNREACHABLE_MESSAGE;
			result.failureDetail = ex.getMessage();
			return result;
		}

		if (folder == null || String.isBlank(folder.id)) {
			result.message = UNREACHABLE_MESSAGE;
			return result;
		}

		result.folderName = folder.name;
		if (folder.trashed == true) {
			result.message = TRASHED_MESSAGE;
		} else if (folder.mimeType != GoogleCloudConstants.MIME_TYPE_GOOGLE_FOLDER) {
			result.message = NOT_A_FOLDER_MESSAGE;
		} else if (folder.capabilities == null || folder.capabilities.canAddChildren != true) {
			result.message = READ_ONLY_MESSAGE;
		} else {
			result.isUsable = true;
		}

		return result;
	}
}
