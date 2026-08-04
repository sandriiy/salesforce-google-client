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
- [X] At least one document contains clear business content for summary and Q&A testing
- [X] At least one Google file owned by internal user A exists and is not yet linked to the target Salesforce record
- [X] At least one Google file not owned by internal user A exists
- [X ] At least one Google file is shared with a public group or a queue
- [X] Enough files exist for internal user A to fill more than one File Explorer page

## Full Validation Suite

### Phase 1: Admin Baseline

Log in as Admin.

- [ ] Open Google Client application
- [ ] Confirm Google Drive integration is configured and validates successfully
- [ ] Confirm only one upload folder is configured under Folder Locations
- [ ] Confirm Gemini / Agent Platform / Vertex is not configured
- [ ] Confirm AI summary / Q&A features are not active
- [ ] Confirm folder structure is set to No folder structure / Default folder only
- [ ] Confirm `Direct Browser Upload` is disabled in Advanced → File Management
- [ ] Confirm the `GoogleDriveDirectUpload` CSP Trusted Site exists and is active in Setup
- [ ] Confirm Org Cache is allocated to the `GoogleCloudClient` Platform Cache partition
- [ ] Confirm File Explorer columns in Advanced → User Interface are at their default selection
- [ ] Confirm neither `Google Client: View All Files` nor `Google Client: Edit All Files` is assigned to any test user
- [ ] Open configuration tabs and confirm there are no page-level errors
- [ ] Confirm admin-only configuration pages are available to the admin user
- [ ] Confirm Analytics tab renders for the admin user
- [ ] Confirm Logger Admin Dashboard renders for the admin user

### Phase 2: Core Cloud Uploads

Log in as Internal User A.

Use Record A.

Use the Lightning record page that contains both Google Client record components:

- Uploader component
- Attachments component

Run the full file-type upload set from the Uploader component first. Files uploaded from the Uploader component should be validated from the Uploader component. Do not assume they appear in the Attachments component.

- [ ] Open the Lightning record page containing Google Client components
- [ ] Confirm Uploader component renders without errors
- [ ] Confirm Attachments component renders without errors
- [ ] Upload a PDF file using the Uploader component
- [ ] Upload a large PDF file using the Uploader component
- [ ] Upload a CSV file using the Uploader component
- [ ] Upload an image file using the Uploader component
- [ ] Upload a large image file using the Uploader component
- [ ] Upload a document file using the Uploader component
- [ ] Upload a non-previewable file using the Uploader component
- [ ] Confirm all files uploaded from the Uploader component appear in the Uploader component
- [ ] Upload one additional previewable file using the Attachments component upload action
- [ ] Confirm the file uploaded from the Attachments component appears in the Attachments component
- [ ] Confirm an uploaded file appears in View All
- [ ] Confirm uploaded files are stored in the default/root configured Google Drive folder
- [ ] Confirm no record-specific or user-specific folder is created

### Phase 3: Uploader Preview and File Actions

Continue as Internal User A.

Use the files uploaded through the Uploader component in Phase 2.

Use the Uploader component as the main entry point for Preview in this phase. Do not use the Attachments component for these Uploader-uploaded files.

- [ ] Open Preview for the PDF file from the Uploader component
- [ ] Confirm PDF preview works
- [ ] Confirm download works
- [ ] Confirm Download as... is visible for the PDF file
- [ ] Open Preview for the large PDF file from the Uploader component
- [ ] Confirm large PDF preview works
- [ ] Open Preview for the CSV file from the Uploader component
- [ ] Confirm CSV preview works
- [ ] Open Preview for the image file from the Uploader component
- [ ] Confirm image preview works
- [ ] Open Preview for the large image file from the Uploader component
- [ ] Confirm large image preview works
- [ ] Open Preview for the document file from the Uploader component
- [ ] Confirm document preview works
- [ ] Confirm Download as... is visible for previewable files
- [ ] Open Preview for the non-previewable file from the Uploader component
- [ ] Confirm non-previewable message is shown
- [ ] Confirm Download as... is not visible for the non-previewable file
- [ ] Confirm AI summary / Q&A actions are not shown while AI is not configured
- [ ] Edit file details for one owned file from Preview opened through the Uploader component
- [ ] Upload a new version for one owned file from Preview opened through the Uploader component
- [ ] Confirm latest version becomes active
- [ ] Confirm older version remains in the org
- [ ] Confirm preview and download use the latest active version

