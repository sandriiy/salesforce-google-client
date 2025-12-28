<div align="center">
  <p>
    <a href="https://github.com/sandriiy/salesforce-google-client/issues/new?labels=bug&template=bug_report.md">
      <img src="https://img.shields.io/badge/🐛%20Report%20Bug-red" alt="Report Bug">
    </a>
    <a href="https://github.com/sandriiy/salesforce-google-client/issues/new?labels=enhancement&template=feature_request.md">
      <img src="https://img.shields.io/badge/✨%20Request%20Feature-green" alt="Request Feature">
    </a>
  </p>

  [![Watch on GitHub](https://img.shields.io/github/watchers/sandriiy/salesforce-google-client.svg?style=social)](https://github.com/sandriiy/salesforce-google-client/watchers)
  [![Star on GitHub](https://img.shields.io/github/stars/sandriiy/salesforce-google-client.svg?style=social)](https://github.com/sandriiy/salesforce-google-client/stargazers)
</div>

## <span id="getting-started">Getting Started</span>

**Salesforce Google Client** is an intelligent, server-to-server integration between Salesforce and Google Cloud, designed to simplify file management, reduce Salesforce storage costs, and make Google Drive files behave like native Salesforce files.

At its core, this project allows you to connect Salesforce to Google Drive and work with files **exactly as if they were standard Salesforce Files** — upload, preview, details, share, generate public links  — while the actual files live securely inside Google Workspace. From a user perspective, there is no visible difference: files feel fully native to Salesforce, even though they are powered by Google Cloud.

Beyond cost optimization, the client addresses long-standing limitations of Salesforce Files:
- True document previews (not image-based rendering)
- Full document interaction (signing, text selection, printing, copying)
- Built-in Google Cloud virus scanning
- Enterprise-grade security and auditing
- Detailed usage and access reporting on the Google Cloud side
- Secure public link generation

Today, the focus is file management through Google Drive. Going forward, this project is designed to evolve into a broader **Google Workspace integration for Salesforce**, including deeper Workspace services and future Gemini-powered experiences.

### Data Model

The internal structure mirrors Salesforce Files:
- **Google File**
- **Google File Version**
- **Google File Link**

This design closely follows Salesforce’s native model (for example, `ContentDocument`, `ContentVersion`, and `ContentDocumentLink`), making the integration feel familiar, predictable, and fully aligned with Salesforce patterns.

### Platform Compatibility

The Salesforce Google Client has been tested with:
- Service Cloud  
- Sales Cloud  
- Experience Cloud  

It is designed to work consistently across other Salesforce Clouds as well.

## Installation

This client depends on two required packages, which **must be installed first**:

1. **Nebula Logger** → https://github.com/jongpie/NebulaLogger

2. **Apex Google Drive Library** → https://github.com/sandriiy/salesforce-google-drive-library

Once both dependencies are installed, you can install the Salesforce Google Client package:

`sf package install --wait 20 --security-type AdminsOnly --package PACKAGE_ID_PLACEHOLDER`

<br>
<div align="center" style="display: flex; justify-content: space-between;">
  <a href="SANDBOX_PACKAGE_INSTALL_URL_PLACEHOLDER">
    <img src="https://img.shields.io/badge/Install%20In%20Sandbox-blue?style=for-the-badge&logo=salesforce" alt="Install the Unlocked Package in Sandbox">
  </a>
  <a href="PRODUCTION_PACKAGE_INSTALL_URL_PLACEHOLDER">
    <img src="https://img.shields.io/badge/Install%20In%20Production-blue?style=for-the-badge&logo=salesforce" alt="Install the Unlocked Package in Production">
  </a>
</div>

## Usage Guide

Comprehensive documentation is being actively developed and will be available via GitHub Pages.

Documentation URL:  
DOCUMENTATION_URL_PLACEHOLDER

The documentation will cover:
- Google Cloud and Salesforce configuration
- Authentication and security setup
- File operations and sharing
- Public links and access control
- Common patterns, examples, and best practices

## <span id="info">Acknowledgments</span>

* https://github.com/sandriiy/salesforce-google-drive-library
* https://github.com/beyond-the-cloud-dev/soql-lib
* https://mozilla.github.io/pdf.js/
* https://github.com/jongpie/NebulaLogger