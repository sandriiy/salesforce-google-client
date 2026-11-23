# Validation Suites

## Starting Point

- [X] Test users are created:
    - [X] Internal user A has `Google Cloud Client User`
    - [X] Internal user B has `Google Cloud Client User`
    - [X] External user E has `Google Cloud Client User`
    - [X] Admin user has `Google Cloud Client Admin` or the combined permission group
    - [X] Admin-level non-system user exists without `View All Data`, but with `Google Cloud Client Admin`
- [X] Core Cloud test records are created:
    - [X] Record A exists
    - [X] Record B exists
    - [X] Record C exists and is used as an unrelated record
    - [X] One record exists whose name is assembled from several fields, such as a Contact
- [X] Experience Cloud is configured
- [X] Experience Cloud pages are configured
- [X] Experience Cloud test record is visible to external user E
- [X] Google Drive integration is configured and validated
- [X] A second Google Drive folder, ideally on a separate Shared Drive, is available but not yet configured
- [X] Org Cache is allocated to the `GoogleCloudClient` Platform Cache partition
- [X] A permission set containing `Google Client: View All Files` exists and is not yet assigned
- [X] A permission set containing `Google Client: Edit All Files` exists and is not yet assigned
- [X] Gemini / Agent Platform / Vertex is not configured yet
- [X] AI Q&A / analysis is disabled
- [X] Folder structure is set to No folder structure / Default folder only
- [X] `Direct Browser Upload` is disabled
- [X] `Open in Google Drive` is disabled
- [X] AI Labeling is disabled and no label definitions exist
- [X] At least two Google Drive labels are published and shared with the service account, and their label IDs are known
- [X] File Explorer columns are left at their default selection
- [X] Required local test files are nearby:
    - [X] PDF file
    - [X] Large PDF file
    - [X] CSV file
    - [X] Image file
    - [X] Large image file
    - [X] Google Docs / DOCX-style document
    - [X] Non-previewable file type
    - [X] File larger than 100 MB
    - [X] Document or spreadsheet file larger than the Maximum Preview File Size setting
- [X] At least one document contains clear business content for summary and Q&A testing
- [X] At least one Google file owned by internal user A exists and is not yet linked to the target Salesforce record
- [X] At least one Google file not owned by internal user A exists
- [X] At least one Google file is shared with a public group or a queue
- [X] Enough files exist for internal user A to fill more than one File Explorer page

## Full Validation Suite

### Phase 1: Admin Baseline

Log in as Admin.

- [X] Open Google Client application
- [X] Confirm Google Drive integration is configured and validates successfully
- [X] Confirm only one upload folder is configured under Folder Locations
- [X] Confirm Gemini / Agent Platform / Vertex is not configured
- [X] Confirm AI summary / Q&A features are not active
- [X] Confirm folder structure is set to No folder structure / Default folder only
- [X] Confirm `Direct Browser Upload` is disabled in Advanced → File Management
- [X] Confirm `Open in Google Drive` is disabled in Advanced → File Management
- [X] Confirm AI Labeling is disabled and no label definitions exist in Advanced → AI Intelligence
- [X] Confirm the `GoogleDriveDirectUpload` CSP Trusted Site exists and is active in Setup
- [X] Confirm Org Cache is allocated to the `GoogleCloudClient` Platform Cache partition
- [X] Confirm File Explorer columns in Advanced → User Interface are at their default selection
- [X] Confirm Maximum Preview File Size in Advanced → File Management is blank and the help text names the automatic size
- [X] Confirm Store files only is off in Advanced → File Management and Folder for Google Workspace Copies (ID) is empty in the Google Drive Folder Locations step
- [X] Confirm neither `Google Client: View All Files` nor `Google Client: Edit All Files` is assigned to any test user
- [X] Open the Migration tab and confirm it renders without errors
- [X] Open configuration tabs and confirm there are no page-level errors
- [X] Confirm admin-only configuration pages are available to the admin user
- [X] Confirm Analytics tab renders for the admin user
- [X] Confirm Logger Admin Dashboard renders for the admin user
- [X] Confirm setup guides show in the side panel and follow the section or Advanced tab that is open
- [X] Confirm a setup guide can be closed and the configuration area stays full width
- [X] Confirm each Advanced tab says what it contains
- [X] Change a setting without saving, switch between Setup and Advanced, and confirm it asks whether to save or discard
- [X] Confirm switching between Google Drive and AI inside Setup with unsaved changes does not ask

### Phase 2: Core Cloud Uploads

Log in as Internal User A.

Use Record A.

Use the Lightning record page that contains both Google Client record components:

- Uploader component
- Attachments component

Run the full file-type upload set from the Uploader component first. Files uploaded from the Uploader component should be validated from the Uploader component. Do not assume they appear in the Attachments component.

- [X] Open the Lightning record page containing Google Client components
- [X] Confirm Uploader component renders without errors
- [X] Confirm Attachments component renders without errors
- [X] Upload a PDF file using the Uploader component
- [X] Upload a large PDF file using the Uploader component
- [X] Upload a CSV file using the Uploader component
- [X] Upload an image file using the Uploader component
- [X] Upload a large image file using the Uploader component
- [X] Upload a document file using the Uploader component
- [X] Upload a non-previewable file using the Uploader component
- [X] Confirm all files uploaded from the Uploader component appear in the Uploader component
- [X] Upload one additional previewable file using the Attachments component upload action
- [X] Confirm the file uploaded from the Attachments component appears in the Attachments component
- [X] Confirm an uploaded file appears in View All
- [X] Confirm uploaded files are stored in the default/root configured Google Drive folder
- [X] Confirm no record-specific or user-specific folder is created

### Phase 3: Uploader Preview and File Actions

Continue as Internal User A.

Use the files uploaded through the Uploader component in Phase 2.

Use the Uploader component as the main entry point for Preview in this phase. Do not use the Attachments component for these Uploader-uploaded files.