### Phase 4: Attachments Preview and File Actions

Continue as Internal User A.

Use only files uploaded through the Attachments component.

Use the Attachments component as the entry point for Preview in this phase. Do not use Uploader-uploaded files for Attachments-specific checks.

- [ ] Open Preview for the small PDF file (upload a new if needed) from the Attachments component
- [ ] Confirm PDF preview works
- [ ] Confirm download works
- [ ] Confirm Download as... is visible for the PDF file
- [ ] Open Preview for the large PDF file (upload a new if needed) from the Attachments component
- [ ] Confirm large PDF preview works
- [ ] Edit file details for one owned file from Preview opened through the Attachments component
- [ ] Upload a new version for one owned file from Preview opened through the Attachments component
- [ ] Confirm older version remains in the org
- [ ] Confirm older version remains available where supported
- [ ] Confirm preview and download use the latest active version

### Phase 5: File Explorer

Continue as Internal User A.

Use the File Explorer Lightning tab only for this phase. Do not use the record page Uploader or Attachments components for File Explorer-specific checks.

- [ ] Open File Explorer
- [ ] Confirm Owned files tab renders correctly
- [ ] Confirm Shared files tab renders correctly
- [ ] Confirm files uploaded from the Uploader component appear under Owned files where expected
- [ ] Confirm files uploaded from the Attachments component appear under Owned files where expected
- [ ] Open Preview from File Explorer
- [ ] Upload a file from the File Explorer upload action
- [ ] Confirm the file uploaded from File Explorer appears in File Explorer
- [ ] Confirm the file uploaded from File Explorer is placed in the expected default/root Google Drive folder

Use an account with more files than fit on a single page for the list behaviour checks.

- [ ] Confirm the first page of files renders without scrolling the whole list
- [ ] Scroll to the bottom and confirm more rows are appended
- [ ] Scroll to the end of the list and confirm no row is repeated and none is missing
- [ ] Confirm the Owner column shows the file owner, including for a file owned by a public group or a queue
- [ ] Confirm the owner is shown as a name rather than an identifier
- [ ] Search by part of a file name and confirm matches are returned from the whole list, not only from the rows already loaded
- [ ] Clear the search and confirm the full list returns
- [ ] Sort by Title and confirm the order is correct across page boundaries
- [ ] Sort by Last Modified Date and confirm the order is correct across page boundaries
- [ ] Confirm Type, Size, Summary, and Access columns cannot be sorted
- [ ] Select Refresh and confirm the list reloads
- [ ] Switch between Owned and Shared and confirm search and sorting apply to the selected view

Log in as Admin.

- [ ] Open Advanced → User Interface
- [ ] Add and reorder columns, then save
- [ ] Confirm a maximum of 7 columns can be selected
- [ ] Confirm Title cannot be removed
- [ ] Add a valid Google File Version field API name as a custom column and save
- [ ] Add an invalid field API name as a custom column and save

Log in as Internal User A.

- [ ] Confirm File Explorer shows the configured columns in the configured order
- [ ] Confirm the valid custom column shows its values
- [ ] Confirm the invalid custom column renders empty and the list still loads

Log in as Admin.

- [ ] Restore the default column selection

### Phase 6: Internal Sharing

Continue as Internal User A.

Use one owned file that was uploaded through the Attachments component on Record A.

Use the Attachments component on Record A to open Preview and Share.

