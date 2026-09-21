/**
 * The values shared across the package: MIME types, the preview and Download As catalogs, the folder
 * structure placeholders and the order records are written in. A literal that carries a rule belongs
 * here only when more than one class needs it, otherwise it stays private to the class that owns it.
 */
public class GoogleCloudConstants {
	// Shared defaults used across logging, naming, and AI output limits.
	public static final String DEFAULT_FILE_NAME = 'Unknown';
    /**
     * The tag on every log entry this package writes, which is what separates them from everything else in a
     * shared org. Never log without it.
     */
    public static final String DEFAULT_LOGGER_TAG = 'Google Client for Salesforce';
	public static final Integer MAX_SUMMARY_CHARACTERS = 255;
	public static final Long MAX_SUMMARY_FILE_SIZE_BYTES = 5242880L;

	// Unit of Work insert order for the package object graph (deletes run in reverse).
	// GoogleFileLink__c must be inserted before GoogleFileVersion__c: the version trigger
	// enqueues the folder placement job, which resolves the record folder from the link.
	/**
	 * The order the object graph is written in. It is load bearing rather than cosmetic: links have to land
	 * before versions, because the version trigger queues the folder placement and that reads the record from
	 * the link. Reordering this breaks uploads quietly.
	 */
	public static final List<SObjectType> DEFAULT_WRITE_ORDER = new List<SObjectType>{
		GoogleFile__c.SObjectType,
		GoogleFileLink__c.SObjectType,
		GoogleFileVersion__c.SObjectType,
		GoogleFileVersionLabel__c.SObjectType,
		GoogleFile__Share.SObjectType
	};

	// Google Workspace target MIME types used when generating preview files.
	public static final String GOOGLE_WORKSPACE_DOCUMENT_TYPE = 'application/vnd.google-apps.document';
	public static final String GOOGLE_WORKSPACE_SPREADSHEET_TYPE = 'application/vnd.google-apps.spreadsheet';

	// Source and export MIME types supported by preview and download flows.
	public static final String MIME_TYPE_DOC = 'application/msword';
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
	public static final String MIME_TYPE_PNG = 'image/png';
	public static final String MIME_TYPE_JPEG = 'image/jpeg';
	public static final String MIME_TYPE_GIF = 'image/gif';
	public static final String MIME_TYPE_BMP = 'image/bmp';
	public static final String MIME_TYPE_SVG = 'image/svg+xml';
	public static final String MIME_TYPE_WEBP = 'image/webp';
	public static final String MIME_TYPE_TIFF = 'image/tiff';
	public static final String MIME_TYPE_OCTET_STREAM = 'application/octet-stream';
	public static final String MIME_TYPE_GOOGLE_FOLDER = 'application/vnd.google-apps.folder';

	// MIME types whose raw bytes read as text without a Google Workspace copy.
	/**
	 * The uploads that read as text without a Workspace copy, so their content can be extracted the moment
	 * they land.
	 */
	public static final Set<String> PLAIN_TEXT_MIME_TYPES = new Set<String>{
		MIME_TYPE_TEXT, MIME_TYPE_CSV, MIME_TYPE_TSV, MIME_TYPE_MARKDOWN
	};

	// File extensions mapped to the MIME type recorded for a Salesforce file that arrives without one.
	/**
	 * The MIME type to record for a Salesforce file, which arrives with an extension and nothing else. What
	 * is recorded here decides whether the file can later be previewed or analyzed.
	 */
	public static final Map<String, String> FILE_EXTENSION_TO_MIME_TYPE = new Map<String, String>{
		'pdf' => MIME_TYPE_PDF,
		'doc' => MIME_TYPE_DOC,
		'docx' => MIME_TYPE_DOCX,
		'odt' => MIME_TYPE_ODT,
		'rtf' => MIME_TYPE_RTF,
		'txt' => MIME_TYPE_TEXT,
		'md' => MIME_TYPE_MARKDOWN,
		'csv' => MIME_TYPE_CSV,
		'tsv' => MIME_TYPE_TSV,
		'xlsx' => MIME_TYPE_XLSX,
		'ods' => MIME_TYPE_ODS,
		'zip' => MIME_TYPE_HTML_ZIP,
		'epub' => MIME_TYPE_EPUB,
		'png' => MIME_TYPE_PNG,
		'jpg' => MIME_TYPE_JPEG,
		'jpeg' => MIME_TYPE_JPEG,
		'gif' => MIME_TYPE_GIF,
		'bmp' => MIME_TYPE_BMP,
		'svg' => MIME_TYPE_SVG,
		'webp' => MIME_TYPE_WEBP,
		'tif' => MIME_TYPE_TIFF,
		'tiff' => MIME_TYPE_TIFF
	};

