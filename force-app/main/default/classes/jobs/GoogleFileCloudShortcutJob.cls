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