- [ ] Open Preview from the Attachments component
- [ ] Open Share modal from Preview
- [ ] Share the file with Internal User B as Viewer
- [ ] Confirm sharing completes successfully

Log in as Internal User B.

Use the Attachments component on Record A to verify access.

- [ ] Open Record A
- [ ] Confirm the shared file is visible in the Attachments component
- [ ] Open Preview for the shared file from the Attachments component
- [ ] Confirm View access behavior
- [ ] Confirm download is available
- [ ] Confirm edit details is not available
- [ ] Confirm upload new version is not available
- [ ] Confirm delete is not available
- [ ] Confirm Share modal is not available
- [ ] Confirm Public Link modal is not available
- [ ] Open File Explorer and confirm the shared file appears under Shared files

Log in as Internal User A.

Use the Attachments component on Record A.

- [ ] Open Share modal again from Preview
- [ ] Change Internal User B access to Collaborator or equivalent edit-level access
- [ ] Confirm sharing update completes successfully

Log in as Internal User B.

Use the Attachments component on Record A.

- [ ] Open Preview for the shared file from the Attachments component
- [ ] Confirm Edit behavior is applied
- [ ] Confirm collaborator can upload a new version
- [ ] Confirm collaborator can edit details

### Phase 7: Public Link

Log in as Internal User A.

Use one owned file that was uploaded through the Attachments component.

Use the Attachments component on Record A to open Preview and Public Link.

- [ ] Open Preview from the Attachments component
- [ ] Open Public Link modal from Preview
- [ ] Create a public link
- [ ] Open the link in a separate browser/session without Salesforce login
- [ ] Confirm the public link opens successfully
- [ ] Revoke the public link
- [ ] Create a public link & set an expiration date
- [ ] Confirm the link no longer works after the expiration date

### Phase 8: Attach Existing Files

Log in as Internal User A.

Use these records:

- Record A: original linked record
- Record B: additional linked record
- Record C: unrelated record

Use the Attachments component for Attach Existing Files. Do not use the Uploader component for this phase.

- [ ] Open Record B
- [ ] Open Attach Existing Files from the Attachments component
- [ ] Confirm files owned by Internal User A are available for selection
- [ ] Confirm files owned by other users are not available for selection
- [ ] Attach an existing owned file from Record A to Record B using the Attach Existing Files flow
- [ ] Confirm the file appears on Record B in the Attachments component
- [ ] Open Record A
- [ ] Confirm the same file still appears on Record A in the Attachments component
- [ ] Open File Record Details page
- [ ] Confirm linked records show Record A and Record B
- [ ] Open Record C
- [ ] Confirm the file does not appear on Record C in the Attachments component

### Phase 9: Multi-Record Security

Use the file linked to Record A and Record B.

Use the Attachments component on each record to validate record-based visibility.

Log in as a user who has access to Record A only.

- [ ] Confirm the file is visible on Record A in the Attachments component
- [ ] Confirm the file is not visible from unrelated Record C in the Attachments component
- [ ] Open Preview from the Attachments component on Record A
- [ ] Confirm resolved access level matches Record A access

Log in as a user who has access to Record B only.

- [ ] Confirm the file is visible on Record B in the Attachments component
- [ ] Confirm the file is not visible from unrelated Record C in the Attachments component
- [ ] Open Preview from the Attachments component on Record B
- [ ] Confirm resolved access level matches Record B access

Log in as a user who has access to Record C only.

- [ ] Confirm the file is not visible on Record C in the Attachments component
- [ ] Confirm the file is not returned in search results
- [ ] Confirm direct Preview URL does not open the file
- [ ] Confirm direct File Details URL does not open the file
- [ ] Confirm file actions cannot be executed from any entry point

Log in as Admin or record owner.

- [ ] Remove the association between the file and Record A
- [ ] Confirm users with access only to Record A no longer have record-based access
- [ ] Confirm users with access to Record B still have access

