# Testing Guide for train-k8s-container

This directory contains integration testing setup and utilities.

## Quick Start

```bash
# 1. Setup kind cluster and test pods
./test/setup-kind.sh

# 2. Run integration tests
bundle exec rspec spec/integration --tag type:integration

# 3. Cleanup
./test/cleanup-kind.sh
```

## Test Scripts

- **setup-kind.sh** - Creates kind cluster with test pods
- **cleanup-kind.sh** - Removes test cluster

## Configuration

- **kind-config.yaml** - kind cluster configuration

For full documentation, see main [README.md](../README.md#testing).
