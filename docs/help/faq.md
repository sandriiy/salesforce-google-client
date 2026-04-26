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

    Beyond cost, the goal of this solution is to give users the file management experience they deserve, one that Salesforce has consistently failed to deliver. That means native previews, structured folders tied to records, version history, controlled sharing with internal and external users, and a security model that actually makes sense. On top of that, AI-powered analytics let you go further, checking files against org policies, applying smart labels, and surfacing insights directly within your workflows. Files become a first-class part of your business operations, not an afterthought bolted onto the side.

??? question "Why should I trust this solution?"

    Security is not an afterthought here, it's foundational.

    Google Client for Salesforce implements a **dedicated security layer** that governs every file interaction. Access is evaluated at both the UI and the API level: if a user does not have access to a record, they cannot see, retrieve, or interact with any file associated with it. There are no shortcuts, no edge cases where a direct link bypasses the check.

    On the infrastructure side, **your files never leave your organization's Google Workspace**. Google Client connects directly between your Salesforce org and your own Google Cloud project using a Service Account you create and control. No files are routed through third-party servers, no data is stored outside your environment, and no external party has access to your content.

    This architecture is well-suited for organizations operating under compliance frameworks such as **GDPR, HIPAA, or SOX**, not because we claim certification, but because the data residency, access controls, and audit logging are in your hands, not ours.