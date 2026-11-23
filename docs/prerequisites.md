# Prerequisites

## Before you begin

You need:

- A Salesforce org where you can install unlocked packages
- Your own Google Cloud project, and an administrator who can create a service account and enable APIs
- Three command-line tools to generate the certificate: [OpenSSL](https://slproweb.com/products/Win32OpenSSL.html){ target="_blank" rel="noopener noreferrer" }, the [Java JDK](https://www.oracle.com/java/technologies/javase/jdk17-archive-downloads.html){ target="_blank" rel="noopener noreferrer" } and [jq](https://jqlang.org/download/){ target="_blank" rel="noopener noreferrer" }

## What you will set up

1. [Install](install-overview.md) the required dependency packages and the Google Client package.
2. [Create a Google Cloud service account](setup/setup-service-account.md) and enable the APIs it uses.
3. [Generate a JKS certificate](setup/configure-certificate.md) and upload it to Salesforce.
4. Assign yourself the **Google Cloud Client Admin** permission set, open the **Google Client** app and [connect Google Drive](setup/configure-drive.md).
5. Assign the **Google Cloud Client User** permission set to the people who work with files, as described in [Permissions](setup/permissions.md).
6. **Optional:** [connect Gemini or Agent Platform](setup/configure-intelligence.md) for document summaries, file Q&A and automatic labels.

Once configuration is complete, [place the components](usage/core-clouds.md) on your Lightning pages. An [Experience Cloud site](usage/experience-cloud.md) needs a few extra steps, described on its own page.

<br>
