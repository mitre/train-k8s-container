# Troubleshooting Guide
## kind Cluster for train-k8s-container Testing

---

## Common Issues

### 1. "cannot exec into a container in a completed pod"

**Error**:
```
error: cannot exec into a container in a completed pod; current phase is Succeeded
```

**Cause**: Test pods run `sleep 3600` and complete after 1 hour.

**Solutions**:

**Option A: Use the setup script** (Recommended)
```bash
./test/setup-kind.sh
```
The script automatically detects and recreates completed pods.

**Option B: Manual recreation**
```bash
kubectl delete pod test-ubuntu test-alpine
kubectl run test-ubuntu --image=ubuntu:22.04 --restart=Never -- sleep infinity
kubectl run test-alpine --image=alpine:3.18 --restart=Never -- sleep infinity
kubectl wait --for=condition=Ready pod/test-ubuntu pod/test-alpine --timeout=120s
```

**Option C: Quick restart**
```bash
kubectl replace --force -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-ubuntu
spec:
  containers:
  - name: test-ubuntu
    image: ubuntu:22.04
    command: ["sleep"]
    args: ["infinity"]
  restartPolicy: Never
EOF
```

---

### 2. Cluster doesn't exist or won't start

**Error**:
```
Error: cluster "test-cluster" not found
```

**Solution**:
```bash
# Check if cluster exists
kind get clusters

# Create cluster
./test/setup-kind.sh

# Or manually
kind create cluster --name test-cluster --config test/kind-config.yaml --wait 60s
```

**Error**:
```
ERROR: failed to create cluster: node(s) already exist for a cluster with the name "test-cluster"
```

**Solution**:
```bash
# Delete and recreate
kind delete cluster --name test-cluster
./test/setup-kind.sh
```

---

### 3. Pods won't become Ready

**Symptoms**:
```
pod/test-ubuntu condition met
Error: timed out waiting for the condition on pods/test-ubuntu
```

**Diagnostics**:
```bash
# Check pod status
kubectl get pods -o wide

# Check pod events
kubectl describe pod test-ubuntu

# Check node status
kubectl get nodes

# Check system pods
kubectl get pods -n kube-system
```

**Common Causes**:

**Image pull issues**:
```bash
# Check image pull status
kubectl describe pod test-ubuntu | grep -A 5 Events

# Pull images manually (kind loads from Docker)
docker pull ubuntu:22.04
docker pull alpine:3.18
kind load docker-image ubuntu:22.04 --name test-cluster
kind load docker-image alpine:3.18 --name test-cluster
```

**Node not ready**:
```bash
# Check node
kubectl get nodes

# Restart cluster if needed
kind delete cluster --name test-cluster
kind create cluster --name test-cluster --wait 120s
```

---

### 4. kubectl commands fail or hang

**Error**:
```
The connection to the server localhost:8080 was refused
```

**Cause**: kubectl can't find cluster context.

**Solution**:
```bash
# Check current context
kubectl config current-context

# Should be: kind-test-cluster
# If not, set it:
kubectl config use-context kind-test-cluster

# Or specify in commands:
kubectl --context kind-test-cluster get pods
```

**Error**:
```
Unable to connect to the server: dial tcp [::1]:54916: connect: connection refused
```

**Cause**: Cluster is not running or port changed.

**Solution**:
```bash
# Check if kind cluster is running
docker ps | grep test-cluster

# Should see: test-cluster-control-plane

# If not running, restart
kind delete cluster --name test-cluster
./test/setup-kind.sh
```

---

### 5. kubectl exec fails with permission errors

**Error**:
```
error: unable to upgrade connection: container not found ("test-ubuntu")
```

**Cause**: Wrong container name or pod not ready.

**Diagnostics**:
```bash
# Verify pod and container names
kubectl get pod test-ubuntu -o jsonpath='{.spec.containers[*].name}'
# Should output: test-ubuntu

# Check pod status
kubectl get pod test-ubuntu
# Should be: Running

# Try with explicit container name
kubectl exec test-ubuntu -c test-ubuntu -- whoami
```

---

### 6. Version compatibility issues

**Symptoms**:
- Deprecation warnings
- API version errors
- Feature not available

