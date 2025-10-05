# Testing Guide for train-k8s-container

This directory contains integration testing setup and utilities.

## Quick Start

```bash
# 1. Setup kind cluster and test pods
./test/setup-kind.sh

# 2. Run integration tests
bundle exec rspec spec/integration

# 3. Cleanup
./test/cleanup-kind.sh
```

## Test Scripts

- **setup-kind.sh** - Creates kind cluster with test pods
- **cleanup-kind.sh** - Removes test cluster
- **test_live.rb** - Manual smoke testing

## Configuration

- **kind-config.yaml** - kind cluster configuration

For full documentation, see main [README.md](../README.md#testing).
