# Security Policy

## Supported versions

AI Stocktake is pre-1.0. Security fixes are made on the latest release and
the `main` branch only.

## Reporting a vulnerability

Please **do not** open a public issue, discussion or pull request for a
security problem.

Report it privately through GitHub:

1. Go to the repository's **Security** tab.
2. Select **Report a vulnerability** (GitHub private vulnerability reporting).
3. Describe the issue, affected version, steps to reproduce and impact.

Please do not include real secrets, tokens or personal data in the report. If a
secret is needed to show the problem, use a fake or revoked value.

We aim to acknowledge reports within 5 business days and will keep you updated
in the advisory until a fix is released. We are happy to credit reporters in
the advisory unless you prefer to stay anonymous.

## Scope

In scope: the AI Stocktake PowerShell module, its catalog and rule files, the
HTML report, and the CI workflows in this repository. Examples of issues we
want to hear about:

- A secret value (rather than its fingerprint) appearing in any output, log,
  report or error message.
- The scanner modifying the machine it scans, or making a network call.
- Script injection or cross-site scripting in the generated HTML report.
