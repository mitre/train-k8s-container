# Architecture Overview

This document provides a technical overview of the train-k8s-container plugin architecture.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           InSpec / Cinc Auditor                             │
│                                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │   Profile   │───▶│  Resources  │───▶│    Train    │───▶│  Transport  │  │
│  │  Controls   │    │ (file, user │    │  Framework  │    │   Plugin    │  │
│  └─────────────┘    │  package..) │    └─────────────┘    └──────┬──────┘  │
└──────────────────────────────────────────────────────────────────┼─────────┘
                                                                   │
                              ┌────────────────────────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        train-k8s-container Plugin                           │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                           Connection                                   │  │
│  │  • URI parsing (k8s-container://namespace/pod/container)              │  │
│  │  • Parameter validation                                                │  │
│  │  • File operations via Train::File::Remote::Linux                     │  │
│  └───────────────────────────────────┬───────────────────────────────────┘  │
│                                      │                                      │
│         ┌────────────────────────────┼────────────────────────────┐        │
│         ▼                            ▼                            ▼        │
│  ┌─────────────────┐    ┌─────────────────────┐    ┌─────────────────┐    │
│  │  ShellDetector  │    │  KubectlExecClient  │    │    Platform     │    │
│  │                 │    │                     │    │                 │    │
│  │ • OS detection  │    │ • Command execution │    │ • Detect+Context│    │
│  │ • Shell probing │    │ • PTY sessions      │    │ • OS families   │    │
│  │ • Linux family  │    │ • Retry handling    │    │ • Kubernetes    │    │
│  └────────┬────────┘    └──────────┬──────────┘    │   context       │    │
│           │                        │               └─────────────────┘    │
│           │             ┌──────────┴──────────┐                           │
│           │             ▼                     ▼                           │
│           │    ┌─────────────────┐   ┌─────────────────┐                 │
│           │    │ SessionManager  │   │ ResultProcessor │                 │
│           │    │   (Singleton)   │   │                 │                 │
│           │    │                 │   │ • ANSI cleanup  │                 │
│           │    │ • Connection    │   │ • Exit codes    │                 │
│           │    │   pooling       │   │ • Error detect  │                 │
│           │    │ • Thread-safe   │   └─────────────────┘                 │
│           │    └────────┬────────┘                                       │
│           │             │                                                 │
│           │             ▼                                                 │
│           │    ┌─────────────────┐                                       │
│           │    │   PtySession    │                                       │
│           │    │                 │                                       │
│           │    │ • Persistent    │                                       │
│           │    │   shell session │                                       │
│           │    │ • Command queue │                                       │
│           │    └─────────────────┘                                       │
│           │                                                               │
│  ┌────────┴──────────────────────────────────────────────────────────┐   │
│  │                        Support Modules                             │   │
│  │                                                                    │   │
│  │  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐ │   │
│  │  │ KubectlCommand   │  │ KubernetesName   │  │  AnsiSanitizer   │ │   │
│  │  │    Builder       │  │   Validator      │  │                  │ │   │
│  │  │                  │  │                  │  │ • CVE-2021-25743 │ │   │
│  │  │ • Shell escaping │  │ • RFC 1123       │  │   mitigation     │ │   │
│  │  │ • Windows/Unix   │  │ • Injection      │  │ • ANSI stripping │ │   │
│  │  └──────────────────┘  │   prevention     │  └──────────────────┘ │   │
│  │                        └──────────────────┘                        │   │
│  └────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              kubectl exec                                   │
│                                                                             │
│     kubectl exec --stdin <pod> -n <namespace> -c <container> -- <cmd>      │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          Kubernetes Cluster                                 │
│                                                                             │
│    ┌─────────────────────────────────────────────────────────────────┐     │
│    │                           Target Pod                             │     │
│    │  ┌─────────────────────────────────────────────────────────┐    │     │
│    │  │                     Target Container                     │    │     │
│    │  │                                                          │    │     │
│    │  │   /bin/bash, /bin/sh, /bin/ash  ──or──  distroless      │    │     │
│    │  │                                                          │    │     │
│    │  └─────────────────────────────────────────────────────────┘    │     │
│    └─────────────────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Command Execution Flow

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                          Command Execution Flow                              │
└──────────────────────────────────────────────────────────────────────────────┘

   InSpec Control                    Plugin Components                   kubectl
   ─────────────                     ─────────────────                   ───────
        │
        │  command('whoami')
        ▼
   ┌─────────┐
   │ Control │
   └────┬────┘
        │
        ▼
   ┌─────────────────┐
   │   Connection    │ ─── parse URI, validate params
   └────────┬────────┘
            │
            ▼
   ┌─────────────────┐
   │ KubectlExec     │
   │    Client       │
   └────────┬────────┘
            │
            │  Check for existing session
            ▼
   ┌─────────────────┐     ┌─────────────────┐
   │ SessionManager  │────▶│   PtySession    │  (if pooled session exists)
   │   (Singleton)   │     │  (persistent)   │
   └────────┬────────┘     └────────┬────────┘
            │                       │
            │  No session?          │ Has session?
            │  Create new           │ Reuse
            ▼                       ▼
   ┌─────────────────┐     ┌─────────────────┐
   │ KubectlCommand  │     │  Send command   │
   │    Builder      │     │  via PTY pipe   │
   └────────┬────────┘     └────────┬────────┘
            │                       │
            ▼                       ▼
   ┌─────────────────┐     ┌─────────────────┐
   │  Mixlib::       │     │  Read response  │
   │  ShellOut       │     │  until marker   │
   └────────┬────────┘     └────────┬────────┘
            │                       │
            ▼                       ▼
        ┌───────────────────────────────┐
        │        kubectl exec           │ ───▶  Container
        └───────────────┬───────────────┘
                        │
                        ▼
               ┌─────────────────┐
               │ ResultProcessor │
               │                 │
               │ • Parse exit    │
               │   code          │
               │ • Strip ANSI    │
               │ • Detect errors │
               └────────┬────────┘
                        │
                        ▼
               ┌─────────────────┐
               │  RetryHandler   │ ─── Retry on transient errors
               │                 │     (exponential backoff)
               └────────┬────────┘
                        │
                        ▼
               Train::Extras::CommandResult
                  (stdout, stderr, exit_code)
```

## File Structure

```
lib/train-k8s-container/
├── transport.rb              # Train plugin registration
├── connection.rb             # Main connection class
├── kubectl_exec_client.rb    # Command execution engine
├── platform.rb               # OS detection (Detect+Context)
├── version.rb                # Version constant
│
├── session_manager.rb        # Connection pool (Singleton)
├── pty_session.rb            # Persistent PTY shell session
│
├── shell_detector.rb         # Shell/OS detection
├── kubectl_command_builder.rb # Command string building
├── result_processor.rb       # Output parsing & validation
├── retry_handler.rb          # Exponential backoff retry
│
├── ansi_sanitizer.rb         # ANSI escape removal (CVE fix)
├── kubernetes_name_validator.rb  # RFC 1123 validation
└── errors.rb                 # Custom error classes
```

## Component Details

### Core Components

#### Transport (`transport.rb`)

Registers the `k8s-container` transport with Train:

```ruby
module TrainPlugins::K8sContainer
  class Transport < Train.plugin(1)
    name 'k8s-container'
    # ...
  end
end
```

Connection options:
- `pod` - Target pod name (required)
- `container_name` - Target container (required)
- `namespace` - Kubernetes namespace (default: `default`)
- `kubeconfig` - Path to kubeconfig file

#### Connection (`connection.rb`)

Main connection handler:
- Parses URI format: `k8s-container://<namespace>/<pod>/<container>`
- Validates required parameters (pod, container)
- Provides `run_command()` for command execution
- Provides file access via `Train::File::Remote::Linux`

#### KubectlExecClient (`kubectl_exec_client.rb`)

Command execution engine:
- Detects available shell via `ShellDetector`
- Routes commands through `SessionManager` for pooling
- Falls back to direct execution for distroless containers
- Integrates `RetryHandler` for transient errors

#### Platform (`platform.rb`)

OS detection using **Detect+Context** pattern:

```ruby
def platform
  # 1. Use Train's scanner to detect actual OS
  @platform = Train::Platforms::Detect.scan(self)

  # 2. Add Kubernetes context families
  add_k8s_families(@platform)

  @platform
end
```

Result: `os.linux?` returns `true` while `platform.families` includes `kubernetes`, `container`.

### Session Management (Connection Pooling)

#### SessionManager (`session_manager.rb`)

Thread-safe singleton that pools PTY sessions:

```ruby
class SessionManager
  include Singleton

  # One session per namespace/pod/container
  def get_session(session_key, kubectl_cmd:, shell:, timeout:, logger:)
    @mutex.synchronize do
      unless @sessions[session_key]&.healthy?
        @sessions[session_key] = PtySession.new(...)
        @sessions[session_key].connect
      end
      @sessions[session_key]
    end
  end
end
```

Benefits:
- Reuses kubectl exec connections across multiple commands
- Significantly faster for profiles with many controls
- Automatic cleanup on session failure or process exit

#### PtySession (`pty_session.rb`)

Persistent PTY-based shell session:

```ruby
# Instead of spawning kubectl for each command:
kubectl exec pod -c container -- /bin/sh -c "command1"
kubectl exec pod -c container -- /bin/sh -c "command2"
kubectl exec pod -c container -- /bin/sh -c "command3"

# Maintains one persistent session:
kubectl exec pod -c container -- /bin/bash
> command1
> command2
> command3
```

Features:
- Uses Ruby's `PTY.spawn` for interactive session
- Sends commands with exit code markers
- Parses output and extracts real exit codes
- Health checking via process status

### Shell & OS Detection

#### ShellDetector (`shell_detector.rb`)

Detects available shell in container:

```
Detection Order (Unix):
  1. /bin/bash   - Ubuntu, Debian, RHEL
  2. /bin/sh     - POSIX standard
  3. /bin/ash    - Alpine, BusyBox
  4. /bin/zsh    - Less common

Detection Order (Windows):
  1. cmd.exe         - Command prompt
  2. powershell.exe  - PowerShell 5.1
  3. pwsh.exe        - PowerShell Core
```

Also detects Linux distribution family from `/etc/os-release`:
- Debian family: ubuntu, debian, linuxmint, kali
- RedHat family: rhel, centos, fedora, rocky, almalinux
- Alpine, Arch, SUSE, Gentoo

### Command Building & Processing

#### KubectlCommandBuilder (`kubectl_command_builder.rb`)

Builds properly escaped kubectl commands:

```ruby
builder = KubectlCommandBuilder.new(
  kubectl_path: '/usr/bin/kubectl',
  pod: 'my-pod',
  namespace: 'default',
  container_name: 'app'
)

# Unix shell
builder.with_shell('/bin/bash', 'cat /etc/passwd')
# => "kubectl exec --stdin my-pod -n default -c app -- /bin/bash -c 'cat /etc/passwd'"

# Windows shell
builder.with_windows_shell('cmd.exe', 'dir')
# => "kubectl exec --stdin my-pod -n default -c app -- cmd.exe /c 'dir'"

# Direct binary (distroless)
builder.direct_binary('cat /etc/os-release')
# => "kubectl exec --stdin my-pod -n default -c app -- cat /etc/os-release"
```

#### ResultProcessor (`result_processor.rb`)

Processes command output:

1. **Validation**: Detects connection errors and silent failures
2. **Sanitization**: Strips ANSI sequences, normalizes line endings
3. **Exit code parsing**: Extracts real exit code from kubectl messages

Connection error patterns detected:
- `error dialing backend`
- `connection refused`
- `pods "name" not found`
- `Error from server`

### Security Components

#### AnsiSanitizer (`ansi_sanitizer.rb`)

Addresses **CVE-2021-25743** (terminal escape sequence injection):

```ruby
module AnsiSanitizer
  CSI_REGEX = /\e\[([;\d]+)?[A-Za-z]/  # Colors, cursor
  OSC_REGEX = /\e\][^\a]*\a/            # Terminal title
  CURSOR_REGEX = /\e\[A|\e\[C|\e\[K/    # Movement

  def self.sanitize(text)
    # Remove all ANSI escape sequences
  end
end
```

#### KubernetesNameValidator (`kubernetes_name_validator.rb`)

Validates names per **RFC 1123** DNS subdomain rules:

```ruby
VALID_NAME_REGEX = /\A[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)?\z/
MAX_NAME_LENGTH = 253

def self.validate!(name, resource_type:)
  # Prevents command injection via malformed names
end
```

### Error Handling

#### RetryHandler (`retry_handler.rb`)

Exponential backoff for transient errors:

```ruby
RetryHandler.with_retry(max_retries: 3, logger: logger) do
  # Network operation
end

# Retry delays: 1s, 2s, 4s (exponential backoff)
```

Retryable errors:
- `NetworkError` - Silent failures, timeouts
- `ConnectionError` - kubectl connection issues

#### Custom Errors (`errors.rb`)

```ruby
K8sContainerError < Train::TransportError  # Base class
KubectlNotFoundError    # kubectl binary not in PATH
ContainerNotFoundError  # Container doesn't exist in pod
PodNotFoundError        # Pod doesn't exist in namespace
ShellNotAvailableError  # Distroless container, no shell
```

## Platform Detection Deep Dive

### Why "Detect + Context" Pattern?

When connecting to an **operating system** (container, VM, bare metal), Train must detect the actual OS for InSpec resources to work correctly.

**Wrong approach** - `force_platform!('k8s-container')`:
- Platform name becomes `k8s-container` instead of `ubuntu`
- `os.linux?` returns `false`
- Resources like `user`, `package`, `service` fail

**Correct approach** - Detect + Context:
- Detect actual OS: `ubuntu`, `alpine`, `centos`
- Add context families: `kubernetes`, `container`
- `os.linux?` returns `true` ✓
- Resources work correctly ✓

### Detection Commands

Train's scanner executes these to identify the OS:

```bash
uname -s                    # "Linux"
uname -m                    # Architecture
cat /etc/os-release         # OS identification
cat /etc/debian_version     # Debian family
cat /etc/alpine-release     # Alpine
cat /etc/redhat-release     # RHEL family
```

### Result

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
```bash
# Full URI
k8s-container://production/web-app/nginx

# Default namespace
k8s-container:///my-pod/my-container
```

## Testing Architecture

### Test Structure

```
spec/
├── train-k8s-container/     # Unit tests (mocked)
│   ├── connection_spec.rb
│   ├── kubectl_exec_client_spec.rb
│   ├── platform_spec.rb
│   ├── shell_detector_spec.rb
│   ├── session_manager_spec.rb
│   └── ...
│
└── integration/             # Integration tests (real cluster)
    ├── platform_detection_spec.rb
    ├── command_execution_spec.rb
    └── ...
```

### CI Matrix

| Test Type | Ruby | Kubernetes | Description |
|-----------|------|------------|-------------|
| Unit | 3.1, 3.2, 3.3 | N/A | Mocked, fast |
| Integration | 3.1, 3.2, 3.3 | 1.29, 1.30, 1.31 | Real kind cluster |
| Pod-to-Pod | 3.3 | 1.30 | Scanner inside cluster |

## Key Design Decisions

1. **kubectl over Kubernetes Ruby client**
   - Simpler dependency management
   - Leverages user's existing kubeconfig and auth
   - Works with any kubectl-compatible cluster

2. **Connection pooling via PTY sessions**
   - Dramatically improves performance for multi-control profiles
   - Single kubectl process instead of one per command
   - Thread-safe singleton pattern

3. **Detect+Context over force_platform**
   - Ensures InSpec resources work correctly
   - Provides Kubernetes awareness via family tags
   - Compatible with existing profiles

4. **RFC 1123 validation**
   - Prevents command injection via malformed names
   - Enforces Kubernetes naming standards

5. **ANSI sanitization (CVE-2021-25743)**
   - Strips terminal escape sequences
   - Prevents injection attacks via kubectl output

6. **Cinc Auditor in CI**
   - Open-source, license-free InSpec distribution
   - No Chef license required for testing

7. **OIDC trusted publishing**
   - Secure gem publishing without API keys
   - Leverages GitHub Actions identity
