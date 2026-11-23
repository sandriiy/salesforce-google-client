# Known Issues & Fixes

If you run into something unexpected, check the list below. If your issue isn't covered, open a [GitHub issue](https://github.com/sandriiy/salesforce-google-client){ target="_blank" rel="noopener noreferrer" } or reach out directly at [ansukh@astertrail.com](mailto:ansukh@astertrail.com).

---

??? info "The migration leaves some Salesforce Files behind"

    **When does it happen?**

    After a migration from the **Migration** tab, some Salesforce Files are still only in Salesforce, and the count the wizard showed before the run was lower than the number of files on the records.

    **Cause**

    The migration moves only Salesforce Files that are attached to at least one record and are 5 MB or smaller. Files not attached to any record, files larger than 5 MB, files stored outside Salesforce, notes and classic Attachments are outside its scope by design, and only the current version of a file is moved, never the earlier ones.

    **Fix**

    Upload the remaining files through the Google Client components, or through the **Upload File to Google Drive** flow action, which takes larger files. A file that could not be copied for another reason is picked up by running the same selection again: files already in Google Drive are skipped, so a second run only copies what the first one left.

??? info ""View All" Attachments page opens and immediately closes"

    **When does it happen?**

    In some sandboxes, clicking **View All** on the **Google Client: Attachments** component opens the page briefly and then closes it.

    **Cause**

    The page needs **Platform Cache**. The package creates a Platform Cache partition named **GoogleCloudClient**, and a sandbox with no cache storage provisioned cannot load it.

    **Fix**

    1. Go to **Setup**.
    2. Search for **Platform Cache**.
    3. Open the partition named **GoogleCloudClient**.
    4. Click **Edit**.
    5. Under **Provider Free**, set **Session Cache** to `1` and **Org Cache** to `1`.
    6. Save.

    That small allocation is enough.

??? info "A record gets more than one folder in Google Drive"

    **When does it happen?**

    With a folder structure configured, a record ends up with more than one folder in Google Drive, most often when several people upload to the same record at the same moment.

    **Cause**

    Google Drive does not always find a folder that was created moments earlier, especially on a drive that holds a large number of items. Google Client remembers the folders it creates so it never has to look them up again, and it keeps that memory in the **GoogleCloudClient** Platform Cache partition. Without Org Cache allocated, two uploads at the same moment can each create a folder.

    **Fix: allocate Org Cache**

    1. Go to **Setup**.
    2. Search for **Platform Cache**.
    3. Open the partition named **GoogleCloudClient**.
    4. Click **Edit**.
    5. Under **Provider Free**, set **Session Cache** to `1` and **Org Cache** to `1`.
    6. Save.

    Uploads and folder placement work with or without the allocation. Org Cache is what keeps each record to a single folder.

??? info ""Google Client Config" record shows a deprecation warning after upgrading to v1.3.0"

    **When does it happen?**

    After upgrading to v1.3.0, opening the Google Client Config record in Setup (Custom Metadata Types → Google Client Config → Manage Records) may show this banner:

    > *This Google Client Config has been marked deprecated. You might lose any changes you make to the component if you later upgrade to a package version that restores it.*

    **Why does this happen?**

    Versions before v1.3.0 shipped a ready-made `GoogleClient` settings record, and every upgrade replaced it with the shipped one, wiping the values you had configured, such as the certificate name, the service account email and API keys.

    To stop that, v1.3.0 removed the record from the package. Salesforce marks it as deprecated because it no longer belongs to any package version, which is exactly the intent.

    **Is anything broken?**

    No. Your configuration is intact, the app keeps working exactly as before and no action is needed. The warning is for information only.

??? info ""Data Not Available" error during authentication or setup"

    **When does it happen?**

    You may see this message in Salesforce:

    > Data Not Available: The data you were trying to access could not be found.

    Here it usually means the Salesforce **Identity Provider** is not enabled for the org.

    **Fix**

    1. Go to **Setup**.
    2. Search for **Identity Provider** in Quick Find.
    3. Open **Identity Provider**.
    4. Click **Enable Identity Provider**.
    5. Click **Save**.
    6. Return to the Google Client setup and try again.

??? info "Files stay on the Lead after it is converted"

    **When does it happen?**

    A Lead that has Google Client files is converted. The files stay on the Lead and do not appear on the new Account, Contact or Opportunity.

    **Cause**

    Salesforce carries its own files over during conversion. It knows nothing about Google Client files, so nothing is moved for you.

    **Fix: move them with a flow**

    Each link between a file and a record is a **Google File Link** record, and that record can be edited. A record-triggered flow on **Lead** that runs when the Lead is converted can point those links at the new record.

    What to get right:

    1. **Find the right links.** Look for **Google File Link** records whose **Linked Object Id** equals the converted Lead's Id.
    2. **Decide whether to move or copy.** Changing **Linked Object Id** moves the file to the new record. Creating a second link keeps it on the Lead as well: copy **Google File** across and set **Is Additional Link?** to true.
    3. **Keep the rest of the link in step.** **Linked Object Type** and **Linked Object Name** are what users see under Linked Records. **Share Type** and **Visibility** decide who can reach the file, so carry them over from the original link instead of choosing new values.
    4. **Choose one target per file.** Conversion can create an Account, a Contact and an Opportunity. Linking the same file to all three makes it show up on all three.

    The Google Drive file itself does not move. Only the Salesforce record it appears on changes.

??? info ""Certificate cannot be null" or "Unable to determine which Google AI Strategy to use" right after saving"

    **When does it happen?**

    The first time you save and validate the Google Drive or the AI provider settings in the Google Client app, validation reports "Certificate cannot be null" or "Unable to determine which Google AI Strategy to use" although everything was filled in.

    **Cause**

    Saving takes a few seconds to complete, and validation can start before the new settings are in place.

    **Fix**

    1. Save the settings.
    2. Wait 10 to 15 seconds.
    3. Click **Validate** again.
    4. If the same message appears, wait a little longer and click **Validate** once more.

    Once the settings have finished saving, validation uses them correctly.

??? info "Reading a file's text in a flow right after uploading it returns nothing"

    **When does it happen?**

    A flow uploads a file to Google Drive and then uses **Extract File Content as Text from Google Drive** on it in the same run. Instead of the text, the action reports that the text is not available yet.

    **Cause**

    Text is read from the Google Workspace copy that Google prepares for the file, not from the uploaded file itself. Google takes a few seconds to prepare it, and the flow reaches the next step long before that.

    **Fix**

    1. Split the work in two. Upload in one flow, and read the text in a second flow that runs afterwards.
    2. In a record triggered flow, put the reading step on a **scheduled path** a few minutes later.
    3. Plain text files such as `.txt`, `.csv` and `.md` need none of this. They are read straight from the upload and are ready immediately.

    Previews and AI summaries wait for the same copy, so a file that cannot be read yet usually cannot be previewed yet either.

<br>
