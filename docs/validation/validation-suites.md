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
- [X] Experience Cloud is configured
- [X] Experience Cloud pages are configured
- [X] Experience Cloud test record is visible to external user E
- [X] Google Drive integration is configured and validated
- [X] Gemini / Agent Platform / Vertex is not configured yet
- [X] AI Q&A / analysis is disabled
- [X] Folder structure is set to No folder structure / Default folder only
- [X] Required local test files are nearby:
    - [X] PDF file
    - [X] Large PDF file
    - [X] CSV file
    - [X] Image file
    - [X] Large image file
    - [X] Google Docs / DOCX-style document
    - [X] Non-previewable file type
- [X] At least one document contains clear business content for summary and Q&A testing
- [X] At least one Google file owned by internal user A exists and is not yet linked to the target Salesforce record
- [X] At least one Google file not owned by internal user A exists

## Full Validation Suite

### Phase 1: Admin Baseline

Log in as Admin.

- [X] Open Google Client application
- [X] Confirm Google Drive integration is configured and validates successfully
- [X] Confirm Gemini / Agent Platform / Vertex is not configured
- [X] Confirm AI summary / Q&A features are not active
- [X] Confirm folder structure is set to No folder structure / Default folder only
- [X] Open configuration tabs and confirm there are no page-level errors
- [X] Confirm admin-only configuration pages are available to the admin user
- [X] Confirm Analytics tab renders for the admin user
- [X] Confirm Logger Admin Dashboard renders for the admin user

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
- [X] Confirm Download as... is visible for previewable files
- [X ] Open Preview for the non-previewable file from the Uploader component
- [X] Confirm non-previewable message is shown
- [X] Confirm Download as... is not visible for the non-previewable file
- [X] Confirm AI summary / Q&A actions are not shown while AI is not configured
- [X] Edit file details for one owned file from Preview opened through the Uploader component
- [X] Upload a new version for one owned file from Preview opened through the Uploader component
- [X] Confirm latest version becomes active
- [X] Confirm older version remains in the org
- [X] Confirm preview and download use the latest active version

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

### Phase 10: File Record Details Page

Log in as Internal User A.

Use the File Record Details page directly for this phase.

- [X] Open File Record Details page for an owned file
- [X] Confirm file details display correctly
- [X] Confirm linked records component renders correctly
- [X] Confirm linked records are shown only when the current user has access to those records
- [X] Confirm file actions respect the current user's resolved access level
- [X] Open File Record Details page for a file the current user should not access
- [X] Confirm access is denied or safe fallback behavior is shown

### Phase 11: Experience Cloud

Log in as External User E.

Use the Experience Cloud test record.

Use the Experience Cloud Uploader component for upload checks and the Experience Cloud Attachments component for file list, View All, and Preview checks.

- [X] Open Experience Cloud page containing Uploader component
- [X] Confirm Uploader renders without errors
- [X] Open Experience Cloud page containing Attachments component
- [X] Confirm Attachments renders without errors
- [X] Confirm files are not visible in the Experience Cloud Attachments component by default unless external visibility is enabled
- [X] Confirm View All navigation works from the Experience Cloud Attachments component
- [X] Confirm Preview opens from the Experience Cloud Attachments component for files the external user can access
- [X] Confirm Preview actions respect external user access level
- [X] Confirm internal-only actions are not available
- [X] Confirm AI summary/sidebar behavior does not break Experience Cloud preview while AI is not configured

Log in as Internal User A.

Use the internal Core Cloud Attachments component on the Experience Cloud test record.

- [X ] Open Share modal for a file linked to the Experience Cloud record from Preview
- [X] Enable external visibility for the related record
- [X] Save sharing changes

Log in as External User E.

Use the Experience Cloud Attachments component.

- [X] Refresh the Experience Cloud record page
- [X] Confirm the externally visible file appears in the Experience Cloud Attachments component
- [X] Open Preview from the Experience Cloud Attachments component
- [X] Confirm Viewer behavior where expected
- [X] Confirm unrelated linked records are not exposed

