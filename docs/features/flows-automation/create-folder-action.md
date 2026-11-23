# Create Folder in Google Drive

**Type:** Action, listed under the **Google Client** category in Flow Builder.

Creates a folder in Google Drive from a flow. The action first looks for a folder with the same name in the same place and returns that one instead of creating a duplicate, so a flow that runs twice does not leave two folders behind.

The same action also returns the folder a record already has, which is how a flow gets a link to a record's folder without creating anything new.

## When to use it

- Give every new record its own folder as soon as the record exists, and store the link on the record.
- Prepare a folder for a set of files before uploading them, so they all land in one place.
- Look up a record's folder, to put its link in an email or on a page.

## How to add it to a flow

1. Open **Flow Builder** in Salesforce Setup.
2. Create a flow, or open an existing one.
3. Add an **Action** element.
4. Choose the **Google Client** category and select **Create Folder in Google Drive**.
5. Enter a **Folder Name**, or leave it blank and supply a **Record ID** to get that record's own folder instead.
6. Set **Parent Folder ID** if the folder has to go somewhere specific.
7. Save and activate the flow.

![Create Folder action in Flow Builder](../../assets/images/flow_action_create_folder_setup.png)

## Inputs

| Input | Required | Description |
|---|---|---|
| **Folder Name** | No | Name of the folder to create. Leave it blank and give a Record ID to get the record's own Google Drive folder instead of creating a new one. |
| **Parent Folder ID** | No | The Google Drive folder the new folder is created in. Leave blank to use the record's folder when a Record ID is given, or the default upload folder otherwise. |
| **Record ID** | No | The Salesforce record whose Google Drive folder is used as the parent. With Folder Name blank, that record folder is what the action returns. |
| **Reuse Existing Folder** | No | On by default. Turn it off to always create a new folder, even when one with that name is already there. |

## Outputs

| Output | Description |
|---|---|
| **Folder ID** | The Google Drive ID of the folder |
| **Folder Name** | The folder's name in Google Drive |
| **Parent Folder ID** | The folder it sits in |
| **Folder URL** | A link that opens the folder in Google Drive |
| **Was Created** | True when a new folder was created, false when an existing one was returned |

## Where the folder goes

The action picks the parent in this order:

1. **Parent Folder ID**, when you supply one.
2. The **Record ID**'s own folder, when the folder structure keeps a folder per record.
3. The default upload folder configured for Google Client.

## Returning a record's own folder

Leave **Folder Name** blank and pass only a **Record ID**. The action returns that record's folder, creating it if nothing has needed it yet, and **Was Created** tells you which of the two happened. The folder is named the same way as every other record folder.

This needs a [folder structure](../../config/folder-structure.md) that includes a **Record folder**. Without one there is no record folder to return, and the action says so instead of guessing.

![Create Folder results in a flow screen](../../assets/images/flow_action_create_folder_result.png)

<br>
