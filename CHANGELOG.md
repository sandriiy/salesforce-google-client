# Changelog

All notable changes to this client will be documented in this file.

## [2.1.0] - 2026-08-05

### Added

- Additional Google Drive upload folders. Up to ten folders can be configured in priority order, and when the folder or shared drive currently in use reaches a hard Google Drive capacity limit, the next folder in the list is used automatically so uploads keep working. Any configured folder structure is created inside whichever folder accepted the file.
- AI Prompt Security Layer for organizations using File Intelligence. Every question is inspected before it reaches the model and every response is inspected before it is shown, with a configurable strictness of Strict, Standard, Relaxed, or Off. Standard is used when nothing is chosen, and a custom Apex implementation can replace the shipped one.
- Configurable File Explorer columns. Administrators choose which columns appear and in what order, and any field of the Google File Version object can be added by API name.
- Search across AI-generated summaries in File Explorer, so a document can be found by what it contains rather than only by its name.
- View All and Edit All custom permissions. Both are shipped inactive and raise, never lower, the access an internal user already has, so a support or compliance user can be given visibility of every file without changing the sharing model.
- All Files view in File Explorer for users holding one of those permissions, with search and sorting across every file.
- Global search support for Google Files. Files now appear in Salesforce search results and open directly on the Google Client file details page.
- Direct Browser Upload, an optional setting that makes large uploads noticeably faster. Turned off by default, so nothing changes for existing organizations until an administrator enables it.
- CSP Trusted Site for `https://www.googleapis.com`, limited to the `connect-src` directive, so the browser can reach the Google Drive upload endpoint.
- Test connection action in Advanced → File Management that verifies the service account, upload folder, and browser connection without leaving a file in Google Drive.
- Retry through Salesforce prompt in the Uploader and in the Attachments and File Explorer upload window when a direct upload cannot complete.

### Changed

- The Google Drive folder for a record is now resolved once per upload — while the files are transferring, so it never delays the upload starting — and reused by every file of that upload instead of being resolved separately for each file.
- File Explorer now loads files as you scroll, for every user. Organizations are no longer limited to the first 10,000 files, and the list opens just as quickly however many files exist.
- File Explorer search now looks through every file you have access to, not only the ones already shown in the list. It matches both the file name and the AI-generated summary.
- Owned by Me and Shared with Me now follow the file's owner, so a file that changes hands moves to the correct view.
- Sorting now orders all of your files rather than only the ones currently on screen. Type, Size, Summary, Access and any custom column can no longer be sorted.
- The Owner column in File Explorer now shows the real record owner, including when a file is owned by a group or a queue, and is displayed as a user rather than an identifier.
- A Refresh action was added to File Explorer.

### Fixed

- Google Client components could appear on Experience Cloud pages for users who were not given access to Google Client, where they loaded but could not be used. The components are now hidden unless the user holds the Google Cloud Client User permission set.
- File Explorer could stop loading more files before the end of the list, and could repeat or skip files while scrolling.
- Your own files were always pulled to the top of the list, ignoring the sort order you chose.
- Searching for text containing `%` or `_` in File Explorer returned unrelated files.
- Salesforce record names shown on the file details page and in Linked Records could appear incomplete for objects whose name is assembled from several fields, such as showing only the last name of a contact. The full displayed name is now resolved the same way Salesforce displays it.
- Duplicated Google Drive folders could be created for the same record when several files, or several users, were uploaded to that record at the same time. A resolved folder is now remembered in the `GoogleCloudClient` Platform Cache partition, so Google Client no longer depends on Google Drive search returning a folder it has just created. Allocating Org Cache to that partition is what guarantees a single folder per record — see Known Issues.
- Records that already have duplicated folders now consistently receive every new file into the same one of those folders, instead of scattering files across them.
- Attaching an existing file to a record that had no Google Drive folder yet created the record folder nested inside the folder the attached file already lived in, instead of under the configured upload folder, so no folder appeared for that record and its shortcut was placed out of reach. The record folder is now always resolved under a configured upload folder.

## [2.0.0] - 2026-06-14

### Added