**Check versions**:
```bash
# kubectl version
kubectl version --short

# Kubernetes server version
kubectl version --output=yaml | grep gitVersion

# kind version
kind version

# Desired versions (from CI):
# - kind: v0.20.0
# - kubectl: v1.30.0
# - Kubernetes: v1.29.0-v1.31.0
```

**Solution**: Use kind-config.yaml which pins to v1.30.0:
```bash
kind delete cluster --name test-cluster
kind create cluster --name test-cluster --config test/kind-config.yaml --wait 60s
```

---

### 7. Train plugin errors

**Error**:
```ruby
Train::ClientError: Kubectl exec failed (exit 1)
```

**Diagnostics**:
```bash
# Test kubectl directly first
kubectl exec test-ubuntu -- whoami

# Enable debug logging
export TRAIN_K8S_LOG_LEVEL=DEBUG
bundle exec ruby test/scripts/test_live.rb

# Test with InSpec
inspec detect -t k8s-container:///test-ubuntu/test-ubuntu
```

**Common causes**:

**KUBECONFIG not set**:
```bash
export KUBECONFIG=~/.kube/config
# Or
export KUBECONFIG=$(kind get kubeconfig --name test-cluster)
```

**Wrong pod/container name**:
```ruby
# Verify parameters match
kubectl get pods  # Check actual pod names

# Try with explicit namespace
inspec shell -t k8s-container://default/test-ubuntu/test-ubuntu
```

---

### 8. Lens shows warnings

**Warning**: "No resource limits set"

**Explanation**: Test pods intentionally omit resource limits for simplicity.

**Fix** (optional):
```yaml
# Create pods with limits
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-ubuntu
spec:
  containers:
  - name: test-ubuntu
    image: ubuntu:22.04
    command: ["sleep"]
    args: ["infinity"]
    resources:
      requests:
        memory: "64Mi"
        cpu: "100m"
      limits:
        memory: "128Mi"
        cpu: "200m"
  restartPolicy: Never
EOF
```

**Warning**: "No security context"

**Explanation**: Pods need root access for InSpec testing.

**Fix** (optional):
```yaml
securityContext:
  runAsNonRoot: false
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
```

---

## Diagnostic Commands

### Cluster Health
```bash
# Overall cluster info
kubectl cluster-info

# Component status
kubectl get componentstatuses

# Node details
kubectl get nodes -o wide
kubectl describe node test-cluster-control-plane

# System pods
kubectl get pods -A
kubectl get pods -n kube-system
```

### Pod Diagnostics
```bash
# Pod status
kubectl get pods -o wide

# Pod details
kubectl describe pod test-ubuntu

# Pod logs (if any)
kubectl logs test-ubuntu

# Pod events
kubectl get events --field-selector involvedObject.name=test-ubuntu

# Pod YAML
kubectl get pod test-ubuntu -o yaml
```

### Network Diagnostics
```bash
# Check DNS
kubectl exec test-ubuntu -- nslookup kubernetes.default

# Check connectivity
kubectl exec test-ubuntu -- ping -c 1 10.96.0.1

# Check services
kubectl get svc -A
```

### Exec Testing
```bash
# Basic exec
kubectl exec test-ubuntu -- whoami

# Interactive shell
kubectl exec -it test-ubuntu -- /bin/bash

# Stdin mode (used by train-k8s-container)
kubectl exec --stdin test-ubuntu -- /bin/sh -c "whoami"

# Multi-line commands
kubectl exec test-ubuntu -- /bin/sh -c "
  echo 'Testing multi-line'
  whoami
  pwd
"
```

---

## Environment Verification

### Complete Health Check Script
```bash
#!/bin/bash
# Save as: test/verify-cluster.sh

set -e

echo "=== Cluster Health Check ==="
echo

echo "1. Cluster Info:"
kubectl cluster-info

echo
echo "2. Node Status:"
kubectl get nodes

echo
echo "3. System Pods:"
kubectl get pods -n kube-system

echo
echo "4. Test Pods:"
kubectl get pods

echo
echo "5. Test Pod Details:"
for pod in test-ubuntu test-alpine; do
  echo "  - $pod:"
  kubectl get pod $pod -o jsonpath='    Status: {.status.phase}, IP: {.status.podIP}'
  echo
done

echo
echo "6. Exec Tests:"
echo "  Ubuntu (bash):"
kubectl exec test-ubuntu -- bash -c 'echo "  - whoami: $(whoami)"'
kubectl exec test-ubuntu -- bash -c 'echo "  - shell: $BASH_VERSION"'

echo "  Alpine (ash):"
kubectl exec test-alpine -- sh -c 'echo "  - whoami: $(whoami)"'
kubectl exec test-alpine -- sh -c 'echo "  - shell: ash"'

echo
echo "7. Train Plugin Test:"
bundle exec ruby test/scripts/test_live.rb | grep -E "(===|✅|❌)"

echo
echo "=== All Checks Complete ==="
```

