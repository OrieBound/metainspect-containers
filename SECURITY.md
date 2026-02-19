# Security Policy

## Supported Scope

This repository is a portfolio project and may not receive enterprise SLA-style response times. Security issues are still appreciated and reviewed.

## Reporting a Vulnerability

Please do not open public issues for sensitive findings.

Report privately to the repository owner with:
- Description of the issue
- Reproduction steps
- Impact assessment
- Suggested remediation (if available)

## Security Practices in This Repo

- No static AWS credentials are stored in source.
- Runtime AWS access is expected through IAM roles (for AWS deployments).
- Sensitive metadata redaction is enabled by default in application behavior.
- Local secret files should remain untracked (`.env`, AWS profiles, private keys).
