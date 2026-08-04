# Getting Started

This page is a map, not a manual. It shows the order to work through, what each step gives you, and where the full instructions live.

Work through the steps in order. Everything up to **Give People Access** is required; the rest depends on what you need.

## 1. Check What You Need

Confirm your org and your Google account meet the requirements, and install the package along with its dependencies.

- [Prerequisites](../prerequisites.md) — what you need on the Salesforce and Google side before you begin
- [Install & Upgrade](../install-overview.md) — the required dependency packages and the install links

## 2. Connect Google

These three pages are the core setup. Complete them in this order, because each one uses something produced by the previous step.

1. [Configure Service Account & APIs](../setup/setup-service-account.md) — create the Google Cloud identity Salesforce authenticates as, and enable the APIs it uses
2. [Configure Certificate](../setup/configure-certificate.md) — convert the Service Account key into a JKS keystore and upload it to Salesforce
3. [Configure Google Workspace](../setup/configure-drive.md) — connect Drive in the Google Client app and choose where files are stored

Once these are done, file management works end to end: upload, preview, sharing, versioning, and public links.

## 3. Give People Access

Nobody can use Google Client until they are assigned a permission set.

- [Permissions](../setup/permissions.md) — which permission set to assign to administrators and to everyday users

## 4. Put the Components on Pages

Google Client ships Lightning components that you place on record pages and app pages yourself.

- [Configure Components (Core Clouds)](../usage/core-clouds.md) — Sales Cloud, Service Cloud, custom apps, and standard record pages
- [Configure Components (Experience Cloud)](../usage/experience-cloud.md) — LWR and Aura sites, which need their own pages

## 5. Optional: AI & Intelligence

Adds document summaries and file Q&A. Everything else works without it.

- [Configure AI & Intelligence](../setup/configure-intelligence.md) — connect Gemini or the Agent Platform

## 6. Tune How Files Are Handled

Optional settings that change how Google Client stores and transfers files. All of them are safe to leave alone — the defaults are what the package has always done.

- [Folder Structure](folder-structure.md) — organize uploads in Drive by user, by record, or both, instead of one flat folder
- [Multiple Upload Folders](multiple-drives.md) — add fallback destinations so uploads keep working when a drive reaches its capacity limit
- [Direct Browser Upload](direct-browser-upload.md) — send large files from the browser straight to Google Drive for noticeably faster uploads

## 7. Fine-Tune the Rest

The **Advanced** screen in the Google Client app holds everything else, grouped into four tabs. Nothing here is required.

- [File Management](advanced/file-management.md) — preview, upload transport, file size, deletion, and public link scope
- [User Interface](advanced/user-interface.md) — which columns appear in File Explorer
- [AI Intelligence](advanced/ai-intelligence.md) — prompts and answer length for summaries and questions
- [Safety & Customization](advanced/safety-customization.md) — how strictly AI questions and answers are inspected

## Where to Go Next

- [Features](../features/file-explorer.md) — what Google Client can do once it is running
- [Security](../security.md) — how access to files is decided
- [Known Issues & Fixes](../help/known-issues.md) and [FAQ](../help/faq.md) — if something is not behaving as expected

<br>
