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

## Release Process

Releases are automated using [release-please](https://github.com/googleapis/release-please) and managed by project maintainers.

### How It Works

1. **Commit with Conventional Commits**: Use prefixes like `feat:`, `fix:`, `docs:`, `chore:`
   - `feat:` triggers a minor version bump (e.g., 2.0.0 → 2.1.0)
   - `fix:` triggers a patch version bump (e.g., 2.0.0 → 2.0.1)
   - `feat!:` or `BREAKING CHANGE:` triggers a major version bump

2. **Release PR Created Automatically**: When commits are pushed to `main`, release-please creates/updates a Release PR that:
   - Bumps the version in `VERSION` file
   - Updates `CHANGELOG.md` with commit messages
   - Shows the proposed version change

3. **Merge to Release**: When maintainers merge the Release PR:
   - A git tag is created (e.g., `v2.1.0`)
   - GitHub Actions builds and publishes the gem to RubyGems.org
   - A GitHub Release is created with auto-generated notes

### Example Workflow

```bash
# Make changes with conventional commit messages
git commit -m "feat: add support for Windows containers"
git push origin main

# release-please automatically creates a PR like:
# "chore(main): release 2.1.0"

# After review, maintainer merges the PR
# → Tag v2.1.0 is created
# → Gem is published to RubyGems.org
```

### Manual Releases (Emergency Only)

For hotfixes that need immediate release without waiting for release-please:

```bash
# Update VERSION manually
echo "2.0.2" > VERSION

# Update CHANGELOG.md manually

# Commit, tag, and push
git add VERSION CHANGELOG.md
git commit -m "chore: release v2.0.2"
git tag v2.0.2
git push origin main --tags
```

**Note:** Manual releases should be rare. Prefer the automated release-please flow.

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
