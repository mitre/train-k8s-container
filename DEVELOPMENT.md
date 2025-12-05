# Development Guide

This guide covers local development and testing for train-k8s-container.

## Prerequisites

- Ruby 3.1+ (3.3 recommended)
- Bundler
- Docker (for integration testing)
- [kind](https://kind.sigs.k8s.io/) (Kubernetes IN Docker)
- kubectl

## Quick Start

```bash
# Clone the repository
git clone https://github.com/mitre/train-k8s-container.git
cd train-k8s-container

# Install dependencies
bundle install

# Run unit tests (no Kubernetes required)
bundle exec rspec spec/train-k8s-container

# Run linting
bundle exec rake style
```

## Project Structure

```
train-k8s-container/
├── lib/
│   └── train-k8s-container/
│       ├── connection.rb        # Main connection class
│       ├── kubectl_exec_client.rb  # kubectl command execution
│       ├── platform.rb          # Platform detection (Detect+Context)
│       ├── retry_handler.rb     # Retry logic for transient failures
│       ├── transport.rb         # Train transport plugin registration
│       └── version.rb           # Version info
├── spec/
│   ├── train-k8s-container/     # Unit tests (mocked)
│   └── integration/             # Integration tests (real kubectl)
├── test/
│   ├── scripts/                 # Manual test scripts
│   ├── setup-kind.sh            # Kind cluster setup
│   └── cleanup-kind.sh          # Kind cluster teardown
└── .github/workflows/           # CI/CD pipelines
```

## Running Tests

### Unit Tests

Unit tests mock all external dependencies and run quickly:

```bash
# Run all unit tests
bundle exec rspec spec/train-k8s-container

# Run specific test file
bundle exec rspec spec/train-k8s-container/connection_spec.rb

# Run specific test by line number
bundle exec rspec spec/train-k8s-container/connection_spec.rb:42

# Run with verbose output
bundle exec rspec --format documentation
```

### Integration Tests

Integration tests require a real Kubernetes cluster:

```bash
# Setup kind cluster with test pods
./test/setup-kind.sh

# Run integration tests
bundle exec rspec spec/integration

# Cleanup when done
./test/cleanup-kind.sh
```

### Full Test Suite

```bash
# Run all tests (unit + integration)
bundle exec rspec

# With coverage report
bundle exec rspec
open coverage/index.html
```

## Setting Up Local Kind Cluster

### Automated Setup

```bash
# Creates cluster and deploys test pods
./test/setup-kind.sh
```

This script:
1. Creates a kind cluster named `test-cluster`
2. Deploys `test-ubuntu` pod (Ubuntu 22.04 with bash)
3. Deploys `test-alpine` pod (Alpine 3.18 with ash/sh)
4. Deploys `test-distroless` pod (no shell, for edge case testing)
5. Waits for all pods to be ready

### Manual Setup

```bash
# Create kind cluster
kind create cluster --name test-cluster

# Deploy test pods
kubectl run test-ubuntu --image=ubuntu:22.04 --restart=Never -- sleep infinity
kubectl run test-alpine --image=alpine:3.18 --restart=Never -- sleep infinity

# Wait for pods
kubectl wait --for=condition=Ready pod/test-ubuntu --timeout=120s
kubectl wait --for=condition=Ready pod/test-alpine --timeout=120s

# Verify
kubectl get pods
kubectl exec test-ubuntu -- echo "ready"
```

### Cleanup

```bash
# Delete cluster
kind delete cluster --name test-cluster

# Or use the cleanup script
./test/cleanup-kind.sh
```

## Testing with InSpec/Cinc Auditor

### Install Plugin Locally

```bash
# Build gem
gem build train-k8s-container.gemspec

# Install in Cinc Auditor
cinc-auditor plugin install train-k8s-container-*.gem

# Verify installation
cinc-auditor plugin list
```

### Manual Testing

```bash
# Detect platform
cinc-auditor detect -t k8s-container:///test-ubuntu/test-ubuntu

# Interactive shell
cinc-auditor shell -t k8s-container:///test-ubuntu/test-ubuntu

# Run a profile
cinc-auditor exec my-profile -t k8s-container:///test-ubuntu/test-ubuntu
```

### Using test_live.rb

```bash
# Requires kind cluster with test pods
bundle exec ruby test/scripts/test_live.rb
```

## Code Quality

### Linting

```bash
# Run Cookstyle/RuboCop
bundle exec rake style

# Auto-fix issues
bundle exec rubocop -a
```

### Security Audit

```bash
# Check for vulnerable dependencies
bundle audit check --update
```

### Full Quality Check

```bash
# Runs style + tests + security
bundle exec rake quality
```

## Debugging

### Enable Debug Logging

```bash
# With InSpec/Cinc
cinc-auditor detect -t k8s-container:///pod/container -l debug

# In tests
TRAIN_K8S_DEBUG=1 bundle exec rspec
```

### Common Issues

#### "No such file or directory - kubectl"

kubectl is not in PATH. Install kubectl or specify the path:
```bash
export PATH=$PATH:/usr/local/bin
```

#### "error: unable to forward port"

The kind cluster may not be running:
```bash
kind get clusters
kind create cluster --name test-cluster
```

#### "container not found"

Pod or container name doesn't exist:
```bash
kubectl get pods -A
kubectl describe pod <pod-name>
```

### Inspecting kubectl Commands

The plugin builds kubectl commands like:
```bash
kubectl exec --stdin <pod> -n <namespace> -c <container> -- /bin/sh -c "<command>"
```

To debug, run the command manually:
```bash
kubectl exec --stdin test-ubuntu -n default -c test-ubuntu -- /bin/sh -c "whoami"
```

## Architecture Notes

### Platform Detection (Detect + Context Pattern)

This plugin uses Train's built-in `Detect.scan(self)` to detect the actual OS inside containers, then adds Kubernetes context families:

```ruby
# lib/train-k8s-container/platform.rb
@platform = Train::Platforms::Detect.scan(self)
add_k8s_families(@platform)  # Adds 'kubernetes', 'container' families
```

This allows InSpec resources to work correctly (`os.linux?` = true) while still providing transport context (`platform.kubernetes?` = true).

### Connection Flow

1. **URI Parsing**: `k8s-container://namespace/pod/container`
2. **Validation**: Pod/container names validated against RFC 1123
3. **Shell Detection**: Probes for available shells (bash, sh, ash, zsh)
4. **Command Execution**: Routes through `KubectlExecClient`
5. **Platform Detection**: Runs `Detect.scan()` on first access

### Key Files

| File | Purpose |
|------|---------|
| `transport.rb` | Plugin registration with Train |
| `connection.rb` | Main connection class, URI parsing |
| `kubectl_exec_client.rb` | Builds and executes kubectl commands |
| `platform.rb` | Platform detection using Detect+Context |
| `retry_handler.rb` | Retry logic for transient failures |

## CI/CD

GitHub Actions runs on every push/PR:

- **Unit tests**: Ruby 3.1, 3.2, 3.3
- **Integration tests**: Kubernetes 1.29, 1.30, 1.31
- **Security scans**: TruffleHog, bundler-audit, SBOM
- **Pod-to-pod tests**: InSpec running inside cluster

See `.github/workflows/ci.yml` for details.

## Releasing

Releases are automated via GitHub Actions when a tag is pushed:

```bash
# Update VERSION file
echo "2.1.0" > VERSION

# Commit and tag
git add VERSION CHANGELOG.md
git commit -m "Release v2.1.0"
git tag v2.1.0
git push origin main --tags
```

The `release-tag.yml` workflow will:
1. Run tests
2. Build gem
3. Publish to RubyGems.org
4. Create GitHub release
