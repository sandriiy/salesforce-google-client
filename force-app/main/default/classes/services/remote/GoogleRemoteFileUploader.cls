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
public without sharing class GoogleRemoteFileUploader {
	public class GoogleRemoteFileUploaderException extends Exception {}

	private GoogleMetadataConfigService metadataService = new GoogleMetadataConfigService();
	private final GoogleDrive remoteGoogleDrive;
	
	public GoogleRemoteFileUploader() {
		GoogleClientApiProvider remoteFileService = new GoogleClientApiProvider();
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