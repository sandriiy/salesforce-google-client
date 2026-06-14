# Contributing

Contributions to **Google Client for Salesforce** are welcome. These guidelines are intended to keep contributions consistent and make reviews easier.

Google Client overview and usage details are documented in: https://sandriiy.github.io/salesforce-google-client/

## Dependencies

This project relies on the following open-source libraries:

- **Nebula Logger** — https://github.com/jongpie/NebulaLogger
- **Google Drive Apex Library** — https://github.com/sandriiy/salesforce-google-drive-library

When contributing, please ensure that changes remain compatible with these dependencies and do not introduce breaking behavior.

## Contribution Workflow

Please follow this general process when contributing:

1. **Review existing documentation**. Familiarize yourself with the README and documentation site to understand current behavior and expectations.

2. **Open or reference an issue**. Before starting work, create a new issue or comment on an existing one to describe what you plan to contribute. This helps coordinate changes and avoid duplication.

3. **Fork the repository**. Contributions should be made from your own fork.

4. **Create a branch from `main` in your fork:**
   - `feature/<issue-number>`
   - `hotfix/<issue-number>`

5. **Implement your changes**. Make sure your changes align with existing code structure and conventions.

6. **Submit a pull request**. Open a pull request targeting the `main` branch and notify the maintainer. Reviewers will review the changes and request adjustments if needed before merging.

Release branches are maintained by the project owner in parallel. Contributors normally do not need to target release branches unless explicitly asked.

## Development Notes

You may develop and test changes using any Salesforce environment of your choice, such as:
- Scratch orgs
- Sandboxes
- Developer Edition orgs

## Pull Requests

- All pull requests should target the `main` branch unless the maintainer explicitly asks for a different target
- Provide a clear description of the changes being introduced
- Reference the related issue
- Include screenshots or recordings for UI-related changes when applicable
- Include validation or testing notes where possible
- Be aware that merge timing can be delayed while the maintainer runs the required validation suite
- Pull requests are merged using **squash and merge**

## Questions & Communication

For questions related to contributing, architecture decisions, or project direction, you may contact: [ansukhetskyi@cloudrylabs.com](mailto:ansukhetskyi@cloudrylabs.com)

Thank you for contributing.
