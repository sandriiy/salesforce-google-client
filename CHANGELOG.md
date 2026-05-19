# Changelog

All notable changes to this project will be documented in this file.

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
