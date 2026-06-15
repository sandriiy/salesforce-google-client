# Enterprise Managed Package

The Enterprise managed package is the path for organizations that want Google Client for Salesforce as a complete, managed file platform with stronger release control, enterprise support, and security-review readiness.

It is designed for teams that need more than a file connector. The Enterprise package will grow into a full file management system that understands the organization and adds managed-package capabilities that are not be available in the open-source version.

## Why Enterprise

Enterprise customers usually need three things before adopting a file platform at scale:

- **Clear operational ownership** - a managed package with a stronger support path and release discipline
- **Stronger validation** - deeper regression coverage, controlled package delivery, and enterprise-focused testing
- **Security reassurance** - penetration testing and Salesforce security review alignment before production rollout

The goal is simple: give business teams a complete file experience inside Salesforce while giving technical architects a package model they can evaluate, plan, and govern with confidence.

## Current Status

The Enterprise managed package is currently in **Beta**.

You can install it, evaluate it, and plan around it, but it is not recommended for production use until it goes through the Salesforce security review process.

!!! warning "Beta package"
    Use this package for sandbox evaluation and enterprise planning. Do not use it for production workloads until the managed package completes the security review process.

## Known Beta Limitations

The current Beta package has a few limitations that are being addressed as the package matures.

- Platform Cache is not currently available in the managed package. Because of this, the **View All** action in the Attachments component may behave incorrectly in some orgs.
- Some Enterprise-only features are still being finalized and will be delivered through future managed package releases.
- Production readiness depends on the completion of the security review and the related validation process.

## Delivery Plan

A complete managed package is planned for delivery by the end of the year.

The Enterprise package will continue to evolve in parallel with the open-source codebase. It will include managed-package-only capabilities where they make sense, stronger validation expectations, and a package structure designed for organizations that need a long-term Salesforce file management platform.

## Install the Beta Package

Use the links below to install the current Enterprise managed package.

<div style="display: flex; justify-content: center; gap: 12px; margin-bottom: 16px;">
  <a href="https://test.salesforce.com/packaging/installPackage.apexp?p0=04tQy000000W3nZIAS" target="_blank" rel="noopener noreferrer">
    <img src="https://img.shields.io/badge/Install%20Enterprise%20Beta-Sandbox-0176D3?style=for-the-badge&logo=salesforce&logoColor=white" alt="Install Enterprise Beta in Sandbox">
  </a>
  <a href="https://login.salesforce.com/packaging/installPackage.apexp?p0=04tQy000000W3nZIAS" target="_blank" rel="noopener noreferrer">
    <img src="https://img.shields.io/badge/Install%20Enterprise%20Beta-Production-0176D3?style=for-the-badge&logo=salesforce&logoColor=white" alt="Install Enterprise Beta in Production">
  </a>
</div>

### CLI Installation

```bash
sf package install --wait 20 --security-type AdminsOnly --package 04tQy000000W3nZIAS
```

<br>