/**
 * How a file should be previewed. DIRECT means the browser renders the upload itself, which covers PDFs
 * and images, and CONVERT means the Google Workspace copy is shown instead.
 */
public enum GoogleFilePreviewAction {
    DIRECT,
    CONVERT
}