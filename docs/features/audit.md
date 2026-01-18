# Audit & Logging

Auditing and logging functionality ensures visibility into how files are accessed, shared, and managed across Salesforce and Google Workspace.

## Salesforce Logging

Inside Salesforce, this client uses [**Nebula Logger**](https://github.com/jongpie/NebulaLogger) for structured logging. Nebula Logger provides:

- Timestamped event logs
- Error and exception logging
- System event tracking

## Google Workspace Audit Visibility

On the Google side, standard Google Workspace tools provide:

- File activity audits
- Access events
- Sharing changes
- Security alerts

Administrators can use the **Google Admin Console** and **Drive Audit Logs** to view activity.

## Why This Matters

Auditing provides:

- Compliance support
- Security incident detection
- Traceability for regulated operations
- Transparency for administrators

No external storage vendors or third-party systems are involved — only yours.

<br>