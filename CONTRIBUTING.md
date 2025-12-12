# Contributing to train-k8s-container

Thank you for your interest in contributing to the train-k8s-container plugin! We welcome contributions from the community.

## Development Workflow

We use a standard GitFlow workflow:

### Quick Setup

```bash
# Fork and clone
git clone https://github.com/YOUR_USERNAME/train-k8s-container.git
cd train-k8s-container
bundle install

# Run tests
bundle exec rspec
```

### Step by Step

1. **Fork** the repository on GitHub
2. **Clone** your fork locally
3. **Create a feature branch** from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```
4. **Make your changes** with appropriate tests
5. **Run the test suite** to ensure everything passes:
   ```bash
   bundle install
   bundle exec rspec
   bundle exec rake style
   ```
6. **Commit your changes** with clear, descriptive messages
7. **Push** to your fork and **create a Pull Request**

## Code Requirements

All contributions must meet our quality standards before merging.

### Testing

- **All new functionality must include tests**
- **Tests must pass**: `bundle exec rspec`
- **Maintain or improve code coverage** (currently 95%+)

### Code Style

- **Follow existing Ruby style conventions**
- **Run linting**: `bundle exec rake style` or `bundle exec rubocop`
- **No RuboCop violations**

### Documentation

- **Update README.md** for user-facing changes
- **Add inline documentation** for new methods
- **Update DEVELOPMENT.md** for development workflow changes

## Types of Contributions

### Bug Reports

Help us fix problems by providing detailed bug reports.

**Requirements:**
- Use GitHub Issues with the "bug" label
- Include steps to reproduce
- Provide InSpec/Cinc and Ruby version information
- Include relevant log output with `-l debug`

### Feature Requests

We love new ideas! Please discuss before implementing.

**Process:**
- Open a GitHub Issue with the "enhancement" label
- Describe the use case and expected behavior
- Discuss implementation approach before coding

### Code Contributions

- Bug fixes
- New features
- Documentation improvements
- Test coverage improvements

## Development Setup

See [DEVELOPMENT.md](DEVELOPMENT.md) for detailed local development and testing instructions, including:

- Setting up a kind cluster for integration testing
- Running unit tests vs integration tests
- Testing with real Kubernetes pods
- Debugging tips

## Testing Guidelines

### Unit Tests

- Test all public methods
- Mock external dependencies (kubectl, kubernetes API)
- Fast execution (< 30 seconds total)

### Integration Tests

- Test real kubectl connectivity
- Use kind cluster for testing
- Document any manual testing requirements

### Running Tests

```bash
# Unit tests only (fast, no kubectl required)
bundle exec rspec spec/train-k8s-container

# Integration tests (requires kind cluster)
bundle exec rspec spec/integration

# All tests
bundle exec rspec

# With coverage report
bundle exec rspec
open coverage/index.html
```

## Pull Request Process

1. **Update Documentation**: Ensure README and relevant docs are updated
2. **Test Coverage**: Maintain or improve test coverage percentage
3. **Security Review**: Run `bundle audit` and check for vulnerabilities
4. **Code Review**: Address feedback from maintainers
5. **CI Passing**: All GitHub Actions checks must pass
6. **Merge**: Maintainers will merge approved PRs

## Versioning and Commit Messages

This project uses [Conventional Commits](https://www.conventionalcommits.org/) and [Semantic Versioning](https://semver.org/). Your commit message prefix determines how the version number changes.

**Official References:**
- [Conventional Commits Specification](https://www.conventionalcommits.org/en/v1.0.0/)
- [Angular Commit Message Guidelines](https://github.com/angular/angular/blob/main/CONTRIBUTING.md#-commit-message-format) (original source)
- [Semantic Versioning](https://semver.org/)

### Commit Prefix → Version Bump

| Commit Prefix | Version Change | When to Use |
|---------------|----------------|-------------|
| `feat:` | **Minor** (2.0.0 → 2.1.0) | New features, capabilities, or enhancements |
| `fix:` | **Patch** (2.0.0 → 2.0.1) | Bug fixes, corrections, error handling |
| `docs:` | **Patch** | Documentation changes only |
| `style:` | **Patch** | Code style, formatting (no logic change) |
| `refactor:` | **Patch** | Code restructuring (no behavior change) |
| `perf:` | **Patch** | Performance improvements |
| `test:` | **Patch** | Adding or updating tests |
| `chore:` | **Patch** | Maintenance, dependencies, tooling |
| `ci:` | **Patch** | CI/CD pipeline changes |
| `build:` | **Patch** | Build system changes |
| `revert:` | **Patch** | Reverting a previous commit |
| `feat!:` | **Major** (2.0.0 → 3.0.0) | Breaking changes (note the `!`) |
| `fix!:` | **Major** | Breaking bug fix |
| `BREAKING CHANGE:` | **Major** | In commit body, forces major bump |

### Type Descriptions

- **feat**: A new feature for the user (not a build script feature)
- **fix**: A bug fix for the user (not a build script fix)
- **docs**: Documentation only changes (README, CONTRIBUTING, inline docs)
- **style**: Changes that don't affect code meaning (whitespace, formatting, semicolons)
- **refactor**: Code change that neither fixes a bug nor adds a feature
- **perf**: Code change that improves performance
- **test**: Adding missing tests or correcting existing tests
- **chore**: Changes to build process, auxiliary tools, libraries
- **ci**: Changes to CI configuration files and scripts
- **build**: Changes that affect the build system or external dependencies
- **revert**: Reverts a previous commit (include reverted commit SHA in body)

### Examples

```bash
# Patch version bump (2.1.0 → 2.1.1)
git commit -m "fix: handle nil response in platform detection"
git commit -m "docs: update installation instructions"
git commit -m "chore: update rubocop dependency"
git commit -m "test: add integration tests for Alpine containers"

