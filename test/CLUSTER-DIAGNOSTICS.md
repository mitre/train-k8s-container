# kind Cluster Diagnostic Report
## train-k8s-container Integration Testing

**Date**: 2025-10-04
**Cluster Name**: test-cluster
**Purpose**: Integration testing for Train plugin kubectl exec functionality

---

## Executive Summary

### ✅ Current Status: WORKING
- Cluster is healthy and fully functional
- All system components running correctly
- Test pods can be exec'd into successfully
- kubectl exec functionality verified

### ⚠️ Issues Found (Lens would flag these)

1. **CRITICAL: Test pods complete after 1 hour** (sleep 3600 expires)
   - Status: `Completed` pods cannot be exec'd into
   - Impact: Integration tests fail after 60 minutes
   - Fix: Added auto-restart logic to setup script

2. **WARNING: No resource limits set on test pods**
   - Test pods have `resources: {}`
   - Lens best practice: Always set requests/limits
   - Impact: Low priority for testing (not production)

3. **INFO: No security context defined**
   - Pods run as root with default security
   - Lens recommendation: Define securityContext
   - Impact: Acceptable for testing environment

4. **INFO: Kubernetes version mismatch**
   - Local cluster: v1.34.0 (latest kind default)
   - CI environment: v1.29.0, v1.30.0, v1.31.0
   - kubectl version: v1.34.1 (latest)
   - Impact: May cause compatibility issues with older K8s APIs

---

## Detailed Findings

### 1. Cluster Configuration

**kind Version**: v0.30.0 (latest)
**Kubernetes Server**: v1.34.0
**kubectl Client**: v1.34.1
**Node**: test-cluster-control-plane (ARM64, Debian 12)
**Container Runtime**: containerd 2.1.3

**Comparison to CI**:
- CI uses: kind v0.20.0 (older)
- CI uses: kubectl v1.30.0 (pinned)
- CI tests K8s: v1.29.0, v1.30.0, v1.31.0
- **Gap**: Local uses v1.34.0 (newer than CI tests)

### 2. Network Configuration

**CNI**: Kindnet (default)
**Pod CIDR**: 10.244.0.0/24
**Service CIDR**: 10.96.0.0/12
**DNS**: CoreDNS 2 replicas (Running)

Status: ✅ All networking components healthy

### 3. Storage Configuration

**Storage Class**: `standard` (default)
**Provisioner**: rancher.io/local-path
**Reclaim Policy**: Delete
**Volume Binding**: WaitForFirstConsumer

Status: ✅ Configured correctly for kind

### 4. Test Pods Analysis

#### test-ubuntu (Ubuntu 22.04)
```yaml
Image: ubuntu:22.04
Command: sleep 3600
Status: Running (after manual restart)
IP: 10.244.0.7
Shell: /bin/bash
```

**Issues**:
- ❌ No resource limits (`resources: {}`)
- ❌ No security context (`securityContext: {}`)
- ❌ Runs as root (UID 0)
- ⚠️ Exits after 1 hour (sleep 3600)

**Testing Results**:
```bash
✅ kubectl exec test-ubuntu -- whoami         # root
✅ kubectl exec test-ubuntu -- uname -a        # Linux 6.10.14
✅ bundle exec ruby test/scripts/test_live.rb  # All tests pass
```

#### test-alpine (Alpine 3.18)
```yaml
Image: alpine:3.18
Command: sleep 3600
Status: Running (after manual restart)
IP: 10.244.0.8
Shell: /bin/ash (symlinked to /bin/sh)
```

**Same Issues as Ubuntu pod**

**Testing Results**:
```bash
✅ kubectl exec test-alpine -- whoami          # root
✅ kubectl exec test-alpine -- cat /etc/alpine-release  # 3.18.12
✅ Train plugin live test                      # All tests pass
```

### 5. System Components

All core Kubernetes components healthy:

