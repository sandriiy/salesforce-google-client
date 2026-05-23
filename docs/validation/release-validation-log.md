# Release Validation Log

This document tracks **test coverage, validation scenarios, and release checks** for each release of **Google Client for Salesforce**. The goal is to ensure that all critical features, integrations, and edge cases are tested when creating a new version.

???+ example "Release v2.0.0"

    ### Validation Suite Used
    - [X] Full Validation Suite
    - [ ] Quick Regression Suite
    - [X] Targeted Regression Suite

    ### Release Changes
    - [ ] Change 1:
    - [ ] Change 2:
    - [ ] Change 3:
    - [ ] Change 4:
    - [ ] Change 5:
    - [ ] Change 6:
    - [ ] Change 7:

    ### Boring Changes
    - [X] Version number assigned to all hard-coded labels
    - [ ] Version ID is assigned to all installation guides.

    ### Smoke Checks
    - [ ] Internal user (Core Cloud) can open Lightning record pages containing Google Client components without errors
    - [ ] External user (Experience Cloud) can open Experience Cloud pages containing Google Client components without errors
    - [ ] Admin can open Google Client app and browse configuration tabs without errors

    ### Suite Execution (only for Full or Quick)
    - [ ] Suite execution completed successfully. No critical defects were identified that would block creating a new version.

    ### Notes
    - Check google docs conversion + folder structure (chaining change). Also check delete queueable job, and check all of them in different combination.
	- Check the "latestVersion" for the FileVersion is set correctly, as I did some refactoring.

??? example "Hotfix v1.3.1"

    ### Validation Suite Used
    - [ ] Full Validation Suite
    - [ ] Quick Regression Suite
    - [X] Targeted Regression Suite

    ### Release Changes
    - [X] Fixed 1: Create a new organization where Experience Cloud is fully disabled under Digital Experiences → Settings. Upload a new file and verify that it can be shared without errors.
    - [X] Fixed 2: Create a new user with the Salesforce license and Standard User profile, then assign the Google Cloud Client Admin permission set. Open the Google Client application and verify that the user can access the Analytics tab and view the dashboard inside it.

    ### Boring Changes
    - [X] Version number assigned to all hard-coded labels
    - [X] Version ID is assigned to all installation guides.

    ### Smoke Checks
    - [X] Internal user (Core Cloud) can open Lightning record pages containing Google Client components without errors
    - [X] External user (Experience Cloud) can open Experience Cloud pages containing Google Client components without errors
    - [X] Admin can open Google Client app and browse configuration tabs without errors

    ### Notes
    - When promoting a new package version, if the installation fails, unassign the Google Cloud Client Admin permission set from all users, then try the installation again.

??? example "Release v1.3.0"

    ### Validation Suite Used
    - [ ] Full Validation Suite
    - [X] Quick Regression Suite
    - [X] Targeted Regression Suite

    ### Release Changes
    - [X] Change 1: Verified the new Gemini & Agent Platform configuration (picklist option) in the Google Client app: confirmed both tabs are present and functional: Gemini API for Developers and Gemini Agent Platform (ex-Vertex AI). For each tab, confirmed all required integration fields are present and can be saved and validated successfully. Confirmed the app is visible only to users with the Google Cloud Client Admin permission and is not accessible to users without it.
    - [X] Change 2: Verified that a Collaborator (non-owner) can successfully upload a new version and share a file: confirmed both actions complete without access errors for internal users and Experience Cloud external users.
    - [X] Change 3: Verified large file preview for PDF files: confirmed that the large PDF opens in the preview modal successfully, and that the setting previously labeled "Default Big File Size" is now labeled "Maximum Preview File Size" across all configuration areas. Verified the behavior is consistent across all Google Client components.
    - [X] Change 4: Verified that non-admin users (without System Administrator profile or View All Data permission) can open "Edit File Details" from the file preview without errors: confirmed the action completes successfully for both internal and Experience Cloud external users.
    - [X] Change 5: Verified the actions dropdown in the file preview header on an LWR Experience Cloud site: confirmed menu items are readable and the dropdown does not render with black text on a black background for external users.
    - [X] Change 6: Verified CSV file preview: confirmed that a CSV file opens in the preview modal and displays its content in a readable format. Confirmed that Download and other existing file actions continue to work for CSV files as they do for other supported file types.
    - [X] Change 7: Verified Nebula Logger improvements: confirmed that Command classes produce logs with relevant transaction context (record ID, input parameters, received data) and that all logs include the DEFAULT_LOGGER_TAG. Confirmed the service layer saves the accumulated log when an exception occurs. Verified the new "Google Client: Analytics" Lightning tab is accessible and loads without errors, and that the "Logger Admin Dashboard" in the "Google Client: Analytics" folder displays log data filtered to this client.

    ### Boring Changes
    - [X] Version number assigned to all hard-coded labels
    - [X] Version ID is assigned to all installation guides.

    ### Smoke Checks
    - [X] Internal user (Core Cloud) can open Lightning record pages containing Google Client components without errors
    - [X] External user (Experience Cloud) can open Experience Cloud pages containing Google Client components without errors
    - [X] Admin can open Google Client app and browse configuration tabs without errors

    ### Suite Execution (only for Full or Quick)
    - [X] Suite execution completed successfully. No critical defects were identified that would block creating a new version.

    ### Notes
    - There is a scenario where, if an external user creates a file and an internal user tries to share it with someone else or make other changes, it causes an error ("INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY"). This scenario does not violate the visibility or security layer, so it is not considered a problem at this time.
    - The `GoogleClientConfig__mdt` record (`GoogleClient`) was removed from the package in this release. In previous versions, the package shipped a pre-built record that Salesforce re-deployed on every upgrade as a full overwrite, silently wiping any values configured by the subscriber (certificate name, service account email, API keys, etc.). Removing it from the package prevents this data loss permanently. As a side effect, customers upgrading from a previous version may see a deprecation warning on the record in Setup — this is expected, harmless, and requires no action. See [Known Issues](../help/known-issues.md) for details.

