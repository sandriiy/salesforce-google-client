# Getting Started (Core Clouds)

This page explains how Salesforce administrators can add Google Client Lightning components to standard Salesforce and custom Lightning apps.

All Google Client components are added using the Lightning App Builder.

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

## Available components

Below is the list of placeable components, referenced by their visible labels as shown in Lightning App Builder.

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
  <li>Eliminates the need to use Salesforce Files when attaching files to records.</li>
</ul>

### Google Client: Uploader

Provides a dedicated upload interface for adding files to Google Drive from Salesforce.

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
</ul>

### Google Client: Record Page Details

Displays detailed information for a selected Google Drive file and supports all versions history.

<strong>Where it can be used</strong>
<ul>
  <li>Record Pages</li>
  <li>URL-addressable navigation targets</li>
</ul>

<strong>Typical use</strong>
<ul>
  <li>Used as a file detail view.</li>
  <li>Supports deep-link navigation from other components.</li>
</ul>

## Components not available for direct placement

The following components cannot be added manually in Lightning App Builder.

<ul>
  <li>Preview, sharing, public link, and version modules</li>
  <li>Modal dialogs for delete, sharing, public link, and file details</li>
</ul>

These components are intentionally hidden to ensure consistency and prevent incorrect usage.

## Important notes

Experience Cloud follows different component placement rules and is [documented separately](experience-cloud.md).
<br>