### Phase 10: File Details Page and Global Search

Log in as Internal User A.

Use the File Details page directly for this phase.

- [ ] Open File Details page for an owned file
- [ ] Confirm file details display correctly
- [ ] Confirm linked records component renders correctly
- [ ] Confirm linked records are shown only when the current user has access to those records
- [ ] Confirm the Salesforce record name is shown in full, including for the record whose name is assembled from several fields
- [ ] Confirm file actions respect the current user's resolved access level
- [ ] Open File Details page for a file the current user should not access
- [ ] Confirm access is denied or safe fallback behavior is shown

Use Salesforce global search for this part.

- [ ] Search for an owned file by name in global search
- [ ] Confirm the file is returned in the results
- [ ] Open the file from the search result
- [ ] Confirm the Google Client file details page opens rather than a standard record layout
- [ ] Confirm standard record buttons and the highlights panel are not shown
- [ ] Confirm the same page opens when the file URL is entered directly
- [ ] Confirm preview, sharing, versions, and linked records all work from this page

### Phase 11: Privileged Access

Log in as Admin.

- [ ] Assign the permission set containing `Google Client: View All Files` to Internal User B

Log in as Internal User B.

- [ ] Open File Explorer
- [ ] Confirm a single All Files view is shown instead of the Owned and Shared views
- [ ] Confirm files owned by other users appear in the list
- [ ] Confirm the Access column shows View for files that would otherwise be inaccessible
- [ ] Confirm search and sorting work across the whole list
- [ ] Open Preview for a file owned by another user
- [ ] Confirm read-only actions are available and edit-level actions are not

Log in as Admin.

- [ ] Replace the assignment with the permission set containing `Google Client: Edit All Files`

Log in as Internal User B.

- [ ] Confirm the Access column now shows Edit
- [ ] Confirm edit-level actions are available on a file owned by another user

Log in as External User E.

- [ ] Confirm no additional files became visible on Experience Cloud pages

Log in as Admin.

- [ ] Remove both permission set assignments from Internal User B

Log in as Internal User B.

- [ ] Confirm File Explorer returns to the Owned and Shared views
- [ ] Confirm files owned by other users are no longer visible

### Phase 12: Experience Cloud

Log in as External User E.

Use the Experience Cloud test record.

Use the Experience Cloud Uploader component for upload checks and the Experience Cloud Attachments component for file list, View All, and Preview checks.

- [ ] Open Experience Cloud page containing Uploader component
- [ ] Confirm Uploader renders without errors
- [ ] Open Experience Cloud page containing Attachments component
- [ ] Confirm Attachments renders without errors
- [ ] Confirm files are not visible in the Experience Cloud Attachments component by default unless external visibility is enabled
- [ ] Confirm View All navigation works from the Experience Cloud Attachments component
- [ ] Confirm Preview opens from the Experience Cloud Attachments component for files the external user can access
- [ ] Confirm Preview actions respect external user access level
- [ ] Confirm internal-only actions are not available
- [ ] Confirm AI summary/sidebar behavior does not break Experience Cloud preview while AI is not configured

Log in as Internal User A.

Use the internal Core Cloud Attachments component on the Experience Cloud test record.

- [ ] Open Share modal for a file linked to the Experience Cloud record from Preview
- [ ] Enable external visibility for the related record
- [ ] Save sharing changes

Log in as External User E.

Use the Experience Cloud Attachments component.

- [ ] Refresh the Experience Cloud record page
- [ ] Confirm the externally visible file appears in the Experience Cloud Attachments component
- [ ] Open Preview from the Experience Cloud Attachments component
- [ ] Confirm Viewer behavior where expected
- [ ] Confirm unrelated linked records are not exposed

### Phase 13: Folder Structure

For each folder structure configuration, log in as Admin first, change the folder structure, then log in as Internal User A and validate upload/attach behavior.

Use these component rules for this phase:

