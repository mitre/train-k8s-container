# Security Policy

## Reporting Security Issues

The MITRE SAF team takes security seriously. If you discover a security vulnerability in the train-k8s-container plugin, please report it responsibly.

### Contact Information

- **Email**: [saf-security@mitre.org](mailto:saf-security@mitre.org)
- **GitHub**: Use the [Security tab](https://github.com/mitre/train-k8s-container/security) to report vulnerabilities privately

### What to Include

When reporting security issues, please provide:

1. **Description** of the vulnerability
2. **Steps to reproduce** the issue
3. **Potential impact** assessment
4. **Suggested fix** (if you have one)

### Response Timeline

- **Acknowledgment**: Within 48 hours
- **Initial Assessment**: Within 7 days
- **Fix Timeline**: Varies by severity (critical: 7-14 days, high: 14-30 days)

## Supported Versions

| Version | Supported |
|---------|-----------|
| 2.x.x   | Yes       |
| < 2.0   | No        |

## Security Best Practices

### For Users

- **Keep Updated**: Use the latest version of the plugin
- **Secure Credentials**: Never commit kubeconfig files to version control
- **Use RBAC**: Configure minimal Kubernetes RBAC permissions for scanner service accounts
- **Network Security**: Use network policies to restrict pod-to-pod communication

### For Contributors

- **Dependency Scanning**: Run `bundle audit` before submitting PRs
- **Credential Handling**: Never log or expose credentials in code
- **Input Validation**: Sanitize all user inputs
- **Test Security**: Include security tests for new features

## Security Testing

The plugin includes comprehensive security testing:

```bash
# Check for vulnerable dependencies
bundle exec bundle-audit check --update

# Run security workflow locally
bundle exec rake security
```

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

## Known Security Considerations

### kubectl Execution
This plugin executes commands via `kubectl exec`. Security considerations:

- **Command injection**: Commands are sanitized with `Shellwords.escape`
- **ANSI sequences**: Output is sanitized to prevent terminal escape attacks (CVE-2021-25743)
- **Credentials**: Uses kubeconfig authentication (same security as kubectl)
- **RFC 1123 validation**: Pod and container names are validated

### Container Access
- Requires existing kubectl access to target namespace/pod
- Does not bypass Kubernetes RBAC
- Runs commands with container's default user permissions

## Contact

- **Security issues**: [saf-security@mitre.org](mailto:saf-security@mitre.org)
- **General questions**: [saf@mitre.org](mailto:saf@mitre.org) or open a GitHub issue