- Attach Existing File support for reusing owned Google Client files across multiple Salesforce records.
- Linked Records on the File Details page to show where a Google Client file is used.
- Google Drive shortcut placement when an existing file is attached to another record and the configured folder structure includes a record folder.
- Download As support from the preview modal for supported previewable files.
- Large image preview support from supported preview entry points.
- AI-generated document summaries stored on Salesforce file versions and shown where supported.
- File Q&A in the preview modal when File Intelligence is configured and available.
- Admin controls for AI summary prompts, question prompts, and question response token limits.

### Changed

- Security access resolution now supports files linked to multiple Salesforce records.
- Preview experience expanded for PDFs, images, CSV/spreadsheet files, documents, non-previewable files, Download As, and optional AI sidebar behavior.
- Latest active file version handling improved across upload, replacement, attach-existing, and new-version flows.

## [1.3.2] - 2026-06-08

### Fixed

- Uploading multiple files at once to a record without an existing resolved Google Drive folder could create multiple folders for the same record when Google Client was configured to use a dedicated folder per record.
- Files uploaded from the File Explorer tab/component could be placed into a user-specific Google Drive folder even when the folder per user option was not enabled.

## [1.3.1] - 2026-04-27

### Fixed

- Organizations with Experience Cloud fully disabled could not share files because the isPortalEnabled field was not accessible.
- Non-admin users without View All Data, but assigned the Google Cloud Client Admin permission set, could not run reports and therefore could not view the Analytics dashboard.

## [1.3.0] - 2026-04-26

### Added

- Gemini API for Developers and Agent Platform configuration tab in the Google Client app.
- Large file preview support for PDF files in the preview modal.
- CSV file preview support in the preview modal.
- Google Client: Analytics Lightning tab with a Logger Admin Dashboard for Nebula Logger visibility.

### Changed

- Setting previously labeled "Default Big File Size" renamed to "Maximum Preview File Size" across all configuration areas.
- Nebula Logger improvements: Command classes now capture transaction context (record ID, input parameters), all logs include `DEFAULT_LOGGER_TAG`, and the service layer persists logs when an exception occurs. A new tab "Analytics" is added to the "Google Client" application with custom reports & dashboard.

### Fixed

- Collaborator (non-owner) was unable to upload a new file version or share a file without errors.
- Non-admin users (without View All Data) received errors when opening "Edit File Details" from the preview window.
- Actions dropdown on LWR Experience Cloud sites rendered with black text on a dark background, making items unreadable.

## [1.2.0] - 2026-02-26

### Added

- File Explorer Lightning tab with two views: Owned by Me and Shared with Me. Includes Is Linked? and Access columns.
- Folder Structure Automation: uploads can now be automatically organized in Google Drive using User, Record, User → Record, or Record → User folder structures.
- "None" Share Type for record-file links — associates a file with a record for audit/traceability without granting access through that relationship.
- Domain-restricted public links — public links can be limited to users signed in under your organization's domain.
- Simplified admin configuration — Google Client can now be configured through the app UI without deploying a custom Apex configuration class.
- Collaborator limitation notice in the Share modal informing users when certain sharing actions require the file owner.

### Fixed

- Experience Cloud record detail Attachments header now shows the correct object label and record name.
- Various bug fixes and stability improvements across the app.

## [1.1.0] - 2026-01-18

### Added

- Support for the Uploader component inside Screen Flows.

### Fixed

- Uploader component required a page refresh before replace/delete controls became visible.
- Re-selecting the same file in the uploader did not trigger re-upload.
- Share Modal displayed the Salesforce record ID instead of the record name.

### Changed

- Internal client architecture refined for improved performance and security.

## [1.0.0] - 2025-12-30

### Added

- Secure server-to-server authentication with Google Cloud using a Service Account and JKS certificate.
- Core Google Drive file operations: upload, download, preview, versioning.
- Native Salesforce UI experience aligned with standard Notes & Attachments behavior.
- Record-level access security layer with consistent enforcement across Salesforce and Experience Cloud.
- Direct file sharing with internal users, public groups, queues, and Experience Cloud users.
- Public link creation and management.
- Support for Core Salesforce Clouds (Sales Cloud, Service Cloud, etc.) and Experience Cloud.
