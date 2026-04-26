# Validation Suites

This page defines the reusable validation suites for Google Client for Salesforce.

## Common Test Data Setup

- [X] Create a test record (any supported object) for Core Cloud testing
- [X] Create a test record/page for Experience Cloud testing
- [X] Create test users:
  	- [X] Internal user A (has "Google Cloud Client User")
  	- [X] Internal user B (has "Google Cloud Client User")
  	- [X] External user E (Experience Cloud, has "Google Cloud Client User")
  	- [X] Admin user (has "Google Cloud Client Admin" or the combined Permission Group)
- [X] Ensure at least two files exist on the record:
  	- [X] File F1 created/owned by internal user A
  	- [X] File F2 created/owned by internal user B
- [X] Ensure at least one file type that previews and one that does not preview are available

## Full Validation Suite

### Permissions and Role Boundaries

- [ ] User permission set enables operational features (files can be uploaded/previewed)
- [ ] Admin permission set enables configuration pages but does not grant day-to-day file operations
- [ ] Non-admin user cannot access admin configuration application/pages

### Admin Configuration and Integration

- [ ] Admin can open Google Client application
- [ ] Admin can configure Google Drive integration (authentication / connection)
- [ ] Admin can configure Drive folder setup and organization rules
- [ ] Admin can modify and save other metadata/configuration

### Component Entry Points (Core Cloud)

Uploader Component

- [ ] Component renders without errors on a Lightning record page
- [ ] Upload succeeds when the user has record access and operational permissions
- [ ] Upload of multiple files succeeds
- [ ] Large file upload succeeds
- [ ] Clicking a file opens Preview

Attachments Component

- [ ] Component renders without errors on a Lightning record page
- [ ] Upload succeeds when the user has record access and operational permissions
- [ ] View All opens the full list page
- [ ] Clicking a file opens Preview

View All Page

- [ ] Page renders without errors
- [ ] Search works
- [ ] Refresh works
- [ ] Clicking a file opens Preview

### Component Entry Points (Experience Cloud)

- [ ] Uploader component renders without errors
- [ ] Attachments component renders without errors
- [ ] View All navigation works
- [ ] Clicking a file opens Preview

### Access Computation (Record-Based)

For record-linked components (Uploader / Attachments):

- [ ] User with No access to the record cannot see the record page and cannot access record-linked file lists
- [ ] User with Read access to the record sees eligible files and receives View access level in Preview
- [ ] User with Edit access to the record sees eligible files and receives Edit access level in Preview

### Preview Window (Base)

- [ ] Preview opens from each entry point (Uploader / Attachments / View All / Record Page)
- [ ] Preview closes correctly
- [ ] Download works for users with at least View access
- [ ] Non-previewable file shows a message but still offers allowed actions

### Preview Actions (Ownership and Access Level)

Owner behavior

- [ ] Owner opens Preview and sees Edit-level actions
- [ ] Owner can edit file details (name, description)
- [ ] Owner can upload a new version
- [ ] Owner can delete the file
- [ ] Owner can open Share modal
- [ ] Owner can open Public Link modal

Non-owner behavior (not shared directly)

- [ ] Non-owner opens Preview and sees View-only behavior
- [ ] Edit details are not available
- [ ] Upload new version is not available
- [ ] Delete is not available
- [ ] Share is not available
- [ ] Public Link is not available

### Direct Sharing (Internal Users, Groups, Queues)

- [ ] Owner shares file with internal user as Viewer
- [ ] Internal user opens Preview and has View access (download allowed; edit/version/delete not available)
- [ ] Owner shares file with internal user as Collaborator
- [ ] Internal user opens Preview and has Edit access (version upload/edit details available as expected)
- [ ] Owner shares file with a group/queue and membership grants access as expected
- [ ] If multiple shares apply, highest access level is used (Viewer + Collaborator => Collaborator)

### External Visibility Toggle and Experience Cloud Access

Precondition: file is linked to a Salesforce record.

- [ ] External user does not see the file by default
- [ ] Owner opens Share modal and enables visibility for the related record (external visibility toggle)
- [ ] External user sees the file after visibility is enabled

External access behaviors

- [ ] External user access mode set to Viewer results in read-only behavior
- [ ] External user access mode set by record access enforces:
  - [ ] Record Edit => Edit behavior in Preview
  - [ ] Record Read => View behavior in Preview

### Public Links

- [ ] Owner creates a public link from Preview
- [ ] Expiration date can be set
- [ ] Link opens without Salesforce login in a separate tab
- [ ] Access can be revoked and link stops working
- [ ] Expired links no longer work (after expiration)

### Versioning

- [ ] Collaborator uploads a new version and latest becomes active
- [ ] Prior versions remain available
- [ ] Access permissions are preserved after new version upload
- [ ] Versions panel can open older versions for preview/download

## Quick Regression Suite

Use this when changes are small and isolated, but you still want confidence across the main flows.

### Core Flow (Happy Path)

- [X] Upload a file and confirm it appears in the list
- [X] Open Preview and confirm download works
- [X] Create a new version and confirm it becomes active
- [X] Share with an internal user as Viewer and confirm read-only behavior

### External Visibility Sanity

- [X] Confirm external user does not see files by default
- [X] Enable external visibility via Share modal toggle and confirm external user can see the file
- [X] Confirm Viewer behavior for external user

### Admin Configuration Sanity (if release touched config)

- [X] Admin can open configuration pages
- [X] Admin can save a configuration change

## Targeted Regression Suite

Use this when you want to validate what was added/changed, without running a full suite.

<br>