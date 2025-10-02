# Testing train-k8s-container

This directory contains testing utilities for train-k8s-container development.

## Quick Start

```bash
# 1. Create test pods in your Kubernetes cluster
./test/scripts/create_test_pods.sh

# 2. Run live tests
ruby test/scripts/test_live.rb

# 3. Run unit tests
bundle exec rspec

# 4. Cleanup when done
./test/scripts/cleanup_test_pods.sh
```

## Test Scripts

### `scripts/create_test_pods.sh`
Creates test pods in your Kubernetes cluster:
- `test-ubuntu` - Ubuntu 22.04 with bash
- `test-alpine` - Alpine 3.18 with ash/sh

Pods run `sleep 3600` to stay alive for testing.

### `scripts/test_live.rb`
Direct Ruby test script that validates:
- Connection to pods
- Platform detection (k8s-container with cloud+unix families)
- Command execution (whoami, cat, etc.)
- File operations (file.exist?)
- Shell detection (bash for Ubuntu, sh/ash for Alpine)

Runs without InSpec - just loads the Train plugin directly.

### `scripts/cleanup_test_pods.sh`
Deletes test pods from cluster.

## Testing Approaches

### Option 1: Unit Tests (Fastest)
```bash
bundle exec rspec
bundle exec rake style
```
- 33 unit tests with mocked kubectl execution
- Fast, no cluster required
- Run on every code change

### Option 2: Live Testing with Ruby (Quick Validation)
```bash
ruby test/scripts/test_live.rb
```
- Tests against real Kubernetes pods
- No InSpec installation needed
- Direct Train plugin testing
- Good for quick validation during development

### Option 3: InSpec Integration (Full Stack)
```bash
# Install plugin from source
inspec plugin install /path/to/train-k8s-container

# Test with InSpec
inspec detect -t k8s-container:///test-ubuntu/test-ubuntu
inspec shell -t k8s-container:///test-alpine/test-alpine

# Run InSpec profile
inspec exec my-profile -t k8s-container:///test-ubuntu/test-ubuntu
```
- Full InSpec integration test
- Tests the plugin as users will use it
- Slower, but most realistic

## Debug Logging

Enable debug logging to see detailed execution:

```bash
# For Ruby testing
TRAIN_K8S_LOG_LEVEL=debug ruby test/scripts/test_live.rb

# For InSpec testing
TRAIN_K8S_LOG_LEVEL=debug inspec shell -t k8s-container:///test-ubuntu/test-ubuntu
```

Log levels: DEBUG, INFO, WARN, ERROR (default: WARN)

## Requirements

- Kubernetes cluster (Docker Desktop, minikube, kind, or real cluster)
- kubectl installed and configured
- Ruby >= 3.3
- bundler

## Troubleshooting

### Pods not starting
```bash
kubectl get pods test-ubuntu test-alpine
kubectl describe pod test-ubuntu
```

### Connection failures
```bash
# Verify kubectl access
kubectl exec -it test-ubuntu -- /bin/bash

# Check logs
kubectl logs test-ubuntu
```

### Test failures
```bash
# Reinstall dependencies
bundle install

# Clean and rebuild
rm -rf vendor/
bundle install
bundle exec rspec
```
