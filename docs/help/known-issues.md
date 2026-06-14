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

??? info ""Google Client Config" record shows a deprecation warning after upgrading to v1.3.0"

    **When does it happen?**

    After upgrading to v1.3.0, opening the `GoogleClientConfig__mdt` record in Setup (Custom Metadata Types → Google Client Config → Manage Records) may display the following banner:

    > *This Google Client Config has been marked deprecated. You might lose any changes you make to the component if you later upgrade to a package version that restores it.*

    **Why does this happen?**

    In previous versions, the package shipped a pre-built `GoogleClient` metadata record. On every upgrade, Salesforce re-deployed it as a full overwrite — silently wiping any values you had manually configured (certificate name, service account email, API keys, etc.).

    To prevent this data loss, the record was removed from the package in v1.3.0. Salesforce marks it as deprecated because it no longer belongs to any package version — which is exactly the intent.

    **Is anything broken?**

    No. Your configuration data is intact, the app continues to work exactly as before, and no action is required. The warning is purely informational.

??? info "Uploader maximum file count is not enforced when attaching existing files"

    **When does it happen?**

    If the **Google Client: Uploader** component has a maximum file count configured, uploading new files respects that limit. However, attaching existing files can allow users to link more files than the configured maximum.

    **Impact**

    This affects the Uploader component limit only. File access, ownership checks, record access checks, preview, sharing, and Google Drive storage behavior continue to work normally.

    **Workaround**

    Use the Attachments component when strict record file count control is required, or review linked files from the record after users attach existing files. This limitation is tracked for a future release.