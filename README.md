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
> [!NOTE]
> Have an idea, want to collaborate, or just need a hand with something? Please reach out at [ansukhetskyi@cloudrylabs.com](mailto:ansukhetskyi@cloudrylabs.com).

**Salesforce Google Client** is a lightweight, server-to-server connector between Salesforce and Google Cloud, built to simplify file management, eliminate unnecessary storage costs, and bring the full power of Google Drive into your Salesforce environment without disrupting existing workflows.

It works as a transparent layer — files live in Google Drive and appear inside Salesforce exactly like native attachments. Your team can upload, preview, share, manage versions, and generate public links without ever leaving Salesforce, while the actual files remain securely in Google Workspace. There is no visible difference for end users, and no changes to how files move through your business.

For organizations looking to modernize their document experience, the client delivers:
- True document previews with full interaction (text selection, printing, signing)
- File versioning and folder structure management
- Sharing controls and secure public link generation
- Automated upload workflows via Screen Flows
- Built-in Google Cloud virus scanning
- Enterprise-grade audit trails and access reporting
- AI-powered file processing through Gemini integration
- End-to-end security aligned with Google Cloud standards

## Installation

This client depends on two required packages, which **must be installed first**:

1. **Nebula Logger** → https://github.com/jongpie/NebulaLogger

2. **Apex Google Drive Library** → https://github.com/sandriiy/salesforce-google-drive-library

Once both dependencies are installed, you can install the Salesforce Google Client package:

`sf package install --wait 20 --security-type AdminsOnly --package 04tJ80000011MVaIAM`

<br>
<div align="center" style="display: flex; justify-content: space-between;">
  <a href="https://test.salesforce.com/packaging/installPackage.apexp?p0=04tJ80000011MVaIAM">
    <img src="https://img.shields.io/badge/Install%20In%20Sandbox-blue?style=for-the-badge&logo=salesforce" alt="Install the Unlocked Package in Sandbox">
  </a>
  <a href="https://login.salesforce.com/packaging/installPackage.apexp?p0=04tJ80000011MVaIAM">
    <img src="https://img.shields.io/badge/Install%20In%20Production-blue?style=for-the-badge&logo=salesforce" alt="Install the Unlocked Package in Production">
  </a>
</div>

## Usage Guide

Comprehensive documentation is available via GitHub Pages and provides step-by-step guidance for setting up and using Salesforce Google Client in real-world environments.

Documentation URL: https://sandriiy.github.io/salesforce-google-client/

## <span id="info">Acknowledgments</span>

* https://github.com/sandriiy/salesforce-google-drive-library
* https://github.com/beyond-the-cloud-dev/soql-lib
* https://mozilla.github.io/pdf.js/
* https://github.com/jongpie/NebulaLogger