### Phase 12: Folder Structure

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

- [X] Upload multiple files at once to a record using the Uploader component
- [X] Confirm the files appear in the Uploader component
- [X] Confirm the same resolved record folder is used
- [X] Upload another file to the same record using the Attachments component
- [X] Confirm the file appears in the Attachments component
- [X] Confirm the existing record folder is reused
- [X] Upload a file to a different record using the Uploader component
- [X] Confirm a different record folder is used
- [X] Attach an existing file to another record using Attach Existing Files from the Attachments component
- [X] Confirm the expected Drive representation is created in the target record folder

#### Folder per User

Log in as Admin.

- [X] Configure Folder per User

Log in as Internal User A.

- [X] Upload multiple files at once to a record using the Attachments component
- [X] Confirm the files appears in the Attachments component
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

### Phase 13: Delete and Cleanup

Log in as Internal User A.

Use a file linked to multiple records.

- [X] Confirm file appears on all linked records in the Attachments/Uploader component
- [X] Delete the file from Preview or supported file action
- [X] Confirm the file is removed from all linked records & Google Drive

### Phase 14: Gemini Configuration

Log in as Admin.

- [X] Configure Gemini API for Developers
- [X] Validate Gemini configuration
- [X] Enable Q&A / analysis
- [X] Configure summary prompt
- [X] Configure question-answering prompt
- [X] Configure token limits

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

Log in as Admin.

- [X] Disable the `Enable AI File Intelligence` setting

Log in as Internal User A.

Use Preview opened from the same component where the files were uploaded.

- [X] Open Preview for the file
- [X] Confirm AI File Intelligence actions are not available after the setting is disabled
- [X] Upload another new file after `Enable AI File Intelligence` is disabled
- [X] Confirm no new summary is generated for files uploaded while `Enable AI File Intelligence` is disabled

### Phase 15: Agent Platform / Vertex Configuration

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

Log in as Admin.

- [X] Disable the `Enable AI File Intelligence` setting

Log in as Internal User A.

Use Preview opened from the same component where the file was uploaded.

- [X] Confirm AI File Intelligence actions are not available while Agent Platform / Vertex remains configured but `Enable AI File Intelligence` is disabled
- [X] Upload another new file after `Enable AI File Intelligence` is disabled
- [X] Confirm no new summary is generated for files uploaded while `Enable AI File Intelligence` is disabled

### Phase 16: Admin and Permission Checks

Log in as Admin-level non-system user without View All Data, but with Google Client Admin permission.

- [X] Open Google Client admin functionality available to Google Client admins
- [X] Open Analytics tab
- [X] Confirm Logger Admin Dashboard renders where expected
- [X] Confirm admin user cannot perform day-to-day file operations from Uploader, Attachments, File Explorer, or Preview unless user permissions are also assigned

Log in as regular operational user without admin permissions.

- [X] Confirm admin configuration pages are not accessible
- [X] Confirm Analytics dashboard is not accessible
- [X] Confirm operational file features still work from Uploader, Attachments, File Explorer, and Preview where user has record/file access

### Phase 17: Final Sweep

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
- [X] Sharing works from Preview
- [X] Public links work from Preview
- [X] Versioning works from Preview
- [X] Attach Existing Files works from the Attachments component
- [X] Multi-record access works
- [X] Folder structure works for Uploader, Attachments, and File Explorer uploads
- [X] AI File Intelligence summary works for files uploaded after `Enable AI File Intelligence` is enabled
- [X] Question answering works when AI provider is configured and `Enable AI File Intelligence` is enabled
- [X] No critical errors appear in the UI
- [X] No critical errors appear in logs

## Quick Regression Suite

Use this when changes are small and isolated, but you still want confidence across the main flows.

### Phase 1: Admin Baseline

Log in as Admin.

