# Contributing

Contributions to **Salesforce Google Client** are welcome.  
These guidelines are intended to keep contributions consistent and make reviews easier.

Google Client overview and usage details are documented in:
- The repository **README**
- The project documentation site (GitHub Pages), which is actively being extended

## Dependencies

This project relies on the following open-source libraries:

- **Nebula Logger** — https://github.com/jongpie/NebulaLogger
- **Google Drive Apex Library** — https://github.com/sandriiy/salesforce-google-drive-library

When contributing, please ensure that changes remain compatible with these dependencies and do not introduce breaking behavior.

## Contribution Workflow

Please follow this general process when contributing:

1. **Review existing documentation**  
   Familiarize yourself with the README and documentation site to understand current behavior and expectations.

2. **Open or reference an issue**  
   Before starting work, create a new issue or comment on an existing one to describe what you plan to contribute. This helps coordinate changes and avoid duplication.

3. **Fork the repository**

4. **Create a branch from `main`**
   Use a descriptive branch name:
   - `feature/<issue-number>`
   - `hotfix/<issue-number>`

5. **Implement your changes**
   Make sure your changes align with existing code structure and conventions.

6. **Submit a pull request**
   Open a pull request targeting the `main` branch. Reviewers will review the changes and request adjustments if needed before merging.

## Development Notes

You may develop and test changes using any Salesforce environment of your choice, such as:
- Scratch orgs
- Sandboxes
- Developer Edition orgs

## Pull Requests

- All pull requests **must target the `main` branch**
- Provide a clear description of the changes being introduced
- Include screenshots or recordings for UI-related changes when applicable
- Pull requests are merged using **squash and merge**

## Questions & Communication

For questions related to contributing, architecture decisions, or project direction, you may contact:

**ansukhetskyi@cloudrylabs.com**

Thank you for contributing.