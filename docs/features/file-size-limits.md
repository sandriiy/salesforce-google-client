# File Size Limits

Google Drive holds the file. Salesforce only ever handles the part of it that one request can carry, and the sizes below are what Google Client works with on its own, without any setting. Where your Salesforce release allows more, Google Client uses more.

<!-- IMAGE: file_size_limits_preview.png — a document preview opening for a file larger than 2 MB on a Winter '27 organization -->

## What each operation handles

| Operation | Up to Summer '26 | From Winter '27 | Larger files |
|---|---|---|---|
| Upload from the Uploader, Attachments or File Explorer | 2 MB in one request | 2.5 MB in one request | Sent in pieces of that size, or straight to Google Drive when Direct Browser Upload is on |
| Download | 2 MB in one request | 3.5 MB in one request | Downloaded in pieces of that size |
| Preview of documents and spreadsheets | 2 MB | 3.5 MB | The preview window offers the download instead |
| Download As | 2 MB | 3.5 MB | The option is hidden |
| Upload File to Google Drive (Flow) | 2 MB in the same run, about 5 MB in the background | 3.5 MB in the same run, about 11 MB in the background | Not transferred; upload them through the Google Client components |
| PDF and image previews | No limit | No limit | |

Document and spreadsheet previews are measured against the preview version Google Client prepares in Google Drive, which is usually far smaller than the uploaded file, so a 20 MB Word document is normally well within the limit. Files uploaded before 2.2.0 are measured by their uploaded size.

## Choosing a size yourself

**Maximum Preview File Size** under **Advanced → File Management** replaces the automatic size for previews, Download As and Flow uploads. Leave it blank to let Google Client choose the largest size your Salesforce release supports. Uploads and downloads from the components always use the automatic size.

Organizations that saved their settings in an earlier version have 2 MB stored in that field. Clear it and save to switch to the automatic size.

📘 See [Advanced: File Management](../config/advanced/file-management.md)

<br>
