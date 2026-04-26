# Prerequisites

## Before you begin

You’ll need:

- A Salesforce org where you can install unlocked packages
- Access to your own Google Cloud project and an administrator who can create a service account and activate the APIs.
- Basic command-line tools for certificate generation (includes: [OpenSSL](https://slproweb.com/products/Win32OpenSSL.html){ target="_blank" rel="noopener noreferrer" }, [Java JDK](https://www.oracle.com/java/technologies/javase/jdk17-archive-downloads.html){ target="_blank" rel="noopener noreferrer" }, [jq](https://jqlang.org/download/){ target="_blank" rel="noopener noreferrer" })

## What you’ll set up

1. Install the required dependency packages and the Google Client package ([click here](setup/install-and-dependencies.md))
2. Create a Google Cloud Service Account and enable the necessary APIs ([click here](setup/setup-service-account.md))
3. Generate a JKS certificate and upload it to Salesforce ([click here](setup/configure-certificate.md))
4. Assign the **Google Cloud Client Admin** permission set ([click here](setup/configure-drive.md))
5. Open the **Google Client** app ([click here](setup/configure-drive.md))
6. Configure Google Workspace connection — make sure **Google Drive** is selected ([click here](setup/configure-drive.md))
7. Assign the **Google Cloud Client User** permission set to users ([click here](setup/permissions.md))
8. **Optional:** Connect Gemini API or Agent Platform to enable analytics, policy checks, smart labeling, and more ([click here](setup/configure-intelligence.md))

<br>
Once configuration is complete, refer to the [Usage](usage/core-clouds.md) section to understand which features are available in the Lightning Experience and Experience Cloud. Any additional manual steps required for Experience Cloud are also mentioned there.
<br>