- [ ] Confirm Google Drive integration is configured and validated
- [ ] Confirm current folder structure configuration is known
- [ ] Confirm current AI provider configuration is known
- [ ] Confirm the `Enable AI File Intelligence` checkbox state is known
- [ ] Open Google Client app and confirm configuration tabs render without errors

### Phase 2: Upload and Preview

Log in as Internal User A.

Use Record A.

Use both record-page components in this phase:

- Upload the previewable file from the Uploader component
- Upload the non-previewable file from the Attachments component
- Open the previewable file from the Uploader component
- Open the non-previewable file from the Attachments component

- [ ] Open the Lightning record page
- [ ] Confirm Uploader component renders without errors
- [ ] Confirm Attachments component renders without errors
- [ ] Upload a previewable file using the Uploader component
- [ ] Confirm the previewable file appears in the Uploader component
- [ ] Open Preview for the previewable file from the Uploader component
- [ ] Confirm preview works
- [ ] Confirm download works
- [ ] Confirm Download as... is visible
- [ ] Upload a non-previewable file using the Attachments component
- [ ] Confirm the non-previewable file appears in the Attachments component
- [ ] Open Preview for the non-previewable file from the Attachments component
- [ ] Confirm non-previewable message is shown
- [ ] Confirm Download as... is not visible

### Phase 3: Versioning

Continue as Internal User A.

Use Preview opened from the same component where the previewable file was uploaded.

- [ ] Upload a new version for the previewable file from Preview
- [ ] Confirm the latest version becomes active
- [ ] Confirm Preview uses the expected latest version
- [ ] Confirm Download uses the expected latest version

### Phase 4: Internal Sharing

Continue as Internal User A.

Use a file from the component where it is visible.

- [ ] Open Preview from the component where the file is visible
- [ ] Share the file with Internal User B as Viewer from Preview

Log in as Internal User B.

Use the same component path where the shared file is expected to appear.

- [ ] Open the same record
- [ ] Confirm the shared file is visible in the expected component
- [ ] Open Preview from the expected component
- [ ] Confirm read-only behavior
- [ ] Confirm download works
- [ ] Confirm edit/version/delete/share/public link actions are not available

### Phase 5: Attach Existing File

Log in as Internal User A.

Use the Attachments component.

- [ ] Open another Salesforce record
- [ ] Open Attach Existing Files from the Attachments component
- [ ] Confirm owned files are available
- [ ] Attach an existing owned file
- [ ] Confirm the file appears on the second record in the Attachments component
- [ ] Confirm the same file still appears on the original record in the Attachments component where expected
- [ ] Confirm File Record Details shows linked records where available

### Phase 6: Access

Use a file linked to two records.

Use the component where the file is expected to be visible for record-level visibility and Preview access checks.

- [ ] Confirm a user with access to a linked record can see the file in the expected component
- [ ] Confirm a user with access only to an unrelated record cannot see the file in the expected component
- [ ] Confirm direct Preview URL does not bypass access checks
- [ ] Confirm direct File Details URL does not bypass access checks

### Phase 7: Folder Structure

Use the currently configured folder structure.

Use the Uploader component, Attachments component, and Attach Existing Files flow explicitly in this phase.

- [ ] Upload one file from the Uploader component
- [ ] Confirm the file appears in the Uploader component
- [ ] Upload one file from the Attachments component
- [ ] Confirm the file appears in the Attachments component
- [ ] Confirm files are placed in the expected Google Drive folder
- [ ] Attach an existing file to another record using Attach Existing Files from the Attachments component
- [ ] Confirm Drive placement or shortcut behavior matches the configured folder structure

If the release touched File Explorer upload or folder placement logic, also run this File Explorer check.

- [ ] Upload one file from File Explorer
- [ ] Confirm the file appears in File Explorer
- [ ] Confirm File Explorer upload uses the expected Google Drive folder

If the release touched folder structure logic, also run this reduced folder matrix.

