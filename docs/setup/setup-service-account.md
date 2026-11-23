# Configure Service Account & APIs

Google Client connects to Google through a **service account**: an identity you create in Google Cloud that acts on behalf of your Salesforce org. It lets Salesforce sign in to Google securely, without anyone's personal credentials.

Create the service account, give it the roles it needs, enable the APIs and download its key.

## Step 1: Create or select a Google Cloud project

1. Open the [**Google Cloud Console**](https://console.cloud.google.com/){ target="_blank" rel="noopener noreferrer" }.
2. Create a new project or select an existing one.

For reference: [https://developers.google.com/workspace/guides/create-project](https://developers.google.com/workspace/guides/create-project){ target="_blank" rel="noopener noreferrer" }

## Step 2: Create a service account

1. Go to [**IAM & Admin → Service Accounts**](https://console.cloud.google.com/iam-admin/serviceaccounts){ target="_blank" rel="noopener noreferrer" }.
2. Create a new service account.
3. Assign its roles during creation or afterwards, as described in Step 3.

## Step 3: Assign IAM roles

The roles depend on which integrations you enable. Google Drive access is granted by sharing Drive folders with the service account, not through IAM, so Drive alone needs no role. Each AI integration needs one.

| Integration | IAM role required |
|---|---|
| Google Workspace (Drive) | None (access comes from sharing the Drive folders) |
| Gemini API for Developers | `Vertex AI User` (`roles/aiplatform.user`) |
| Agent Platform | `Vertex AI User` (`roles/aiplatform.user`) |

To assign a role: **IAM & Admin → IAM → find your service account → Edit → Add Role**

## Step 4: Enable APIs

Enable the APIs for the integrations you plan to use. Search for each one under **APIs & Services → Library** and enable it.

| Integration | API to enable |
|---|---|
| Google Workspace (Drive) | [Google Drive API](https://console.cloud.google.com/apis/library/drive.googleapis.com){ target="_blank" rel="noopener noreferrer" } |
| Gemini API for Developers | [Gemini API](https://ai.google.dev/gemini-api/docs/api-key){ target="_blank" rel="noopener noreferrer" } |
| Agent Platform | [Agent Platform API / Vertex AI API](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/start){ target="_blank" rel="noopener noreferrer" } |

## Step 5: Generate a service account key

1. Open the new service account.
2. Go to the **Keys** tab.
3. Create a new key, either **JSON**, Google's default, or **P12**, which takes fewer steps to convert.
4. Download the file and store it securely.

With the key file in hand, continue to [Configure Certificate](configure-certificate.md) to turn it into a JKS keystore and upload it to Salesforce.

<br>