- [X] Open Preview for the PDF file from the Uploader component
- [X] Confirm PDF preview works
- [X] Confirm download works
- [X] Confirm Download as... is visible for the PDF file
- [X] Open Preview for the large PDF file from the Uploader component
- [X] Confirm large PDF preview works
- [X] Open Preview for the CSV file from the Uploader component
- [X] Confirm CSV preview works
- [X] Open Preview for the image file from the Uploader component
- [X] Confirm image preview works
- [X] Open Preview for the large image file from the Uploader component
- [X] Confirm large image preview works
- [X] Open Preview for the document file from the Uploader component
- [X] Confirm document preview works
- [X] Open Preview for the document larger than the Maximum Preview File Size setting
- [X] Confirm that document previews rather than reporting that it is too large
- [X] Confirm Download as... is visible for previewable files
- [X] Open Preview for the non-previewable file from the Uploader component
- [X] Confirm non-previewable message is shown
- [X] Confirm Download as... is not visible for the non-previewable file
- [X] Confirm AI summary / Q&A actions are not shown while AI is not configured
- [X] Confirm Open in Google Drive is not offered while the setting is off
- [X] Edit file details for one owned file from Preview opened through the Uploader component
- [X] Upload a new version for one owned file from Preview opened through the Uploader component
- [X] Confirm latest version becomes active
- [X] Confirm older version remains in the org
- [X] Confirm preview and download use the latest active version
- [X] Confirm every uploaded file in the Uploader component has a checkbox, and a file still uploading has none
- [X] Tick two files, one of them larger than 3.5 MB, and confirm "2 of N selected" and Download (2) appear above the list
- [X] Download them and confirm one ZIP archive named after the record arrives with both files intact
- [X] Start a download of a large file, click Stop, and confirm nothing is saved and the selection is kept

Log in as Admin.

- [X] Enable `Open in Google Drive` in Advanced → File Management

Log in as Internal User A.

- [X] Confirm Open in Google Drive is offered in Preview for an owned file
- [X] Open the file in Google Drive and confirm it opens
- [X] Confirm the file opens read only and the folder around it cannot be reached
- [X] Confirm Open in Google Drive is not offered for a file owned by another user

Log in as Admin.

- [X] Enter 1 MB in Maximum Preview File Size under Advanced → File Management and save

Log in as Internal User A.

- [X] Confirm Download as... is no longer offered for a document larger than 1 MB
- [X] Confirm a document whose uploaded size is under 1 MB still previews and offers Download as...

Log in as Admin.

- [X] Clear Maximum Preview File Size, save, and confirm the help text names the automatic size again

### Phase 4: Attachments Preview and File Actions

Continue as Internal User A.

Use only files uploaded through the Attachments component.

Use the Attachments component as the entry point for Preview in this phase. Do not use Uploader-uploaded files for Attachments-specific checks.

- [X] Open Preview for the small PDF file (upload a new if needed) from the Attachments component
- [X] Confirm PDF preview works
- [X] Confirm download works
- [X] Confirm Download as... is visible for the PDF file
- [X] Open Preview for the large PDF file (upload a new if needed) from the Attachments component
- [X] Confirm large PDF preview works
- [X] Edit file details for one owned file from Preview opened through the Attachments component
- [X] Upload a new version for one owned file from Preview opened through the Attachments component
- [X] Confirm older version remains in the org
- [X] Confirm older version remains available where supported
- [X] Confirm preview and download use the latest active version
- [X] Open View All from the Attachments component and confirm every row has a checkbox
- [X] Tick two files, one of them larger than 3.5 MB, and confirm Download (2) appears next to Upload Files
- [X] Download them and confirm one ZIP archive named after the record arrives with both files intact
- [X] Search by part of a name, tick the checkbox in the column header, and confirm only the files shown are selected
- [X] Start a download of several large files, click Stop, and confirm nothing is saved and the selection is kept
- [X] Confirm Clear selection unticks every file

### Phase 5: File Explorer

Continue as Internal User A.

Use the File Explorer Lightning tab only for this phase. Do not use the record page Uploader or Attachments components for File Explorer-specific checks.

- [X] Open File Explorer
- [X] Confirm Owned files tab renders correctly
- [X] Confirm Shared files tab renders correctly
- [X] Confirm files uploaded from the Uploader component appear under Owned files where expected
- [X] Confirm files uploaded from the Attachments component appear under Owned files where expected
- [X] Open Preview from File Explorer
- [X] Upload a file from the File Explorer upload action
- [X] Confirm the file uploaded from File Explorer appears in File Explorer
- [X] Confirm the file uploaded from File Explorer is placed in the expected default/root Google Drive folder

Use an account with more files than fit on a single page for the list behaviour checks.

- [X] Confirm the first page of files renders without scrolling the whole list
- [X] Scroll to the bottom and confirm more rows are appended
- [X] Scroll to the end of the list and confirm no row is repeated and none is missing
- [X] Confirm the Owner column shows the file owner, including for a file owned by a public group or a queue
- [X] Open Search, type a word from a file's name, narrow it with the File type filter, and confirm only matching files you can open are listed
- [X] In Owned by Me, tick two files and confirm they download together as one ZIP archive
- [X] Confirm the owner is shown as a name rather than an identifier
- [X] Search by part of a file name and confirm matches are returned from the whole list, not only from the rows already loaded
- [X] Clear the search and confirm the full list returns
- [X] Sort by Title and confirm the order is correct across page boundaries
- [X] Sort by Last Modified Date and confirm the order is correct across page boundaries
- [X] Confirm Type, Size, Summary, and Access columns cannot be sorted
- [X] Select Refresh and confirm the list reloads
- [X] Switch between Owned and Shared and confirm search and sorting apply to the selected view

Log in as Admin.

- [X] Open Advanced → User Interface
- [X] Add and reorder columns, then save
- [X] Confirm a maximum of 7 columns can be selected
- [X] Confirm Title cannot be removed
- [X] Add a valid Google File Version field API name as a custom column and save
- [X] Add an invalid field API name as a custom column and save

Log in as Internal User A.

- [X] Confirm File Explorer shows the configured columns in the configured order
- [X] Confirm the valid custom column shows its values
- [X] Confirm the invalid custom column renders empty and the list still loads

Log in as Admin.

- [X] Restore the default column selection

### Phase 6: Internal Sharing

Continue as Internal User A.

Use one owned file that was uploaded through the Attachments component on Record A.

Use the Attachments component on Record A to open Preview and Share.

- [X] Open Preview from the Attachments component
- [X] Open Share modal from Preview
- [X] Share the file with Internal User B as Viewer
- [X] Confirm sharing completes successfully

Log in as Internal User B.

Use the Attachments component on Record A to verify access.

- [X] Open Record A
- [X] Confirm the shared file is visible in the Attachments component
- [X] Open Preview for the shared file from the Attachments component
- [X] Confirm View access behavior
- [X] Confirm download is available
- [X] Confirm edit details is not available
- [X] Confirm upload new version is not available
- [X] Confirm delete is not available
- [X] Confirm Share modal is not available
- [X] Confirm Public Link modal is not available
- [X] Open File Explorer and confirm the shared file appears under Shared files

Log in as Internal User A.

Use the Attachments component on Record A.

- [X] Open Share modal again from Preview
- [X] Change Internal User B access to Collaborator or equivalent edit-level access
- [X] Confirm sharing update completes successfully

