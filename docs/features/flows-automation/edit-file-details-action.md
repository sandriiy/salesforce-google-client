# Edit Google File Details

**Type:** Action, listed under the **Google Client** category in Flow Builder.

Renames a Google Client file or one of its versions and changes the description, without anyone opening the preview window.

This is the action behind the **Edit Details** screen users see on a file, so a flow that uses it produces exactly the same result.

## When To Use It

- Apply a naming convention to files as soon as they arrive.
- Put a reference number or a record name into the file name.
- Write a description onto a file from data the flow already has.

## How To Add It To A Flow

1. Open **Flow Builder** in Salesforce Setup.
2. Create a flow, or open an existing one.
3. Add an **Action** element.
4. Choose the **Google Client** category and select **Edit Google File Details**.
5. Pass the **Google File** record and the **Google File Version** record you want to change.
6. Fill in whichever of the three new values you want to apply.
7. Save and activate the flow.

## Inputs

| Input | Required | Description |
|---|---|---|
| **localFileRecord** | Yes | The Google File record being changed. It has to carry its current Name, because that is what the new name is compared against. |
| **localFileVersionRecord** | Yes | The Google File Version record being changed, also with its current Name. |
| **newFileName** | No | A new name for the file. The original extension is kept. |
| **newFileVersionName** | No | A new name for that version. |
| **newFileDescription** | No | A new description for the file. |

The action returns nothing. Nothing is written when none of the three values actually change anything.

!!! note
    The name changes in Salesforce only, the file keeps its Google Drive name. Load both records with **Get Records** first and include **Name**, which the new name is compared against.

📘 See [Upload File to Google Drive](upload-file-action.md) to name a file at the moment it arrives instead.

<br>
