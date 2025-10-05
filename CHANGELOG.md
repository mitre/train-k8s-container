# Changelog

## [2.0.0] - 2025-10-04

### Breaking Changes
- **BREAKING**: Namespace changed from `Train::K8s::Container` to `TrainPlugins::K8sContainer` (Train v2 standard)
- **BREAKING**: Replaced deprecated chefstyle with cookstyle for linting
- Ruby requirement: >= 3.1

### Added
- **Shell Detection**: Auto-detect bash, sh, ash, zsh (Unix) and cmd.exe, powershell.exe, pwsh.exe (Windows)
- **OS Detection**: Heuristic detection of Unix vs Windows containers
- **Windows Container Support**: Full support for Windows Server containers
- **Persistent Sessions**: Optional 60% performance improvement with session pooling (TRAIN_K8S_SESSION_MODE=true)
- **Error Handling**: Retry logic with exponential backoff
- **ANSI Sanitization**: Strip escape sequences for security (CVE-2021-25743)
- **Logging**: Configurable logging via TRAIN_K8S_LOG_LEVEL (DEBUG/WARN/ERROR)
- **Custom Errors**: Specific error classes for better error handling
- **Testing Utilities**: test/scripts/ for local development

### Changed
- File structure: lib/train/k8s/container/* → lib/train-k8s-container/*
- Platform: Uses force_platform! with cloud+unix families
- Connection: Lazy kubectl_client initialization
- Transport: Proper v2 API implementation

### Fixed
- Shell detection command escaping
- Platform detection (no longer probes Windows on Linux containers)
- Thread safety (SessionManager with Mutex)
- Test command output validation

### Security
- ANSI injection prevention
- Command escaping with Shellwords
- Network error detection

<!-- latest_release 1.3.1 -->
## [v1.3.1](https://github.com/inspec/train-k8s-container/tree/v1.3.1) (2024-03-05)

#### Merged Pull Requests
- Bug Fix shell run command [#21](https://github.com/inspec/train-k8s-container/pull/21) ([sathish-progress](https://github.com/sathish-progress))
<!-- latest_release -->

<!-- release_rollup -->
### Changes not yet released to rubygems.org

#### Merged Pull Requests
- Bug Fix shell run command [#21](https://github.com/inspec/train-k8s-container/pull/21) ([sathish-progress](https://github.com/sathish-progress)) <!-- 1.3.1 -->
- add support to file connection [#19](https://github.com/inspec/train-k8s-container/pull/19) ([sathish-progress](https://github.com/sathish-progress)) <!-- 1.3.0 -->
- Fix for undefined method presence [#17](https://github.com/inspec/train-k8s-container/pull/17) ([Vasu1105](https://github.com/Vasu1105)) <!-- 1.2.1 -->
- CHEF-7406 update README and inspec compatibility [#15](https://github.com/inspec/train-k8s-container/pull/15) ([sathish-progress](https://github.com/sathish-progress)) <!-- 1.2.0 -->
- CHEF-7406 connection to container [#14](https://github.com/inspec/train-k8s-container/pull/14) ([sathish-progress](https://github.com/sathish-progress)) <!-- 1.1.2 -->
- CHEF-7406 specs for transporter [#13](https://github.com/inspec/train-k8s-container/pull/13) ([sathish-progress](https://github.com/sathish-progress)) <!-- 1.1.1 -->
- CHEF-7406 kubectl exec client [#10](https://github.com/inspec/train-k8s-container/pull/10) ([sathish-progress](https://github.com/sathish-progress)) <!-- 1.1.0 -->
- CHEF-7406 transporter for k8s container [#9](https://github.com/inspec/train-k8s-container/pull/9) ([sathish-progress](https://github.com/sathish-progress)) <!-- 1.0.0 -->
- Updates verify pipeline and coverage pipeline [#12](https://github.com/inspec/train-k8s-container/pull/12) ([Vasu1105](https://github.com/Vasu1105)) <!-- 0.0.7 -->
- Add Version bumper [#11](https://github.com/inspec/train-k8s-container/pull/11) ([sathish-progress](https://github.com/sathish-progress)) <!-- 0.0.6 -->
- Set license to Apache v 2.0 [#8](https://github.com/inspec/train-k8s-container/pull/8) ([clintoncwolfe](https://github.com/clintoncwolfe)) <!-- 0.0.5 -->
- CHEF-8269: Configures sonarqube for code coverage analysis [#7](https://github.com/inspec/train-k8s-container/pull/7) ([Vasu1105](https://github.com/Vasu1105)) <!-- 0.0.4 -->
- CHEF-8270: Initialize repo with `bundle gem train-k8s-container` [#2](https://github.com/inspec/train-k8s-container/pull/2) ([ahasunos](https://github.com/ahasunos)) <!-- 0.0.3 -->
- CHEF-8269: Implement coverage pipeline for train-k8s-container [#3](https://github.com/inspec/train-k8s-container/pull/3) ([ahasunos](https://github.com/ahasunos)) <!-- 0.0.2 -->
<!-- release_rollup -->

<!-- latest_stable_release -->
<!-- latest_stable_release -->