Log in as Internal User B.

Use the Attachments component on Record A.

- [X] Open Preview for the shared file from the Attachments component
- [X] Confirm Edit behavior is applied
- [X] Confirm collaborator can upload a new version
- [X] Confirm collaborator can edit details

### Phase 7: Public Link

Log in as Internal User A.

Use one owned file that was uploaded through the Attachments component.

Use the Attachments component on Record A to open Preview and Public Link.

- [X] Open Preview from the Attachments component
- [X] Open Public Link modal from Preview
- [X] Create a public link
- [X] Open the link in a separate browser/session without Salesforce login
- [X] Confirm the public link opens successfully
- [X] Revoke the public link
- [X] Create a public link & set an expiration date
- [X] Confirm the link no longer works after the expiration date

### Phase 8: Attach Existing Files

Log in as Internal User A.

Use these records:

- Record A: original linked record
- Record B: additional linked record
- Record C: unrelated record

Use the Attachments component for Attach Existing Files. Do not use the Uploader component for this phase.

- [X] Open Record B
- [X] Open Attach Existing Files from the Attachments component
- [X] Confirm files owned by Internal User A are available for selection
- [X] Confirm files owned by other users are not available for selection
- [X] Attach an existing owned file from Record A to Record B using the Attach Existing Files flow
- [X] Confirm the file appears on Record B in the Attachments component
- [X] Open Record A
- [X] Confirm the same file still appears on Record A in the Attachments component
- [X] Open File Record Details page
- [X] Confirm linked records show Record A and Record B
- [X] Open Record C
- [X] Confirm the file does not appear on Record C in the Attachments component

### Phase 9: Multi-Record Security

Use the file linked to Record A and Record B.

Use the Attachments component on each record to validate record-based visibility.

Log in as a user who has access to Record A only.

- [X] Confirm the file is visible on Record A in the Attachments component
- [X] Confirm the file is not visible from unrelated Record C in the Attachments component
- [X] Open Preview from the Attachments component on Record A
- [X] Confirm resolved access level matches Record A access

Log in as a user who has access to Record B only.

- [X] Confirm the file is visible on Record B in the Attachments component
- [X] Confirm the file is not visible from unrelated Record C in the Attachments component
- [X] Open Preview from the Attachments component on Record B
- [X] Confirm resolved access level matches Record B access

Log in as a user who has access to Record C only.

- [X] Confirm the file is not visible on Record C in the Attachments component
- [X] Confirm the file is not returned in search results
- [X] Confirm direct Preview URL does not open the file
- [X] Confirm direct File Details URL does not open the file
- [X] Confirm file actions cannot be executed from any entry point

Log in as Admin or record owner.

- [X] Remove the association between the file and Record A
- [X] Confirm users with access only to Record A no longer have record-based access
- [X] Confirm users with access to Record B still have access

### Phase 10: File Details Page and Global Search

Log in as Internal User A.

Use the File Details page directly for this phase.

- [X] Open File Details page for an owned file
- [X] Confirm file details display correctly
- [X] Confirm linked records component renders correctly
- [X] Confirm linked records are shown only when the current user has access to those records
- [X] Confirm the Salesforce record name is shown in full, including for the record whose name is assembled from several fields
- [X] Confirm file actions respect the current user's resolved access level
- [X] Open File Details page for a file the current user should not access
- [X] Confirm access is denied or safe fallback behavior is shown

Use Salesforce global search for this part.

- [X] Search for an owned file by name in global search
- [X] Confirm the file is returned in the results
- [X] Open the file from the search result
- [X] Confirm the Google Client file details page opens rather than a standard record layout
- [X] Confirm standard record buttons and the highlights panel are not shown
- [X] Confirm the same page opens when the file URL is entered directly
- [X] Confirm preview, sharing, versions, and linked records all work from this page
- [X] Confirm Open in Google Drive is offered for an owned file and opens the file

### Phase 11: Privileged Access

Log in as Admin.

- [X] Assign the permission set containing `Google Client: View All Files` to Internal User B

Log in as Internal User B.

- [X] Open File Explorer
- [X] Confirm the All Files and Search views are shown instead of the Owned and Shared views
- [X] Confirm files owned by other users appear in the list
- [X] Confirm the Access column shows View for files that would otherwise be inaccessible
- [X] Confirm search and sorting work across the whole list
- [X] Open Preview for a file owned by another user
- [X] Confirm read-only actions are available and edit-level actions are not

Log in as Admin.

- [X] Replace the assignment with the permission set containing `Google Client: Edit All Files`

Log in as Internal User B.

- [X] Confirm the Access column now shows Edit
- [X] Confirm edit-level actions are available on a file owned by another user

Log in as External User E.

- [X] Confirm no additional files became visible on Experience Cloud pages

Log in as Admin.

- [X] Remove both permission set assignments from Internal User B

Log in as Internal User B.

- [X] Confirm File Explorer returns to the Owned and Shared views
- [X] Confirm files owned by other users are no longer visible

### Phase 12: Experience Cloud

Log in as External User E.

Use the Experience Cloud test record.

Use the Experience Cloud Uploader component for upload checks and the Experience Cloud Attachments component for file list, View All, and Preview checks.

- [X] Open Experience Cloud page containing Uploader component
- [X] Confirm Uploader renders without errors
- [X] Tick two visible files in the Experience Cloud Uploader and confirm they download together as one ZIP archive
- [X] Open Experience Cloud page containing Attachments component
- [X] Confirm Attachments renders without errors
- [X] Confirm files are not visible in the Experience Cloud Attachments component by default unless external visibility is enabled
- [X] Confirm View All navigation works from the Experience Cloud Attachments component
- [X] Tick two visible files on the View All page and confirm they download together as one ZIP archive
- [X] Confirm Preview opens from the Experience Cloud Attachments component for files the external user can access
- [X] Confirm Preview actions respect external user access level
- [X] Confirm internal-only actions are not available
- [X] Confirm Open in Google Drive is not offered anywhere on Experience Cloud
- [X] Confirm AI summary/sidebar behavior does not break Experience Cloud preview while AI is not configured

Log in as Internal User A.

Use the internal Core Cloud Attachments component on the Experience Cloud test record.

- [X] Open Share modal for a file linked to the Experience Cloud record from Preview
- [X] Enable external visibility for the related record
- [X] Save sharing changes

Log in as External User E.

Use the Experience Cloud Attachments component.

- [X] Refresh the Experience Cloud record page
- [X] Confirm the externally visible file appears in the Experience Cloud Attachments component
- [X] Open Preview from the Experience Cloud Attachments component
- [X] Confirm Viewer behavior where expected
- [X] Confirm unrelated linked records are not exposed