- [ ] No folder structure / Default folder only
- [ ] Folder per Record
- [ ] Folder per User
- [ ] Folder per Record → User
- [ ] Folder per User → Record

### Phase 8: Experience Cloud

Log in as External User E.

Use Experience Cloud components only for this phase.

- [ ] Open Experience Cloud page containing Google Client Uploader and Attachments components
- [ ] Confirm Experience Cloud Uploader component renders without errors
- [ ] Confirm Experience Cloud Attachments component renders without errors
- [ ] Confirm files are hidden in the Experience Cloud Attachments component by default unless external visibility is enabled
- [ ] Open a visible file from the Experience Cloud Attachments component
- [ ] Confirm Preview works
- [ ] Confirm external user sees only allowed actions

### Phase 9: AI

Run this phase only if AI configuration or AI-related UI was touched.

Log in as Admin.

- [ ] Confirm Gemini or Agent Platform / Vertex configuration is available
- [ ] Confirm the `Enable AI File Intelligence` checkbox is in the expected state
- [ ] Confirm prompts and token limits can be saved

Log in as Internal User A.

Use the component where the file should be validated.

Files uploaded before `Enable AI File Intelligence` was enabled are not expected to receive summaries.

- [ ] If `Enable AI File Intelligence` is enabled, upload a new file with clear business content from the component being tested
- [ ] Confirm the new file appears in the same component where it was uploaded
- [ ] Open Preview for the new file from the same component
- [ ] Confirm summary behavior matches the current AI provider and `Enable AI File Intelligence` setting
- [ ] Confirm hover behavior matches the current AI provider and `Enable AI File Intelligence` setting in Uploader where supported
- [ ] Confirm hover behavior matches the current AI provider and `Enable AI File Intelligence` setting in Attachments where supported
- [ ] If `Enable AI File Intelligence` is enabled, confirm question answering works from Preview for files uploaded after the setting was enabled
- [ ] If `Enable AI File Intelligence` is disabled, confirm question answering is not available from Preview
- [ ] If `Enable AI File Intelligence` is disabled, confirm no new summary is generated for files uploaded while the setting is disabled

### Phase 10: Final Smoke Check

- [ ] Internal user can open Core Cloud record pages without errors
- [ ] External user can open Experience Cloud pages without errors
- [ ] Admin can open Google Client app without errors
- [ ] Uploader component works where expected
- [ ] Attachments component works where expected
- [ ] File Explorer works where expected
- [ ] No critical errors appear in the UI
- [ ] No critical errors appear in logs

## Targeted Regression Suite

Use this when you want to validate what was added/changed, without running a full suite.

### Direct Browser Upload

Log in as Admin.

- [ ] Before enabling anything, upload a large file from the Uploader, from Attachments, and from File Explorer, and confirm all three behave exactly as before
- [ ] Confirm the `GoogleDriveDirectUpload` CSP Trusted Site exists and is active in Setup
- [ ] Enable `Direct Browser Upload` in Advanced → File Management and save
- [ ] Run `Test connection` and confirm it succeeds
- [ ] Confirm no `google-client-connection-test.tmp` file was left behind in Google Drive
- [ ] Deactivate the CSP Trusted Site, reload the page, run `Test connection`, and confirm it reports that the browser could not reach Google
- [ ] Reactivate the CSP Trusted Site

Log in as Internal User A.

- [ ] Upload a 5 MB file from the Uploader and confirm the progress bar advances and the record is created
- [ ] Upload a 100 MB file and confirm it completes and lands in the configured folder
- [ ] Upload a file smaller than 2 MB and confirm it is unaffected
- [ ] Upload a file smaller than 16 MB, so the whole file is a single chunk, and confirm it completes without any error shown
- [ ] Upload a new version of an existing file and confirm versioning is correct
- [ ] Confirm folder structure, preview, and AI summary behave the same as for a standard upload
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

<br>