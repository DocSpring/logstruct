# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.1] - 2025-03-04

### Added

- Pushed empty gem to RubyGems to secure the name

## [0.0.2-rc1] - 2025-09-05

### Added

- Unified GitHub Actions workflow to release RubyGem and sync/tag the Terraform provider; dry-run support for safe validation
- Provider catalog export script and automated provider CI (build/vet/test)
- Terraform docs page with quickstart, recipes, and provider README link
- API design doc (typed vs. untyped) planned; initial philosophy captured
- Coverage threshold gate (>= 80%) in CI; additional tests to lift coverage
- Release helper: scripts/create_release_tag.sh (creates annotated tag from version.rb)

### Changed

- ActionMailer callbacks patched for Rails 7.0; event logging + metadata collection tested
- Provider CloudWatch filter builder refactored for testability; key lookups aligned with exported catalog (event/source)

### Fixed

- Pre-commit hooks reporting; cspell dictionary updated; TypeScript import fixes in site