### Phase 13: Folder Structure

For each folder structure configuration, log in as Admin first, change the folder structure, then log in as Internal User A and validate upload/attach behavior.

Use these component rules for this phase:

- Record-page Uploader component validates upload behavior from Uploader and Uploader-only file visibility
- Record-page Attachments component validates upload behavior from Attachments, Attachments-only file visibility, and Attach Existing Files
- File Explorer validates File Explorer upload behavior separately

#### No Folder Structure / Default Folder Only

Log in as Admin.

- [X] Configure No folder structure / Default folder only

Log in as Internal User A.

- [X] Upload a file from the Uploader component
- [X] Confirm the file appears in the Uploader component
- [X] Upload a file from the Attachments component
- [X] Confirm the file appears in the Attachments component
- [X] Upload a file from File Explorer
- [X] Confirm the file appears in File Explorer
- [X] Confirm files uploaded from Uploader, Attachments, and File Explorer are placed in the default/root configured folder
- [X] Attach an existing file to another record using Attach Existing Files from the Attachments component
- [X] Confirm no record-specific or user-specific folder is created

#### Folder per Record

Log in as Admin.

- [X] Configure Folder per Record

Log in as Internal User A.

- [X] Upload multiple files at once to a record that has no Google files yet, using the Uploader component
- [X] Confirm the files appear in the Uploader component
- [X] Confirm exactly one folder was created for that record
- [X] Confirm every file of that upload is placed in the same folder
- [X] Upload another file to the same record using the Attachments component
- [X] Confirm the file appears in the Attachments component
- [X] Confirm the existing record folder is reused
- [X] Upload a file to a different record using the Uploader component
- [X] Confirm a different record folder is used

Log in as Internal User B while Internal User A uploads to the same new record at the same time.

- [X] Confirm both users' files land in the same record folder
- [X] Confirm no duplicate folder is created for that record

Continue as Internal User A.

- [X] Attach an existing file to a record that has no Google Drive folder yet, using Attach Existing Files
- [X] Confirm the record folder is created under the configured upload folder
- [X] Confirm the record folder is not created inside the folder of the attached file
- [X] Confirm the expected Drive representation is created in the target record folder

#### Folder per User

Log in as Admin.

- [X] Configure Folder per User

Log in as Internal User A.

- [X] Upload multiple files at once to a record using the Attachments component
- [X] Confirm the files appear in the Attachments component
- [X] Confirm files are placed under Internal User A folder
- [X] Upload a file from the Uploader component
- [X] Confirm the file appears in the Uploader component
- [X] Confirm the file is placed under Internal User A folder
- [X] Upload a file from File Explorer
- [X] Confirm the file appears in File Explorer
- [X] Confirm File Explorer upload uses the expected user folder
- [X] Attach an existing file to another record using Attach Existing Files from the Attachments component
- [X] Confirm user-based folder structure is respected

Log in as Internal User B.

- [X] Upload a file from the Uploader component
- [X] Confirm the file appears in the Uploader component
- [X] Confirm file is placed under Internal User B folder
- [X] Upload a file from the Attachments component
- [X] Confirm the file appears in the Attachments component
- [X] Confirm Attachments upload is placed under Internal User B folder
- [X] Confirm Internal User A and Internal User B use different user folders

#### Folder per Record → User

Log in as Admin.

- [X] Configure Folder per Record → User

Log in as Internal User A.

- [X] Upload a file to a record using the Uploader component
- [X] Confirm the file appears in the Uploader component
- [X] Confirm file is placed under Record → User path
- [X] Upload a file to the same record using the Attachments component
- [X] Confirm the file appears in the Attachments component
- [X] Confirm Attachments upload is placed under the same Record → User path
- [X] Attach an existing file to another record using Attach Existing Files from the Attachments component
- [X] Confirm expected Drive representation is created under the target Record → User path

Log in as Internal User B.

- [X] Upload a file to the same record using the Uploader component
- [X] Confirm the file appears in the Uploader component
- [X] Confirm Internal User B uses a separate user folder under the same record folder

#### Folder per User → Record

Log in as Admin.

- [X] Configure Folder per User → Record

Log in as Internal User A.

- [X] Upload a file to Record A using the Uploader component
- [X] Confirm the file appears in the Uploader component
- [X] Confirm file is placed under User → Record A path
- [X] Upload a file to Record A using the Attachments component
- [X] Confirm the file appears in the Attachments component
- [X] Confirm Attachments upload is placed under User → Record A path
- [X] Upload a file to Record B using the Uploader component
- [X] Confirm the file appears in the Uploader component
- [X] Confirm file is placed under User → Record B path
- [X] Attach an existing file to another record using Attach Existing Files from the Attachments component
- [X] Confirm expected Drive representation is created under the target User → Record path

#### Folder Names

Log in as Admin.

- [X] Configure Folder per Record → User, open the Folder structure step, and confirm the Folder Names toggle is off and no formula is listed
- [X] Add a formula for Opportunity such as `Name & "_" & TEXT(CloseDate)` and confirm the row shows an example name from one of your records
- [X] Add a formula for User such as `FirstName & " " & LastName` and save
- [X] Add a formula with a field that does not exist and confirm Salesforce's explanation shows and the settings cannot be saved
- [X] Add a formula using `TODAY()` and confirm Save is refused, with an error under the box that starts "I acknowledge that", until that box is ticked, then remove it

Log in as Internal User A.

- [X] Upload a file to a new Opportunity and confirm its folder is created with the formula's name
- [X] Rename an Account that already has a folder, upload a file to it, and confirm the folder keeps its old name while Folder Names is off

Log in as Admin.

- [X] Switch on Folder Names and save

Log in as Internal User A.

- [X] Upload a file to the renamed Account and confirm its folder in Google Drive takes the new name, with its files still inside
- [X] Confirm your user folder for that record is named by the User formula, and that another user's folder for the same record is left as it is
- [X] Rename the record folder by hand in Google Drive, upload a file to the record, and confirm the folder is renamed back

Log in as Admin.

- [X] Remove the formulas, switch Folder Names off and save

### Phase 14: Multiple Upload Folders

Log in as Admin.

- [X] Add a second folder under Folder Locations and save
- [X] Confirm both folders are listed in the configured order
- [X] Confirm up to ten folders can be added

Log in as Internal User A.

- [X] Upload a file from the Uploader component
- [X] Confirm the file is placed in the first configured folder
- [X] Confirm the configured folder structure is created inside that folder

Log in as Admin.

- [X] Move the second folder to the first position and save

Log in as Internal User A.

- [X] Upload a file from the Uploader component
- [X] Confirm the file is placed in the newly promoted first folder
- [X] Confirm files uploaded earlier remain in their original folder and are still reachable from Salesforce