- Record-page Uploader component validates upload behavior from Uploader and Uploader-only file visibility
- Record-page Attachments component validates upload behavior from Attachments, Attachments-only file visibility, and Attach Existing Files
- File Explorer validates File Explorer upload behavior separately

#### No Folder Structure / Default Folder Only

Log in as Admin.

- [ ] Configure No folder structure / Default folder only

Log in as Internal User A.

- [ ] Upload a file from the Uploader component
- [ ] Confirm the file appears in the Uploader component
- [ ] Upload a file from the Attachments component
- [ ] Confirm the file appears in the Attachments component
- [ ] Upload a file from File Explorer
- [ ] Confirm the file appears in File Explorer
- [ ] Confirm files uploaded from Uploader, Attachments, and File Explorer are placed in the default/root configured folder
- [ ] Attach an existing file to another record using Attach Existing Files from the Attachments component
- [ ] Confirm no record-specific or user-specific folder is created

#### Folder per Record

Log in as Admin.

- [ ] Configure Folder per Record

Log in as Internal User A.

- [ ] Upload multiple files at once to a record that has no Google files yet, using the Uploader component
- [ ] Confirm the files appear in the Uploader component
- [ ] Confirm exactly one folder was created for that record
- [ ] Confirm every file of that upload is placed in the same folder
- [ ] Upload another file to the same record using the Attachments component
- [ ] Confirm the file appears in the Attachments component
- [ ] Confirm the existing record folder is reused
- [ ] Upload a file to a different record using the Uploader component
- [ ] Confirm a different record folder is used

Log in as Internal User B while Internal User A uploads to the same new record at the same time.

- [ ] Confirm both users' files land in the same record folder
- [ ] Confirm no duplicate folder is created for that record

Continue as Internal User A.

- [ ] Attach an existing file to a record that has no Google Drive folder yet, using Attach Existing Files
- [ ] Confirm the record folder is created under the configured upload folder
- [ ] Confirm the record folder is not created inside the folder of the attached file
- [ ] Confirm the expected Drive representation is created in the target record folder

#### Folder per User

Log in as Admin.

- [ ] Configure Folder per User

Log in as Internal User A.

- [ ] Upload multiple files at once to a record using the Attachments component
- [ ] Confirm the files appear in the Attachments component
- [ ] Confirm files are placed under Internal User A folder
- [ ] Upload a file from the Uploader component
- [ ] Confirm the file appears in the Uploader component
- [ ] Confirm the file is placed under Internal User A folder
- [ ] Upload a file from File Explorer
- [ ] Confirm the file appears in File Explorer
- [ ] Confirm File Explorer upload uses the expected user folder
- [ ] Attach an existing file to another record using Attach Existing Files from the Attachments component
- [ ] Confirm user-based folder structure is respected

Log in as Internal User B.

- [ ] Upload a file from the Uploader component
- [ ] Confirm the file appears in the Uploader component
- [ ] Confirm file is placed under Internal User B folder
- [ ] Upload a file from the Attachments component
- [ ] Confirm the file appears in the Attachments component
- [ ] Confirm Attachments upload is placed under Internal User B folder
- [ ] Confirm Internal User A and Internal User B use different user folders

#### Folder per Record → User

Log in as Admin.

- [ ] Configure Folder per Record → User

Log in as Internal User A.

- [ ] Upload a file to a record using the Uploader component
- [ ] Confirm the file appears in the Uploader component
- [ ] Confirm file is placed under Record → User path
- [ ] Upload a file to the same record using the Attachments component
- [ ] Confirm the file appears in the Attachments component
- [ ] Confirm Attachments upload is placed under the same Record → User path
- [ ] Attach an existing file to another record using Attach Existing Files from the Attachments component
- [ ] Confirm expected Drive representation is created under the target Record → User path

Log in as Internal User B.