# Minor version bump (2.1.0 → 2.2.0)
git commit -m "feat: add support for Windows containers"
git commit -m "feat: add retry logic for transient kubectl failures"

# Major version bump (2.1.0 → 3.0.0)
git commit -m "feat!: change URI format to k8s://namespace/pod/container"
git commit -m "fix!: remove deprecated connection options"
```

### Commit Message Format

```
<type>(<optional scope>): <description>

[optional body]

[optional footer(s)]
```

**Examples:**
```bash
# Simple
git commit -m "fix: handle empty shell response"

# With scope
git commit -m "feat(platform): add FreeBSD detection"

# With body
git commit -m "feat: add Windows container support

This adds support for Windows containers running in Kubernetes.
Tested with Windows Server 2022 and Windows Server Core images."

# Breaking change with body
git commit -m "feat!: require Ruby 3.1+

BREAKING CHANGE: Ruby 2.7 and 3.0 are no longer supported.
This allows us to use pattern matching and other Ruby 3.1 features."
```

## Release Process

Releases are **fully automated** using [release-please](https://github.com/googleapis/release-please) with auto-merge enabled.

### How It Works

1. **Release PR Created Automatically**: When commits are pushed to `main`, release-please creates/updates a Release PR with auto-merge enabled that:
   - Bumps the version in `lib/train-k8s-container/version.rb`
   - Updates `CHANGELOG.md` with commit messages
   - Shows the proposed version change

2. **Auto-Merge When CI Passes**: The Release PR automatically merges once all CI checks pass:
   - Unit tests (Ruby 3.1, 3.2, 3.3)
   - Integration tests (Kubernetes 1.29, 1.30, 1.31)
   - Security audit
   - Branch protection enforces all checks must pass

3. **Automatic Publishing**: After merge, release-please creates a GitHub Release which triggers:
   - Gem build
   - Publish to RubyGems.org (via OIDC trusted publishing)
   - Gem artifact attached to GitHub Release

### Complete Automated Flow

```
Push commit → CI runs → Release PR created (auto-merge enabled)
                                    ↓
                            CI passes on PR
                                    ↓
                            PR auto-merges
                                    ↓
                        GitHub Release created
                                    ↓
                        Gem published to RubyGems
```

### Example

```bash
# Make changes with conventional commit messages
git commit -m "feat: add support for Windows containers"
git push origin main

# Everything else is automatic:
# 1. release-please creates PR: "chore(main): release 2.2.0"
# 2. CI runs on the PR
# 3. PR auto-merges when CI passes
# 4. Tag v2.2.0 is created
# 5. Gem is published to RubyGems.org
```

No manual intervention required for releases.

## Getting Help

- **Questions**: Open a GitHub Discussion or Issue
- **Real-time help**: Email [saf@mitre.org](mailto:saf@mitre.org)
- **Security issues**: Email [saf-security@mitre.org](mailto:saf-security@mitre.org)

## Community

- Follow our [Code of Conduct](CODE_OF_CONDUCT.md)
- Be respectful and collaborative
- Help others learn and contribute

## License

By contributing, you agree that your contributions will be licensed under the same Apache-2.0 license that covers the project.
