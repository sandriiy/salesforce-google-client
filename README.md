<div align="center">

<p>
<a href="https://github.com/sandriiy/salesforce-google-client/issues/new?labels=bug&template=bug_report.md" target="_blank" rel="noopener noreferrer"><img src="https://img.shields.io/badge/🐛%20Report%20Bug-red?style=for-the-badge" alt="Report Bug"></a>
&nbsp;&nbsp;
<a href="https://github.com/sandriiy/salesforce-google-client/issues/new?labels=enhancement&template=feature_request.md" target="_blank" rel="noopener noreferrer"><img src="https://img.shields.io/badge/✨%20Request%20Feature-green?style=for-the-badge" alt="Request Feature"></a>
</p>

<p>
<a href="https://github.com/sandriiy/salesforce-google-client/watchers" target="_blank" rel="noopener noreferrer"><img src="https://img.shields.io/github/watchers/sandriiy/salesforce-google-client.svg?style=social" alt="Watch on GitHub"></a>
<a href="https://github.com/sandriiy/salesforce-google-client/stargazers" target="_blank" rel="noopener noreferrer"><img src="https://img.shields.io/github/stars/sandriiy/salesforce-google-client.svg?style=social" alt="Star on GitHub"></a>
</p>

</div>

<br />

## <span id="getting-started">Getting Started</span>

**Salesforce Google Client** is a lightweight, server-to-server connector between Salesforce and Google Cloud, built to simplify file management, eliminate unnecessary storage costs, and bring the full power of Google Workspace into your Salesforce environment without disrupting existing workflows.

It works as a transparent layer — files live in Google Drive and appear inside Salesforce exactly like native attachments. Your team can upload, preview, share, manage versions, and generate public links without ever leaving Salesforce, while the actual files remain securely in Google Workspace.

There is no visible difference for end users, and no changes to how files move through your business.

<br />

## What it delivers

**Salesforce Google Client** lets you use Google Drive as the file storage layer for Salesforce while keeping the experience native for end users. Your team can continue working with files from Salesforce records, but the actual documents live in Google Workspace instead of Salesforce storage.

### Core capabilities

- Store Salesforce files in Google Drive to reduce storage costs
- Upload, preview, download, replace, and version files from Salesforce records
- Preview Google Drive files directly from Salesforce records
- Organize files automatically in Google Drive using configurable folder structures
- Use files in Salesforce apps, Screen Flows, and Experience Cloud
- Share files with users, groups, queues, and Experience Cloud users
- Create public links with optional Google Workspace domain restrictions
- Enforce Salesforce-based access before users can open, share, or modify files
- Support compliance needs with audit logging, reports, and file activity visibility
- Use Gemini integration to bring AI-powered file processing into business workflows

<br />

## Installation

This client depends on two required packages, which **must be installed first**: <a href="https://github.com/jongpie/NebulaLogger" target="_blank" rel="noopener noreferrer"><strong>Nebula Logger</strong></a> and <a href="https://github.com/sandriiy/salesforce-google-drive-library" target="_blank" rel="noopener noreferrer"><strong>Apex Google Drive Library</strong></a>. Once both dependencies are installed, you can install the Salesforce Google Client package.

### Install the package

<div align="center">

<p><strong>Sandbox Installation</strong></p>

<p>Use this option to test Google Client for Salesforce before installing it in production.</p>

<p>
<a href="https://test.salesforce.com/packaging/installPackage.apexp?p0=04tQy000000VyHdIAK" target="_blank" rel="noopener noreferrer"><img src="https://img.shields.io/badge/Install%20Google%20Client%20for%20Salesforce-Sandbox-0176D3?style=for-the-badge&logo=salesforce&logoColor=white" alt="Install Google Client for Salesforce in Sandbox" height="52"></a>
</p>

<br />

<p><strong>Production Installation</strong></p>

<p>Use this option when you are ready to install the package in your production org.</p>

<p>
<a href="https://login.salesforce.com/packaging/installPackage.apexp?p0=04tQy000000VyHdIAK" target="_blank" rel="noopener noreferrer"><img src="https://img.shields.io/badge/Install%20Google%20Client%20for%20Salesforce-Production-0176D3?style=for-the-badge&logo=salesforce&logoColor=white" alt="Install Google Client for Salesforce in Production" height="52"></a>
</p>

</div>

<br />

### CLI Installation

```bash
sf package install --wait 20 --security-type AdminsOnly --package 04tQy000000VyHdIAK
```

<br />

## Usage Guide

Comprehensive documentation is available via GitHub Pages and provides step-by-step guidance for setting up and using Salesforce Google Client in real-world environments. Read the full setup and usage guide here:

### <a href="https://sandriiy.github.io/salesforce-google-client/" target="_blank" rel="noopener noreferrer">Salesforce Google Client Documentation</a>

<br />

> [!NOTE]
> Need help with setup, configuration, or questions about the client? Reach out to <a href="mailto:ansukhetskyi@cloudrylabs.com" target="_blank" rel="noopener noreferrer">ansukhetskyi@cloudrylabs.com</a>.

<br />

## <span id="info">Acknowledgments</span>

This project builds on top of several excellent open-source tools and libraries:

- <a href="https://github.com/sandriiy/salesforce-google-drive-library" target="_blank" rel="noopener noreferrer">https://github.com/sandriiy/salesforce-google-drive-library</a>
- <a href="https://github.com/beyond-the-cloud-dev/soql-lib" target="_blank" rel="noopener noreferrer">https://github.com/beyond-the-cloud-dev/soql-lib</a>
- <a href="https://mozilla.github.io/pdf.js/" target="_blank" rel="noopener noreferrer">https://mozilla.github.io/pdf.js/</a>
- <a href="https://github.com/jongpie/NebulaLogger" target="_blank" rel="noopener noreferrer">https://github.com/jongpie/NebulaLogger</a>