- [ ] Upload a file to the same record using the Uploader component
- [ ] Confirm the file appears in the Uploader component
- [ ] Confirm Internal User B uses a separate user folder under the same record folder

#### Folder per User → Record

Log in as Admin.

- [ ] Configure Folder per User → Record

Log in as Internal User A.

- [ ] Upload a file to Record A using the Uploader component
- [ ] Confirm the file appears in the Uploader component
- [ ] Confirm file is placed under User → Record A path
- [ ] Upload a file to Record A using the Attachments component
- [ ] Confirm the file appears in the Attachments component
- [ ] Confirm Attachments upload is placed under User → Record A path
- [ ] Upload a file to Record B using the Uploader component
- [ ] Confirm the file appears in the Uploader component
- [ ] Confirm file is placed under User → Record B path
- [ ] Attach an existing file to another record using Attach Existing Files from the Attachments component
- [ ] Confirm expected Drive representation is created under the target User → Record path

### Phase 14: Multiple Upload Folders

Log in as Admin.

- [ ] Add a second folder under Folder Locations and save
- [ ] Confirm both folders are listed in the configured order
- [ ] Confirm up to ten folders can be added

Log in as Internal User A.

- [ ] Upload a file from the Uploader component
- [ ] Confirm the file is placed in the first configured folder
- [ ] Confirm the configured folder structure is created inside that folder

Log in as Admin.

- [ ] Move the second folder to the first position and save

Log in as Internal User A.

- [ ] Upload a file from the Uploader component
- [ ] Confirm the file is placed in the newly promoted first folder
- [ ] Confirm files uploaded earlier remain in their original folder and are still reachable from Salesforce

Log in as Admin.

- [ ] Remove the second folder and return to a single configured folder

### Phase 15: Direct Browser Upload

Log in as Admin.

- [ ] Enable `Direct Browser Upload` in Advanced → File Management and save
- [ ] Run `Test connection` and confirm it succeeds
- [ ] Confirm no test file was left behind in Google Drive
- [ ] Deactivate the `GoogleDriveDirectUpload` CSP Trusted Site, reload the page, run `Test connection`, and confirm it reports that the browser could not reach Google
- [ ] Reactivate the CSP Trusted Site

Log in as Internal User A.

- [ ] Upload a 5 MB file from the Uploader and confirm the progress advances and the record is created
- [ ] Upload a file larger than 100 MB and confirm it completes and lands in the configured folder
- [ ] Upload a file smaller than 2 MB and confirm it is unaffected
- [ ] Upload a file smaller than 16 MB, so the whole file is a single chunk, and confirm it completes without any error shown
- [ ] Upload a new version of an existing file and confirm versioning is correct
- [ ] Confirm folder structure and preview behave the same as for a standard upload
- [ ] Upload several files at once from Attachments and confirm every file completes
- [ ] Deactivate the CSP Trusted Site, reload, upload a large file from the Uploader, and confirm the file card offers a retry through Salesforce
- [ ] Accept the retry and confirm the file uploads and the record is created
- [ ] Upload another large file in the same browser session and confirm it goes straight through Salesforce without prompting again
- [ ] Repeat the deactivated-CSP case from Attachments and confirm the retry prompt appears at the bottom of the upload window
- [ ] Dismiss the retry prompt instead of accepting it, and confirm the upload window can still be closed with Done
- [ ] Reactivate the CSP Trusted Site
- [ ] Disable the network mid-upload, restore it, and confirm the upload resumes without user action

Log in as External User E.

- [ ] Upload a large file from an Experience Cloud page and confirm it completes
- [ ] Confirm the uploaded file respects Visibility and is not exposed beyond the expected users

Log in as Admin.

- [ ] Turn `Direct Browser Upload` back off and confirm large uploads still work from all three components
- [ ] Confirm logs tagged `Google Client for Salesforce` show the expected direct upload outcomes and no unexpected errors

### Phase 16: Delete and Cleanup

Log in as Internal User A.

