# Security & Access Model

How Google Client decides who can see a file and what they can do with it.

The model is built so that:

- People see only the files they are allowed to see
- Access works the same way in Lightning and on Experience Cloud sites
- The rules are clear and predictable

All of this is enforced by a **dedicated security layer** inside Google Client, not by Salesforce's standard file sharing. A file can be linked to records of any object, which Salesforce sharing cannot follow, so Google Client decides access itself while still respecting your record access and your Google Workspace policies.

## The two questions

Whenever someone works with a file, by opening it, sharing it, creating a public link, uploading a new version or anything else, Google Client answers two questions:

1. **Should this user see the file at all?**
2. **If so, do they have View access or Edit access?**

Files the user should not see are **left out entirely**. Files they can see carry their **access level**, View or Edit. The check runs on the server for every list and every action, wherever the file appears.

## Ownership

Every file has an **owner**.

- The owner always has **Edit** access to the file, including all of its versions.
- Ownership is the strongest kind of access and cannot be taken away from the owner.

## Direct sharing with people and groups

A file can be **shared directly** with:

- Individual users
- Public groups
- Queues

Each share gives one of two access levels:

- **Viewer**: can open, preview and download the file
- **Collaborator**: full access, including changes and new versions

A user who belongs to a group or queue the file is shared with is treated as sharing in that access.

When a person has several shares, the **highest** level wins. A Viewer through one share and a Collaborator through another is a Collaborator.

## Files linked to records

A file can be **linked to records**, such as an Account, a Case or an Opportunity. Each link is a **Google File Link** record that connects the file to one record, and a single file can be linked to many records without the file being duplicated.

Each link has a **Share Type** that decides what access, if any, the record can give:

| Share Type | Stored value | What it grants |
|---|---|---|
| **Viewer** | `Viewer` | View access to anyone who can see the record |
| **Collaborator** | `Collaborator` | Edit access to anyone who can see the record |
| **Set by Record** | `InferredFromRecord` | Access that follows the user's access to the record |
| **None** | `None` | **No access** through the record. The file stays linked to show where it belongs, but only the owner and the people it is shared with can reach it. |

The sharing window offers **None**, **Viewer** and **Set by Record**. **Collaborator** links come from automation and from migrated files.

With **Set by Record**, the file follows the record:

- A user with **edit** access to the record gets **Edit** access to the file
- A user with **read** access to the record gets **View** access to the file
- A user who cannot see the record gets nothing through that link

## Files linked to several records

When a file is linked to more than one record, Google Client considers every linked record the current user can actually reach.

For example:

- A file is linked to Record A and Record B
- User 1 can read Record A
- User 2 can read only an unrelated Record C

User 1 may get access through Record A, depending on that link's Share Type. User 2 gets nothing through Record C, because Record C is not linked to the file.

Reusing a file across records extends it to legitimate business context. It never makes the file visible to everyone.

## Internal and external users

The model treats **internal users** (employees on standard Salesforce licenses) and **external users** (Experience Cloud customers and partners) differently where it matters:

- A file link can make the file visible to **all users**, or to **internal users only**
- External users see only the files that are made available to them through sharing or a record

So you can share files safely with customers and partners on an Experience Cloud site, keep internal documents for employees only, and use one file model for both.

## Combining all access paths

For every file, Google Client looks at:

- Who owns it
- Whether it is shared directly with the user, or with their groups and queues
- Every record it is linked to, and what each link's **Share Type** allows
- Whether it is visible to internal users only or to all users

The result is one access level:

- **Edit**: the user can fully work with the file, including new versions
- **View**: the user can see and download the file, but not change it
- **No access**: the file is not returned at all

When several rules apply, the **highest** access level wins.

## Administrators: View All and Edit All

Google Client ships two **custom permissions** that give access to every Google File. Nobody has them until an administrator adds them to a permission set or a profile.

The one exception is the **System Administrator** profile. Installing Google Client for admins only, as the [installation guide](install-overview.md) does, gives that profile both permissions, so every System Administrator can open and change every internal file.

- **Google Client: View All Files** (`GoogleClientViewAllAccess`) gives the user **at least View** on every file.
- **Google Client: Edit All Files** (`GoogleClientEditAllAccess`) gives the user **Edit** on every file.

They set a **minimum, not an override**: they only ever raise access, never lower it. An owner keeps **Edit**, and a collaborator keeps the level they were given. Users without either permission are judged by the rules above. The permissions decide which files a person may reach, but they do not replace the **Google Cloud Client User** permission set, which a person still needs to open a file at all.

For safety, they apply to **internal users only**. An external user who holds one of them still follows the internal and external visibility rules and never sees files meant for internal users only.

## Access in Google Drive itself

Everything above governs what a person can reach **inside Salesforce**. One feature also gives a person access **in Google Drive**: [Open in Google Drive](features/open-in-drive.md).

It is off until an administrator turns it on. When it is on, the rules are deliberately narrow:

- Only the **owner** of a file can use it, and only an **internal** user. Collaborators, people the file is shared with, administrators holding View All or Edit All, and Experience Cloud users never see the option.
- The access granted is **view only**. The person can read, print, download and keep their own copy.
- The access covers **that one file**. It gives nothing on the folder, and nothing on any other file in it.
- Where Google Drive supports timed access, it **ends after a week** on its own, and opening the file again extends it. Where it does not, the access stays until it is removed in Google Drive.
- **Google Workspace records every grant** as a sharing change in its Drive audit log, so administrators can review who was given access to what, and when.

Because this access lives in Google Drive rather than in Salesforce, it does not disappear the moment something changes in Salesforce. If a file changes owner, the previous owner keeps their view access in Google Drive until it expires.

## Finding files with global search

Google Files can be found through Salesforce **global search**, the same search box you use for any other record.

Global search follows Salesforce's standard sharing, so it finds the files you **own** or that are **shared directly** with you. Files you can reach only through a record may not appear there, but they are always available in **File Explorer** and the record components.

When you open a file from a search result, the security layer runs again before anything is shown. Search never bypasses these checks: if you are not allowed to see a file, opening it shows a "no access" message.

<br>
