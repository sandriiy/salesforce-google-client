# AI & Intelligence

Google Client includes an optional AI layer powered by **Google Gemini**. When enabled, it can analyse files stored in Google Drive and surface insights directly inside Salesforce — things like automatic document classification, smart labeling, policy checks, and content summaries.

This feature is **completely optional**. The core functionality of Google Client (file upload, preview, sharing, versioning) works without it. AI & Intelligence is an add-on for teams that want to go further.

## What It Enables

With AI connected, Google Client can:

- Analyse the contents of documents uploaded through Salesforce
- Apply smart labels or categories to files based on what they contain
- Flag files that may not meet policy or compliance requirements
- Generate summaries or extract key details from documents

The specific capabilities available will grow over time as the feature matures.

## Two Ways to Connect

There are two integration options, and the right choice depends on your environment:

**Gemini Developer API** uses a simple API key from Google AI Studio. It is the fastest way to get started and works well for development, sandboxes, and internal experimentation.

**Agent Platform** (Gemini Enterprise Agent Platform, formerly Vertex AI) uses your existing Google Cloud service account and project. It is the recommended approach for production and UAT environments, offering enterprise-grade reliability and controls.

Both options are configured in the same place.

## Where to Configure It

AI & Intelligence is set up inside the **Google Client** application on the Home page, under **Google Integration Settings**. Expand the **Gemini & Agent Platform** section to get started.

Full setup instructions are on the [Configure AI & Intelligence](../../setup/configure-intelligence.md) page.

<br>
