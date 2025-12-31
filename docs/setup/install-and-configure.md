# Install & Configure

Once dependencies are installed and auth is ready, install **Salesforce Google Client**.

## Install

Package install command:
```bash
sf package install --wait 20 --security-type AdminsOnly --package 04tJ80000011MDsIAM
```

## Configure in the Google Client App

Before configuring the application, the administrator must grant themselves access to the app.

### Step 1: Assign Admin Permissions

1. Assign the **Google Cloud Client Admin** permission set to your user.
2. This permission grants access to the **Google Client** application and configuration features.

### Step 2: Open the Google Client Application

After permissions are assigned:

1. Open the **Google Client** application from the App Launcher.
2. You will land on the **Home** page, which displays:

<ul>
  <li>Current configuration status</li>
  <li>Authentication setup details</li>
  <li>Validation messages for missing or incomplete settings</li>
</ul>

### Step 3: Configure Authentication (Apex Authorizer)

The Google Client uses an **Apex-based authorization flow**. You must explicitly provide an Apex class responsible for issuing access tokens.

1. Create a new Apex class that implements the library’s authorization contract.
2. Reference this class in the **Custom Google Authorizer Class** field of the Google Client app.

📘 Reference documentation: [Library Authorization Flow](https://github.com/sandriiy/salesforce-google-drive-library/wiki/Library-Authorization-Flow)

📘 Certificate setup (use the certificate created earlier): [Service Account Setup](google-cloud.md)

### Step 4: Complete Application Configuration

After authentication is configured:

1. Provide the **Google Drive Folder ID**.
2. Leave all other settings unchanged unless you have specific requirements.

### Recommended Folder Strategy

- Use a **Shared Drive** for centralized, team-managed access.
- Maintain a dedicated root folder per environment (**Dev / UAT / Prod**).
