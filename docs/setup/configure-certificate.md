# Configure Certificate

This page walks through converting the Service Account key you downloaded into a JKS keystore and uploading it to Salesforce. Once uploaded, the Google Client app will reference it by name to sign requests to Google APIs, with no credentials stored or exposed.

!!! note
    Before this step, make sure you have already created your Service Account and downloaded the key file. If not, start here: [Set Up Service Account](setup-service-account.md)

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

## Step 1: Prepare certificate artifacts

The end goal is a **JKS keystore** file, which is the format Salesforce requires to store the private key securely. The commands you run depend on which key file type you downloaded when [setting up your Service Account](setup-service-account.md) (JSON or P12). Follow the path that matches your file.

---

### If you have a JSON key

**1. Extract the private key**

Pulls the `private_key` field out of the JSON file and saves it as a PEM file:

```bash
jq -r ".private_key" service_account.json | Set-Content -Path service_account_key.pem -Encoding utf8
```

??? note "Manual alternative"
    Open the JSON file, copy the value of `private_key`, and save it as `service_account_key.pem`. The file must follow this exact format: each line of base64 content must be exactly 64 characters long:

    ```
    -----BEGIN PRIVATE KEY-----
    MIIBVwIBADANBgkqhkiG9w0BAQEFAASCATwwggE4AgEAAkE...
    ...base64-encoded content (64 chars per line)...
    ...more 64 chars per line...
    -----END PRIVATE KEY-----
    ```

**2. Generate a Certificate Signing Request (CSR)**

Creates a CSR that OpenSSL will use to issue a self-signed certificate:

```bash
openssl req -new -key service_account_key.pem -out service_account.csr
```

OpenSSL will prompt you for a few details:

- Country Name (2-letter code): e.g., `US`
- State or Province Name: e.g., `California`
- Locality Name: e.g., `San Francisco`
- Organization Name: e.g., `Your Company`
- Common Name: your Service Account email, e.g., `test-110@vital-lyceum-426217-h7.iam.gserviceaccount.com`
- Email Address: same as Common Name
- Challenge password: at least 6 characters

All other fields are optional, just press Enter to skip.

**3. Issue a self-signed certificate**

Signs the CSR with your private key and produces a certificate valid for 365 days:

```bash
openssl x509 -req -days 365 -in service_account.csr -signkey service_account_key.pem -out service_account_cert.crt
```

**4. Package into a PKCS12 keystore**

Bundles the certificate and private key into a `.p12` file. You will be prompted to set an export password, keep it safe as you will need it in the next step:

```bash
openssl pkcs12 -export -in service_account_cert.crt -inkey service_account_key.pem -out service_account.p12 -name "ServiceAccountName"
```

**5. Convert to JKS**

Converts the PKCS12 keystore into a JKS file, which is the format Salesforce requires:

```bash
keytool -importkeystore -srckeystore service_account.p12 -srcstoretype PKCS12 -destkeystore service_account.jks -deststoretype JKS
```

---

### If you have a P12 key

Your key is already in PKCS12 format, so you can skip straight to the final conversion.

**Convert to JKS**

Converts your existing `.p12` file into a JKS keystore, which is the format Salesforce requires:

```bash
keytool -importkeystore -srckeystore service_account.p12 -srcstoretype PKCS12 -destkeystore service_account.jks -deststoretype JKS
```

## Step 2: Upload certificate to Salesforce

In Salesforce Setup:

1. Navigate to **Certificate and Key Management**
2. Select **Import from Keystore**
3. Upload the generated **JKS file**
4. Provide the key password
5. Save

<br>
Once the certificate is uploaded to Salesforce, proceed to [Configure Google Workspace](configure-drive.md).

## Reference & deep-dive guides

- [**Quick Setup Guide (Service Account + Certificate)**](https://github.com/sandriiy/salesforce-google-drive-library/wiki/Quick-Setup-Guide){ target="_blank" rel="noopener noreferrer" }
- [**Google Service Accounts overview**](https://cloud.google.com/iam/docs/service-accounts){ target="_blank" rel="noopener noreferrer" }
- [**Google Drive API documentation**](https://developers.google.com/drive/api){ target="_blank" rel="noopener noreferrer" }

<br>