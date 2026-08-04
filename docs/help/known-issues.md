# Known Issues & Fixes

If you run into something unexpected, check the list below. If your issue isn't covered, feel free to open a [GitHub issue](https://github.com/sandriiy/salesforce-google-client){ target="_blank" rel="noopener noreferrer" } or reach out directly at [ansukhetskyi@cloudrylabs.com](mailto:ansukhetskyi@cloudrylabs.com).

---

??? info ""View All" Attachments page opens and immediately closes"

    **When does it happen?**

    In some sandbox environments, clicking **"View All"** on the **Google Client: Attachments** component causes the page to open briefly and close itself automatically.

    **Root Cause**

    This happens when **Platform Cache** is unavailable. During installation, the package creates a Platform Cache Partition named **GoogleCloudClient**. If your sandbox has **0 cache storage** provisioned, screens that rely on Platform Cache may fail to load.

    **Fix**

    1. Go to **Setup**
    2. Search for **Platform Cache**
    3. Click into the partition named **GoogleCloudClient**
    4. Click **Edit**
    5. Under **Provider Free**, set: **Session Cache** = `1` and **Org Cache** = `1`
    6. Save

    This allocates minimal cache and resolves the issue.

??? info "Duplicated Google Drive folders are created for the same record"

    **When does it happen?**

    With a **Folder Structure** configured, a record can end up with more than one Drive folder (most visibly when several users upload to the same record at the same moment).

    **Root Cause**

    Google Drive's search index is *eventually consistent*: a folder that was created moments ago is not always returned by a search yet, especially on a Drive holding a large number of items. When each file resolved its own folder, the search for the next file found nothing and created a second folder.

    Google Client now resolves the folder **once per upload**, starting as soon as the files are selected so it resolves while the content is still transferring, and remembers the result in the **Platform Cache** partition named **GoogleCloudClient**. Every file in that upload reuses the same folder, so Google Client never has to ask Drive for a folder it just created.

    **Fix — allocate Org Cache**

    1. Go to **Setup**
    2. Search for **Platform Cache**
    3. Click into the partition named **GoogleCloudClient**
    4. Click **Edit**
    5. Under **Provider Free**, set: **Session Cache** = `1` and **Org Cache** = `1`
    6. Save

    Uploads and folder placement keep working correctly whether or not cache is allocated — allocating **Org Cache** is what guarantees a single folder per record.

??? info ""Google Client Config" record shows a deprecation warning after upgrading to v1.3.0"

    **When does it happen?**

    After upgrading to v1.3.0, opening the `GoogleClientConfig__mdt` record in Setup (Custom Metadata Types → Google Client Config → Manage Records) may display the following banner:

    > *This Google Client Config has been marked deprecated. You might lose any changes you make to the component if you later upgrade to a package version that restores it.*

    **Why does this happen?**

    In previous versions, the package shipped a pre-built `GoogleClient` metadata record. On every upgrade, Salesforce re-deployed it as a full overwrite — silently wiping any values you had manually configured (certificate name, service account email, API keys, etc.).

    To prevent this data loss, the record was removed from the package in v1.3.0. Salesforce marks it as deprecated because it no longer belongs to any package version — which is exactly the intent.

    **Is anything broken?**

    No. Your configuration data is intact, the app continues to work exactly as before, and no action is required. The warning is purely informational.

??? info ""Data Not Available" error during authentication or setup"

    **When does it happen?**

    You may see this message in Salesforce:

    > Data Not Available: The data you were trying to access could not be found.

    In this context, it usually means the Salesforce **Identity Provider** is not enabled for the org.

    **Fix**

    1. Go to **Setup**.
    2. Search for **Identity Provider** in Quick Find.
    3. Open **Identity Provider**.
    4. Click **Enable Identity Provider**.
    5. Click **Save**.
    6. Return to Google Client setup and try the action again.

??? info ""Certificate cannot be null" when saving and validating Google Drive configuration"

    **When does it happen?**

    This can happen the first time you save and validate Google Drive configuration in the Google Client app.

    **Root Cause**

    The configuration save and validation can run too close together. The save is still being committed when validation starts, so validation may not see the certificate information yet and returns a certificate error.

    **Fix**

    1. Save the Google Drive configuration.
    2. Wait 10-15 seconds.
    3. Click **Validate** again.
    4. If the same message appears, wait a little longer and click **Validate** again.

    After the authentication details finish saving, validation should use the new certificate information correctly.

<br>