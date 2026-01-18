# Sharing

File sharing enables collaboration within your Salesforce organization without using Salesforce Files as storage.

Users with **Collaboration Access** can share files with:

- Internal Users
- Public Groups
- Customer Community Users

**Note:** Only the file owner can share files. Support for delegated access requests is planned.

## How to Share Files

To access the sharing options:

1. Open a file in Salesforce.
2. The file will open in the **Preview Window**.
3. Click the **Share** button (second button on the toolbar).

![Sharing Window](../assets/images/client_sharing_window.png)

## Access Levels

There are two access levels when sharing with internal users and groups:

- **Viewer** — read-only: view or download
- **Collaborator** — full access: view, modify, upload new versions

## Sharing With Experience Cloud Users

When a file is linked to a Salesforce record (e.g., Account), it can be shared with Customer/Community users.

Inside the sharing modal:

1. Expand the *Who Can Access* accordion
2. Toggle visibility for the related record
3. Select access behavior:

| Access Mode      | Behavior                                                                 |
|------------------|--------------------------------------------------------------------------|
| **Viewer**       | Read-only access                                                         |
| **Set by Record**| Access determined by record permissions (Edit → full, Read → read-only)  |

<br>