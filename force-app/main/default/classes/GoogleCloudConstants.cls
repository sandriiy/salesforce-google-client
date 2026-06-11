public class GoogleCloudConstants {
	public static final String DEFAULT_FILE_NAME = 'Unknown';
    public static final String DEFAULT_LOGGER_TAG = 'Google Client for Salesforce';
	public static final Integer MAX_SUMMARY_CHARACTERS = 255;
	public static final Long MAX_SUMMARY_FILE_SIZE_BYTES = 5242880L;

	public static final String GOOGLE_WORKSPACE_DOCUMENT_TYPE = 'application/vnd.google-apps.document';
	public static final String GOOGLE_WORKSPACE_SPREADSHEET_TYPE = 'application/vnd.google-apps.spreadsheet';
	public static final String MIME_TYPE_DOCX = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
	public static final String MIME_TYPE_ODT = 'application/vnd.oasis.opendocument.text';
	public static final String MIME_TYPE_RTF = 'application/rtf';
	public static final String MIME_TYPE_PDF = 'application/pdf';
	public static final String MIME_TYPE_TEXT = 'text/plain';
	public static final String MIME_TYPE_HTML_ZIP = 'application/zip';
	public static final String MIME_TYPE_EPUB = 'application/epub+zip';
	public static final String MIME_TYPE_MARKDOWN = 'text/markdown';
	public static final String MIME_TYPE_XLSX = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
	public static final String MIME_TYPE_ODS = 'application/vnd.oasis.opendocument.spreadsheet';
	public static final String MIME_TYPE_CSV = 'text/csv';
	public static final String MIME_TYPE_TSV = 'text/tab-separated-values';

	public static final Map<String, String> FILE_EXTENSION_TO_PREVIEW_TYPE = new Map<String, String>{
		MIME_TYPE_PDF => GOOGLE_WORKSPACE_DOCUMENT_TYPE,
		'application/msword' => GOOGLE_WORKSPACE_DOCUMENT_TYPE,
		MIME_TYPE_DOCX => GOOGLE_WORKSPACE_DOCUMENT_TYPE,
		'image/png' => GOOGLE_WORKSPACE_DOCUMENT_TYPE,
		'image/jpeg' => GOOGLE_WORKSPACE_DOCUMENT_TYPE,
		'image/webp' => GOOGLE_WORKSPACE_DOCUMENT_TYPE,
		'image/tiff' => GOOGLE_WORKSPACE_DOCUMENT_TYPE,
		MIME_TYPE_CSV => GOOGLE_WORKSPACE_SPREADSHEET_TYPE,
		MIME_TYPE_XLSX => GOOGLE_WORKSPACE_SPREADSHEET_TYPE,
		'application/vnd.google-apps.spreadsheet' => GOOGLE_WORKSPACE_SPREADSHEET_TYPE
	};

	public static final Map<String, List<GoogleFileDownloadAsOptionDTO>> GOOGLE_WORKSPACE_DOWNLOAD_AS_TYPES = new Map<String, List<GoogleFileDownloadAsOptionDTO>>{
		GOOGLE_WORKSPACE_DOCUMENT_TYPE => new List<GoogleFileDownloadAsOptionDTO>{
			new GoogleFileDownloadAsOptionDTO('Microsoft Word (.docx)', MIME_TYPE_DOCX, 'docx'),
			new GoogleFileDownloadAsOptionDTO('PDF Document (.pdf)', MIME_TYPE_PDF, 'pdf'),
			new GoogleFileDownloadAsOptionDTO('OpenDocument Format (.odt)', MIME_TYPE_ODT, 'odt'),
			new GoogleFileDownloadAsOptionDTO('Plain Text (.txt)', MIME_TYPE_TEXT, 'txt'),
			new GoogleFileDownloadAsOptionDTO('Rich Text Format (.rtf)', MIME_TYPE_RTF, 'rtf'),
			new GoogleFileDownloadAsOptionDTO('Web Page (.html, zipped)', MIME_TYPE_HTML_ZIP, 'zip'),
			new GoogleFileDownloadAsOptionDTO('EPUB Publication (.epub)', MIME_TYPE_EPUB, 'epub'),
			new GoogleFileDownloadAsOptionDTO('Markdown (.md)', MIME_TYPE_MARKDOWN, 'md')
		},
		GOOGLE_WORKSPACE_SPREADSHEET_TYPE => new List<GoogleFileDownloadAsOptionDTO>{
			new GoogleFileDownloadAsOptionDTO('Microsoft Excel (.xlsx)', MIME_TYPE_XLSX, 'xlsx'),
			new GoogleFileDownloadAsOptionDTO('OpenDocument (.ods)', MIME_TYPE_ODS, 'ods'),
			new GoogleFileDownloadAsOptionDTO('PDF (.pdf)', MIME_TYPE_PDF, 'pdf'),
			new GoogleFileDownloadAsOptionDTO('Web Page (.html)', MIME_TYPE_HTML_ZIP, 'zip'),
			new GoogleFileDownloadAsOptionDTO('Comma Separated Values (.csv)', MIME_TYPE_CSV, 'csv'),
			new GoogleFileDownloadAsOptionDTO('Tab Separated Values (.tsv)', MIME_TYPE_TSV, 'tsv')
		}
	};

	public static final String STRUCTURE_USER = '{User}';
	public static final String STRUCTURE_RECORD = '{Record}';
	public static final String STRUCTURE_USER_RECORD = '{User}-{Record}';
	public static final String STRUCTURE_RECORD_USER = '{Record}-{User}';
}