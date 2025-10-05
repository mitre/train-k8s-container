# Security Policy

## Supported Versions

| Version | Supported |
| ------- | --------- |
| 2.x.x   | Yes       |
| 1.3.x   | Yes       |
| < 1.3   | No        |

## Reporting a Vulnerability

Please report security vulnerabilities to inspec@progress.com

**DO NOT** open public issues for security vulnerabilities.

### What to Include

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if available)

### Response Timeline

- **Initial Response**: Within 48 hours
- **Status Update**: Within 7 days
- **Fix Timeline**: Depends on severity (critical: 7-14 days, high: 14-30 days)

## Security Measures

This project implements comprehensive automated security scanning:

### Secret Scanning
- **Tool**: TruffleHog OSS
- **Frequency**: Every push, pull request, and weekly
- **Coverage**: 800+ secret types (API keys, tokens, credentials)

### Vulnerability Scanning
- **Tool**: bundler-audit
- **Frequency**: Every push, pull request, and weekly
- **Database**: Ruby Advisory Database (continuously updated)

### Software Bill of Materials (SBOM)
- **Tool**: CycloneDX Ruby
- **Format**: JSON
- **Retention**: 90 days in GitHub artifacts
- **Standard**: OWASP CycloneDX specification

### License Compliance
- **Tool**: license_finder
- **Frequency**: Every push, pull request, and weekly
- **Purpose**: Ensure dependency license compliance

## Security Best Practices

When contributing to this project:

1. **Never commit secrets** - Use environment variables or secure vaults
2. **Keep dependencies updated** - Regularly update gems to patch vulnerabilities
3. **Review security scan results** - Check CI output for findings
4. **Follow secure coding practices** - Sanitize inputs, validate data
5. **Use least privilege** - kubectl credentials should have minimal required permissions

## Known Security Considerations

### kubectl Execution
This plugin executes commands via `kubectl exec`. Security considerations:

- **Command injection**: Commands are sanitized with `Shellwords.escape`
- **ANSI sequences**: Output is sanitized to prevent terminal escape attacks (CVE-2021-25743)
- **Credentials**: Uses kubeconfig authentication (same security as kubectl)

### Container Access
- Requires existing kubectl access to target namespace/pod
- Does not bypass Kubernetes RBAC
- Runs commands with container's default user permissions

## Vulnerability Disclosure

If a vulnerability is confirmed:

1. We will work on a fix immediately
2. A security advisory will be published
3. A patched version will be released
4. Credit will be given to the reporter (if desired)

## Security Updates

Security updates are released as:
- **Patch versions** (2.0.x) for minor security fixes
- **Minor versions** (2.x.0) for significant security enhancements
- Security fixes may be backported to previous minor versions if still supported

## Contact

For security concerns: inspec@progress.com

For general questions: Open a GitHub issue (non-security topics only)
