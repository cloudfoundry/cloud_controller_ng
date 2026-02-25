# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Updated Ruby version requirement to 3.0+ (dropped Ruby 2.7 support)
- Updated development dependencies to latest versions
- Added GitHub Actions for CI/CD
- CI now tests all Ruby versions independently (fail-fast: false)
- Refactored syslog sink to use syslog gem directly instead of unmaintained syslog-logger

### Added
- Automated testing on multiple Ruby versions (3.0, 3.1, 3.2, 3.3, 3.4)
- Ruby 3.4 compatibility: added syslog gem dependency for non-Windows platforms
- Dependabot configuration for automated dependency updates
- GitHub Actions release workflow for automatic gem publishing
- Release documentation (RELEASING.md)

### Fixed
- Multiple RuboCop violations
- Code quality improvements (frozen constants, removed redundant requires)

## [Previous versions history would go here]

When you release a version, move the "Unreleased" section below to the appropriate version header.

Example format for completed releases:

```markdown
## [1.2.3] - 2024-02-17

### Added
- New feature description

### Changed
- Breaking change description

### Fixed
- Bug fix description

### Deprecated
- Deprecation notice

### Removed
- Removed feature

### Security
- Security fix description
```