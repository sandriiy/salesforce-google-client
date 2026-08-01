# Direct Browser Upload

Large files normally travel to Google Drive in two hops: the browser sends each chunk to Salesforce, and Apex forwards it to Google. Direct Browser Upload removes the middle hop. Apex still opens and confirms the upload, but the file content goes straight from the browser to Google Drive.

This setting is **off by default**. Until an administrator turns it on, uploads behave exactly as they always have.

## Why It Is Faster

On the standard path every byte crosses the network twice, and the browser must Base64-encode each chunk first, which inflates it by about a third. Chunks are also limited to 2 MB because a larger chunk would exceed the Apex heap limit.

Sending the bytes directly removes the Base64 inflation, removes the second hop entirely, and allows much larger chunks. A 100 MB upload moves roughly 233 MB across the network on the standard path versus 100 MB directly, and uses 2 Apex transactions instead of about 50.

## What Does Not Change

Direct Browser Upload only changes how file content reaches Google Drive. Everything else is identical:

- The security model, and who can see or edit the file
- Folder structure, including per-user and per-record folders
- The Salesforce records created for the file, its version, and its record links
- Versioning, preview generation, and AI summaries
- Files under 2 MB, which continue to use the standard upload

## Prerequisite: CSP Trusted Site

For the browser to talk to Google directly, Salesforce must allow it. Google Client ships a CSP Trusted Site named **GoogleDriveDirectUpload** that permits browser connections to `https://www.googleapis.com`.

It relaxes only the `connect-src` directive for that one address, and no upload uses it until the setting below is turned on. The record is part of the package, so a package upgrade restores it if it is changed or deactivated.

## Enabling It

1. Open the **Google Client** app
2. Go to **Advanced → File Management**
3. Turn on **Direct Browser Upload**
4. Save
5. Select **Test connection**

The test opens a real upload session, sends a small chunk, and cancels the session, so no file is created in Google Drive. A successful test confirms the service account, the upload folder, and the browser connection all work together.

If the test reports that the browser could not reach Google, check that the **GoogleDriveDirectUpload** CSP Trusted Site exists and is active in Setup.

## When an Upload Cannot Be Sent Directly

Nothing is lost if a direct upload does not complete. Transient network errors are retried automatically, and if the upload still cannot finish, the user is offered a retry that uses the standard upload path:

- In the **Uploader**, the retry appears on the file card itself
- In the **Attachments** and **File Explorer** upload window, the retry appears at the bottom of the window

Once the user accepts a retry, the rest of that browser session uses the standard path automatically, so a misconfigured org does not prompt on every file.

Failed and recovered uploads are recorded through the logging framework with the `Google Client for Salesforce` tag, so administrators can see them on the Analytics dashboard.

## Experience Cloud

Direct Browser Upload works on Experience Cloud sites. The shipped CSP Trusted Site applies to all contexts, so no additional configuration is required.

<br>
