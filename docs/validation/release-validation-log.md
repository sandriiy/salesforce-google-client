# Release Validation Log

This document tracks **test coverage, validation scenarios, and release checks** for each release of **Google Client for Salesforce**. The goal is to ensure that all critical features, integrations, and edge cases are tested when creating a new version.

## Release v1.2.0

### Validation Suite Used
- [X] Full Validation Suite
- [ ] Quick Regression Suite
- [ ] Changes-Only Suite

### Release Changes
- [ ] Change 1: Verified the Google Client lightning app is in a healthy working state: user can authorize successfully, admin/developer settings load correctly, and updated metadata values save as expected, including Main Upload Folder ID, Folder Structure selection, and the Organizational Domain value in the Advanced section.
- [ ] Change 2: Verified Folder Structure behavior in Google Client across supported structures (Main Upload Folder only, User, User → Record, Record → User, Record): for each structure, uploading a file creates the expected folder(s) under the Main Upload Folder and places the file in the correct location. Tested using one standard object and one custom object to confirm consistency.
- [ ] Change 3: Verified the Organizational Domain field behavior in the Public Link flow: when an Organizational Domain is configured, the Public Link window displays a new checkbox that controls link scope (unchecked = domain-restricted link, checked = global link). Confirmed the user still has the ability to create a global public link, while the default behavior is domain-restricted.
- [ ] Change 4: Verified the new Share Type option in the Share modal: from the Preview window, clicked Share (at the top), selected the record the file is attached to, and confirmed the Share Type picklist includes a new value “None”. When “None” is selected, confirmed record-based access does not grant visibility to the file and only explicitly shared users can see it. Validated by explicitly sharing the file to another user, logging in as that user, and confirming behavior for both internal and external users.
- [ ] Change 5: Verified collaborator limitations messaging in the Share modal: shared a file to another user as Collaborator, then opened the Share modal (via Preview) as that collaborator and confirmed a new informational message appears indicating the user has collaborator access, some sharing actions may be limited, and the user should contact the file owner (visible in the list) if changes cannot be applied.
- [ ] Change 6: Verified File Explorer tab behavior for internal users with Google Client user permissions: confirmed a “File Explorer” tab appears in the top-left navigation and opens in a new tab with two left-sidebar items (Owned by Me, Shared with Me). Confirmed “Owned by Me” lists all files uploaded by the current user and includes a datatable indicator showing whether each file is attached to a record; validated the indicator by removing the record link via the Share modal (without deleting the file) and confirming the UI reflects the correct attached/not-attached state. Confirmed the user can upload a new file directly from File Explorer (no file type/size restrictions enforced by the UI), and that the upload completes successfully without linking the file to any record. Confirmed Preview actions work end-to-end for owned files (Share, Public Link, Rename, Edit, Download, Upload New Version). Confirmed “Shared with Me” lists files shared to the current user; validated by logging in as another user, uploading a file to a record, sharing it to the target user, then logging in as the target user and confirming it appears. Confirmed permission levels are reflected correctly in the UI (Viewer = read-only, Collaborator = edit access), and confirmed Owned files always remain editable for the owner.
- [ ] Change 7: Verified Experience Cloud behavior on record detail pages: configured required custom pages, added the Attachments component to the record detail page, uploaded a file, clicked “View All”, and confirmed the opened page/component shows the correct object label (e.g., “Account”) and the record name in the top-left header area.

### Boring Changes
- [ ] Version number assigned to all hard-coded labels

### Smoke Checks
- [ ] Internal user (Core Cloud) can open Lightning record pages containing Google Client components without errors
- [ ] External user (Experience Cloud) can open Experience Cloud pages containing Google Client components without errors
- [ ] Admin can open Google Client app and browse configuration tabs without errors

### Suite Execution (only for Full or Quick)
- [ ] Suite execution completed successfully. No critical defects were identified that would block creating a new version. For detailed coverage, see the Validation Suites tab to review exactly what was tested.

### Notes
- None

<br>