# Architecture Overview

This document provides a technical overview of the train-k8s-container plugin architecture.

## Plugin Structure

train-k8s-container follows the Train v2 plugin pattern, enabling InSpec and Cinc Auditor to execute compliance checks against containers running in Kubernetes clusters.

```
lib/train-k8s-container/
├── transport.rb         # Plugin registration with Train
├── connection.rb        # Main connection handler
├── kubectl_exec_client.rb  # kubectl command execution
├── platform.rb          # OS detection (Detect+Context pattern)
├── version.rb           # Version constant
└── ...
```

## Core Components

### Transport (`transport.rb`)

Registers the `k8s-container` transport with Train and manages connection options:
- `kubeconfig` - Path to kubeconfig file
- `pod` - Target pod name (required)
- `container_name` - Target container name (required)
- `namespace` - Kubernetes namespace (default: `default`)

### Connection (`connection.rb`)

Handles URI parsing and connection lifecycle:
- Parses URI format: `k8s-container://<namespace>/<pod>/<container>`
- Validates required parameters
- Delegates command execution to KubectlExecClient
- Provides file access via Train::File::Remote::Linux

### KubectlExecClient (`kubectl_exec_client.rb`)

Executes commands inside containers via kubectl:

```bash
kubectl exec --stdin <pod> -n <namespace> -c <container> -- /bin/sh -c "<command>"
```

- Uses Mixlib::ShellOut for command execution
- Returns Train::Extras::CommandResult objects
- Handles shell detection (bash, sh, ash, zsh)

### Platform Detection (`platform.rb`)

Uses the **"Detect + Context"** pattern:

1. Runs `Train::Platforms::Detect.scan(self)` to detect the actual OS inside the container
2. Adds `kubernetes` and `container` families for context awareness

This ensures InSpec resources work correctly (`os.linux?` returns `true` for Linux containers) while still providing Kubernetes context.

```bash
$ cinc-auditor detect -t k8s-container:///my-pod/my-container

Name:      ubuntu
Families:  debian, linux, unix, os, kubernetes, container
Release:   22.04
Arch:      aarch64
```

## URI Format

```
k8s-container://<namespace>/<pod>/<container>
```

| Component | Required | Default | Example |
|-----------|----------|---------|---------|
| namespace | No | `default` | `production` |
| pod | Yes | - | `web-app-7d4b8c9f-x2k4m` |
| container | Yes | - | `nginx` |

**Examples:**
- `k8s-container://production/web-app/nginx` - Full URI
- `k8s-container:///my-pod/my-container` - Default namespace

## Dependencies

- **kubectl** - Must be installed and in PATH
- **kubeconfig** - Must exist (default: `~/.kube/config`, override with `KUBECONFIG` env var)
- **RBAC** - User must have `pods/exec` permissions on target pods

## Testing Architecture

### Unit Tests (`spec/train-k8s-container/`)

Mock all external dependencies (kubectl, Kubernetes API). Run quickly without any cluster access.

```bash
bundle exec rspec spec/train-k8s-container
```

### Integration Tests (`spec/integration/`)

Test against real Kubernetes clusters using kind (Kubernetes IN Docker).

```bash
# Setup kind cluster
./test/setup-kind.sh

# Run integration tests
bundle exec rspec spec/integration

# Cleanup
./test/cleanup-kind.sh
```

### CI Matrix

| Test Type | Ruby Versions | Kubernetes Versions |
|-----------|---------------|---------------------|
| Unit | 3.1, 3.2, 3.3 | N/A |
| Integration | 3.1, 3.2, 3.3 | 1.29, 1.30, 1.31 |
| Pod-to-Pod | 3.3 | 1.30 |

## Platform Detection Deep Dive

### Why "Detect + Context" Pattern?

When connecting to an **operating system** (container, VM, bare metal), Train must detect the actual OS for InSpec resources to work. Using `force_platform!('k8s-container')` would break resources because:

1. Platform name becomes `k8s-container` instead of `ubuntu`, `alpine`, etc.
2. `os.linux?` returns `false`
3. Resources like `user`, `package`, `service` fail with "not supported on platform"

### Detection Flow

```ruby
def platform
  # 1. Use Train's built-in scanner to detect actual OS
  @platform = Train::Platforms::Detect.scan(self)

  # 2. Add Kubernetes context families
  add_k8s_families(@platform)  # Adds 'kubernetes', 'container'

  @platform
end
```

### Commands Run During Detection

Train's scanner executes these commands to identify the OS:

```bash
uname -s                    # Returns "Linux"
uname -m                    # Returns architecture
cat /etc/os-release         # OS identification
cat /etc/debian_version     # Debian family check
cat /etc/alpine-release     # Alpine detection
```

## Release Process

Releases are fully automated using [release-please](https://github.com/googleapis/release-please):

```
Push commit → Release PR created (auto-merge) → CI passes → PR merges → Gem published
```

### Conventional Commits

| Prefix | Version Bump |
|--------|--------------|
| `feat:` | Minor (2.1.0 → 2.2.0) |
| `fix:` | Patch (2.1.0 → 2.1.1) |
| `feat!:` | Major (2.1.0 → 3.0.0) |

See [CONTRIBUTING.md](CONTRIBUTING.md#versioning-and-commit-messages) for full details.

## Key Design Decisions

1. **kubectl over Kubernetes Ruby client** - Simpler dependency management, leverages user's existing kubectl configuration and authentication

2. **Shell-based command execution** - All commands wrapped in `/bin/sh -c` for consistent behavior across container types

3. **Detect+Context over force_platform** - Ensures InSpec resources work correctly while providing Kubernetes awareness

4. **Cinc Auditor in CI** - Uses open-source, license-free InSpec distribution for testing

5. **OIDC trusted publishing** - Secure gem publishing without storing API keys
