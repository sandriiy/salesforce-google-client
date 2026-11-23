# Public Link Expiration

**Type:** Action, listed under the **Google Client** category in Flow Builder.

Withdraws the public link of a file version. The link stops working for anyone holding it, and the file is again reachable only through Salesforce.

Google Client ships a record triggered flow that already uses this action to withdraw links on their expiry date, so in most orgs there is nothing to build.

## When to use it

- Withdraw a link early, before the date it was set to expire.
- Withdraw every link on a record when a case closes or a deal is lost.
- Withdraw links on a schedule that follows your own rules rather than the expiry date.

## How to add it to a flow

1. Open **Flow Builder** in Salesforce Setup.
2. Create a flow, or open an existing one.
3. Add an **Action** element.
4. Choose the **Google Client** category and select **Public Link Expiration**.
5. Pass the Id of the **Google File Version** whose link should be withdrawn.
6. Save and activate the flow.

## Inputs

| Input | Required | Description |
|---|---|---|
| **localFileRecordId** | Yes | The Google File Version whose public link is withdrawn. This is the version Id, not the file Id. |

<br>