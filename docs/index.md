# Google Client for Salesforce

Google Client for Salesforce replaces Salesforce Files with Google Drive while keeping the file experience inside Salesforce.

It solves a simple business problem: **Salesforce is where users work, but it should not be the place where every document has to live.**

<div class="page-actions" markdown>
[Get started](prerequisites.md){ .md-button .md-button--primary }
[Install the package](install-overview.md){ .md-button }
</div>

## How It Works

A user uploads a file to a Salesforce record exactly as they always have. The file is stored in Google Drive, and Salesforce keeps only a lightweight pointer to it. Back on the record, that file looks and behaves like a native Salesforce file — it can be previewed, shared, versioned, downloaded, and linked to other records without anyone leaving Salesforce or needing to know where the document physically lives.

<!-- VIDEO: swap the id below when the new overview is recorded -->

<div class="video-embed">
  <iframe src="https://www.youtube-nocookie.com/embed/cyVFIoocE4I" title="Google Client for Salesforce — product overview" loading="lazy" referrerpolicy="strict-origin-when-cross-origin" allow="accelerometer; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>
</div>

## Why It Matters

<div class="grid cards" markdown>

- **Storage pressure disappears**

    Documents live in Google Drive, so Salesforce stays focused on business data instead of filling up with attachments.

- **One file, many records**

    The same Google file can be linked to several Salesforce records, so teams reuse the right document instead of uploading a copy into every process — and can see everywhere it is used.

- **Google Drive stays organized**

    Folders can follow users, records, or both. Reused files get a Drive shortcut in the right folder rather than a duplicate.

- **A real file experience**

    Upload, attach existing files, preview large PDFs and images, download in another format, share, manage public links, and work with versions — all inside Salesforce.

- **Access follows real paths**

    Ownership, direct sharing, record access, internal or external visibility, and every linked record are all resolved together. If there is no valid path to a file, it is not exposed.

- **Documents explain themselves**

    Optional AI summaries and file Q&A help people understand a document without reading all of it, while admins keep control of the provider, prompts, and cost.

</div>

## Where to Go Next

| If you want to | Go to |
|---|---|
| See the whole path from install to live, in order | [Getting Started](config/getting-started.md) |
| Check your org and Google account are ready | [Prerequisites](prerequisites.md) |
| Install or upgrade the package | [Install & Upgrade](install-overview.md) |
| See what it can do | [Features](features/file-explorer.md) |
| Change how files are stored or shown | [Settings](config/folder-structure.md) |
| Understand how access is decided | [Security](security.md) |
| Fix something that is not behaving | [Known Issues](help/known-issues.md) · [FAQ](help/faq.md) |
| See what changed in this release | [Changelog](changelog.md) |

<br>
