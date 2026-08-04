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
public with sharing class GoogleFileCloudShortcutJob extends GQueueableJob.AllowsCallouts {
	public class GoogleFileCloudShortcutJobException extends Exception {}

	@TestVisible
	private static Boolean skipExecution = false;

	private final Id initiatorUserId;
	private final Id localGoogleFileId;
	private final Id linkLocalGoogleFileId;

	public GoogleFileCloudShortcutJob(Id initiatorUserId, Id localGoogleFileId, Id linkLocalGoogleFileId) {
		this.initiatorUserId = initiatorUserId;
		this.localGoogleFileId = localGoogleFileId;
		this.linkLocalGoogleFileId = linkLocalGoogleFileId;
	}

	public override void work() {
		if (skipExecution) return;

		try {
			Logger.info(
				'Shortcut Placement Job --> FileId=' + String.valueOf(localGoogleFileId) +
				', LinkId=' + String.valueOf(linkLocalGoogleFileId)
			).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

			new GoogleFileShortcutPlacementCommand()
				.initiatedBy(initiatorUserId)
				.forFile(localGoogleFileId)
				.forLink(linkLocalGoogleFileId)
				.execute();
		} catch (Exception ex) {
			Logger.error('Shortcut Placement Job Failed --> ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw new GoogleFileCloudShortcutJobException('Unable to create the file shortcut. Please try again or contact your system administrator');
		}
	}
}