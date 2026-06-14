# FAQ

Have a question that isn't answered here?
Open a [GitHub issue](https://github.com/sandriiy/salesforce-google-client){ target="_blank" rel="noopener noreferrer" } or reach out directly at [ansukhetskyi@cloudrylabs.com](mailto:ansukhetskyi@cloudrylabs.com).

---

??? question "Why Google Client for Salesforce?"

    Salesforce Files was never built for scale. It works, until it doesn't.

    The core problem is how Salesforce calculates file storage entitlement:

    > **Total File Storage = 10 GB + (2 GB × number of eligible users)**

    The word *eligible* matters. Internal users contribute 2 GB each, but many license types — including Experience Cloud and community licenses — add **zero** storage entitlement, even though files uploaded by those users still count against the same org-wide limit. Therefore, your storage fills up far faster than your entitlement grows.

    This is especially common in Experience Cloud orgs. High-volume external users consume storage but don't contribute to it. Once you hit the limit, Salesforce sells you more at a significant cost.

    **Google Client for Salesforce solves this** by moving file storage entirely to Google Workspace, where your organization already has capacity. Files live where they belong, costs stay predictable, and your Salesforce storage limit becomes a non-issue.

    Beyond cost, the goal of this solution is to give users the file management experience they expect inside Salesforce. That means previews, structured folders tied to records, file reuse without duplicate uploads, version history, controlled sharing with internal and external users, and a security model that evaluates the real access paths. Optional AI summaries and file Q&A take it further by helping users understand document content without opening separate tools.

??? question "Why should I trust this solution?"

    Security is not an afterthought here, it's foundational.

    Google Client for Salesforce implements a **dedicated security layer** that governs every file interaction. Access is evaluated at both the UI and the API level: if a user does not have access to a record, they cannot see, retrieve, or interact with any file associated with it. There are no shortcuts, no edge cases where a direct link bypasses the check.

    On the infrastructure side, **your files never leave your organization's Google Workspace**. Google Client connects directly between your Salesforce org and your own Google Cloud project using a Service Account you create and control. No files are routed through third-party servers, no data is stored outside your environment, and no external party has access to your content.

    This architecture is well-suited for organizations operating under compliance frameworks such as **GDPR, HIPAA, or SOX**, not because we claim certification, but because the data residency, access controls, and audit logging are in your hands, not ours.

??? question "Can the same Google file be used on multiple Salesforce records?"

    Yes. Google Client can attach an existing owned Google Client file to another Salesforce record.

    The Google Drive file is not duplicated, and the Google Client file record is not duplicated. Salesforce stores additional record links so the same document can appear in the right business contexts.

    This is useful when one document belongs to more than one Account, Opportunity, Case, or custom record. Users can also see linked records from the File Details page, subject to their record access.

??? question "Does linking a file to multiple records expose it to everyone?"

    No. Multi-record reuse still goes through the Google Client security layer.

    Access can come from file ownership, direct sharing, group or queue sharing, public link rules, internal/external visibility, and linked Salesforce records. If a user does not have a valid access path, the file is not returned to them.

??? question "Is AI required?"

    No. AI & Intelligence is optional.

    Upload, preview, download, sharing, public links, folder structure, file reuse, and versioning work without AI. When AI is configured, supported files can get stored summaries and file Q&A inside the preview window.