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
 * Creates a folder in Google Drive and hands back its Id and link. By default it adopts a folder that
 * already carries the same name in the same parent, so a flow that runs twice does not leave two
 * folders behind. This one has nothing to do with the configured folder structure, which
 * GoogleFileFolderStructureCommand owns.
 */
public without sharing class GoogleFolderCreateCommand {
	public class GoogleFolderCreateCommandException extends Exception {}

	private static final Integer SEARCH_MAX_RESULT = 25;
	private static final String FOLDER_FIELDS = 'id, name, parents, webViewLink';
	private static final String DEFAULT_FOLDER_NAME = 'Untitled';

	private final GoogleDrive remoteGoogleDrive;

	private String folderName;
	private String parentFolderId;
	private Boolean reusesExistingFolder = true;

	public GoogleFolderCreateCommand() {
		this.remoteGoogleDrive = new GoogleClientApiProvider().retrieveGoogleDriveClient();
	}

	/**
	 * Sets the folder name. It is trimmed, and a blank one becomes "Untitled".
	 *
	 * @param value The name to create the folder under.
	 * @return This same instance, so the call chains onto under().
	 */
	public GoogleFolderCreateCommand named(String value) {
		this.folderName = value;
		return this;
	}

	/**
	 * Sets the Drive folder the new folder is created in. It is required, the command does not guess.
	 *
	 * @param value The parent folder Id in Google Drive.
	 * @return This same instance, so the call chains onto execute().
	 */
	public GoogleFolderCreateCommand under(String value) {
		this.parentFolderId = value;
		return this;
	}

	/**
	 * Decides what happens when the name is already taken in that parent. Reuse is on unless you turn it
	 * off, and turning it off means every call creates another folder.
	 *
	 * @param value False to always create, true to adopt a matching folder.
	 * @return This same instance, so the call chains onto execute().
	 */
	public GoogleFolderCreateCommand reuseExisting(Boolean value) {
		this.reusesExistingFolder = value == true;
		return this;
	}

	/**
	 * Creates the folder, or returns the matching one when reuse is on. Where duplicates already exist
	 * the lowest Id wins, so repeated calls keep landing in the same folder.
	 *
	 * @return The folder, with wasCreated telling you whether it is new.
	 */
	public GoogleFolderCreateResult execute() {
		if (String.isBlank(parentFolderId)) {
			throw new GoogleFolderCreateCommandException('Parent folder Id must not be blank');
		}

		String effectiveName = String.isBlank(folderName) ? DEFAULT_FOLDER_NAME : folderName.trim();

		if (reusesExistingFolder) {
			GoogleFileEntity existingFolder = findExistingFolder(parentFolderId, effectiveName);
			if (existingFolder != null) {
				Logger.info('Folder Create --> Reused, FolderId=' + existingFolder.id + ', ParentFolderId=' + parentFolderId + ', Name=' + effectiveName).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
				return new GoogleFolderCreateResult(existingFolder, parentFolderId, false);
			}
		}

		GoogleFileEntity createdFolder = remoteGoogleDrive.files().multipartCreate()
			.setFileName(effectiveName)
			.setMimeType(GoogleCloudConstants.MIME_TYPE_GOOGLE_FOLDER)
			.setParentFolders(new List<String>{ parentFolderId })
			.setSupportsAllDrives(true)
			.setFields(FOLDER_FIELDS)
			.setBody('')
			.execute();

		if (createdFolder == null || String.isBlank(createdFolder.id)) {
			throw new GoogleFolderCreateCommandException('Google Drive did not return the created folder');
		}

		Logger.info('Folder Create --> Created, FolderId=' + createdFolder.id + ', ParentFolderId=' + parentFolderId + ', Name=' + effectiveName).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
		return new GoogleFolderCreateResult(createdFolder, parentFolderId, true);
	}

	/**
	 * Loads a folder that is already known by Id, which is how a caller that resolved a folder elsewhere
	 * returns it in the same shape as a created one.
	 *
	 * @param folderId The Drive folder to load.
	 * @param wasCreated What to report in the result, since only the caller knows.
	 * @return The folder details from Google Drive.
	 */
	public GoogleFolderCreateResult retrieve(String folderId, Boolean wasCreated) {
		if (String.isBlank(folderId)) {
			throw new GoogleFolderCreateCommandException('Folder Id must not be blank');
		}

		GoogleFileEntity folder = remoteGoogleDrive.files().retrieve().download(folderId)
			.setFileDownloadType(GoogleDownloadFileBuilder.DownloadType.METADATA)
			.setSearchOnAllDrives(true)
			.setFields(FOLDER_FIELDS)
			.execute();

		if (folder == null || String.isBlank(folder.id)) {
			throw new GoogleFolderCreateCommandException('Folder was not found in Google Drive: ' + folderId);
		}

		return new GoogleFolderCreateResult(folder, firstParent(folder), wasCreated == true);
	}

	private GoogleFileEntity findExistingFolder(String parentId, String name) {
		String query = 'mimeType = \'' + GoogleCloudConstants.MIME_TYPE_GOOGLE_FOLDER + '\' ';
		query += 'and name = \'' + escapeQueryValue(name) + '\' ';
		query += 'and \'' + escapeQueryValue(parentId) + '\' in parents ';
		query += 'and trashed = false';

		GoogleFileSearchResult searchResult = remoteGoogleDrive.files().search()
			.setMaxResult(SEARCH_MAX_RESULT)
			.setSearchQuery(query)
			.setSearchOnAllDrives(true)
			.setFields('files(' + FOLDER_FIELDS + ')')
			.execute();

		if (searchResult == null || searchResult.files == null) return null;

		GoogleFileEntity adoptedFolder = null;
		for (GoogleFileEntity candidate : searchResult.files) {
			if (candidate == null || String.isBlank(candidate.id)) continue;
			if (adoptedFolder == null || candidate.id.compareTo(adoptedFolder.id) < 0) {
				adoptedFolder = candidate;
			}
		}

		return adoptedFolder;
	}

	private String firstParent(GoogleFileEntity folder) {
		if (folder == null || folder.parents == null) return null;

		for (String parent : folder.parents) {
			if (String.isNotBlank(parent)) return parent;
		}

		return null;
	}

	private String escapeQueryValue(String value) {
		if (value == null) return '';
		return value.replace('\\', '\\\\').replace('\'', '\\\'');
	}

	/**
	 * What a folder call ended up with. wasCreated is false when an existing folder was adopted.
	 */
	public class GoogleFolderCreateResult {
		public final String folderId;
		public final String folderName;
		public final String parentFolderId;
		public final String webViewLink;
		public final Boolean wasCreated;

		/**
		 * Wraps the Drive answer with the parent the caller asked for, because Drive does not always return
		 * the parents on a create.
		 *
		 * @param folder The folder as Google Drive returned it.
		 * @param parentFolderId The folder it was created in.
		 * @param wasCreated True when this call created it.
		 */
		public GoogleFolderCreateResult(GoogleFileEntity folder, String parentFolderId, Boolean wasCreated) {
			this.folderId = folder.id;
			this.folderName = folder.name;
			this.parentFolderId = parentFolderId;
			this.webViewLink = folder.webViewLink;
			this.wasCreated = wasCreated;
		}
	}
}
