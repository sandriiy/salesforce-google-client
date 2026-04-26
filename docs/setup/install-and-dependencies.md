# Install

## Dependencies

Two packages are required before installing Google Client for Salesforce. If you already have them in your org, just confirm the versions meet the minimum requirement.

- [**Nebula Logger**](https://github.com/jongpie/NebulaLogger){ target="_blank" rel="noopener noreferrer" } v4.16.5 or later, providing structured logging and troubleshooting visibility across the app.
- [**Apex Google Drive Library**](https://github.com/sandriiy/salesforce-google-drive-library){ target="_blank" rel="noopener noreferrer" } v1.2.2 or later, providing the underlying Google Drive API integration and authorization flow that this client builds on.

## Package

Install Google Client for Salesforce using one of the options below.

<div style="display: flex; justify-content: center; gap: 12px; margin-bottom: 16px;">
  <a href="https://test.salesforce.com/packaging/installPackage.apexp?p0=04tJ80000011MVaIAM" target="_blank" rel="noopener noreferrer">
    <img src="https://img.shields.io/badge/Install%20In%20Sandbox-blue?style=for-the-badge&logo=salesforce" alt="Install the Unlocked Package in Sandbox">
  </a>
  <a href="https://login.salesforce.com/packaging/installPackage.apexp?p0=04tJ80000011MVaIAM" target="_blank" rel="noopener noreferrer">
    <img src="https://img.shields.io/badge/Install%20In%20Production-blue?style=for-the-badge&logo=salesforce" alt="Install the Unlocked Package in Production">
  </a>
</div>

Or via CLI:

```bash
sf package install --wait 20 --security-type AdminsOnly --package 04tJ80000011MVaIAM
```

Once both dependencies and the package are installed, proceed to [Set Up Service Account](setup-service-account.md).

<br>