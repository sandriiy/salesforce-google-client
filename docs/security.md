# Security & Access Model

This page explains, in simple terms, how **file access and security** work in the Google Client for Salesforce.

The goal of this model is to ensure that:

- People only see the Files they are allowed to see  
- Access is consistent across Salesforce and Experience Cloud  
- File rules are clear and predictable 

All of this is enforced by a **dedicated security layer** inside the Google Client, not by Salesforce’s standard file sharing model. This gives the solution full control over how Files are exposed while still respecting your existing record access and Google Workspace policies.

## High-Level Principles

When a user tries to work with Files (preview, share, create a public link, upload a new version, etc.), the system runs an access check that answers two questions:

1. **Should this user see this File at all?**  
2. **If yes, do they have View access or Edit access?**

The result is:

- Files the user **should not see** are simply **filtered out**
- Files the user **can see** are marked with a **User Access Level** (View or Edit)

This happens automatically in the background and is applied consistently, no matter where the File appears in Salesforce.

## Ownership

Every File has an **owner**.

- The owner always has **Edit** access to the File.
- This includes all versions of the File.

Ownership is the strongest kind of access and cannot be taken away from the owner.

## Direct Sharing with People and Groups

A File can be **explicitly shared** with:

- Individual users
- Groups
- Queues (for work distribution scenarios)

For each of these, two access levels are possible:

- **Viewer** – can open, preview, and download the File  
- **Collaborator** – full access, including editing and uploading new versions  

If a user is part of any group or queue that has access, that File is treated as shared with them.

The system always looks for the **highest** access level a person has (for example, if they are a Viewer via one share and a Collaborator via another, they are treated as a Collaborator).

## Files Assigned to Records

Files can be **assigned to records** (for example, a File attached to an Account, Case, Opportunity, etc.). When this happens, the system creates a **File Link** that connects the File to that record.

A single File can be linked to multiple Salesforce records. This allows teams to reuse one Google Drive file across related business records without duplicating the file.

Each File Link includes a **Share Type** that defines what access (if any) this record relationship can grant:

- **Viewer** – grants View access (if the record is visible to the user)  
- **Collaborator** – grants Edit access (if the record is visible to the user)  
- **InferredFromRecord** – grants access based on the user’s access to the linked Salesforce record  
- **None** – grants **no access** through the record relationship; the File remains linked for traceability, but access is limited strictly to the owner and people the owner explicitly shared the File with  

When Share Type is **InferredFromRecord**, the File can **inherit access** from the record it is assigned to:

- If a user has **edit rights** on the record → they may get **Edit** access to the File  
- If a user has **read-only rights** on the record → they may get **View** access to the File  
- If a user cannot see the record → they will not see the File through that relationship  

This “inherit from record” behavior is especially useful when:

- Many users work on the same record  
- Access is already carefully managed at the record level  
- You want File access to stay aligned with how people work in Salesforce today  

## Multi-Record Access Resolution

When a File is linked to more than one record, Google Client evaluates all valid linked records the current user can use as an access path.

Example:

- A File is linked to Record A and Record B
- User 1 can read Record A
- User 2 can read only unrelated Record C

User 1 may receive access through Record A, depending on the File Link Share Type. User 2 does not receive access through Record C because Record C is not linked to the File.

This prevents accidental exposure when files are reused across records. Reuse expands legitimate business context; it does not make a file globally visible.

## Internal vs External Users

The access model treats **internal users** (employees, standard Salesforce users) and **external users** (Experience Cloud, customer or partner users) differently where it makes sense.

Examples:

- Some Files or links can be marked as visible to **all users**
- Some Files or links can be restricted to **internal users only**
- External users only see Files that are explicitly made available to them through sharing or record-based access

This allows you to:

- Safely expose Files to customer and partner users in Experience Cloud  
- Keep internal-only documents restricted to employees  
- Use a consistent file model for both audiences  

## Combining All Access Paths

For any given File, the security layer looks at:

- Who owns the File  
- Whether it has been shared directly with the user (or their groups/queues)  
- Whether it is assigned to one or more records via File Links, and what each link’s **Share Type** allows  
- Whether the File is allowed for internal users only or for all users  

From this, it calculates a final **User Access Level**:

- **Edit** – user can fully work with the File (including new versions)  
- **View** – user can see and download the File, but not modify it  
- **No Access** – the File is not returned at all  

If multiple rules apply, the system always chooses the **highest** access level the user qualifies for.

## Finding Files with Global Search

Google Files can be found through Salesforce **global search**, the same search box you use to find any other record.

Because global search follows Salesforce’s standard sharing, results include the Files you **own** or that have been **directly shared** with you. Files you can reach only through **record-based access** (a File Link on a record you can see) may not appear in global search, but they remain available through the **File Explorer** and the record components.

When you open a File from a search result, the security layer described above runs again before anything is shown. Search never bypasses these checks: if you are not allowed to see a File, opening it simply shows a “no access” message.

<br>