Log in as Admin.

- [X] Remove the second folder and return to a single configured folder

### Phase 15: Direct Browser Upload

Log in as Admin.

- [X] Enable `Direct Browser Upload` in Advanced → File Management and save
- [X] Run `Test connection` and confirm it succeeds
- [X] Confirm no test file was left behind in Google Drive
- [X] Deactivate the `GoogleDriveDirectUpload` CSP Trusted Site, reload the page, run `Test connection`, and confirm it reports that the browser could not reach Google
- [X] Reactivate the CSP Trusted Site

Log in as Internal User A.

- [X] Upload a 5 MB file from the Uploader and confirm the progress advances and the record is created
- [X] Upload a file larger than 100 MB and confirm it completes and lands in the configured folder
- [X] Upload a file smaller than 2 MB and confirm it is unaffected
- [X] Upload a file smaller than 16 MB, so the whole file is a single chunk, and confirm it completes without any error shown
- [X] Upload a new version of an existing file and confirm versioning is correct
- [X] Confirm folder structure and preview behave the same as for a standard upload
- [X] Upload several files at once from Attachments and confirm every file completes
- [X] Deactivate the CSP Trusted Site, reload, upload a large file from the Uploader, and confirm the file card offers a retry through Salesforce
- [X] Accept the retry and confirm the file uploads and the record is created
- [X] Upload another large file in the same browser session and confirm it goes straight through Salesforce without prompting again
- [X] Repeat the deactivated-CSP case from Attachments and confirm the retry prompt appears at the bottom of the upload window
- [X] Dismiss the retry prompt instead of accepting it, and confirm the upload window can still be closed with Done
- [X] Reactivate the CSP Trusted Site
- [X] Disable the network mid-upload, restore it, and confirm the upload resumes without user action

Log in as External User E.

- [X] Upload a large file from an Experience Cloud page and confirm it completes
- [X] Confirm the uploaded file respects Visibility and is not exposed beyond the expected users

Log in as Admin.

- [X] Turn `Direct Browser Upload` back off and confirm large uploads still work from all three components
- [X] Confirm logs tagged `Google Client for Salesforce` show the expected direct upload outcomes and no unexpected errors

### Phase 16: Delete and Cleanup

Log in as Internal User A.

Use a file linked to multiple records.

- [X] Confirm file appears on all linked records in the Attachments/Uploader component
- [X] Delete the file from Preview or supported file action
- [X] Confirm the file is removed from all linked records & Google Drive

### Phase 17: Gemini Configuration

Log in as Admin.

- [X] Confirm AI Analytics cannot be switched on while no provider is saved
- [X] Confirm AI Labeling cannot be switched on while AI Analytics is off
- [X] Configure Gemini API for Developers
- [X] Validate Gemini configuration
- [X] Enter a wrong API key, try to switch AI Analytics on, and confirm it refuses and explains what to do
- [X] Restore the correct API key
- [X] Enable Q&A / analysis
- [X] Configure summary prompt
- [X] Save a summary prompt longer than 255 characters, reopen the page, and confirm the whole prompt is still there
- [X] Configure question-answering prompt
- [X] Configure token limits
- [X] Confirm Summary Max Output Tokens is empty with 80 as its hint before anything is entered
- [X] Set Summary Max Output Tokens, save and reload, and confirm the value is kept
- [X] Enter 0 in both token settings, save and reload, confirm both still show 0, then set them back and save
- [X] Define two Google Drive labels in Advanced → AI Intelligence with a name, a label ID and a plain language description
- [X] Save a label description longer than 255 characters, reopen the page, and confirm it is still there in full
- [X] Set a minimum confidence and leave the thinking budget empty
- [X] Enable AI Labeling

Log in as Internal User A.

- [X] Upload a new business-content file using the Uploader component after `Enable AI File Intelligence` is enabled
- [X] Confirm the new file appears in the Uploader component
- [X] Confirm summary appears on hover in the Uploader component
- [X] Open Preview for the new file from the Uploader component
- [X] Confirm summary is generated and appears in Preview sidebar
- [X] Ask a question about the file
- [X] Confirm answer is related to the currently opened file
- [X] Confirm question answering respects configured prompt and token limits
- [X] Upload a new business-content file using the Attachments component after `Enable AI File Intelligence` is enabled
- [X] Confirm the new file appears in the Attachments component
- [X] Confirm summary appears on hover in the Attachments component
- [X] Open Preview for the new file from the Attachments component
- [X] Confirm summary is generated and appears in Preview sidebar
- [X] Ask a question about the file
- [X] Add the Summary column in File Explorer and confirm the generated summary is shown
- [X] Search File Explorer for a word that appears in the summary but not in the file name, and confirm the file is found
- [X] Confirm the summary follows the long summary prompt saved for this phase

Use the two labels defined for this phase.

- [X] Upload a file that clearly matches one of the defined labels
- [X] Confirm the label is applied and shows next to the file name in Preview
- [X] Confirm the label is listed in the File Intelligence panel
- [X] Confirm the same label is applied to the file in Google Drive
- [X] Confirm a Google File Version Label record exists for that version with its name and confidence
- [X] Upload a file that matches none of the defined labels and confirm it stays unlabeled

Log in as Admin.

- [X] Add the Labels column in Advanced → User Interface and save
- [X] Raise the minimum confidence above what the model returned

Log in as Internal User A.

- [X] Confirm the Labels column shows the applied label in File Explorer
- [X] Search File Explorer by the label name and confirm the labeled file is found
- [X] Confirm the Labels column cannot be sorted
- [X] Open the File Details page for the labeled file and confirm the Labels card lists the label, the version it belongs to and the confidence
- [X] Open the File Details page for an unlabeled file and confirm the Labels card shows nothing rather than failing
- [X] Upload the same kind of file again and confirm no label is applied at the higher confidence

Log in as Admin.

- [X] Set the minimum confidence back and set a thinking budget

Log in as Internal User A.

- [X] Upload a matching file again and confirm labeling still completes
- [X] Make the labeled file externally visible for the Experience Cloud test record

Log in as External User E.

- [X] Confirm the labeled file shows its label in the Experience Cloud preview
- [X] Confirm labels of files the external user cannot access are not visible

Log in as Admin.

- [X] Disable the `Enable AI File Intelligence` setting
- [X] Confirm AI Labeling is switched off together with AI Analytics
- [X] Confirm the reminder that AI analysis is off shows as a notice in the corner of the page and can be dismissed

Log in as Internal User A.

Use Preview opened from the same component where the files were uploaded.