Use a file linked to multiple records.

- [ ] Confirm file appears on all linked records in the Attachments/Uploader component
- [ ] Delete the file from Preview or supported file action
- [ ] Confirm the file is removed from all linked records & Google Drive

### Phase 17: Gemini Configuration

Log in as Admin.

- [ ] Configure Gemini API for Developers
- [ ] Validate Gemini configuration
- [ ] Enable Q&A / analysis
- [ ] Configure summary prompt
- [ ] Configure question-answering prompt
- [ ] Configure token limits

Log in as Internal User A.

- [ ] Upload a new business-content file using the Uploader component after `Enable AI File Intelligence` is enabled
- [ ] Confirm the new file appears in the Uploader component
- [ ] Confirm summary appears on hover in the Uploader component
- [ ] Open Preview for the new file from the Uploader component
- [ ] Confirm summary is generated and appears in Preview sidebar
- [ ] Ask a question about the file
- [ ] Confirm answer is related to the currently opened file
- [ ] Confirm question answering respects configured prompt and token limits
- [ ] Upload a new business-content file using the Attachments component after `Enable AI File Intelligence` is enabled
- [ ] Confirm the new file appears in the Attachments component
- [ ] Confirm summary appears on hover in the Attachments component
- [ ] Open Preview for the new file from the Attachments component
- [ ] Confirm summary is generated and appears in Preview sidebar
- [ ] Ask a question about the file
- [ ] Add the Summary column in File Explorer and confirm the generated summary is shown
- [ ] Search File Explorer for a word that appears in the summary but not in the file name, and confirm the file is found

Log in as Admin.

- [ ] Disable the `Enable AI File Intelligence` setting

Log in as Internal User A.

Use Preview opened from the same component where the files were uploaded.

- [ ] Open Preview for the file
- [ ] Confirm AI File Intelligence actions are not available after the setting is disabled
- [ ] Upload another new file after `Enable AI File Intelligence` is disabled
- [ ] Confirm no new summary is generated for files uploaded while `Enable AI File Intelligence` is disabled

### Phase 18: Agent Platform / Vertex Configuration

Log in as Admin.

- [ ] Disable or clear Gemini configuration where needed
- [ ] Configure Agent Platform / Vertex
- [ ] Validate Agent Platform / Vertex configuration
- [ ] Configure summary prompt
- [ ] Configure question-answering prompt
- [ ] Configure token limits
- [ ] Enable the `Enable AI File Intelligence` setting

Log in as Internal User A.

- [ ] Upload a new business-content file using the Uploader component after `Enable AI File Intelligence` is enabled
- [ ] Confirm the new file appears in the Uploader component
- [ ] Confirm summary appears on hover in the Uploader component
- [ ] Open Preview for the new file from the Uploader component
- [ ] Confirm summary is generated and appears in Preview sidebar
- [ ] Ask a question about the file
- [ ] Confirm answer is related to the currently opened file
- [ ] Confirm question answering respects configured prompt and token limits
- [ ] Upload a new business-content file using the Attachments component after `Enable AI File Intelligence` is enabled
- [ ] Confirm the new file appears in the Attachments component
- [ ] Confirm summary appears on hover in the Attachments component
- [ ] Open Preview for the new file from the Attachments component
- [ ] Confirm summary is generated and appears in Preview sidebar
- [ ] Ask a question about the file

Log in as Admin.

- [ ] Disable the `Enable AI File Intelligence` setting

Log in as Internal User A.

Use Preview opened from the same component where the file was uploaded.

- [ ] Confirm AI File Intelligence actions are not available while Agent Platform / Vertex remains configured but `Enable AI File Intelligence` is disabled
- [ ] Upload another new file after `Enable AI File Intelligence` is disabled
- [ ] Confirm no new summary is generated for files uploaded while `Enable AI File Intelligence` is disabled

### Phase 19: AI Prompt Security

Log in as Admin.

