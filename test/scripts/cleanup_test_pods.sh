#!/bin/bash
# Cleanup test pods

echo "Deleting test pods..."
kubectl delete pod test-ubuntu --ignore-not-found
kubectl delete pod test-alpine --ignore-not-found
# kubectl delete pod test-distroless --ignore-not-found

echo "Test pods deleted."
