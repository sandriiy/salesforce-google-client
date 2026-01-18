# Known Issues & Fixes

Google Client for Salesforce is currently in open beta and will remain so until **March 2026**. If you encounter issues or have questions, please open a [GitHub](https://github.com/sandriiy/salesforce-google-client) issue or start a discussion. For help with customization or implementation, you may also contact **ansukhetskyi@cloudrylabs.com**, who is offering free consulting support during the beta period.

## "View All" Attachments Page Opens and Immediately Closes

In some sandbox environments, when clicking **"View All"** on the **Google Client: Attachments** component, the page may open briefly and then close itself automatically.

### **Root Cause**

This behavior may occur when **Platform Cache** is unavailable. During installation, the package creates a Platform Cache Partition named: **GoogleCloudClient**. If your Sandbox has **0 cache storage** provisioned, certain screens relying on Platform Cache may fail to load correctly.

### **Fix**

To resolve:

1. Go to **Setup**
2. Search for **Platform Cache**
3. Click into the cache partition named **GoogleCloudClient**
4. Click **Edit**
5. Under the **Provider Free** category, ensure your org has available cache
6. Set: **Session Cache** = `1` and **Org Cache** = `1`
7. Save changes

This will allocate minimal cache resources and fix the behavior.