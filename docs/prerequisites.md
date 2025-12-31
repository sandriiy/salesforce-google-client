# Prerequisites

To get started with Salesforce Google Client, you’ll need access to the **Google Cloud Console** and a small set of local tools to generate a JKS certificate. The [Setup](setup/dependencies.md) page then guides you through all required configuration steps. Prior experience with Google Cloud is helpful for designing a secure Google Workspace architecture. If you need assistance or security consulting, contact [opensupport@cloudrylabs.com](mailto:opensupport@cloudrylabs.com)

## Before you begin

You’ll need:

- A Salesforce org where you can install unlocked packages
- Access to a Google Cloud project / admin who can create a Service Account
- Basic command-line tools for certificate generation (includes: [OpenSSL](https://slproweb.com/products/Win32OpenSSL.html), [Java JDK](https://www.oracle.com/java/technologies/javase/jdk17-archive-downloads.html), [jq](https://jqlang.org/download/))

## What you’ll set up

1. Install the required dependency packages ([click here](setup/dependencies.md))
2. Configure Google Cloud Console and create a Service Account certificate ([click here](setup/google-cloud.md))
3. Install this package ([click here](setup/install-and-configure.md))
4. Assign the **Google Cloud Client Admin** permission set ([click here](setup/install-and-configure.md))
5. Open the **Google Client** app ([click here](setup/install-and-configure.md))
6. Configure Salesforce authentication (Apex-based authorization flow) ([click here](setup/install-and-configure.md))
7. Assign the **Google Cloud Client User** permission set to users ([click here](setup/permissions.md))

<br>
Once configuration is complete, refer to the [Usage](usage/core-clouds.md) section to understand which features are available in the Lightning Experience and Experience Cloud. Any additional manual steps required for Experience Cloud are also mentioned there.