- [X] Open Preview for the file
- [X] Confirm AI File Intelligence actions are not available after the setting is disabled
- [X] Confirm a file that already has a summary or a label keeps its preview sidebar, and that it stays closed until opened
- [X] Confirm asking a question is unavailable and the panel explains that questions are turned off
- [X] Confirm a file with no summary and no label shows no sidebar at all
- [X] Upload another new file after `Enable AI File Intelligence` is disabled
- [X] Confirm no new summary is generated for files uploaded while `Enable AI File Intelligence` is disabled
- [X] Confirm no label is applied to files uploaded while `Enable AI File Intelligence` is disabled

### Phase 18: Agent Platform / Vertex Configuration

Log in as Admin.

- [X] Disable or clear Gemini configuration where needed
- [X] Configure Agent Platform / Vertex
- [X] Validate Agent Platform / Vertex configuration
- [X] Configure summary prompt
- [X] Configure question-answering prompt
- [X] Configure token limits
- [X] Enable the `Enable AI File Intelligence` setting

Log in as Internal User A.

- [X] Upload a new business-content file using the Uploader component after `Enable AI File Intelligence` is enabled
- [X] Confirm the new file appears in the Uploader component
- [X] Confirm summary appears on hover in the Uploader component
- [X] Open Preview for the new file from the Uploader component
- [X] Confirm summary is generated and appears in Preview sidebar
- [X] Ask a question about the file
- [X] Confirm answer is related to the currently opened file
- [X] Confirm question answering respects configured prompt and token limits
- [X] Upload a new business-content file using the Attachments component after `Enable AI File Intelligence` is enabled
- [X] Confirm the new file appears in the Attachments component
- [X] Confirm summary appears on hover in the Attachments component
- [X] Open Preview for the new file from the Attachments component
- [X] Confirm summary is generated and appears in Preview sidebar
- [X] Ask a question about the file
- [X] Upload a file that clearly matches one of the defined labels and confirm the label is applied
- [X] Confirm the same label is applied to the file in Google Drive

Log in as Admin.

- [X] Disable the `Enable AI File Intelligence` setting

Log in as Internal User A.

Use Preview opened from the same component where the file was uploaded.

- [X] Confirm AI File Intelligence actions are not available while Agent Platform / Vertex remains configured but `Enable AI File Intelligence` is disabled
- [X] Upload another new file after `Enable AI File Intelligence` is disabled
- [X] Confirm no new summary is generated for files uploaded while `Enable AI File Intelligence` is disabled

### Phase 19: AI Prompt Security

Log in as Admin.

- [X] Re-enable `Enable AI File Intelligence`
- [X] Confirm Advanced → Safety & Customization shows Standard as the active mode when nothing was chosen
- [X] Confirm the safety settings are disabled while File Intelligence is off and enabled once it is on

Log in as Internal User A.

Use Preview with the AI sidebar open.

- [X] Ask a normal question about the document and confirm it is answered
- [X] Ask the model to ignore its instructions and confirm the request is refused with a readable message
- [X] Ask the model to reveal its configuration or system prompt and confirm the request is refused
- [X] Ask an unrelated general-knowledge question and confirm it is refused
- [X] Confirm a refusal does not break the preview or the sidebar

Log in as Admin.

- [X] Set the mode to Strict

Log in as Internal User A.

- [X] Confirm normal questions are still answered
- [X] Confirm a very long question is refused with a message about length

Log in as Admin.

- [X] Set the mode to Off

Log in as Internal User A.

- [X] Confirm questions are answered without inspection

Log in as Admin.

- [X] Set the mode back to Standard
- [X] Enter a class name that does not exist in `Custom AI Prompt Safety Guard Class` and save

Log in as Internal User A.

- [X] Confirm questions are still answered and the shipped protection is still applied

Log in as Admin.

- [X] Clear the `Custom AI Prompt Safety Guard Class` field

### Phase 20: Admin and Permission Checks

Log in as Admin-level non-system user without View All Data, but with Google Client Admin permission.

- [X] Open Google Client admin functionality available to Google Client admins
- [X] Open Analytics tab
- [X] Confirm Logger Admin Dashboard renders where expected
- [X] Confirm admin user cannot perform day-to-day file operations from Uploader, Attachments, File Explorer, or Preview unless user permissions are also assigned

Log in as regular operational user without admin permissions.

- [X] Confirm admin configuration pages are not accessible
- [X] Confirm Analytics dashboard is not accessible
- [X] Confirm operational file features still work from Uploader, Attachments, File Explorer, and Preview where user has record/file access

### Phase 21: Flow Actions

Log in as Admin.

Build one screen flow on a record page that calls the four actions in turn, each with a fault path.

- [X] Confirm the Google Client category in Flow Builder lists Create Folder in Google Drive, Upload File to Google Drive, Download File from Google Drive and Extract File Content as Text from Google Drive
- [X] Confirm Edit Google File Details and Public Link Expiration sit in the same category
- [X] Run Create Folder in Google Drive with a folder name and confirm the folder is created in Google Drive
- [X] Run it again with the same name and confirm the same folder is returned instead of a second one
- [X] Run it with the folder name left blank and a record Id, and confirm the folder that record already owns is returned
- [X] Run Upload File to Google Drive with a Salesforce file and a record Id, and confirm the file appears on the record like any other upload
- [X] Confirm the uploaded file is placed according to the configured folder structure
- [X] Run it with Remove Salesforce Copy on and confirm the Salesforce file is deleted and the Google file remains
- [X] Run it with a file above the Maximum Preview File Size setting, confirm it reports that the upload finishes in the background, then confirm the file appears on the record shortly afterwards
- [X] Run Download File from Google Drive and confirm the file is saved in Salesforce and attached to the record
- [X] Run it with Convert To set to pdf and confirm a PDF is saved
- [X] Run Extract File Content as Text and confirm the file text is returned
- [X] Set Maximum Characters and confirm the text is cut at that length and reported as cut short
- [X] Run it against a file whose preview copy is still preparing and confirm it reports that text is not available yet
- [X] Point one action at a file that does not exist and confirm the fault path shows a readable message
- [X] Confirm logs tagged `Google Client for Salesforce` show the expected outcomes and no unexpected errors

### Phase 22: Salesforce Files Migration

Log in as Admin-level non-system user without Query All Files, but with Google Client Admin permission.

- [X] Open the Migration tab and confirm it explains that Query All Files is needed and offers nothing else

Log in as Admin.

Attach a few Salesforce Files to Record A and Record B first: one attached to both records, one larger than 5 MB, and one attached to no record at all.

