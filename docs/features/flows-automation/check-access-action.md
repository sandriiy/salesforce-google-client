# Check Access to a Google File

**Type:** Action, listed under the **Google Client** category in Flow Builder.

Tells whether the user running the flow can open or change a Google Client file. It applies the same rules as the Google Client components: ownership, sharing, the records the file is linked to, and internal or external visibility.

The other Google Client actions do not check who runs the flow, because many flows run without a person behind them. This action is how a flow that shows or changes a file for someone finds out what that person may do with it.

## When to use it

- A screen flow lets someone pick a file by its ID and then shows its details or its text. Check that they can open it before showing anything.
- A flow renames a file or withdraws its public link at a user's request. Check that they can change it before the change is made.
- A flow takes a file ID from a record field or from another system. Check that the person behind the run is allowed to work with that file.

## How to add it to a flow

1. Open **Flow Builder** in Salesforce Setup.
2. Create a flow, or open an existing one.
3. Add an **Action** element.
4. Choose the **Google Client** category and select **Check Access to a Google File**.
5. Set **Google File or Version ID** to the file you are about to show or change.
6. Add a **Decision** after it that continues only when **Can View** or **Can Edit** is true, depending on what the flow does next.
7. Save and activate the flow.

## Inputs

| Input | Required | Description |
|---|---|---|
| **Google File or Version ID** | Yes | The Google File to check, or one of its versions. A version is judged by its file. |

## Outputs

| Output | Description |
|---|---|
| **Access Level** | `View` or `Edit`, or blank when the user cannot open the file |
| **Can View** | True when the user can open the file |
| **Can Edit** | True when the user can change the file |

A file or version that does not exist gives the same answer as one the user cannot open: a blank **Access Level** and both flags false. The action does not fault for it, so the **Decision** after it handles both cases.

<br>