- [ ] Re-enable `Enable AI File Intelligence`
- [ ] Confirm Advanced → Safety & Customization shows Standard as the active mode when nothing was chosen
- [ ] Confirm the safety settings are disabled while File Intelligence is off and enabled once it is on

Log in as Internal User A.

Use Preview with the AI sidebar open.

- [ ] Ask a normal question about the document and confirm it is answered
- [ ] Ask the model to ignore its instructions and confirm the request is refused with a readable message
- [ ] Ask the model to reveal its configuration or system prompt and confirm the request is refused
- [ ] Ask an unrelated general-knowledge question and confirm it is refused
- [ ] Confirm a refusal does not break the preview or the sidebar

Log in as Admin.

- [ ] Set the mode to Strict

Log in as Internal User A.

- [ ] Confirm normal questions are still answered
- [ ] Confirm a very long question is refused with a message about length

Log in as Admin.

- [ ] Set the mode to Off

Log in as Internal User A.

- [ ] Confirm questions are answered without inspection

Log in as Admin.

- [ ] Set the mode back to Standard
- [ ] Enter a class name that does not exist in `Custom AI Prompt Safety Guard Class` and save

Log in as Internal User A.

- [ ] Confirm questions are still answered and the shipped protection is still applied

Log in as Admin.

- [ ] Clear the `Custom AI Prompt Safety Guard Class` field

### Phase 20: Admin and Permission Checks

Log in as Admin-level non-system user without View All Data, but with Google Client Admin permission.

- [ ] Open Google Client admin functionality available to Google Client admins
- [ ] Open Analytics tab
- [ ] Confirm Logger Admin Dashboard renders where expected
- [ ] Confirm admin user cannot perform day-to-day file operations from Uploader, Attachments, File Explorer, or Preview unless user permissions are also assigned

Log in as regular operational user without admin permissions.

- [ ] Confirm admin configuration pages are not accessible
- [ ] Confirm Analytics dashboard is not accessible
- [ ] Confirm operational file features still work from Uploader, Attachments, File Explorer, and Preview where user has record/file access

### Phase 21: Final Sweep

Use the final intended release configuration.

- [ ] Internal user can open Core Cloud record pages without errors
- [ ] External user can open Experience Cloud pages without errors
- [ ] Admin can open Google Client app without errors
- [ ] Upload works from the Uploader component
- [ ] Uploaded files appear in the Uploader component where expected
- [ ] Upload works from the Attachments component
- [ ] Attached files appear in the Attachments component where expected
- [ ] Upload works from File Explorer
- [ ] Files uploaded from File Explorer appear in File Explorer where expected
- [ ] Preview works from the Uploader component
- [ ] Preview works from the Attachments component
- [ ] Preview works from File Explorer
- [ ] Download works
- [ ] Download as... works for previewable files
- [ ] Sharing works from Preview
- [ ] Public links work from Preview
- [ ] Versioning works from Preview
- [ ] Attach Existing Files works from the Attachments component
- [ ] Multi-record access works
- [ ] Folder structure works for Uploader, Attachments, and File Explorer uploads
- [ ] One folder per record is created when Folder per Record is configured
- [ ] File Explorer loads more rows on scroll, searches, and sorts without repeated or missing rows
- [ ] Google Files are returned by global search and open on the Google Client file details page
- [ ] AI File Intelligence summary works for files uploaded after `Enable AI File Intelligence` is enabled
- [ ] Question answering works when AI provider is configured and `Enable AI File Intelligence` is enabled
- [ ] AI prompt security refuses an obvious injection attempt
- [ ] No critical errors appear in the UI
- [ ] No critical errors appear in logs

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
- [X] Open Google Client app and confirm configuration tabs render without errors

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

- [ ] No folder structure / Default folder only
- [ ] Folder per Record
- [ ] Folder per User
- [ ] Folder per Record → User
- [ ] Folder per User → Record

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