- [X] Open the Migration tab and confirm Readiness shows the Google Drive connection and where files land
- [X] Choose Files Matching Conditions, enter a condition that selects the test files, click Check, and confirm the count and the sample match
- [X] Enter a condition Salesforce cannot run and confirm it is refused with a readable message
- [X] Narrow the run to the object of Record A and start the migration
- [X] Confirm the Progress card updates by itself and is still there after leaving and returning to the page
- [X] Confirm the run ends as Finished and that the file larger than 5 MB and the unattached file were not copied
- [X] Confirm the migrated files show under Notes & Attachments on Record A, keep their owner, and the file attached to both records is linked to both
- [X] Confirm the Migrated files card lists the copied files and opens the preview
- [X] With AI Analytics on, confirm migrated files get a summary unless Skip AI analysis was chosen
- [X] Start the same selection again, confirm the files already copied are skipped, and click Stop to confirm the run ends as Stopped

### Phase 23: Google Workspace Copies

Log in as Admin.

- [X] In the Google Drive Folder Locations step, enter a folder shared with the service account as Content manager in Folder for Google Workspace Copies (ID) and confirm its name is shown
- [X] Enter a folder shared as Viewer, then a file, then an ID that does not exist, and confirm each is refused with a plain reason
- [X] Save with the Content manager folder

Log in as Internal User A.

- [X] Upload a Word document to Record A and confirm its Google Workspace copy lands in the copies folder while the record folder holds only the original
- [X] Confirm preview, Download as... and AI questions work for that file

Log in as Admin.

- [X] Turn on Store files only and save

Log in as Internal User A.

- [X] Upload a PDF, an image, a Word document and a spreadsheet, and confirm no Google Workspace copy is made for any of them
- [X] Confirm the PDF and the image preview, while the Word document and the spreadsheet show Preview unavailable with Download
- [X] Confirm Download as... and AI questions are not offered for any document, including one uploaded before Store files only was turned on
- [X] Run Extract File Content as Text on a text file and on a Word document, and confirm the text file is read and the Word document ends on the fault path with a plain reason

Log in as External User E.

- [X] Confirm a visible PDF still previews on an Experience Cloud page

Log in as Admin.

- [X] Turn off Store files only, clear the copies folder and save

Log in as Internal User A.

- [X] Open the Word document uploaded while Store files only was on and confirm it says the preview is unavailable, not that it is being prepared, and offers no Download as...

### Phase 24: Final Sweep

Use the final intended release configuration.

- [X] Internal user can open Core Cloud record pages without errors
- [X] External user can open Experience Cloud pages without errors
- [X] Admin can open Google Client app without errors
- [X] Upload works from the Uploader component
- [X] Uploaded files appear in the Uploader component where expected
- [X] Upload works from the Attachments component
- [X] Attached files appear in the Attachments component where expected
- [X] Upload works from File Explorer
- [X] Files uploaded from File Explorer appear in File Explorer where expected
- [X] Preview works from the Uploader component
- [X] Preview works from the Attachments component
- [X] Preview works from File Explorer
- [X] Download works
- [X] Download as... works for previewable files
- [X] Two files ticked on the View All page download together as one ZIP archive
- [X] Two files ticked in the Uploader component download together as one ZIP archive
- [X] Search in File Explorer finds a file by a word in its name, and two files ticked there download together as one ZIP archive
- [X] Sharing works from Preview
- [X] Public links work from Preview
- [X] Versioning works from Preview
- [X] Attach Existing Files works from the Attachments component
- [X] Multi-record access works
- [X] Folder structure works for Uploader, Attachments, and File Explorer uploads
- [X] One folder per record is created when Folder per Record is configured
- [X] A new record folder takes the name its object's formula gives, and with Folder Names on a renamed record's folder follows the new name
- [X] With Store files only on, PDFs and images preview and no Google Workspace copy is made
- [X] The preview fits a narrow window, with its buttons and Close on screen
- [X] File Explorer loads more rows on scroll, searches, and sorts without repeated or missing rows
- [X] Google Files are returned by global search and open on the Google Client file details page
- [X] AI File Intelligence summary works for files uploaded after `Enable AI File Intelligence` is enabled
- [X] Question answering works when AI provider is configured and `Enable AI File Intelligence` is enabled
- [X] AI prompt security refuses an obvious injection attempt
- [X] Labels applied by AI are shown in File Explorer and on the File Details page
- [X] A document larger than the Maximum Preview File Size setting previews
- [X] Open in Google Drive works for an owned file and is not offered to external users
- [X] Flow actions create a folder, upload, download and read file text without errors
- [X] The Migration tab opens and a run copies a Salesforce file into Google Drive
- [X] No critical errors appear in the UI
- [X] No critical errors appear in logs

## Quick Regression Suite

Use this when changes are small and isolated, but you still want confidence across the main flows.

### Phase 1: Admin Baseline

Log in as Admin.

- [X] Confirm Google Drive integration is configured and validated
- [X] Confirm current folder structure configuration is known
- [X] Confirm current AI provider configuration is known
- [X] Confirm the `Enable AI File Intelligence` checkbox state is known
- [X] Confirm the `Direct Browser Upload` state is known
- [X] Confirm the configured File Explorer columns are known
- [X] Confirm the Maximum Preview File Size value is known
- [X] Confirm the Folder Names, Store files only and copies folder settings are known
- [X] Open Google Client app and confirm configuration tabs render without errors
- [X] Open the Migration tab and confirm it renders without errors

### Phase 2: Upload and Preview

Log in as Internal User A.

Use Record A.

Use both record-page components in this phase:

- Upload the previewable file from the Uploader component
- Upload the non-previewable file from the Attachments component
- Open the previewable file from the Uploader component
- Open the non-previewable file from the Attachments component

- [X] Open the Lightning record page
- [X] Confirm Uploader component renders without errors
- [X] Confirm Attachments component renders without errors
- [X] Upload a previewable file using the Uploader component
- [X] Confirm the previewable file appears in the Uploader component
- [X] Open Preview for the previewable file from the Uploader component
- [X] Confirm preview works
- [X] Confirm download works
- [X] Confirm Download as... is visible
- [X] Upload a non-previewable file using the Attachments component
- [X] Confirm the non-previewable file appears in the Attachments component
- [X] Open Preview for the non-previewable file from the Attachments component
- [X] Confirm non-previewable message is shown
- [X] Confirm Download as... is not visible
- [X] Open View All from the Attachments component, tick two files and confirm they download together as one ZIP archive
- [X] Tick two files in the Uploader component and confirm they download together as one ZIP archive
- [X] Open a preview in a narrow window and confirm its buttons and Close stay on screen

### Phase 3: Versioning

Continue as Internal User A.

Use Preview opened from the same component where the previewable file was uploaded.

