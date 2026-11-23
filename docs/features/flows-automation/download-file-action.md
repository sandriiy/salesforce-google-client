# Download File from Google Drive

**Type:** Action, listed under the **Google Client** category in Flow Builder.

Brings a Google Client file back into Salesforce as an ordinary Salesforce file, which is what an email alert, a Send Email action or a record attachment needs.

Give it a Google File to download the latest version, or a specific Google File Version to download exactly that one.

## When to use it

- Attach a document to an email the flow sends, since Salesforce can only send files it holds.
- Hand a file to another system or process that reads Salesforce files.
- Produce a PDF of a Google document and save it on the record.

## How to add it to a flow

1. Open **Flow Builder** in Salesforce Setup.
2. Create a flow, or open an existing one.
3. Add an **Action** element.
4. Choose the **Google Client** category and select **Download File from Google Drive**.
5. Set either **Google File ID** or **Google File Version ID**.
6. Set **Attach To Record ID** if the downloaded file should show up on a record.
7. Set **Convert To** if you want a different format than the original.
8. Save and activate the flow.

## Inputs

| Input | Required | Description |
|---|---|---|
| **Google File Version ID** | One of the two | The exact version to download. |
| **Google File ID** | One of the two | The file whose latest version is downloaded when no version is given. |
| **Attach To Record ID** | No | The Salesforce record the downloaded file is attached to. Leave blank to keep it unattached. |
| **File Name** | No | A different name for the Salesforce file. The extension is kept when the new name has none. |
| **Convert To** | No | The format to download in, as a file extension. Leave blank for the original file. |

## Outputs

| Output | Description |
|---|---|
| **Content Version ID** | The new Salesforce file version |
| **Content Document ID** | The new Salesforce file |
| **File Name**, **File Size (bytes)** | What was saved |

## Converting while downloading

**Convert To** works for documents and spreadsheets that have a Google Workspace copy. Use the file extension of the format you want:

| Original | Formats you can ask for |
|---|---|
| Documents | `docx`, `pdf`, `odt`, `txt`, `rtf`, `epub`, `md`, `zip` |
| Spreadsheets | `xlsx`, `ods`, `pdf`, `csv`, `tsv`, `zip` |

Asking for a format the file cannot produce faults with a message saying the format is unavailable. While **Store files only** is turned on, conversion is not available and only the original file can be downloaded.

Every downloaded file passes through Salesforce, and a batch larger than one element can hold is refused.

<br>