# Set Up Service Account

The integration runs through a **Service Account**: a special non-human identity you create in Google Cloud that acts on behalf of your Salesforce org. It's the mechanism that allows Salesforce to authenticate with Google APIs securely, without user credentials or OAuth flows.

This page walks through setting up that Service Account, assigning the right permissions, and enabling the APIs you need.

## Step 1: Create or select a Google Cloud project

1. Open the [**Google Cloud Console**](https://console.cloud.google.com/){ target="_blank" rel="noopener noreferrer" }
2. Create a new project or select an existing one.

For reference: [https://developers.google.com/workspace/guides/create-project](https://developers.google.com/workspace/guides/create-project){ target="_blank" rel="noopener noreferrer" }

## Step 2: Create a Service Account

1. Go to [**IAM & Admin → Service Accounts**](https://console.cloud.google.com/iam-admin/serviceaccounts){ target="_blank" rel="noopener noreferrer" }
2. Create a new Service Account
3. Proceed to Step 3 before saving; you can assign roles during creation or after.

## Step 3: Assign IAM Roles

Role assignment depends on which integrations you are enabling. Google Drive access is managed via Drive sharing (not IAM), so no roles are needed for Drive alone. AI integrations require at least one role.

| Integration | IAM Role Required |
|---|---|
| Google Workspace (Drive) | None (access is managed via Drive folder sharing) |
| Gemini API for Developers | `Vertex AI User` (`roles/aiplatform.user`) |
| Agent Platform | `Vertex AI User` (`roles/aiplatform.user`) |

To assign a role: **IAM & Admin → IAM → Find your Service Account → Edit → Add Role**

!!! note
    If you are only setting up Google Drive at this stage, you can skip role assignment entirely. You can always return here and add the role later when configuring AI.

## Step 4: Enable APIs

Enable the APIs that correspond to the integrations you plan to use. Navigate to **APIs & Services → Library** to search and enable each one.

| Integration | API to Enable |
|---|---|
| Google Workspace (Drive) | [Google Drive API](https://console.cloud.google.com/apis/library/drive.googleapis.com){ target="_blank" rel="noopener noreferrer" } |
| Gemini API for Developers | [Gemini API](https://ai.google.dev/gemini-api/docs/api-key){ target="_blank" rel="noopener noreferrer" } |
| Agent Platform | [Agent Platform API / Vertex AI API](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/start){ target="_blank" rel="noopener noreferrer" } |

Navigate to **APIs & Services → Library** to search and enable each one.

## Step 5: Generate a Service Account key

1. Open the newly created Service Account
2. Navigate to the **Keys** tab
3. Create a new **JSON** key (recommended; requires more setup steps) or a **P12** key (simpler; fewer setup steps)
4. Download and securely store the file

Once you have the key file, proceed to [Configure Certificate](configure-certificate.md) to generate the JKS keystore and upload it to Salesforce.

<br>