- [X] Upload a new version for the previewable file from Preview
- [X] Confirm the latest version becomes active
- [X] Confirm Preview uses the expected latest version
- [X] Confirm Download uses the expected latest version

### Phase 4: Internal Sharing

Continue as Internal User A.

Use a file from the component where it is visible.

- [X] Open Preview from the component where the file is visible
- [X] Share the file with Internal User B as Viewer from Preview

Log in as Internal User B.

Use the same component path where the shared file is expected to appear.

- [X] Open the same record
- [X] Confirm the shared file is visible in the expected component
- [X] Open Preview from the expected component
- [X] Confirm read-only behavior
- [X] Confirm download works
- [X] Confirm edit/version/delete/share/public link actions are not available

### Phase 5: File Explorer

Log in as Internal User A.

Use an account with more files than fit on a single page.

- [X] Open File Explorer
- [X] Confirm the list renders and the configured columns are shown
- [X] Scroll to the bottom and confirm more rows are appended without repeats
- [X] Search by part of a file name and confirm the expected file is found
- [X] Sort by Last Modified Date and confirm the order is correct
- [X] Select Refresh and confirm the list reloads
- [X] Open Preview from File Explorer
- [X] Open Search, narrow the list with a word and one filter, tick two of the files found and confirm they download together as one ZIP archive

### Phase 6: Attach Existing File

Log in as Internal User A.

Use the Attachments component.

- [X] Open another Salesforce record
- [X] Open Attach Existing Files from the Attachments component
- [X] Confirm owned files are available
- [X] Attach an existing owned file
- [X] Confirm the file appears on the second record in the Attachments component
- [X] Confirm the same file still appears on the original record in the Attachments component where expected
- [X] Confirm File Details shows linked records where available

### Phase 7: Access

Use a file linked to two records.

Use the component where the file is expected to be visible for record-level visibility and Preview access checks.

- [X] Confirm a user with access to a linked record can see the file in the expected component
- [X] Confirm a user with access only to an unrelated record cannot see the file in the expected component
- [X] Confirm direct Preview URL does not bypass access checks
- [X] Confirm direct File Details URL does not bypass access checks

### Phase 8: Folder Structure

Use the currently configured folder structure.

Use the Uploader component, Attachments component, and Attach Existing Files flow explicitly in this phase.

- [X] Upload one file from the Uploader component
- [X] Confirm the file appears in the Uploader component
- [X] Upload one file from the Attachments component
- [X] Confirm the file appears in the Attachments component
- [X] Confirm files are placed in the expected Google Drive folder
- [X] Upload several files at once to a record that has no Google files yet, and confirm one folder is created for that record
- [X] Attach an existing file to another record using Attach Existing Files from the Attachments component
- [X] Confirm Drive placement or shortcut behavior matches the configured folder structure

If the release touched File Explorer upload or folder placement logic, also run this File Explorer check.

- [X] Upload one file from File Explorer
- [X] Confirm the file appears in File Explorer
- [X] Confirm File Explorer upload uses the expected Google Drive folder

If the release touched folder structure logic, also run this reduced folder matrix.

- [X] No folder structure / Default folder only
- [X] Folder per Record
- [X] Folder per User
- [X] Folder per Record → User
- [X] Folder per User → Record

If the release touched folder naming, also run these checks.

- [X] With a formula for the record's object, confirm a new record folder takes the formula's name
- [X] With Folder Names on, rename a record that has a folder, upload a file to it, and confirm the folder takes the new name

If the release touched the Google Workspace copies, also run these checks.

- [X] With Store files only on, upload a PDF and a Word document, and confirm the PDF previews and the Word document shows Preview unavailable
- [X] With a copies folder set, upload a Word document and confirm its copy lands in the copies folder and its preview works

### Phase 9: Direct Browser Upload

Log in as Admin.

- [X] Enable `Direct Browser Upload` and save

Log in as Internal User A.

- [X] Upload one large file from the Uploader and confirm it completes and lands in the configured folder

Log in as Admin.

- [X] Disable `Direct Browser Upload` and save

Log in as Internal User A.

- [X] Upload one large file from the Uploader and confirm it completes and lands in the configured folder

### Phase 10: Experience Cloud

Log in as External User E.

Use Experience Cloud components only for this phase.

- [X] Open Experience Cloud page containing Google Client Uploader and Attachments components
- [X] Confirm Experience Cloud Uploader component renders without errors
- [X] Confirm Experience Cloud Attachments component renders without errors
- [X] Confirm files are hidden in the Experience Cloud Attachments component by default unless external visibility is enabled
- [X] Open a visible file from the Experience Cloud Attachments component
- [X] Confirm Preview works
- [X] Confirm external user sees only allowed actions

### Phase 11: AI

Run this phase only if AI configuration or AI-related UI was touched.

Log in as Admin.

- [X] Confirm Gemini or Agent Platform / Vertex configuration is available
- [X] Confirm the `Enable AI File Intelligence` checkbox is in the expected state
- [X] Confirm prompts and token limits can be saved

Log in as Internal User A.

Use the component where the file should be validated.

Files uploaded before `Enable AI File Intelligence` was enabled are not expected to receive summaries.

- [X] If `Enable AI File Intelligence` is enabled, upload a new file with clear business content from the component being tested
- [X] Confirm the new file appears in the same component where it was uploaded
- [X] Open Preview for the new file from the same component
- [X] Confirm summary behavior matches the current AI provider and `Enable AI File Intelligence` setting
- [X] Confirm hover behavior matches the current AI provider and `Enable AI File Intelligence` setting in Uploader where supported
- [X] Confirm hover behavior matches the current AI provider and `Enable AI File Intelligence` setting in Attachments where supported
- [X] If `Enable AI File Intelligence` is enabled, confirm question answering works from Preview for files uploaded after the setting was enabled
- [X] If `Enable AI File Intelligence` is enabled, confirm an obvious attempt to override the model's instructions is refused
- [X] If `Enable AI File Intelligence` is disabled, confirm question answering is not available from Preview
- [X] If `Enable AI File Intelligence` is disabled, confirm no new summary is generated for files uploaded while the setting is disabled

### Phase 12: Final Smoke Check

- [X] Internal user can open Core Cloud record pages without errors
- [X] External user can open Experience Cloud pages without errors
- [X] Admin can open Google Client app without errors
- [X] Uploader component works where expected
- [X] Attachments component works where expected
- [X] File Explorer works where expected
- [X] Google Files are returned by global search and open on the Google Client file details page
- [X] No critical errors appear in the UI
- [X] No critical errors appear in logs

## Targeted Regression Suite

Use this when you want to validate what was added/changed, without running a full suite.

<br>
