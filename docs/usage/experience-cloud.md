# Configure Components (Experience Cloud)

This page explains how to use **Google Client** Lightning components in **Experience Cloud** sites.

Google Client components work in both **LWR** and **Aura-based** Experience Cloud sites.  

Experience Cloud requires additional setup compared to Core Clouds because site navigation is stricter. Google Client needs two fixed pages for View All and File Details navigation before record components can work correctly.

If you are configuring standard Salesforce Lightning record pages instead, use [Configure Components (Core Clouds)](core-clouds.md).

## Required Setup

Experience Cloud does not allow components to open arbitrary pages at runtime. For Google Client to support navigation patterns such as **View All** and **File Details**, two dedicated pages must exist in the site.

These pages act as fixed navigation targets and host internal Google Client components.

### Pages you must create

You must create **two empty Experience Cloud pages** with the following **URLs**:

<ul>
  <li>
    <strong>gview-all-files</strong>
    <ul>
      <li>Label/API can be set to something user-friendly (for example: “View All Files”).</li>
      <li>This page will be opened automatically when users click “View All”.</li>
    </ul>
  </li>
  <li>
    <strong>gfile-details</strong>
    <ul>
      <li>Label/API can be set to something user-friendly (for example: “File Details”).</li>
      <li>This page will be opened automatically when users click “View File Details“.</li>
    </ul>
  </li>
</ul>

## Step-by-step: Creating the Required Pages

<ol>
  <li>Open Salesforce and navigate to your Experience Cloud site.</li>
  <li>Click <strong>Builder</strong> to open Experience Builder.</li>
  <li>In the top-left corner, open the <strong>Pages</strong> panel.</li>
  <li>Click <strong>New Page</strong>.</li>
  <li>Select <strong>Standard Page</strong>.</li>
  <li>Click <strong>New Blank Page</strong>.</li>
  <li>Choose <strong>1 full-width column</strong> layout.</li>
  <li>Create the first page:
    <ul>
      <li>Label: View All Files (or similar)</li>
      <li>API Name: ViewAllFiles (or similar)</li>
	  <li>URL: <strong>gview-all-files</strong></li>
    </ul>
  </li>
  <li>Create the second page:
    <ul>
      <li>Label: File Details (or similar)</li>
      <li>API Name: FileDetails (or similar)</li>
	  <li>URL: <strong>gfile-details</strong></li>
    </ul>
  </li>
</ol>

## Place Required Internal Components

After creating the pages, place the required internal Google Client components on each page. These components are not the main record components your users work with directly; they are navigation targets used by Google Client after a user clicks View All or View File Details.

### Page: gview-all-files

<ul>
  <li>Open the <strong>gview-all-files</strong> page in Experience Builder.</li>
  <li>From the components panel, locate <strong>Google Client: All Attachments</strong>.</li>
  <li>Drag the component into the main content area.</li>
  <li>Use a single, wide section for best results.</li>
</ul>

### Page: gfile-details

<ul>
  <li>Open the <strong>gfile-details</strong> page in Experience Builder.</li>
  <li>From the components panel, locate <strong>Google Client: Record Page Details</strong>.</li>
  <li>Drag the component into the main content area.</li>
  <li>Use a single, wide section for best results.</li>
</ul>

After placing both components, click <strong>Publish</strong> to make the pages available. At this point, navigation used by Google Client components is fully configured.

## Components You Can Place on Record Pages

After completing the setup above, you can safely place Google Client components on record-driven Experience Cloud pages.

### Google Client: Attachments

Provides full Google Drive file management for a Salesforce record, serving as a complete replacement for Notes & Attachments.

<strong>Where it can be used</strong>
<ul>
  <li>Experience Cloud record pages</li>
</ul>

<strong>Important configuration notes</strong>
<ul>
  <li>
    <strong>recordId</strong>  
    Use <code>{!recordId}</code> to enable dynamic binding to the current record.
  </li>
  <li>
    <strong>objectApiName</strong>  
    Set this statically based on the object where the component is placed.
  </li>
</ul>

<strong>Typical use</strong>
<ul>
  <li>Main file list for records exposed in Experience Cloud.</li>
  <li>Lets external users upload new files or attach existing owned Google Client files where their access allows it.</li>
  <li>Automatically opens the “View All Files” page when needed.</li>
</ul>

### Google Client: Uploader

Provides a dedicated upload interface for adding files to Google Drive from Experience Cloud.

<strong>Where it can be used</strong>
<ul>
  <li>Experience Cloud record pages</li>
</ul>

<strong>Important configuration notes</strong>
<ul>
  <li>
    <strong>recordId</strong>  
    Use <code>{!recordId}</code> for dynamic binding.
  </li>
  <li>
    <strong>objectApiName</strong>  
    Set statically to match the record type used on the page.
  </li>
</ul>

<strong>Typical use</strong>
<ul>
  <li>Controlled upload experience for external or community users.</li>
  <li>Supports the same preview, sharing, version, and attach-existing flows when the user has the required access.</li>
</ul>

## What Users Get After Placement

Experience Cloud users work with the same Google Client security model used in Core Clouds. Access is resolved through ownership, direct sharing, record access, public link rules, internal/external visibility, and linked record associations.

Depending on their access, users can upload, attach existing owned files, preview supported files, download, share, manage public links, and open file details without leaving the site.

## Important Notes

<ul>
  <li>Both LWR and Aura Experience Cloud sites are supported.</li>
  <li>The required pages must exist before record-level components will work correctly.</li>
  <li>The page URLs must match exactly: <code>gview-all-files</code> and <code>gfile-details</code>.</li>
  <li>Record context must be provided using <code>{!recordId}</code>.</li>
</ul>