??? example "Release v1.2.0"

    ### Validation Suite Used
    - [X] Full Validation Suite
    - [ ] Quick Regression Suite
    - [ ] Targeted Regression Suite

    ### Release Changes
    - [X] Change 1: Verified the Google Client lightning app is in a healthy working state: user can authorize successfully, admin/developer settings load correctly, and updated metadata values save as expected, including Main Upload Folder ID, Folder Structure selection, and the Organizational Domain value in the Advanced section.
    - [X] Change 2: Verified Folder Structure behavior in Google Client across supported structures (Main Upload Folder only, User, User → Record, Record → User, Record): for each structure, uploading a file creates the expected folder(s) under the Main Upload Folder and places the file in the correct location. Tested using one standard object and one custom object to confirm consistency.
    - [X] Change 3: Verified the Organizational Domain field behavior in the Public Link flow: when an Organizational Domain is configured, the Public Link window displays a new checkbox that controls link scope (unchecked = domain-restricted link, checked = global link). Confirmed the user still has the ability to create a global public link, while the default behavior is domain-restricted.
    - [X] Change 4: Verified the new Share Type option in the Share modal: from the Preview window, clicked Share (at the top), selected the record the file is attached to, and confirmed the Share Type picklist includes a new value "None". When "None" is selected, confirmed record-based access does not grant visibility to the file and only explicitly shared users can see it. Validated by explicitly sharing the file to another user, logging in as that user, and confirming behavior for both internal and external users.
    - [X] Change 5: Verified collaborator limitations messaging in the Share modal: shared a file to another user as Collaborator, then opened the Share modal (via Preview) as that collaborator and confirmed a new informational message appears indicating the user has collaborator access, some sharing actions may be limited, and the user should contact the file owner (visible in the list) if changes cannot be applied.
    - [X] Change 6: Verified File Explorer tab behavior for internal users with Google Client user permissions: confirmed a "File Explorer" tab appears in the top-left navigation and opens in a new tab with two left-sidebar items (Owned by Me, Shared with Me). Confirmed "Owned by Me" lists all files uploaded by the current user and includes a datatable indicator showing whether each file is attached to a record; validated the indicator by removing the record link via the Share modal (without deleting the file) and confirming the UI reflects the correct attached/not-attached state. Confirmed the user can upload a new file directly from File Explorer (no file type/size restrictions enforced by the UI), and that the upload completes successfully without linking the file to any record. Confirmed Preview actions work end-to-end for owned files (Share, Public Link, Rename, Edit, Download, Upload New Version). Confirmed "Shared with Me" lists files shared to the current user; validated by logging in as another user, uploading a file to a record, sharing it to the target user, then logging in as the target user and confirming it appears. Confirmed permission levels are reflected correctly in the UI (Viewer = read-only, Collaborator = edit access), and confirmed Owned files always remain editable for the owner.
    - [X] Change 7: Verified Experience Cloud behavior on record detail pages: configured required custom pages, added the Attachments component to the record detail page, uploaded a file, clicked "View All", and confirmed the opened page/component shows the correct object label (e.g., "Account") and the record name in the top-left header area.

    ### Boring Changes
    - [X] Version number assigned to all hard-coded labels
    - [X] Version ID is assigned to all installation guides.

    ### Smoke Checks
    - [X] Internal user (Core Cloud) can open Lightning record pages containing Google Client components without errors
    - [X] External user (Experience Cloud) can open Experience Cloud pages containing Google Client components without errors
    - [X] Admin can open Google Client app and browse configuration tabs without errors

    ### Suite Execution (only for Full or Quick)
    - [X] Suite execution completed successfully. No critical defects were identified that would block creating a new version. For detailed coverage, see the Validation Suites tab to review exactly what was tested.

    ### Notes
    - The System Administrator has access to functionality even if the "Google Cloud Client User" permission set is not assigned to the user.
    - A new bug related to UI/UX file preview has been created, [see here](https://github.com/sandriiy/salesforce-google-client/issues/23){ target="_blank" rel="noopener noreferrer" }
    - A new bug related to the "Edit File Details" window (from preview) has been created, [see here](https://github.com/sandriiy/salesforce-google-client/issues/24){ target="_blank" rel="noopener noreferrer" }
    - A new bug related to the security layer has been created, [see here](https://github.com/sandriiy/salesforce-google-client/issues/25){ target="_blank" rel="noopener noreferrer" }