	// MIME types that can be rendered directly without converted file.
	/**
	 * The files a browser renders itself, which therefore need no Google Workspace copy and no size check.
	 */
	public static final Set<String> DIRECT_PREVIEW_MIME_TYPES = new Set<String>{
		MIME_TYPE_PDF, MIME_TYPE_PNG, MIME_TYPE_JPEG, MIME_TYPE_GIF, MIME_TYPE_BMP, MIME_TYPE_SVG, MIME_TYPE_WEBP, MIME_TYPE_TIFF
	};

	// Source MIME types mapped to the Google Workspace preview file type to generate.
	/**
	 * Which Google Workspace type each upload is converted to for previews, and so also what it can later be
	 * downloaded as.
	 */
	public static final Map<String, String> FILE_EXTENSION_TO_PREVIEW_TYPE = new Map<String, String>{
		MIME_TYPE_PDF => GOOGLE_WORKSPACE_DOCUMENT_TYPE,
		MIME_TYPE_DOC => GOOGLE_WORKSPACE_DOCUMENT_TYPE,
		MIME_TYPE_DOCX => GOOGLE_WORKSPACE_DOCUMENT_TYPE,
		MIME_TYPE_PNG => GOOGLE_WORKSPACE_DOCUMENT_TYPE,
		MIME_TYPE_JPEG => GOOGLE_WORKSPACE_DOCUMENT_TYPE,
		MIME_TYPE_GIF => GOOGLE_WORKSPACE_DOCUMENT_TYPE,
		MIME_TYPE_BMP => GOOGLE_WORKSPACE_DOCUMENT_TYPE,
		MIME_TYPE_SVG => GOOGLE_WORKSPACE_DOCUMENT_TYPE,
		MIME_TYPE_WEBP => GOOGLE_WORKSPACE_DOCUMENT_TYPE,
		MIME_TYPE_TIFF => GOOGLE_WORKSPACE_DOCUMENT_TYPE,
		MIME_TYPE_CSV => GOOGLE_WORKSPACE_SPREADSHEET_TYPE,
		MIME_TYPE_XLSX => GOOGLE_WORKSPACE_SPREADSHEET_TYPE,
		GOOGLE_WORKSPACE_SPREADSHEET_TYPE => GOOGLE_WORKSPACE_SPREADSHEET_TYPE
	};

	// Download As option catalogs keyed by generated Google Workspace preview type.
	/**
	 * What a document or a spreadsheet can be downloaded as, which is exactly what Google Drive will export.
	 */
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

	// Folder structure placeholders used in configurable Google Drive folder layouts.
	/**
	 * The placeholder for a folder per user in the configured folder structure.
	 */
	public static final String STRUCTURE_USER = '{User}';
	/**
	 * The placeholder for a folder per record in the configured folder structure.
	 */
	public static final String STRUCTURE_RECORD = '{Record}';
	public static final String STRUCTURE_USER_RECORD = '{User}-{Record}';
	public static final String STRUCTURE_RECORD_USER = '{Record}-{User}';

	// File Explorer constants used to change its appearance (column display, pagination etc).
	/**
	 * The columns File Explorer knows by name. Anything else configured is treated as a field API name on the
	 * version. This list exists twice, here and in the Lightning module, and the two have to agree.
	 */
	public static final Set<String> FILE_EXPLORER_COLUMNS = new Set<String>{
		'title', 'type', 'size', 'owner', 'fileOwner', 'createdDate', 'lastModified', 'isLinked', 'access', 'summary', 'labels'
	};
	public static final String FILE_EXPLORER_COLUMN_TITLE = 'title';
	public static final Integer FILE_EXPLORER_MAX_COLUMNS = 7;
	public static final Integer FILE_EXPLORER_PAGE_SIZE = 50;
	public static final Integer FILE_EXPLORER_MAX_PAGE_SIZE = 200;
	public static final String FILE_EXPLORER_BUCKET_OWNED = 'owned';
	public static final String FILE_EXPLORER_BUCKET_SHARED = 'shared';
}