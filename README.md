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
> This open-source project can be backed by an enterprise support plan for production use, including hands-on setup, security guidance, troubleshooting, and prioritized feature extensions delivered in an upgrade-safe way. Contact [opensupport@cloudrylabs.com](mailto:opensupport@cloudrylabs.com) for details.

**Salesforce Google Client** is an intelligent, server-to-server integration between Salesforce and Google Cloud, designed to simplify file management, reduce Salesforce storage costs, and make Google Drive files behave like native Salesforce files.

At its core, this project allows you to connect Salesforce to Google Drive and work with files **exactly as if they were standard Salesforce Files** — upload, preview, details, share, generate public links  — while the actual files live securely inside Google Workspace. From a user perspective, there is no visible difference: files feel fully native to Salesforce, even though they are powered by Google Cloud.

Beyond cost optimization, the client addresses long-standing limitations of Salesforce Files:
- True document previews (not image-based rendering)
- Full document interaction (signing, text selection, printing, copying)
- Built-in Google Cloud virus scanning
- Enterprise-grade security and auditing
- Detailed usage and access reporting on the Google Cloud side
- Secure public link generation

## Installation

This client depends on two required packages, which **must be installed first**:

1. **Nebula Logger** → https://github.com/jongpie/NebulaLogger

2. **Apex Google Drive Library** → https://github.com/sandriiy/salesforce-google-drive-library

Once both dependencies are installed, you can install the Salesforce Google Client package:

`sf package install --wait 20 --security-type AdminsOnly --package 04tJ80000011MDsIAM`

<br>
<div align="center" style="display: flex; justify-content: space-between;">
  <a href="https://test.salesforce.com/packaging/installPackage.apexp?p0=04tJ80000011MDsIAM">
    <img src="https://img.shields.io/badge/Install%20In%20Sandbox-blue?style=for-the-badge&logo=salesforce" alt="Install the Unlocked Package in Sandbox">
  </a>
  <a href="https://login.salesforce.com/packaging/installPackage.apexp?p0=04tJ80000011MDsIAM">
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