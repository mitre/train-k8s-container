#!/bin/bash
# Cleanup kind cluster after integration testing

set -e

CLUSTER_NAME="${CLUSTER_NAME:-test-cluster}"

echo "=== Cleaning up kind cluster ==="
echo

if ! kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    echo "✅ Cluster '${CLUSTER_NAME}' does not exist, nothing to clean up"
    exit 0
fi

echo "Deleting kind cluster '${CLUSTER_NAME}'..."
kind delete cluster --name "${CLUSTER_NAME}"

echo
echo "✅ Cleanup complete!"
