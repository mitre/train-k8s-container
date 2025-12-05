# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **ci**: Real STIG profile execution (canonical-ubuntu-22.04-lts-stig-baseline)
- **ci**: Same-pod container-to-container scanning test
- **ci**: Pod-to-pod scanning with cinc-scanner Docker image

### Documentation

- MITRE standards documentation (LICENSE.md, NOTICE.md, CODE_OF_CONDUCT.md)
- CONTRIBUTING.md with development workflow
- DEVELOPMENT.md with local testing guide (kind cluster setup)
- README.md rewrite with MITRE branding and comprehensive usage docs
- SECURITY.md with MITRE SAF contact info

### Fixed

- **ci**: Use pre-built cinc-scanner:local image for same-pod testing
- **platform**: Detect+Context pattern for accurate OS detection

### Miscellaneous Tasks

- Switch from InSpec to Cinc Auditor (open source, license-free)
- Add git-cliff configuration for automated changelog generation
- Add release-tag.yml workflow for RubyGems publication

## [2.0.0] - 2025-10-04

### Breaking Changes

- **BREAKING**: Namespace changed from `Train::K8s::Container` to `TrainPlugins::K8sContainer` (Train v2 standard)
- **BREAKING**: File structure changed from `lib/train/k8s/container/*` to `lib/train-k8s-container/*`
- Ruby requirement: >= 3.1

### Added

- **Platform Detection**: Detect+Context pattern using `Train::Platforms::Detect.scan(self)`
  - Returns actual OS (ubuntu, alpine, centos) so InSpec resources work correctly
  - Adds `kubernetes` and `container` families for transport awareness
  - Fallback platform for distroless/minimal containers
- **Shell Detection**: Tiered detection with automatic fallback
  - Unix: bash → sh → ash → zsh
  - Windows: cmd.exe → powershell.exe → pwsh.exe (scaffolded, not tested)
  - Linux family detection from /etc/os-release
- **Security Hardening**:
  - ANSI escape sequence sanitization (CVE-2021-25743 mitigation)
  - Command injection prevention with Shellwords.escape
  - RFC 1123 validation for pod/container names
- **Error Handling**:
  - Custom error classes (ConnectionError, CommandError, ValidationError)
  - Retry logic with exponential backoff for transient failures
- **CI/CD Pipeline**:
  - GitHub Actions with kind cluster integration tests
  - Multi-version Ruby (3.1, 3.2, 3.3) and Kubernetes (1.29, 1.30, 1.31) matrix
  - Security scanning (TruffleHog, bundler-audit, SBOM generation)
  - Pod-to-pod testing with InSpec running inside cluster
- **Code Quality**:
  - Cookstyle linting (replaced deprecated chefstyle)
  - 95%+ test coverage with SimpleCov
  - Unit tests (mocked) and integration tests (real kubectl)

### Changed

- Transport: Proper Train v2 plugin API implementation
- Connection: Lazy initialization of kubectl client
- Platform: Uses Train's built-in detection instead of force_platform!

### Fixed

- Shell detection command escaping
- Platform detection accuracy (returns real OS, not generic k8s-container)
- Thread safety in session management

### Security

- ANSI injection prevention (sanitizes terminal escape sequences)
- Command escaping with Shellwords
- Input validation for Kubernetes resource names

### Components

| File | Purpose |
|------|---------|
| `transport.rb` | Train v2 plugin registration |
| `connection.rb` | URI parsing, connection management |
| `kubectl_exec_client.rb` | kubectl command execution |
| `platform.rb` | Detect+Context platform detection |
| `shell_detector.rb` | Shell availability detection |
| `ansi_sanitizer.rb` | CVE-2021-25743 mitigation |
| `kubernetes_name_validator.rb` | RFC 1123 validation |
| `retry_handler.rb` | Exponential backoff retry logic |

## [1.3.1] - 2024-03-05

### Fixed

- Fix run command to use Bourne shell for OS resource commands ([#21](https://github.com/inspec/train-k8s-container/pull/21))

## [1.3.0] - 2024-01-31

### Added

- Add support for file connections ([#19](https://github.com/inspec/train-k8s-container/pull/19))

## [1.2.1] - 2024-01-18

### Fixed

- Fix for undefined method presence ([#17](https://github.com/inspec/train-k8s-container/pull/17))

## [1.2.0] - 2024-01-16

### Changed

- Update README and InSpec compatibility ([#15](https://github.com/inspec/train-k8s-container/pull/15))

## [1.1.2] - 2024-01-16

### Fixed

- Connection to container improvements ([#14](https://github.com/inspec/train-k8s-container/pull/14))

## [1.1.1] - 2024-01-15

### Testing

- Specs for transporter ([#13](https://github.com/inspec/train-k8s-container/pull/13))

## [1.1.0] - 2024-01-11

### Added

- kubectl exec client implementation ([#10](https://github.com/inspec/train-k8s-container/pull/10))

## [1.0.0] - 2024-01-11

### Added

- Initial transporter for k8s container ([#9](https://github.com/inspec/train-k8s-container/pull/9))

## Pre-1.0 Releases

- **0.0.7** - Pipeline updates
- **0.0.6** - Version bumper
- **0.0.5** - Apache v2.0 license
- **0.0.4** - SonarQube integration
- **0.0.3** - Initial repo setup
- **0.0.2** - Expeditor configuration

<!-- generated by git-cliff -->