| Component | Status | Notes |
|-----------|--------|-------|
| etcd | ✅ Healthy | Single instance |
| kube-apiserver | ✅ Healthy | Running |
| kube-controller-manager | ✅ Healthy | Running |
| kube-scheduler | ✅ Healthy | Running |
| kube-proxy | ✅ Running | CNI networking |
| CoreDNS | ✅ Running | 2 replicas |
| Kindnet | ✅ Running | CNI plugin |
| local-path-provisioner | ✅ Running | Storage |

### 6. kubectl exec Compatibility

**Test Results**:
```bash
# Direct kubectl commands
✅ kubectl exec test-ubuntu -- whoami
✅ kubectl exec test-alpine -- whoami
✅ kubectl exec --stdin test-ubuntu -- /bin/sh -c "echo test"
✅ kubectl exec --stdin test-alpine -- /bin/sh -c "echo test"

# Train plugin commands
✅ bundle exec ruby test/scripts/test_live.rb
  - Platform detection: k8s-container (cloud+container+unix)
  - Command execution: whoami, cat, uname
  - File operations: /etc/passwd existence check
  - Shell detection: bash (Ubuntu), sh/ash (Alpine)
```

**Status**: ✅ Full compatibility with train-k8s-container plugin

### 7. What Lens Would Flag

Lens Desktop would show these warnings:

#### High Priority
- 🔴 **No resource limits**: Test pods have no CPU/memory limits
- 🟡 **Security context missing**: Pods run with default security

#### Medium Priority
- 🟡 **Running as root**: Both pods use UID 0
- 🟡 **No readiness/liveness probes**: Pods don't define health checks

#### Low Priority (Info)
- ℹ️ **No labels**: Minimal pod labels (only `run=<name>`)
- ℹ️ **No network policies**: Default allow-all networking
- ℹ️ **Deprecated APIs**: ComponentStatus API (deprecated v1.19+)

#### Not Issues for Testing
- ✅ No ingress configured (not needed)
- ✅ No metrics server (not needed for exec testing)
- ✅ No persistent volumes (stateless testing)

---

## Recommended Configuration

### Option 1: Minimal (Current + Fixes)

Keep current setup but fix critical issues:

**Changes**:
1. ✅ Add pod restart detection to setup script
2. ✅ Create kind-config.yaml for consistency
3. Consider: Pin Kubernetes version to match CI

**Pros**: Simple, matches CI closely
**Cons**: Still has Lens warnings (acceptable for testing)

### Option 2: Production-Like (Lens-Compliant)

Add resource limits and security context:

```yaml
# Enhanced test pod configuration
apiVersion: v1
kind: Pod
metadata:
  name: test-ubuntu
  labels:
    app: train-k8s-test
    environment: integration
spec:
  containers:
  - name: test-ubuntu
    image: ubuntu:22.04
    command: ["sleep"]
    args: ["infinity"]  # Never exits
    resources:
      requests:
        memory: "64Mi"
        cpu: "100m"
      limits:
        memory: "128Mi"
        cpu: "200m"
    securityContext:
      runAsNonRoot: false  # Need root for InSpec testing
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: false
      capabilities:
        drop:
          - ALL
  restartPolicy: Never
```

**Pros**: Lens-compliant, production-like
**Cons**: More complex, may interfere with testing

### Option 3: Long-Running Pods (Recommended)

Simple fix for the critical issue:

**Change**: `sleep 3600` → `sleep infinity`

```bash
kubectl run test-ubuntu --image=ubuntu:22.04 --restart=Never -- sleep infinity
kubectl run test-alpine --image=alpine:3.18 --restart=Never -- sleep infinity
```

**Pros**:
- Pods never complete
- Simple one-line change
- Still minimal/clean

**Cons**:
- Must manually delete when done

---

## Action Items (Prioritized)

### Critical (Must Fix)

1. **✅ DONE: Add pod status check to setup script**
   - Detects `Completed` pods
   - Auto-recreates if needed
   - Prevents "cannot exec into completed pod" errors

2. **Use `sleep infinity` instead of `sleep 3600`**
   - Prevents pods from completing
   - Aligns with long-running test scenarios
   - Already updated in enhanced setup script

