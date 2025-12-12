# train-k8s-container

A Train transport plugin that enables Chef InSpec and Cinc Auditor to execute compliance checks against containers running in Kubernetes clusters via kubectl exec.

[![Gem Version](https://badge.fury.io/rb/train-k8s-container-mitre.svg)](https://badge.fury.io/rb/train-k8s-container-mitre)
[![CI](https://github.com/mitre/train-k8s-container/actions/workflows/ci.yml/badge.svg)](https://github.com/mitre/train-k8s-container/actions/workflows/ci.yml)
[![Security](https://github.com/mitre/train-k8s-container/actions/workflows/security.yml/badge.svg)](https://github.com/mitre/train-k8s-container/actions/workflows/security.yml)

## Overview

This plugin allows InSpec/Cinc Auditor to scan containers running in Kubernetes clusters, enabling compliance-as-code for containerized workloads. It supports:

- **Pod-to-Pod Scanning**: Scanner pod connects to target containers in other pods
- **Same-Pod Scanning**: Scanner sidecar scans sibling containers within the same pod
- **External Scanning**: Run scans from outside the cluster using kubeconfig

## Features

- **Train v2 Compliance** - Modern TrainPlugins namespace and structure
- **Multi-Platform Support** - Linux containers (Ubuntu, Alpine, RHEL, distroless)
- **Shell Detection** - Automatic detection of available shells (bash, sh, ash, zsh)
- **Platform Detection** - Uses Train's Detect+Context pattern for accurate OS detection
- **Security Hardening** - CVE-2021-25743 mitigation, RFC 1123 validation, command injection prevention
- **Comprehensive Testing** - 95%+ code coverage with unit and integration tests

## Installation

### From RubyGems (Recommended)

**Important:** Always install Train plugins using `inspec plugin install` or `cinc-auditor plugin install`. Do NOT use `gem install` directly, as this can cause issues with plugin discovery and management.

```bash
# Using Cinc Auditor (recommended - open source, license-free)
cinc-auditor plugin install train-k8s-container-mitre

# Or using Chef InSpec
inspec plugin install train-k8s-container-mitre
```

### From Source

```bash
git clone https://github.com/mitre/train-k8s-container.git
cd train-k8s-container
gem build train-k8s-container.gemspec
cinc-auditor plugin install train-k8s-container-mitre-*.gem
```

## Prerequisites

- **kubectl** installed and in PATH
- **kubeconfig** configured with cluster access (default: `~/.kube/config`)
- **RBAC permissions** to exec into target pods

## Usage

### URI Format

```
k8s-container://<namespace>/<pod>/<container>
```

- `namespace` - Kubernetes namespace (use empty for `default`)
- `pod` - Pod name
- `container` - Container name within the pod

### Examples

```bash
# Detect container platform
cinc-auditor detect -t k8s-container://production/web-app/nginx

# Using default namespace
cinc-auditor detect -t k8s-container:///my-pod/my-container

# Interactive shell
cinc-auditor shell -t k8s-container:///my-pod/my-container

# Run a compliance profile
cinc-auditor exec my-profile -t k8s-container://prod/app-pod/app

# Run STIG baseline
cinc-auditor exec https://github.com/mitre/canonical-ubuntu-22.04-lts-stig-baseline \
  -t k8s-container:///target-pod/target-container
```

### Platform Detection Output

```bash
$ cinc-auditor detect -t k8s-container:///test-ubuntu/test-ubuntu

Name:      ubuntu
Families:  debian, linux, unix, os, kubernetes, container
Release:   22.04
Arch:      aarch64
```

### Running Compliance Checks

```ruby
# Example InSpec control
control 'container-security-1' do
  impact 1.0
  title 'Verify container user'

  describe user('root') do
    it { should exist }
  end

  describe file('/etc/passwd') do
    it { should exist }
    its('owner') { should eq 'root' }
  end
end
```

## Kubernetes RBAC Setup

For pod-to-pod scanning, the scanner pod needs exec permissions:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: inspec-scanner
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: inspec-scanner-role
rules:
- apiGroups: [""]
  resources: ["pods", "pods/exec"]
  verbs: ["get", "list", "create"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: inspec-scanner-binding
subjects:
- kind: ServiceAccount
  name: inspec-scanner
  namespace: default
roleRef:
  kind: ClusterRole
  name: inspec-scanner-role
  apiGroup: rbac.authorization.k8s.io
```

## Supported Container Types

### Linux Containers

| Distribution | Shell | Status |
|-------------|-------|--------|
| Ubuntu/Debian | bash | Full support |
| Alpine/BusyBox | ash/sh | Full support |
| RHEL/CentOS | bash | Full support |
| Distroless | N/A | Limited (direct binary only) |

### Not Yet Supported

- Windows containers (planned)

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `KUBECONFIG` | Path to kubeconfig file | `~/.kube/config` |
| `TRAIN_K8S_DEBUG` | Enable debug logging | `false` |

## Development

See [DEVELOPMENT.md](DEVELOPMENT.md) for local development setup and testing.

### Quick Start

```bash
# Install dependencies
bundle install

# Run unit tests
bundle exec rspec spec/train-k8s-container

# Run linting
bundle exec rake style

# Setup kind cluster for integration tests
./test/setup-kind.sh

# Run integration tests
bundle exec rspec spec/integration
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

1. Fork the repository
2. Create a feature branch
3. Make changes with tests
4. Run `bundle exec rspec && bundle exec rake style`
5. Submit a pull request

### Versioning

This project uses [Conventional Commits](https://www.conventionalcommits.org/) for automated releases:

| Commit Prefix | Version Bump | Example |
|---------------|--------------|---------|
| `feat:` | Minor (2.1.0) | New features |
| `fix:` | Patch (2.0.1) | Bug fixes |
| `feat!:` | Major (3.0.0) | Breaking changes |

See [CONTRIBUTING.md](CONTRIBUTING.md#versioning-and-commit-messages) for full details.

## Security

See [SECURITY.md](SECURITY.md) for security policy and reporting vulnerabilities.

- Report vulnerabilities to [saf-security@mitre.org](mailto:saf-security@mitre.org)
- Do NOT open public issues for security vulnerabilities

## License

Licensed under Apache-2.0. See [LICENSE.md](LICENSE.md) and [NOTICE.md](NOTICE.md).

## Maintainers

This project is maintained by the MITRE SAF (Security Automation Framework) team.

- **Email**: [saf@mitre.org](mailto:saf@mitre.org)
- **Website**: [saf.mitre.org](https://saf.mitre.org)

## Acknowledgments

This project is a fork of [inspec/train-k8s-container](https://github.com/inspec/train-k8s-container), significantly enhanced with:

- Train v2 plugin architecture
- Detect+Context platform detection pattern
- Comprehensive CI/CD with pod-to-pod testing
- Security hardening and SBOM generation
- MITRE SAF ecosystem integration

---

NOTICE: This software was produced for the U.S. Government under Contract Number HHSM-500-2012-00008I, and is subject to Federal Acquisition Regulation Clause 52.227-14, Rights in Data-General.

(c) 2025 The MITRE Corporation.
