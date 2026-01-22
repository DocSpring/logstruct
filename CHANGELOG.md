# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

## [0.1.9] - 2026-01-23

### Changed

- **Fix**: ActiveJob integration handles Rails main event reporter subscribers
- **Fix**: Rack error handler avoids deprecated CSRF exception class on Rails main
- **CI**: Added Rails main daily integration run and updated Rails test matrix (7.1.6, 7.2.3, 8.0.4, 8.1.2)

## [0.1.8] - 2026-01-22

- **Fix**: Lograge custom options now appear in request logs
- **Fix**: Request logs include request metadata fields (request_id, source_ip, user_agent, referer, host, content_type, accept)
- **Docs**: Documented Lograge custom options and request metadata fields

## [0.1.7] - 2025-12-06

- **Fix**: Puma server detection now uses `$PROGRAM_NAME` instead of checking `defined?(::Puma::Server)` which was unreliable
- **Fix**: Test isolation for `server_mode` state in configuration tests
- **CI**: Updated to Ruby 3.4.7 and Rails 8.1.1

## [0.1.6] - 2025-11-30

- Rename `PROVIDER_PUSH_TOKEN` secret to `TF_PROVIDER_GITHUB_TOKEN`

## [0.1.5] - 2025-11-30

- **Fix**: Development logs no longer wrapped in `{message: "..."}` when LogStruct is disabled
  - The TaggedLogging formatter monkey patch now checks `LogStruct.enabled?` before modifying log messages
  - This preserves original Rails logging behavior in development mode

## [0.1.4] - 2025-10-13

- Improve rack spoof handling and split integration setup

## [0.1.3] - 2025-10-11

- **Fix**: Changed storage, queue name, and format fields from `String` to `Symbol` type to match Rails conventions
  - Affected log types: ActiveStorage, CarrierWave, Shrine (storage field), ActiveJob, GoodJob (queue_name field), Request (format field)
- JSON logging now enabled for all test runs (both local and CI) to ensure tests catch production bugs
  - Previously only enabled for CI test runs, now always enabled in test environment
  - This ensures local tests match CI behavior and catch serialization issues early
- Fixed host authorization app

## [0.1.2] - 2025-10-03

Better default policy for when JSON logs are enabled: machines get JSON, humans get readable logs.
Enable LogStruct for production servers and test runs (both local and CI) to ensure tests catch production bugs.
Keep dev-friendly logging on local machines or when running interactive commands on production servers.

## [0.1.1] - 2025-09-29

Added dotenv-rails integration. Many other fixes and improvements.

## [0.1.0] - 2025-09-07

Initial beta release.