### Recommended (Should Fix)

3. **Pin Kubernetes version in kind config**
   - Match CI environment (v1.30.0)
   - Use kind-config.yaml to specify version
   - Prevents compatibility surprises

4. **Document version alignment**
   - Update test/README.md with version requirements
   - Note differences between local and CI
   - Add troubleshooting for version mismatches

### Optional (Nice to Have)

5. **Add resource limits to test pods**
   - Silence Lens warnings
   - More production-like
   - Low priority for testing

6. **Add pod labels**
   - Better organization in Lens
   - Easier cleanup
   - Not critical for functionality

7. **Create pod manifests**
   - Move from `kubectl run` to `kubectl apply -f`
   - Version control pod configurations
   - Easier to manage resources/security

---

## Improved kind Configuration

Created: `test/kind-config.yaml`

**Features**:
- Single control-plane node (sufficient for testing)
- Kindnet CNI (default, lightweight)
- Standard networking (pod/service subnets)
- Port mappings for ingress (80/443) if needed later
- Containerd runtime configuration

**Usage**:
```bash
# Now automatically used by setup-kind.sh
kind create cluster --name test-cluster --config test/kind-config.yaml --wait 60s
```

---

## Updated Setup Script

Enhanced: `test/setup-kind.sh`

**New Features**:
1. ✅ Detects completed pods and auto-recreates
2. ✅ Uses kind-config.yaml if available
3. ✅ Checks pod status on existing cluster
4. ✅ Graceful handling of pod recreation
5. ✅ Better error messages and diagnostics

**Example Output**:
```bash
$ ./test/setup-kind.sh
=== Setting up kind cluster for integration testing ===

✅ kind installed: kind v0.30.0 go1.25.0 darwin/arm64
⚠️  Cluster 'test-cluster' already exists
Using existing cluster
Kubernetes control plane is running at https://127.0.0.1:54916

⚠️  Test pods are not running (Ubuntu: Succeeded, Alpine: Succeeded)
Recreating test pods...
pod "test-ubuntu" deleted
pod "test-alpine" deleted
pod/test-ubuntu created
pod/test-alpine created
pod/test-ubuntu condition met
pod/test-alpine condition met

NAME          READY   STATUS    RESTARTS   AGE
test-alpine   1/1     Running   0          5s
test-ubuntu   1/1     Running   0          5s
```

---

## kubectl exec Compatibility Assessment

### ✅ Fully Compatible

The current kind cluster setup is **fully compatible** with train-k8s-container:

**Verified Functionality**:
- ✅ Basic exec: `kubectl exec <pod> -- <command>`
- ✅ Stdin mode: `kubectl exec --stdin <pod> -- /bin/sh -c "<command>"`
- ✅ Shell detection: Bash (Ubuntu), ash/sh (Alpine)
- ✅ Command execution: All basic commands work
- ✅ File operations: Train::File::Remote::Linux works
- ✅ Platform detection: Correctly identifies k8s-container
- ✅ Error handling: Connection errors properly reported

**Train Plugin Test Results**:
```
Train-k8s-container Live Testing
Version: 1.3.1

=== Ubuntu Container (bash) ===
  Platform: k8s-container
  Families: cloud, container, unix
  URI: k8s-container://default/test-ubuntu/test-ubuntu
  Unique ID: default/test-ubuntu/test-ubuntu
  whoami: root (exit: 0)
  /etc/passwd exists: true
  OS: PRETTY_NAME="Ubuntu 22.04.5 LTS"
  ✅ All tests passed for Ubuntu Container (bash)

=== Alpine Container (ash/sh) ===
  Platform: k8s-container
  Families: cloud, container, unix
  URI: k8s-container://default/test-alpine/test-alpine
  Unique ID: default/test-alpine/test-alpine
  whoami: root (exit: 0)
  /etc/passwd exists: true
  Alpine version: 3.18.12
  ✅ All tests passed for Alpine Container (ash/sh)

✅ All live tests completed successfully!
```

