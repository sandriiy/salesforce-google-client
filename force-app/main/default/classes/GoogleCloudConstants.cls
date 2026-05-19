public class GoogleCloudConstants {
	public static final String DEFAULT_FILE_NAME = 'Unknown';
    public static final String DEFAULT_LOGGER_TAG = 'Google Client for Salesforce';
	public static final Map<String, String> FILE_EXTENSION_TO_PREVIEW_TYPE = new Map<String, String>{
		'application/pdf' => 'application/vnd.google-apps.document',
		'application/msword' => 'application/vnd.google-apps.document',
		'application/vnd.openxmlformats-officedocument.wordprocessingml.document' => 'application/vnd.google-apps.document',
		'image/png' => 'application/vnd.google-apps.document',
		'image/jpeg' => 'application/vnd.google-apps.document',
		'image/webp' => 'application/vnd.google-apps.document',
		'image/tiff' => 'application/vnd.google-apps.document',
		'text/csv' => 'application/vnd.google-apps.spreadsheet',
		'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' => 'application/vnd.google-apps.spreadsheet',
		'application/vnd.google-apps.spreadsheet' => 'application/vnd.google-apps.spreadsheet'
	};
}