Usage:
```bash
chmod +x test/verify-cluster.sh
./test/verify-cluster.sh
```

---

## Reset Procedures

### Soft Reset (Keep Cluster)
```bash
# Just recreate pods
kubectl delete pod test-ubuntu test-alpine --ignore-not-found=true
./test/scripts/create_test_pods.sh
```

### Medium Reset (Recreate Cluster)
```bash
# Delete and recreate cluster
kind delete cluster --name test-cluster
./test/setup-kind.sh
```

### Hard Reset (Clean Everything)
```bash
# Remove all kind clusters
kind get clusters | xargs -n1 kind delete cluster --name

# Remove cached images (optional)
docker system prune -a

# Recreate from scratch
./test/setup-kind.sh
```

---

## Performance Issues

### Slow Pod Startup
```bash
# Pre-pull images
docker pull ubuntu:22.04
docker pull alpine:3.18

# Load into kind
kind load docker-image ubuntu:22.04 --name test-cluster
kind load docker-image alpine:3.18 --name test-cluster
```

### High CPU/Memory Usage
```bash
# Check resource usage
docker stats test-cluster-control-plane

# Allocate more resources to Docker Desktop
# Settings > Resources > Increase CPU/Memory

# Or use resource limits on pods (see issue #8)
```

---

## CI vs Local Differences

| Issue | CI (GitHub Actions) | Local (macOS) | Solution |
|-------|---------------------|---------------|----------|
| Architecture | x86_64 | ARM64 (M-series) | Use multi-arch images |
| Kubernetes version | v1.29-1.31 | v1.34 | Use kind-config.yaml (pins v1.30) |
| Pod lifetime | Recreated each run | Persistent | Use setup script |
| kubectl version | v1.30.0 | v1.34.1 | Version mismatch acceptable |
| Docker runtime | containerd | containerd | Same (good) |

---

## Getting Help

### Useful Resources
- kind documentation: https://kind.sigs.k8s.io/
- kubectl reference: https://kubernetes.io/docs/reference/kubectl/
- Train documentation: https://github.com/inspec/train

### Debug Logs
```bash
# Enable kubectl debug
kubectl -v=8 exec test-ubuntu -- whoami

# Enable train-k8s-container debug
export TRAIN_K8S_LOG_LEVEL=DEBUG

# Enable InSpec debug
inspec exec --log-level debug
```

### Collect Diagnostics
```bash
# Create diagnostic bundle
mkdir -p /tmp/kind-diagnostics
kubectl cluster-info dump > /tmp/kind-diagnostics/cluster-dump.txt
kubectl get all -A -o yaml > /tmp/kind-diagnostics/all-resources.yaml
kubectl get events -A > /tmp/kind-diagnostics/events.txt
kind export logs /tmp/kind-diagnostics/kind-logs
tar czf kind-diagnostics.tar.gz /tmp/kind-diagnostics/
```

---

## Quick Commands Reference

```bash
# Status checks
kubectl get pods
kubectl get nodes
kubectl cluster-info

# Recreate pods
kubectl delete pod test-ubuntu test-alpine
./test/scripts/create_test_pods.sh

# Test exec
kubectl exec test-ubuntu -- whoami
kubectl exec test-alpine -- whoami

# Test plugin
bundle exec ruby test/scripts/test_live.rb

# Reset cluster
kind delete cluster --name test-cluster
./test/setup-kind.sh

# Cleanup
./test/cleanup-kind.sh
```

---

**Last Updated**: 2025-10-04
**Compatible with**: kind v0.20+, Kubernetes v1.29-v1.34, kubectl v1.30+
