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

- [X] User permission set enables operational features (files can be uploaded/previewed)
- [X] Admin permission set enables configuration pages but does not grant day-to-day file operations
- [X] Non-admin user cannot access admin configuration application/pages

### Admin Configuration and Integration

- [X] Admin can open Google Client application
- [X] Admin can configure Google Drive integration (authentication / connection)
- [X] Admin can configure Drive folder setup and organization rules
- [X] Admin can modify and save other metadata/configuration

### Component Entry Points (Core Cloud)

Uploader Component

- [X] Component renders without errors on a Lightning record page
- [X] Upload succeeds when the user has record access and operational permissions
- [X] Upload of multiple files succeeds
- [X] Large file upload succeeds
- [X] Clicking a file opens Preview

Attachments Component

- [X] Component renders without errors on a Lightning record page
- [X] Upload succeeds when the user has record access and operational permissions
- [X] View All opens the full list page
- [X] Clicking a file opens Preview

View All Page

- [X] Page renders without errors
- [X] Search works
- [X] Refresh works
- [X] Clicking a file opens Preview

### Component Entry Points (Experience Cloud)

- [X] Uploader component renders without errors
- [X] Attachments component renders without errors
- [X] View All navigation works
- [X] Clicking a file opens Preview

### Access Computation (Record-Based)

For record-linked components (Uploader / Attachments):

- [X] User with No access to the record cannot see the record page and cannot access record-linked file lists
- [X] User with Read access to the record sees eligible files and receives View access level in Preview
- [X] User with Edit access to the record sees eligible files and receives Edit access level in Preview

### Preview Window (Base)

- [X] Preview opens from each entry point (Uploader / Attachments / View All / Record Page)
- [X] Preview closes correctly
- [X] Download works for users with at least View access
- [X] Non-previewable file shows a message but still offers allowed actions

### Preview Actions (Ownership and Access Level)

Owner behavior

- [X] Owner opens Preview and sees Edit-level actions
- [ ] Owner can edit file details (name, description)
- [X] Owner can upload a new version
- [X] Owner can delete the file
- [X] Owner can open Share modal
- [X] Owner can open Public Link modal

Non-owner behavior (not shared directly)

- [X] Non-owner opens Preview and sees View-only behavior
- [X] Edit details are not available
- [X] Upload new version is not available
- [X] Delete is not available
- [X] Share is not available
- [X] Public Link is not available

### Direct Sharing (Internal Users, Groups, Queues)

- [X] Owner shares file with internal user as Viewer
- [X] Internal user opens Preview and has View access (download allowed; edit/version/delete not available)
- [X] Owner shares file with internal user as Collaborator
- [X] Internal user opens Preview and has Edit access (version upload/edit details available as expected)
- [X] Owner shares file with a group/queue and membership grants access as expected
- [X] If multiple shares apply, highest access level is used (Viewer + Collaborator => Collaborator)

### External Visibility Toggle and Experience Cloud Access

Precondition: file is linked to a Salesforce record.

- [X] External user does not see the file by default
- [X] Owner opens Share modal and enables visibility for the related record (external visibility toggle)
- [X] External user sees the file after visibility is enabled

External access behaviors

- [X] External user access mode set to Viewer results in read-only behavior
- [X] External user access mode set by record access enforces:
  - [X] Record Edit => Edit behavior in Preview
  - [X] Record Read => View behavior in Preview

### Public Links

- [X] Owner creates a public link from Preview
- [X] Expiration date can be set
- [X] Link opens without Salesforce login in a separate tab
- [X] Access can be revoked and link stops working
- [X] Expired links no longer work (after expiration)

### Versioning

- [ ] Collaborator uploads a new version and latest becomes active
- [X] Prior versions remain available
- [X] Access permissions are preserved after new version upload
- [X] Versions panel can open older versions for preview/download

## Quick Regression Suite

Use this when changes are small and isolated, but you still want confidence across the main flows.

### Core Flow (Happy Path)

- [ ] Upload a file and confirm it appears in the list
- [ ] Open Preview and confirm download works
- [ ] Create a new version and confirm it becomes active
- [ ] Share with an internal user as Viewer and confirm read-only behavior

### External Visibility Sanity

- [ ] Confirm external user does not see files by default
- [ ] Enable external visibility via Share modal toggle and confirm external user can see the file
- [ ] Confirm Viewer behavior for external user

### Admin Configuration Sanity (if release touched config)

- [ ] Admin can open configuration pages
- [ ] Admin can save a configuration change

## Changes-Only Suite

Use this when you want to validate only what was added/changed, without running a full suite.

<br>