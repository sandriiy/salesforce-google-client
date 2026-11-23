# Configure Certificate

Turn the service account key you downloaded into a JKS keystore and upload it to Salesforce. The Google Client app refers to the certificate by name to sign its requests to Google, so no credentials are stored or exposed.

!!! note
    Create the service account and download its key first. If you have not done that yet, start with [Configure Service Account & APIs](setup-service-account.md).

## Required tools

Install these tools on your computer. They are needed only to create the certificate.

- [OpenSSL](https://slproweb.com/products/Win32OpenSSL.html){ target="_blank" rel="noopener noreferrer" } generates and converts the certificate.
- [Java JDK 11 or 17](https://www.oracle.com/java/technologies/javase/jdk17-archive-downloads.html){ target="_blank" rel="noopener noreferrer" } provides `keytool`.
- [jq](https://jqlang.org/download/){ target="_blank" rel="noopener noreferrer" } reads values out of the JSON key.

## Step 1: Prepare the certificate

The goal is a **JKS keystore** file, which is the format Salesforce needs to store the private key securely. The commands depend on the type of key you downloaded when you [created the service account](setup-service-account.md). Follow the path that matches your file.

---

### If you have a JSON key

**1. Extract the private key**

Takes the `private_key` field out of the JSON file and saves it as a PEM file:

```bash
jq -r ".private_key" service_account.json | Set-Content -Path service_account_key.pem -Encoding utf8
```

??? note "Manual alternative"
    Open the JSON file, copy the value of `private_key` and save it as `service_account_key.pem`. The file must follow this exact format, with every line of base64 content exactly 64 characters long:

    ```
    -----BEGIN PRIVATE KEY-----
    MIIBVwIBADANBgkqhkiG9w0BAQEFAASCATwwggE4AgEAAkE...
    ...base64-encoded content (64 chars per line)...
    ...more 64 chars per line...
    -----END PRIVATE KEY-----
    ```

**2. Generate a Certificate Signing Request (CSR)**

Creates a CSR that OpenSSL uses to issue a self-signed certificate:

```bash
openssl req -new -key service_account_key.pem -out service_account.csr
```

OpenSSL asks for a few details:

- Country Name (2-letter code): for example `US`
- State or Province Name: for example `California`
- Locality Name: for example `San Francisco`
- Organization Name: for example `Your Company`
- Common Name: your service account email, for example `test-110@vital-lyceum-426217-h7.iam.gserviceaccount.com`
- Email Address: the same as Common Name
- Challenge password: at least 6 characters

Every other field is optional. Press Enter to skip it.

**3. Issue a self-signed certificate**

Signs the CSR with your private key and produces a certificate valid for 365 days:

```bash
openssl x509 -req -days 365 -in service_account.csr -signkey service_account_key.pem -out service_account_cert.crt
```

**4. Package it into a PKCS12 keystore**

Bundles the certificate and the private key into a `.p12` file. You are asked to set an export password. Keep it safe, because the next step needs it:

```bash
openssl pkcs12 -export -in service_account_cert.crt -inkey service_account_key.pem -out service_account.p12 -name "ServiceAccountName"
```

**5. Convert to JKS**

Converts the PKCS12 keystore into a JKS file, the format Salesforce needs:

```bash
keytool -importkeystore -srckeystore service_account.p12 -srcstoretype PKCS12 -destkeystore service_account.jks -deststoretype JKS
```

---

### If you have a P12 key

Your key is already in PKCS12 format, so you can go straight to the final conversion.

**Convert to JKS**

Converts your `.p12` file into a JKS keystore, the format Salesforce needs:

```bash
keytool -importkeystore -srckeystore service_account.p12 -srcstoretype PKCS12 -destkeystore service_account.jks -deststoretype JKS
```

## Step 2: Upload the certificate to Salesforce

In Salesforce Setup:

1. Go to **Certificate and Key Management**.
2. Select **Import from Keystore**.
3. Upload the **JKS file** you generated.
4. Enter the keystore password.
5. Save.

Once the certificate is in Salesforce, continue to [Configure Google Workspace](configure-drive.md).

## Further reading

- [**Quick Setup Guide (Service Account + Certificate)**](https://github.com/sandriiy/salesforce-google-drive-library/wiki/Quick-Setup-Guide){ target="_blank" rel="noopener noreferrer" }
- [**Google Service Accounts overview**](https://cloud.google.com/iam/docs/service-accounts){ target="_blank" rel="noopener noreferrer" }
- [**Google Drive API documentation**](https://developers.google.com/drive/api){ target="_blank" rel="noopener noreferrer" }

<br>
