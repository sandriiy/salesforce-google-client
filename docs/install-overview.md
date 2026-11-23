# Install & Upgrade

Google Client for Salesforce is an unlocked package. Installing it and upgrading it are the same action: you install the newer version over the org you already have, and your configuration is left alone.

## Dependencies

Two packages are required **before** you install or upgrade Google Client for Salesforce.

- [**Nebula Logger**](https://github.com/jongpie/NebulaLogger){ target="_blank" rel="noopener noreferrer" } v4.16.5 or later, which records what goes wrong so administrators can troubleshoot it.
- [**Apex Google Drive Library**](https://github.com/sandriiy/salesforce-google-drive-library){ target="_blank" rel="noopener noreferrer" } v1.3.0 or later, which provides the Google Drive connection and the sign-in to Google that this client builds on.

If you already have them, confirm the installed versions meet the minimums above. A newer Google Client release may need newer versions of these packages, and an outdated dependency is the most common reason an upgrade fails.

## Install the latest version

<div class="page-actions" markdown>
[Install in Sandbox](https://test.salesforce.com/packaging/installPackage.apexp?p0=04tQy000000byBhIAI){ .md-button .md-button--primary target="_blank" rel="noopener noreferrer" }
[Install in Production](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tQy000000byBhIAI){ .md-button target="_blank" rel="noopener noreferrer" }
</div>

Or via CLI:

```bash
sf package install --wait 20 --security-type AdminsOnly --package 04tQy000000byBhIAI
```

## Previous versions

Every released version stays installable.

| Version | Released | Package Id | Drive Library Dependency | Nebula Dependency |
|---|---|---|---|---|
| **2.4.0** *(latest)* | 2026-11-23 | `04tQy000000byBhIAI` | v1.3.0 | v4.16.5 |
| 2.3.0 | 2026-10-23 | `04tQy000000aZnFIAU` | v1.3.0 | v4.16.5 |
| 2.2.0 | 2026-09-21 | `04tQy000000ZTtZIAW` | v1.3.0 | v4.16.5 |
| 2.1.0 | 2026-08-05 | `04tQy000000XoFlIAK` | v1.2.4 | v4.16.5 |
| 2.0.0 | 2026-06-14 | `04tQy000000W3Z3IAK` | v1.2.4 | v4.16.5 |
| 1.3.2 | 2026-06-08 | `04tQy000000VyHdIAK` | v1.2.3 | v4.16.5 |
| 1.3.1 | 2026-04-27 | `04tJ80000011MVpIAM` | v1.2.3 | v4.16.5 |
| 1.3.0 | 2026-04-26 | `04tJ80000011MVaIAM` | v1.2.3 | v4.16.5 |
| 1.2.0 | 2026-02-26 | `04tJ80000011MKfIAM` | v1.2.3 | v4.16.5 |
| 1.1.0 | 2026-01-18 | `04tJ80000011MEqIAM` | v1.2.2 | v4.16.5 |
| 1.0.0 | 2025-12-30 | `04tJ80000011MDsIAM` | v1.2.2 | v4.16.5 |

Install any of them by putting the package Id into the CLI command above, or into an install URL:

```
https://login.salesforce.com/packaging/installPackage.apexp?p0=<package Id>
```

<br>
