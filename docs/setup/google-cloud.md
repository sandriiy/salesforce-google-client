# Google Cloud & Certificate

This guide explains the minimum required setup on the Google Cloud side to integrate Salesforce with Google Cloud using a Service Account and a JKS certificate.

## What you will create

On the **Google Cloud** side:

- A Google Cloud Project
- A Service Account
- Enabled Google Drive API
- A Service Account key (JSON)

On the **Salesforce** side:

- A JKS certificate generated from the Service Account key
- The certificate uploaded to Salesforce (Certificate & Key Management)

## Required tools

Install the following tools locally (used only for certificate creation):

<ul>
  <li>
    <a href="https://slproweb.com/products/Win32OpenSSL.html" target="_blank">
      OpenSSL
    </a>
    – used to generate and convert certificates
  </li>
  <li>
    <a href="https://www.oracle.com/java/technologies/javase/jdk17-archive-downloads.html" target="_blank">
      Java JDK 11 or 17
    </a>
    – required for <code>keytool</code>
  </li>
  <li>
    <a href="https://jqlang.org/download/" target="_blank">
      jq
    </a>
    – used to extract values from the Service Account JSON key
  </li>
</ul>
<br>

## Step 1: Create or select a Google Cloud project

1. Open the [**Google Cloud Console**](https://console.cloud.google.com/)
2. Create a new project or select an existing one.

For reference: [https://developers.google.com/workspace/guides/create-project](https://developers.google.com/workspace/guides/create-project)

## Step 2: Enable required APIs

In the Google Cloud Console:

1. Navigate to **APIs & Services → Library**
2. Enable: **Google Drive API**

Direct link: [https://console.cloud.google.com/apis/library/drive.googleapis.com](https://console.cloud.google.com/apis/library/drive.googleapis.com)

!!! note

    No OAuth consent screen is required when using a Service Account.

## Step 3: Create a Service Account

1. Go to [**IAM & Admin → Service Accounts**](https://console.cloud.google.com/iam-admin/serviceaccounts)
2. Create a new Service Account
3. Skip optional role assignment (Drive access is granted via sharing, not IAM roles).

## Step 4: Generate a Service Account key (JSON/P12)

1. Open the newly created Service Account
2. Navigate to **Keys**
3. Create a new **JSON** key (recommended; requires more setup steps) or a **P12** key (simpler; fewer setup steps).
4. Download and securely store the file

This key will be used to generate the Salesforce certificate.

## Step 5: Prepare certificate artifacts

From the Service Account JSON/P12 key, you will generate:

- A private key file (JSON)
- A converted PKCS8 key (JSON)
- A certificate file (JSON)
- A keystore file (JSON)
- A final **JKS keystore** compatible with Salesforce (JSON/P12)

Below is a list of commands used to create a JKS certificate. This certificate is recommended to enhance your organization’s security, as it is the only right way to store the private key securely. Depending on whether you initially received a JSON or P12 key file, follow the steps below.

This guide was taken from here: [Quick-Setup-Guide](https://github.com/sandriiy/salesforce-google-drive-library/wiki/Quick-Setup-Guide)

### A private key file (JSON)
<p>

```bash
jq -r ".private_key" service_account.json | Set-Content -Path service_account_key.pem -Encoding utf8
```

</p>
<p>
  Manual alternative (if needed): Extract the private key from the `private_key` value in the JSON file and save it as a separate file with a .PEM extension. Then, format your key correctly by ensuring it has base64 encoding, a header, a footer, and lines split by 64 characters each. This step is crucial because an incorrectly formatted key can block further steps, so double-check that it is correct.

```bash
    -----BEGIN PRIVATE KEY-----
    MIIBVwIBADANBgkqhkiG9w0BAQEFAASCATwwggE4AgEAAkE...
    ...base64-encoded content...
    ...more base64-encoded content...
    -----END PRIVATE KEY-----
```

</p>

### A converted PKCS8 key (JSON)
<p>

```bash
openssl req -new -key service_account_key.pem -out service_account.csr
```

</p>

During the process, OpenSSL will ask you to enter details such as:

- Country Name (2-letter code): e.g., US
- State or Province Name: e.g., California
- Locality Name (City): e.g., San Francisco
- Organization Name: e.g., Your Company
- Common Name: This is typically your Google service account’s email, like test-110@vital-lyceum-426217-h7.iam.gserviceaccount.com
- Email: This is typically your Google service account’s email, like test-110@vital-lyceum-426217-h7.iam.gserviceaccount.com
- A challenge password: Create a password that is at least 6 characters long

All other fields are optional, and you can skip them by simply pressing Enter.

### A certificate file (JSON)
<p>

```bash
openssl x509 -req -days 365 -in service_account.csr -signkey service_account_key.pem -out service_account_cert.crt
```

</p>

### A keystore file (JSON)
<p>

```bash
openssl pkcs12 -export -in service_account_cert.crt -inkey service_account_key.pem -out service_account.p12 -name "ServiceAccountName"
```

</p>
<p>
  You will be prompted to set an export password. Keep it safe; you will need it again.
</p>

### A final JKS keystore compatible with Salesforce (JSON/P12)
<p>

```bash
keytool -importkeystore -srckeystore service_account.p12 -srcstoretype PKCS12 -destkeystore service_account.jks -deststoretype JKS
```

</p>

## Step 6: Upload certificate to Salesforce

In Salesforce Setup:

1. Navigate to **Certificate and Key Management**
2. Select **Import from Keystore**
3. Upload the generated **JKS file**
4. Provide the key password
5. Save

## Reference & deep-dive guides

- [**Quick Setup Guide (Service Account + Certificate)**](https://github.com/sandriiy/salesforce-google-drive-library/wiki/Quick-Setup-Guide)
- [**Google Service Accounts overview**](https://cloud.google.com/iam/docs/service-accounts)
- [**Google Drive API documentation**](https://developers.google.com/drive/api)