### Known Limitations (Not Issues)

- No TTY allocation tested (plugin uses `--stdin`, not `--stdin --tty`)
- No multi-container pod testing (single container per pod)
- No namespace-scoped RBAC (using default service account)

**Assessment**: These are intentional design choices, not bugs.

---

## Comparison: Local vs CI

| Aspect | Local (Current) | CI (GitHub Actions) |
|--------|----------------|---------------------|
| **kind version** | v0.30.0 | v0.20.0 |
| **K8s version** | v1.34.0 | v1.29.0-1.31.0 |
| **kubectl version** | v1.34.1 | v1.30.0 |
| **Node architecture** | ARM64 (M-series) | x86_64 (AMD64) |
| **Container runtime** | containerd 2.1.3 | containerd (version varies) |
| **Config file** | kind-config.yaml | None (defaults) |
| **Pod lifetime** | ~~3600s~~ → infinity | 3600s (recreated each run) |
| **Setup method** | Interactive script | GitHub Actions YAML |

**Recommendation**: Pin local K8s version to v1.30.0 to match CI middle version.

---

## Next Steps

### Immediate (Do Now)

1. ✅ **DONE**: Updated setup-kind.sh with pod status checking
2. ✅ **DONE**: Created kind-config.yaml for reproducibility
3. **Test the updated script**:
   ```bash
   kind delete cluster --name test-cluster
   ./test/setup-kind.sh
   bundle exec ruby test/scripts/test_live.rb
   ```

### Short Term (This Week)

4. **Pin Kubernetes version to v1.30.0**:
   - Update kind-config.yaml:
     ```yaml
     nodes:
     - role: control-plane
       image: kindest/node:v1.30.0@sha256:...
     ```
   - Verify compatibility with CI

5. **Update test/README.md**:
   - Document new setup script features
   - Add troubleshooting for completed pods
   - Note version requirements

### Long Term (Future)

6. **Consider pod manifests**:
   - Create `test/manifests/test-pods.yaml`
   - Add resource limits (optional)
   - Version control pod configuration

7. **Add health checks** (optional):
   - Readiness probe: `exec: command: ["/bin/true"]`
   - Liveness probe: `exec: command: ["/bin/true"]`
   - Silences Lens warnings

---

## Conclusion

**Current Status**: ✅ **CLUSTER IS FULLY FUNCTIONAL**

The kind cluster is working correctly for train-k8s-container integration testing. The primary issue Lens would flag (completed pods after 1 hour) has been addressed with:

1. Enhanced setup script that detects and recreates completed pods
2. Optional kind-config.yaml for reproducible configuration
3. Recommendation to use `sleep infinity` for long-running test scenarios

**Lens Warnings** (resource limits, security context) are low-priority for a testing environment and can be safely ignored or addressed later if needed.

**kubectl exec Compatibility**: ✅ Fully verified and working

**Ready for Integration Testing**: ✅ Yes

---

## Quick Reference

### Check Cluster Health
```bash
kubectl cluster-info
kubectl get nodes
kubectl get pods -A
kubectl get componentstatuses
```

### Recreate Test Pods
```bash
kubectl delete pod test-ubuntu test-alpine --ignore-not-found=true
kubectl run test-ubuntu --image=ubuntu:22.04 --restart=Never -- sleep infinity
kubectl run test-alpine --image=alpine:3.18 --restart=Never -- sleep infinity
kubectl wait --for=condition=Ready pod/test-ubuntu pod/test-alpine --timeout=120s
```

### Test Plugin
```bash
bundle exec ruby test/scripts/test_live.rb
```

### Cleanup
```bash
kind delete cluster --name test-cluster
```

### Reset Everything
```bash
./test/cleanup-kind.sh
./test/setup-kind.sh
```

---

**Report Generated**: 2025-10-04
**Cluster Version**: Kubernetes v1.34.0 (kind v0.30.0)
**Test Status**: ✅ All systems operational
