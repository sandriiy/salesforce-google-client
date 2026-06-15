# AI & Intelligence

Google Client includes an optional AI layer that helps users understand documents without leaving Salesforce.

When configured, Google Client can generate short document summaries, store them on the Salesforce file version, and let users ask questions about the opened file from the preview window.

The core Google Drive experience does not depend on AI. Upload, preview, download, sharing, public links, folder structure, file reuse, and versioning continue to work when File Intelligence is disabled or not configured.

![AI summary and Q&A panel](../../assets/images/client_preview_summary_and_question.png)

## What It Enables

With File Intelligence enabled, Google Client can:

- Generate a short business-facing summary for supported documents
- Store the summary in Salesforce on the file version
- Show the summary where supported, including hover experiences and the preview sidebar
- Let users ask questions about the current file from the preview window
- Return answers based on the document content that Google Client can export for analysis

## File Q&A

File Q&A is available from the preview window when:

- File Intelligence is enabled
- Gemini Developer API or Agent Platform is configured and validates successfully
- Q&A is available for the selected file
- The user has access to the file

Users ask questions in Salesforce and receive answers based on the current file content. This is useful for contracts, reports, requirements, proposals, statements of work, and other business documents where users need the answer faster than they need the full document.

## Supported Providers

Google Client supports two AI connection options:

**Gemini Developer API** uses an API key from Google AI Studio. It is the fastest option for development, sandboxes, and internal evaluation.

**Agent Platform** uses your Google Cloud project and the same service account model already used for Google Drive. It is the recommended fit for UAT and production environments where teams want stronger Google Cloud controls.

## Admin Controls

Admins control the AI behavior from the Google Client app. Configuration includes provider selection, model name, enablement, summary prompt, question prompt, and question output token limit.

This keeps the output aligned with your organization’s language and cost expectations without changing the core file management experience.

Full setup instructions are on the [Configure AI & Intelligence](../../setup/configure-intelligence.md) page.

<br>
