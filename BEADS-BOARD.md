# train-k8s-container - Project Board

**Last Updated:** 2025-12-21
**Current Version:** 2.0.1
**RubyGems:** `train-k8s-container-mitre`
**Branch:** main

---

## Current Status: ✅ Released

v2.0.1 published to RubyGems and working correctly.

---

## Quick Start

```bash
# Resume Claude session
claude --continue

# Install plugin
cinc-auditor plugin install train-k8s-container-mitre

# Test with running pod
cinc-auditor detect -t k8s-container://default/test-nginx/test-nginx
```

---

## Active Tasks

| Task | Status | Notes |
|------|--------|-------|
| Submit PR: Auto-discover train plugins | ⏳ Pending | Plan at `../inspec/PR-AUTO-DISCOVER-TRAIN-PLUGINS.md` |
| Submit PR: Dynamic os.kubernetes? | ⏳ Pending | Plan at `../inspec/PR-DYNAMIC-OS-FAMILY-METHODS.md` |

---

## Test Environment

```bash
# Available test pods (may need recreation if completed)
kubectl run test-nginx --image=nginx:alpine --restart=Never
kubectl run test-ubuntu --image=ubuntu:24.04 --restart=Never -- sleep infinity
kubectl run test-ubi9 --image=registry.access.redhat.com/ubi9/ubi:latest --restart=Never -- sleep infinity

# Check pod status
kubectl get pods
```

---

## Key Files

| File | Purpose |
|------|---------|
| `lib/train-k8s-container/transport.rb` | Train.plugin(1) registration |
| `lib/train-k8s-container/connection.rb` | kubectl exec connection |
| `lib/train-k8s-container/platform.rb` | OS detection + k8s families |
| `lib/train-k8s-container-mitre.rb` | Shim for gem name |
| `.github/workflows/release-please.yml` | Automated version PRs |
| `.github/workflows/release-tag.yml` | Publish on tag |

---

## Release Process

1. Commits with conventional prefixes land on `main`
2. release-please creates a Release PR
3. Merge PR → tag created automatically
4. Tag triggers `release-tag.yml` → publishes to RubyGems

**Do NOT manually tag** - let release-please handle it.

---

## Session History

| Date | Session | Summary |
|------|---------|---------|
| 2025-12-21 | SESSION-2025-12-21-008.md | Plugin API clarified, tested on 3 OS types |
| 2025-12-12 | SESSION-2025-12-12-009.md | Diagrams research |
| 2025-12-05 | SESSION-2025-12-05-007.md | v2.0.1 released to RubyGems |
| 2025-12-04 | SESSION-2025-12-04-006.md | CI fixed, release automation |

---

## Known Issues

1. **gem install doesn't show in plugin list** - InSpec bug, PR plan ready
2. **Test pods expire** - Recreate with `--restart=Never` + `sleep infinity`

---

## Recovery Prompt

```
Continue train-k8s-container from BEADS-BOARD.md

Status: v2.0.1 released and working
Pending: Submit 2 PRs to inspec/inspec upstream
Test pods: test-nginx, test-ubuntu, test-ubi9 (may need recreation)
```
