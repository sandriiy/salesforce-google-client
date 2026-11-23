# Permissions

Access to Google Client and its configuration is controlled through permission sets. Assign them according to what each person does.

## Permission sets

| Permission set | What it grants |
|---|---|
| **Google Cloud Client User** | Everything people need to work with files. Only users with this permission set can use the Google Client components. |
| **Google Cloud Client Admin** | The **Google Client** app, its configuration and the **Migration** tab. It does **not** grant day-to-day work with files. |
| **Google Cloud Client User & Admin** (permission set group) | Both of the above, usually for technical leads and system owners who configure Google Client and work with files too. |

!!! note
    The Google Client components appear only for users holding **Google Cloud Client User**. Without it, the Uploader and Attachments components stay hidden on the page instead of loading and failing.

## Flow actions

The Google Client Flow actions need no permission set. A flow runs them for whoever runs the flow, so who may use one is decided by who may run that flow. Calling an action directly through the Salesforce API, outside any flow, needs access to its Apex class, which none of the Google Client permission sets gives.

## Access to every file

Two custom permissions, **Google Client: View All Files** and **Google Client: Edit All Files**, give internal users at least View or Edit access on every Google File. Nobody has them until you add them to a permission set or a profile, except the **System Administrator** profile, which receives both when Google Client is installed for admins only. Every System Administrator can therefore open and change every internal file.

📘 See [Security](../security.md) for how they combine with the rest of the access rules.

## How to assign

1. Go to **Setup** → **Permission Sets**, or **Permission Set Groups** for the combined group.
2. Assign **Google Cloud Client User**, **Google Cloud Client Admin**, or **Google Cloud Client User & Admin** when someone needs both.
3. Open the **Google Client** app to check. Users should be able to load and work with files, and administrators should be able to open the configuration.

<br>
