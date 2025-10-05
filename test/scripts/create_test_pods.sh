#!/bin/bash
# Create test pods for manual testing of train-k8s-container

set -e

echo "Creating test pods in default namespace..."

# Ubuntu pod (has bash)
kubectl run test-ubuntu \
  --image=ubuntu:22.04 \
  --command -- sleep 3600 \
  --restart=Never 2>/dev/null || echo "test-ubuntu already exists"

# Alpine pod (has ash/sh, no bash)
kubectl run test-alpine \
  --image=alpine:3.18 \
  --command -- sleep 3600 \
  --restart=Never 2>/dev/null || echo "test-alpine already exists"

# Distroless pod (no shell - for future testing)
# kubectl run test-distroless \
#   --image=gcr.io/distroless/base-debian11 \
#   --command -- sleep 3600 \
#   --restart=Never 2>/dev/null || echo "test-distroless already exists"

echo
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=Ready pod/test-ubuntu --timeout=60s
kubectl wait --for=condition=Ready pod/test-alpine --timeout=60s

echo
echo "Test pods ready:"
kubectl get pods test-ubuntu test-alpine

echo
echo "Test pods created successfully!"
echo
echo "To test with InSpec:"
echo "  inspec detect -t k8s-container:///test-ubuntu/test-ubuntu"
echo "  inspec shell -t k8s-container:///test-alpine/test-alpine"
echo
echo "To test with Ruby:"
echo "  ruby test/scripts/test_live.rb"
