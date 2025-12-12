# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0](https://github.com/mitre/train-k8s-container/compare/train-k8s-container-mitre-v2.0.1...train-k8s-container-mitre/v2.1.0) (2025-12-12)


### Features

* **ci:** Add real STIG profile and same-pod container-to-container tests ([4e246b3](https://github.com/mitre/train-k8s-container/commit/4e246b3fed6651a372403455218878859c6935cb))
* Fix platform detection using Detect + Context pattern ([2bf1b1e](https://github.com/mitre/train-k8s-container/commit/2bf1b1eb9d93ea1ecc082a330a7871380fa5e8ad))
* Migrate to Train plugin v2 with multi-platform support and security improvements ([d1bfb21](https://github.com/mitre/train-k8s-container/commit/d1bfb2181d7c10c6a35c8caad211a3357275fbca))
* Migrate to Train plugin v2 with multi-platform support and security improvements ([#1](https://github.com/mitre/train-k8s-container/issues/1)) ([798357f](https://github.com/mitre/train-k8s-container/commit/798357f9aad9212c4da21044e7c9a97b2afe97b6))


### Bug Fixes

* Add shim for train-k8s-container-mitre gem name ([677d0f2](https://github.com/mitre/train-k8s-container/commit/677d0f2453b9ca2a40b8cda6ef3294524f08cbd1))
* **ci:** Fix distroless test, Dockerfile, and shellcheck warnings ([8cdca08](https://github.com/mitre/train-k8s-container/commit/8cdca086a00b4d1d8f1f040a568d0b92fc83edbb))
* **ci:** Fix kubectl cp glob pattern for same-pod test ([3187bef](https://github.com/mitre/train-k8s-container/commit/3187bef38dc0dbf86f31b9c9923643dba2a53aa9))
* **ci:** Use pre-built cinc-scanner:local for same-pod testing ([0b98f74](https://github.com/mitre/train-k8s-container/commit/0b98f7401b387d97fb89d2e65993193ec76f172e))
* Remove gemspec warnings for RubyGems publishing ([e3093d5](https://github.com/mitre/train-k8s-container/commit/e3093d5bcf22d54cf42cf6a7e78119ee9fef7012))
* Reset version to 2.0.0 for correct release-please calculation ([0a4521b](https://github.com/mitre/train-k8s-container/commit/0a4521b53ead2ef5f3b1909a60f69e538dc035ef))


### Documentation

* Add MITRE standards documentation and release workflow ([bd22131](https://github.com/mitre/train-k8s-container/commit/bd22131fc06517827fb4513ebd7892137737bde7))
* Rewrite CHANGELOG with accurate v2.0.0 content ([2786478](https://github.com/mitre/train-k8s-container/commit/278647802b25fa6a24dbf35dc6bbbc0935e700e3))
* Update CHANGELOG for v2.0.1 release ([2237873](https://github.com/mitre/train-k8s-container/commit/2237873cc5142f48ca416242f985be0f41550e4d))
* Update CHANGELOG.md with git-cliff format ([c702246](https://github.com/mitre/train-k8s-container/commit/c70224671709904f79b2e220c2d9c8e2ca7883f2))
* Update installation instructions and add post-install warning ([8649575](https://github.com/mitre/train-k8s-container/commit/86495758a6794ae00505e50391f109442487d72a))
* Update release process documentation for release-please ([a9f4fd3](https://github.com/mitre/train-k8s-container/commit/a9f4fd3ce1da48557aa3442d62ca97ab983b3d21))


### Miscellaneous Chores

* add doc dir with a sample readme ([eb9e803](https://github.com/mitre/train-k8s-container/commit/eb9e803f76b191e04d947cd4df49f29f615b88df))
* Add git-cliff configuration for changelog generation ([66846e7](https://github.com/mitre/train-k8s-container/commit/66846e775d05175a6dd9ab6f1bcb298a22b38daa))
* Bump version to 2.0.1 for release ([071c963](https://github.com/mitre/train-k8s-container/commit/071c9631ef7b57fe0a4ed36708a977a7c0bade74))
* **release:** update CHANGELOG for v2.0.0 ([81e0bf2](https://github.com/mitre/train-k8s-container/commit/81e0bf22dfbe64d91da0d340daf29b80ca1fbb5f))
* Rename gem to train-k8s-container-mitre for RubyGems publishing ([7e5d2f0](https://github.com/mitre/train-k8s-container/commit/7e5d2f0557cd4711b91e039975ea3981e0eb7e2c))


### Code Refactoring

* DRY improvements, CI enhancements, and distroless support ([28ed34b](https://github.com/mitre/train-k8s-container/commit/28ed34b7bee21c1fa40b898a0f204158e45aaccc))


### Tests

* **integration:** Update platform tests for Detect+Context pattern ([c0c3199](https://github.com/mitre/train-k8s-container/commit/c0c31994f290bd0593f2b8f489b2adf5ab392b97))


### Continuous Integration

* Add git-cliff to release workflow for automated changelog ([e460fef](https://github.com/mitre/train-k8s-container/commit/e460feffc88c978aa079814b156b29b62580769f))
* Add release-please for automated versioning and changelog ([e5648c4](https://github.com/mitre/train-k8s-container/commit/e5648c436a8ba200196a5a0c4c49e280ac32b691))
* Switch from InSpec to Cinc Auditor (license-free) ([f98e562](https://github.com/mitre/train-k8s-container/commit/f98e5624d3da7ed9d5bc41b8f80e7354037101df))
* Use official git-cliff-action for changelog generation ([daf61a6](https://github.com/mitre/train-k8s-container/commit/daf61a6b9174036cb5a54c0d16c5f0643e9ceda1))

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
