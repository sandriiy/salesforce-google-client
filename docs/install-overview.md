# Install & Upgrade

Google Client for Salesforce is an unlocked package. Installing it and upgrading it are the same action — you install the newer version over the org you already have, and your configuration is left alone.

## Dependencies

Two packages are required **before** installing or upgrading Google Client for Salesforce.

- [**Nebula Logger**](https://github.com/jongpie/NebulaLogger){ target="_blank" rel="noopener noreferrer" } v4.16.5 or later, providing structured logging and troubleshooting visibility across the app.
- [**Apex Google Drive Library**](https://github.com/sandriiy/salesforce-google-drive-library){ target="_blank" rel="noopener noreferrer" } v1.2.4 or later, providing the underlying Google Drive API integration and authorization flow that this client builds on.

If you already have them, confirm the installed versions meet the minimums above. A newer Google Client release may depend on newer versions of these packages, and installing over an older dependency is the most common reason an upgrade fails.

## Install the Latest Version

<div class="page-actions" markdown>
[Install in Sandbox](https://test.salesforce.com/packaging/installPackage.apexp?p0=04tQy000000XoFlIAK){ .md-button .md-button--primary target="_blank" rel="noopener noreferrer" }
[Install in Production](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tQy000000XoFlIAK){ .md-button target="_blank" rel="noopener noreferrer" }
</div>

Or via CLI:

```bash
sf package install --wait 20 --security-type AdminsOnly --package 04tQy000000XoFlIAK
```

## Upgrading an Existing Org

Upgrades are designed to be uneventful. Install the new version over the old one — there is no uninstall step, and nothing is migrated by hand.

- **Your configuration is never overwritten.** Settings you have saved stay exactly as they are.
- **New settings arrive empty, and that is correct.** A blank setting means "behave as before". Google Client keeps doing what it did until you deliberately turn something on.
- **New features arrive switched off** when they change existing behavior, so an upgrade does not surprise your users.

After upgrading, open the **Google Client** app once. Anything new worth your attention is surfaced there, and the release notes tell you what to look for.

📘 See the [Changelog](changelog.md) for what changed in each version.

## Previous Versions

Every released version stays installable. You would normally only need one of these to reproduce an issue on the version an org is actually running, or to line a sandbox up with production before testing an upgrade.

| Version | Released | Package Id |
|---|---|---|
| **2.1.0** *(latest)* | 2026-08-05 | `04tQy000000XoFlIAK` |
| 2.0.0 | 2026-06-14 | `04tQy000000W3Z3IAK` |
| 1.3.2 | 2026-06-08 | `04tQy000000VyHdIAK` |
| 1.3.1 | 2026-04-27 | `04tJ80000011MVpIAM` |
| 1.3.0 | 2026-04-26 | `04tJ80000011MVaIAM` |
| 1.2.0 | 2026-02-26 | `04tJ80000011MKfIAM` |
| 1.1.0 | 2026-01-18 | `04tJ80000011MEqIAM` |
| 1.0.0 | 2025-12-30 | `04tJ80000011MDsIAM` |

Install any of them by putting the package Id into the CLI command above, or into an install URL:

```
https://login.salesforce.com/packaging/installPackage.apexp?p0=<package Id>
```

!!! warning
    Unlocked packages cannot be downgraded. Once an org is on a newer version, installing an older one over it is not possible — restoring the earlier version means uninstalling the package, which removes its data. Test upgrades in a sandbox.

<br>
