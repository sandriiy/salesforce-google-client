# Getting Started

Work through these steps in order. Everything up to **Give people access** is required, and the rest depends on what you need. Each step links to the page with the full instructions.

## 1. Check what you need

Confirm your org and your Google account meet the requirements, then install the package and its dependencies.

- [Prerequisites](../prerequisites.md) lists what you need on the Salesforce and Google side before you begin.
- [Install & Upgrade](../install-overview.md) has the required dependency packages and the install links.

## 2. Connect Google

These three pages are the core setup. Complete them in this order, because each one uses something the previous step produced.

1. [Configure Service Account & APIs](../setup/setup-service-account.md): create the Google Cloud identity Salesforce signs in as, and enable the APIs it uses.
2. [Configure Certificate](../setup/configure-certificate.md): turn the service account key into a JKS keystore and upload it to Salesforce.
3. [Configure Google Workspace](../setup/configure-drive.md): connect Google Drive in the Google Client app and choose where files are stored.

Once these are done, file management works end to end: upload, preview, sharing, versioning and public links.

## 3. Give people access

Nobody can use Google Client until they are assigned a permission set.

- [Permissions](../setup/permissions.md) explains which permission set to give administrators and which to give everyday users.

## 4. Put the components on pages

Google Client ships Lightning components that you place on record pages and app pages yourself.

- [Configure Components (Core Clouds)](../usage/core-clouds.md) covers Sales Cloud, Service Cloud, custom apps and standard record pages.
- [Configure Components (Experience Cloud)](../usage/experience-cloud.md) covers LWR and Aura sites, which need two pages of their own.
- [Uploader in Screen Flows](../features/flows-automation/uploader-screen-flows.md) collects uploads inside a screen flow, with Flow actions beside it for folders, uploads, downloads, file text and access checks.

## 5. Optional: AI & Intelligence

Adds document summaries, file Q&A and automatic labels. Everything else works without it.

- [Configure AI & Intelligence](../setup/configure-intelligence.md) connects Gemini or Agent Platform.

## 6. Tune how files are handled

Optional settings that change how Google Client stores and transfers files. All of them are safe to leave alone.

- [Folder Structure](folder-structure.md) organizes uploads in Google Drive by user, by record or both, and sets how those folders are named.
- [Multiple Upload Folders](multiple-drives.md) adds fallback destinations, so uploads keep working when a drive reaches its capacity limit.
- [Google Workspace Folder](workspace-copies-folder.md) keeps the copies made for previews, AI and Download As out of record folders.
- [Direct Browser Upload](direct-browser-upload.md) sends large files from the browser straight to Google Drive for noticeably faster uploads.

## 7. Fine-tune the rest

The **Advanced** screen in the Google Client app holds everything else, grouped into four tabs. Nothing here is required.

- [File Management](advanced/file-management.md): Store files only, upload transport, Open in Google Drive, file size, deletion and public link scope.
- [User Interface](advanced/user-interface.md): which columns appear in File Explorer.
- [AI Intelligence](advanced/ai-intelligence.md): prompts, how long summaries and answers may be, and automatic labeling.
- [Safety & Customization](advanced/safety-customization.md): how strictly AI questions and answers are inspected.

## Where to go next

- [Features](../features/preview.md) shows what Google Client can do once it is running.
- [Security](../security.md) explains how access to files is decided.
- [Known Issues & Fixes](../help/known-issues.md) and the [FAQ](../help/faq.md) help when something is not behaving as expected.

<br>
