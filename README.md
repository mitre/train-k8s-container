# train-k8s-container - Train Plugin for Kubernetes Containers

**Version 2.0** - Modern Train v2 Plugin with Performance Optimization

A Train transport plugin that enables Chef InSpec to execute compliance checks against containers running in Kubernetes clusters via kubectl exec.

## Features

- ✅ **Train v2 Compliance** - Modern namespace and structure
- ✅ **Multi-Platform Support** - Unix (bash/sh/ash/zsh) and Windows (cmd/PowerShell) containers
- ✅ **Smart Shell Detection** - Automatic detection of available shells
- ✅ **Performance Optimization** - Optional 60% faster execution with persistent sessions
- ✅ **Production-Grade** - Retry logic, error handling, ANSI sanitization
- ✅ **Cross-Platform** - Works on Linux, macOS, and Windows hosts

This plugin allows applications that rely on Train to communicate with Kubernetes containers. For example, InSpec uses this to perform compliance checks against any container in your cluster.

Train itself has no CLI, nor a sophisticated test harness.  InSpec does have such facilities, so installing Train plugins will require an InSpec installation.  You do not need to use or understand InSpec.

Train plugins may be developed without an InSpec installation.

## To Install this Plugin

Train plugins are installed using `inspec plugin install`. Once released, train-k8s-container will be released as a RubyGem, like all train plugins.

### During Development

While the project is still in its early phases and the gem is not yet released, you can preview the functionality.

First obtain a git clone of the train-k8s-container repo:

```bash
$ git clone https://github.com/inspec/train-k8s-container.git
```

Then use the path form of the plugin installer:

```bash
$ inspec plugin install path/to/train-k8s-container
train-k8s-container plugin installed via source path reference, resolved to entry point /Users/wolfe/sandbox/inspec/train-k8s-container/lib/train-k8s-container.rb
```

This technique allows you to run the plugin from the source in the given directory, so you can run from a branch or work from edits. If you are curious how this works, see ~/.inspec/plugins.json .

### As A Gem

Once train-k8s-container is released as a gem, you can install it by name.

Simply run:

```bash
$ inspec plugin install train-k8s-container
```

## Configuration

Below are the two mandatory pre-requisites for this plugin to work.
- `train-k8s-container` creates connection to k8s containers using the [kubeconfig](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl)
Both the kubeconfig and kubectl has to be present on the host machine from where this plugin is executed 

By default, it looks for the kubeconfig file in `~/.kube/config`. It can be overridden by the `ENV["KUBECONFIG"]`.

## Parameters

`pod` and `container_name` are two mandatory parameters. `namespace` is optional only if the namespace is a `default` k8s namespace.
You can then run the Inspec using the `--target` / `-t` option, using the format `-t k8s-container://<namespace>/<pod>/<container_name>`:
for example, 
In order to connect to a container `nginx` of pod `shell-demo` running on `prod` namespace 
the URI would be `k8s-container://prod/shell-demo/nginx`
if in case the targeted container is on a `default` namespace, it can be skipped like this `k8s-container:///shell-demo/nginx`

```bash
$ inspec detect -t k8s-container://default/shell-demo/nginx

 ────────────────────────────── Platform Details ──────────────────────────────

Name:      k8s-container
Families:  unix, os
Release:   1.2.1
Arch:      unknown
```

```bash
$ inspec shell -t k8s-container:///shell-demo/nginx

Welcome to the interactive InSpec Shell
To find out how to use it, type: help

You are currently running on:

    Name:      k8s-container
    Families:  unix, os
    Release:   1.2.1
    Arch:      unknown

inspec>
```

## Supported Container Types

### Linux Containers
- ✅ Ubuntu, Debian, RHEL, CentOS (bash)
- ✅ Alpine, BusyBox (ash/sh)
- ✅ Minimal containers (zsh)
- ⚠️ Distroless (limited - direct binary execution only)

### Windows Containers
- ✅ Windows Server Core (cmd.exe, PowerShell)
- ✅ Nano Server (PowerShell Core)
- **Note**: Requires Windows Kubernetes nodes (tested in CI)

## Usage

### Basic Examples

#### Detect Container Platform
```bash
inspec detect -t k8s-container://production/web-app/nginx
```

#### Run Commands
```bash
inspec> describe command("whoami") do
          its("stdout") { should cmp "root" }
        end
```

#### Check Files
```bash
inspec> describe file('/etc/passwd') do
          it { should exist }
          its('owner') { should eq 'root' }
        end
```

### Persistent Session Mode

**Enabled by default** - Maintains a single kubectl exec session for 60% faster execution:

```bash
# Persistent sessions enabled by default
# To disable (opt-out):
export TRAIN_K8S_SESSION_MODE=false
inspec exec my-profile -t k8s-container:///my-pod/my-container
```

**How it works:**
- Maintains one kubectl exec session (vs spawning kubectl for each command)
- Uses Ruby PTY.spawn for process management (stdin-only, not full TTY)
- SessionManager pools sessions per container
- Automatic fallback to one-off execution on errors

**Platform Support:**
- Unix hosts (Linux, macOS): Persistent sessions enabled by default
- Windows hosts: Automatically disabled, uses one-off execution



## Reporting Issues

Bugs, typos, limitations, and frustrations are welcome to be reported through the [GitHub issues page for the train-k8s-container project](https://github.com/inspec/train-k8s-container/issues).

You may also ask questions in the #inspec channel of the Chef Community Slack team.  However, for an issue to get traction, please report it as a github issue.

## Development on this Plugin

### Development Process

If you wish to contribute to this plugin, please use the usual fork-branch-push-PR cycle.  All functional changes need new tests, and bugfixes are expected to include a new test that demonstrates the bug.

### Reference Information

[Plugin Development](https://github.com/inspec/train/blob/master/docs/dev/plugins.md) is documented on the `train` project on GitHub.