# FAQ

Have a question that isn't answered here?
Open a [GitHub issue](https://github.com/sandriiy/salesforce-google-client){ target="_blank" rel="noopener noreferrer" } or reach out directly at [ansukh@astertrail.com](mailto:ansukh@astertrail.com).

---

??? question "Why Google Client for Salesforce?"

    Salesforce Files was never built for scale. It works, until it doesn't.

    The core problem is how Salesforce calculates file storage:

    > **Total File Storage = 10 GB + (2 GB × number of eligible users)**

    The word *eligible* matters. Internal users add 2 GB each, but many license types, including Experience Cloud and community licenses, add **nothing**, even though the files those users upload count against the same org-wide limit. Your storage fills up far faster than your allowance grows.

    This is especially common in Experience Cloud orgs, where high-volume external users consume storage without adding to it. Once you hit the limit, Salesforce sells you more at a significant cost.

    **Google Client for Salesforce solves this** by moving file storage to Google Workspace, where your organization already has capacity. Files live where they belong, costs stay predictable, and the Salesforce storage limit stops being a problem.

    Beyond cost, the goal is to give people the file experience they expect inside Salesforce: previews, folders tied to records, file reuse without duplicate uploads, version history, controlled sharing with internal and external users, and a security model that follows the real access paths. Optional AI summaries, file Q&A and labels take it further by helping people understand documents without opening separate tools.

??? question "Why should I trust this solution?"

    Security is not an afterthought here. It is the foundation.

    Google Client for Salesforce has a **dedicated security layer** that governs every file interaction. Access is checked on the server for every screen and every request: if a user has no access to a record, they cannot see, retrieve or work with any file that reaches them only through it. There are no shortcuts and no direct link that skips the check.

    On the infrastructure side, **your files never leave your organization's Google Workspace**. Google Client connects your Salesforce org directly to your own Google Cloud project, through a service account you create and control. No files pass through third-party servers, no data is stored outside your environment, and no outside party has access to your content.

    That makes it a good fit for organizations working under frameworks such as **GDPR, HIPAA or SOX**. Google Client holds no certification of its own. It fits because data residency, access control and audit logging stay in your hands.

??? question "Can the same Google file be used on several Salesforce records?"

    Yes. A user can attach a Google Client file they own to another Salesforce record.

    Neither the Google Drive file nor the Google Client file is duplicated. Salesforce stores an extra record link, so the same document appears wherever it belongs.

    This is useful when one document belongs to more than one Account, Opportunity, Case or custom record. Users can also see the linked records on the File Details page, limited to the records they can access.

??? question "Does linking a file to several records expose it to everyone?"

    No. A reused file still goes through the Google Client security layer.

    Access can come from ownership, direct sharing, group or queue sharing, internal or external visibility and the records the file is linked to. A user without a valid access path never gets the file.

??? question "What are these extra files in my Google Drive folder?"

    For most files (Word, Excel, CSV, PDF and images) Google Client keeps a second, Google Workspace version next to the one you uploaded. It is what makes previews of documents and spreadsheets, Download As, AI summaries, questions and labels, and reading a file's text possible.

    You have two options:

    - **Store files only**, under **Advanced** → **File Management**. No copies are made. PDFs and images keep their preview, while previews of documents and spreadsheets, Download As and AI are no longer available.
    - **Folder for Google Workspace Copies (ID)**, in the **Folder Locations** step of the Google Drive settings. Keep the copies, but in a folder of their own, so record folders hold only the files people uploaded.

    Copies that already exist stay where they are either way.

    📘 See [File Management](../config/advanced/file-management.md) and [Google Workspace Folder](../config/workspace-copies-folder.md)

??? question "Why does a record's folder in Google Drive still have its old name?"

    By default a folder keeps the name it was created with. Switch on the toggle beside **Folder Names** in the **Folder Structure** step, and the folder takes the record's current name the next time a file is added to it. Folders are never renamed in bulk.

    📘 See [Folder Structure](../config/folder-structure.md#renaming-folders)

??? question "Is AI required?"

    No. AI & Intelligence is optional.

    Upload, preview, download, sharing, public links, folder structure, file reuse and versioning all work without AI. With AI configured, files get a stored summary, people can ask questions about a file in the preview window, and new files can be labeled automatically with one of your Google Drive labels.

<br>
