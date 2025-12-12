# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.1](https://github.com/mitre/train-k8s-container/compare/v2.1.0...v2.1.1) (2025-12-12)


### Bug Fixes

* Parse PR number from JSON in auto-merge step ([09a3667](https://github.com/mitre/train-k8s-container/commit/09a3667cb67010c58837d3ff1ddcf5b197dc3d0d))


### Documentation

* Add ARCHITECTURE.md with technical overview ([acfe73a](https://github.com/mitre/train-k8s-container/commit/acfe73a5ad16faa9b481d0c7802d2a8f6f64efb9))
* Enhance ARCHITECTURE.md with comprehensive technical details ([519675d](https://github.com/mitre/train-k8s-container/commit/519675db04d3766ac3d00575989e748da738a7ea))
* Fix inaccurate claims in README acknowledgments ([fa2e53c](https://github.com/mitre/train-k8s-container/commit/fa2e53c0eee41638edfa04a583bdcea4fd7eb272))
* Update release process documentation for automated workflow ([23d1fcf](https://github.com/mitre/train-k8s-container/commit/23d1fcfb38b1415c12029564b92dbcb9df34715d))

## [2.1.0](https://github.com/mitre/train-k8s-container/compare/v2.0.3...v2.1.0) (2025-12-12)


### Features

* Enable auto-merge for release-please PRs ([f098f5a](https://github.com/mitre/train-k8s-container/commit/f098f5a150d5532b4def7702e9427448d65764bb))


### Bug Fixes

* Remove duplicate push trigger from release workflow ([f1b4c87](https://github.com/mitre/train-k8s-container/commit/f1b4c872f8e1617c38149bc0172ba20e49ba3dc8))

## [2.0.3](https://github.com/mitre/train-k8s-container/compare/v2.0.2...v2.0.3) (2025-12-12)


### Bug Fixes

* Remove duplicate tests from release workflow ([dc9080a](https://github.com/mitre/train-k8s-container/commit/dc9080a48be97cc4c2c4526628d1697636fbe879))
* Use PAT for release-please to trigger CI on PRs ([725a1e3](https://github.com/mitre/train-k8s-container/commit/725a1e359425ca3df6ee2347906935c15fd34de0))

## [2.0.2](https://github.com/mitre/train-k8s-container/compare/v2.0.1...v2.0.2) (2025-12-12)


### Bug Fixes

* Add post-install warning for correct plugin installation ([832e1c3](https://github.com/mitre/train-k8s-container/commit/832e1c36920d59e51ca34fce786fea4749fc4fc4))
* Configure release-please to use simple v* tags ([aefc7ba](https://github.com/mitre/train-k8s-container/commit/aefc7baa4f86608dcfe91479491b150850989d43))


### Documentation

* Update CHANGELOG for v2.0.1 release ([2237873](https://github.com/mitre/train-k8s-container/commit/2237873cc5142f48ca416242f985be0f41550e4d))
* Update installation instructions and add post-install warning ([8649575](https://github.com/mitre/train-k8s-container/commit/86495758a6794ae00505e50391f109442487d72a))
* Update release process documentation for release-please ([a9f4fd3](https://github.com/mitre/train-k8s-container/commit/a9f4fd3ce1da48557aa3442d62ca97ab983b3d21))

## [2.0.1] - 2025-12-05

### Fixed

- Add shim file for train-k8s-container-mitre gem name compatibility
- Reset version tracking for release-please integration

### Miscellaneous Tasks

- Add release-please for automated versioning and changelog
- Bump version to 2.0.1 for first MITRE RubyGems release

## [2.0.0] - 2025-12-05

### Added

- Migrate to Train plugin v2 with multi-platform support and security improvements ([#1](https://github.com/mitre/train-k8s-container/issues/1))
- Migrate to Train plugin v2 with multi-platform support and security improvements
- Fix platform detection using Detect + Context pattern
- **ci**: Add real STIG profile and same-pod container-to-container tests

### Documentation

- Add MITRE standards documentation and release workflow
- Update CHANGELOG.md with git-cliff format
- Rewrite CHANGELOG with accurate v2.0.0 content

### Fixed

- **ci**: Fix distroless test, Dockerfile, and shellcheck warnings
- **ci**: Fix kubectl cp glob pattern for same-pod test
- **ci**: Use pre-built cinc-scanner:local for same-pod testing
- Remove gemspec warnings for RubyGems publishing

### Miscellaneous Tasks

- Switch from InSpec to Cinc Auditor (license-free)
- Add git-cliff configuration for changelog generation
- Add git-cliff to release workflow for automated changelog
- Use official git-cliff-action for changelog generation
- Rename gem to train-k8s-container-mitre for RubyGems publishing

### Refactor

- DRY improvements, CI enhancements, and distroless support

### Testing

- **integration**: Update platform tests for Detect+Context pattern

## [1.3.1] - 2024-03-05

### Fixed

- Fix run command to be run with Bourne shell to execute commands

This is to make sure we are able to run all OS resource commands

Signed-off-by: Sathish Babu <sbabu@progress.com>

## [1.3.0] - 2024-01-31

### Testing

- Test file connections

Signed-off-by: Sathish Babu <sbabu@progress.com>

## [1.2.1] - 2024-01-18

## [1.2.0] - 2024-01-16

## [1.1.2] - 2024-01-16

### Fixed

- Fix connection spec

Signed-off-by: Sathish Babu <sbabu@progress.com>
- Fix specs to use mocks over real connections

Signed-off-by: Sathish Babu <sbabu@progress.com>

## [1.1.1] - 2024-01-15

### Fixed

- Fix typo with spec

Signed-off-by: Sathish Babu <sbabu@progress.com>

### Testing

- Test connection

Signed-off-by: Sathish Babu <sbabu@progress.com>

## [1.1.0] - 2024-01-11

### Testing

- Test kubectl exec client

Signed-off-by: Sathish Babu <sbabu@progress.com>
- Test connection and platform

Signed-off-by: Sathish Babu <sbabu@progress.com>

## [1.0.0] - 2024-01-11

## [0.0.7] - 2024-01-11

## [0.0.6] - 2024-01-09

## [0.0.5] - 2024-01-02

## [0.0.4] - 2023-11-20

## [0.0.3] - 2023-11-15

### DELETE

- Remove files not required for the library

### ENHANCE

- Minor improvement with gemspec and rakefile

### GEM

- Initialize repo with bundle gem train-k8s-container

### Miscellaneous Tasks

- Add doc dir with a sample readme

## [0.0.2] - 2023-11-15

### CONFIG

- Add basic expeditor config
- Add basic verify pipeline
- Add subscriptions to expeditor config
- Add basic coverage pipeline template
- Add configurations for sonarscanner in verify and update coverage pipeline

### DOC

- Add empty changelog required for expeditor

<!-- generated by git-cliff -->
