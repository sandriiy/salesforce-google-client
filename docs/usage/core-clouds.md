# Configure Components (Core Clouds)

This page explains how Salesforce administrators add Google Client components to standard Salesforce Lightning pages.

Use this page when you are configuring **Sales Cloud, Service Cloud, custom Lightning apps, or any standard Lightning record page**. Experience Cloud has a different setup because it requires fixed navigation pages, so it is covered separately: [Configure Components (Experience Cloud)](experience-cloud.md).

All placeable Google Client components are added using the Lightning App Builder.

<ol>
  <li>Open Salesforce in Lightning Experience.</li>
  <li>Navigate to the page where you want to add components:
    <ul>
      <li><strong>Home page</strong></li>
      <li><strong>App page</strong></li>
      <li><strong>Record page</strong></li>
    </ul>
  </li>
  <li>Click the ⚙️ Setup icon in the top-right corner.</li>
  <li>Select <strong>Edit Page</strong>.</li>
</ol>

This opens the Lightning App Builder, where you can drag and configure components.

## Components You Can Place

Below is the list of components administrators should place manually, referenced by their visible labels in Lightning App Builder.

### Google Client: Attachments

Provides full Google Drive file management for a Salesforce record in a familiar Notes & Attachments–style list.

<strong>Where it can be used</strong>
<ul>
  <li>Record Pages</li>
</ul>

<strong>Configurable properties</strong>
<ul>
  <li><strong>Icon</strong> — Icon shown in the component header.</li>
  <li><strong>Title</strong> — Component title.</li>
  <li><strong>Visible files count</strong> — Number of files shown before “View All” is required.</li>
  <li><strong>Allow multiple files</strong> — Enables multi-file selection.</li>
  <li><strong>Allowed file types</strong> — File extensions allowed for upload.</li>
  <li><strong>Maximum file size (MB)</strong> — Upload size limit per file.</li>
</ul>

<strong>Typical use</strong>
<ul>
  <li>Replaces Salesforce Files for record attachments while storing the documents in Google Drive.</li>
  <li>Lets users upload new files or attach existing owned Google Client files to the record.</li>
  <li>Opens preview, sharing, public link, versioning, and file details flows from one familiar record component.</li>
</ul>

### Google Client: Uploader

Provides a dedicated upload interface for adding files to Google Drive from Salesforce. <strong>This component is available for use in Screen Flows since version 1.1.</strong>

<strong>Where it can be used</strong>
<ul>
  <li>Record Pages</li>
</ul>

<strong>Configurable properties</strong>
<ul>
  <li><strong>Supported file extensions</strong> — Allowed upload types.</li>
  <li><strong>Maximum file size (MB)</strong> — Upload size limit.</li>
  <li><strong>Allow multiple files</strong> — Enables bulk uploads.</li>
  <li><strong>Maximum file count</strong> — Limits the number of files per upload.</li>
</ul>

<strong>Typical use</strong>
<ul>
  <li>Replaces Salesforce Files with a dedicated upload experience for a specific record, including support for limiting the number of files (for example, one file per record).</li>
  <li>Allows users to attach existing owned Google Client files when the component is used on a record page.</li>
</ul>

## Components not available for direct placement

The following components cannot be added manually in Lightning App Builder.

<ul>
  <li>Google Client: Record Page Details</li>
  <li>Preview, sharing, public link, and version modules</li>
  <li>Modal dialogs for delete, sharing, public link, attach existing files, download as, and file details</li>
</ul>

These components are launched by Google Client when the user opens a file, clicks View All, attaches an existing file, edits details, shares, creates a public link, downloads in another format, or works with versions. They are intentionally hidden to keep navigation and security consistent.

## What Users Get After Placement

After the record components are placed, users can work with Google Drive files directly from the Salesforce record:

- Upload new files to Google Drive
- Attach existing owned Google Client files to the record
- Preview supported files, including large PDFs and images
- Download files or use Download As where supported
- Share files, create public links, and manage versions
- Open file details to see versions and linked Salesforce records

## Important Notes

Experience Cloud follows different placement and navigation rules. Use the [Experience Cloud guide](experience-cloud.md) when configuring a site.
<br>