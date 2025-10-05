#!/bin/bash
# Setup kind cluster for integration testing
# Mirrors CI environment for local testing

set -e

CLUSTER_NAME="${CLUSTER_NAME:-test-cluster}"
KUBECTL_VERSION="${KUBECTL_VERSION:-v1.30.0}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/kind-config.yaml"

echo "=== Setting up kind cluster for integration testing ==="
echo

# Check if kind is installed
if ! command -v kind &> /dev/null; then
    echo "❌ kind is not installed"
    echo "Install with: brew install kind"
    echo "Or see: https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
    exit 1
fi

echo "✅ kind installed: $(kind version)"

# Check if cluster already exists
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    echo "⚠️  Cluster '${CLUSTER_NAME}' already exists"
    read -p "Delete and recreate? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Deleting existing cluster..."
        kind delete cluster --name "${CLUSTER_NAME}"
    else
        echo "Using existing cluster"
        kubectl cluster-info --context "kind-${CLUSTER_NAME}"

        # Check if test pods are running
        if kubectl get pods test-ubuntu test-alpine &>/dev/null; then
            UBUNTU_STATUS=$(kubectl get pod test-ubuntu -o jsonpath='{.status.phase}')
            ALPINE_STATUS=$(kubectl get pod test-alpine -o jsonpath='{.status.phase}')

            if [[ "$UBUNTU_STATUS" != "Running" ]] || [[ "$ALPINE_STATUS" != "Running" ]]; then
                echo "⚠️  Test pods are not running (Ubuntu: $UBUNTU_STATUS, Alpine: $ALPINE_STATUS)"
                echo "Recreating test pods..."
                kubectl delete pod test-ubuntu test-alpine --ignore-not-found=true
                kubectl run test-ubuntu --image=ubuntu:22.04 --restart=Never -- sleep infinity
                kubectl run test-alpine --image=alpine:3.18 --restart=Never -- sleep infinity
                kubectl wait --for=condition=Ready pod/test-ubuntu --timeout=120s
                kubectl wait --for=condition=Ready pod/test-alpine --timeout=120s
            fi
        else
            echo "Creating test pods..."
            kubectl run test-ubuntu --image=ubuntu:22.04 --restart=Never -- sleep infinity
            kubectl run test-alpine --image=alpine:3.18 --restart=Never -- sleep infinity
            kubectl wait --for=condition=Ready pod/test-ubuntu --timeout=120s
            kubectl wait --for=condition=Ready pod/test-alpine --timeout=120s
        fi

        kubectl get pods
        exit 0
    fi
fi

# Create kind cluster with config file
echo
echo "Creating kind cluster '${CLUSTER_NAME}' with configuration..."
if [[ -f "$CONFIG_FILE" ]]; then
    echo "Using config: $CONFIG_FILE"
    kind create cluster --name "${CLUSTER_NAME}" --config "$CONFIG_FILE" --wait 60s
else
    echo "⚠️  Config file not found, using default configuration"
    kind create cluster --name "${CLUSTER_NAME}" --wait 60s
fi

# Verify cluster
echo
echo "Verifying cluster..."
kubectl cluster-info --context "kind-${CLUSTER_NAME}"
kubectl get nodes

# Create test pods (same as CI)
echo
echo "Creating test pods..."
kubectl run test-ubuntu --image=ubuntu:22.04 --restart=Never -- sleep 3600
kubectl run test-alpine --image=alpine:3.18 --restart=Never -- sleep 3600

# Wait for pods to be ready
echo
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=Ready pod/test-ubuntu --timeout=120s
kubectl wait --for=condition=Ready pod/test-alpine --timeout=120s

# Verify pods
echo
echo "Verifying pods..."
kubectl get pods

echo
echo "=== Setup Complete! ==="
echo
echo "Test pods running:"
echo "  - test-ubuntu (Ubuntu 22.04 with bash)"
echo "  - test-alpine (Alpine 3.18 with ash/sh)"
echo
echo "Run integration tests:"
echo "  bundle exec rspec --tag integration"
echo
echo "Run all tests (unit + integration):"
echo "  bundle exec rspec"
echo
echo "Cleanup when done:"
echo "  kind delete cluster --name ${CLUSTER_NAME}"
echo
