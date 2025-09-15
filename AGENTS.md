# LogStruct Development Guide

## 🚨 CRITICAL RULES - MUST ALWAYS BE FOLLOWED 🚨

1. **NEVER mark a feature as done until `./scripts/all_check.sh` is passing**
2. **ALWAYS run `./scripts/all_check.sh` before claiming completion**
3. **NO EXCEPTIONS to the above rules - features are NOT complete until all checks pass**
4. **This rule must ALWAYS be followed no matter what**

## Commands

### Core Commands

- Setup: `scripts/setup.sh`
- Run all checks: `scripts/all_check.sh` (runs typecheck, export, lint, test, etc.)
- Run all checks with auto-fix: `scripts/all_write.sh`
- Interactive console: `scripts/console.rb`

### Testing Commands

- Run all tests (unit + Rails integration): `scripts/all_tests.sh`
- Run all Ruby unit tests: `scripts/test.rb`
- Run single test file: `scripts/test.rb test/path_to_test.rb`
- Run test at specific line: `scripts/test.rb test/path_to_test.rb:LINE_NUMBER`
- Run test by name: `scripts/test.rb -n=test_method_name`
- Debug a specific test: Add `debugger` statements (developer only)
- Run Rails integration tests: `scripts/rails_tests.sh`
- Merge coverage reports: `scripts/merge_coverage.sh`
- Run Next.js TypeScript tests: `cd site && npm test`

### Quality Commands

- Ruby typecheck: `scripts/typecheck.sh`
- Next.js typecheck: `cd site && pnpm exec tsc --noEmit`
- Lint Ruby: `scripts/rubocop.rb`
- Format Ruby: `scripts/rubocop.rb -A`
- Format JS/TS/JSON: `scripts/prettier.sh --write`
- Lint JS/TS/JSON: `scripts/prettier.sh --check`
- Spellcheck: `scripts/spellcheck.sh`

### Development Commands

- Generate Sorbet RBI files: `scripts/tapioca.rb`
- Generate spellcheck dictionary: `scripts/generate_lockfile_words.sh`
- Generate TypeScript + Ruby structs from YAML schemas: `scripts/generate_structs.rb`

## Terraform Provider repo in this workspace

- The Terraform provider lives in a separate GitHub repo: `DocSpring/terraform-provider-logstruct`.
- For convenience, the provider repo is checked out as a plain directory at `./terraform-provider-logstruct/` in this repo. It is NOT a Git submodule and is ignored by this repo’s `.gitignore`.
- You can inspect/build it locally:
  - `cd terraform-provider-logstruct`
  - `go build ./...`
  - Changes you make here are not committed by this repo. To contribute to the provider, commit from inside its directory and push to its own remote.

## Automated releases (gem + provider)

- Workflow: `.github/workflows/release.yml` ("Release Gem + Sync Terraform Provider").
- Triggers:
  - Push tag matching `v*` (e.g., `v0.0.1-rc1`, `v0.2.0`).
  - GitHub Release published.
  - Manual run (workflow_dispatch) with `dry_run` input.
- Behavior:
  - Builds and publishes the Ruby gem to RubyGems (requires `RUBYGEMS_API_KEY`).
  - Regenerates the provider’s embedded catalog (`scripts/export_provider_catalog.rb`), builds the provider, commits catalog changes, and tags the provider repo with the same version.
  - Enforces version alignment: the tag `vX.Y.Z` (or RC) must match `lib/log_struct/version.rb` unless run in dry-run.

## Dry-run mode

- CI dry-run lets you smoke-test the workflow without publishing anything:
  - Actions → "Release Gem + Sync Terraform Provider" → Run workflow → `dry_run=true`.
  - The workflow builds the gem and provider, shows diffs, and skips pushes/tags/uploads.
- Local dry-run for the GitHub Actions workflow isn’t practical without a runner like `act`. You can still sanity-check pieces locally:
  - `gem build logstruct.gemspec`
  - `ruby scripts/generate_structs.rb`
  - `ruby scripts/export_provider_catalog.rb`
  - `cd terraform-provider-logstruct && go build ./...`

## Required secrets

- `RUBYGEMS_API_KEY`: API key with permission to publish `logstruct`.
- `PROVIDER_PUSH_TOKEN`: PAT with write access to `DocSpring/terraform-provider-logstruct` for syncing/tagging.

# Core Dependencies

This gem requires Rails 7.0+ and will always have access to these core Rails modules:

- `::Rails`
- `::ActiveSupport`
- `::ActionDispatch`
- `::ActionController`

You do not need to check if these are defined with `defined?` - they are guaranteed to be available.

## Code Style

- NEVER add comments about what you changed (e.g. "this was moved", or "more performant".)
- NEVER worry about backwards compatibility. This is all brand new code, you must delete old methods and files after refactoring, don't keep them for compatibility.
- Use strict Sorbet typing with `# typed: strict` annotations
- You can use `# typed: true` in tests
- Method signatures must include proper return types
- Use `::` prefixes for external modules (Rails/third-party gems)
- `T.must` may be used very sparingly but only in tests - e.g. `T.must(log_file.path)`
- `T.unsafe` must NEVER be used. Use proper typing or `T.let`/`T.cast` when necessary
- Don't call `def` inside a method definition in tests (or anywhere). Use mocks or stubs.
- For modules included in other classes, use `requires_ancestor`
- Custom type overrides belong in `sorbet/rbi/overrides/`
- Follow standard Ruby naming conventions:
  - Classes: `CamelCase`
  - Methods/variables: `snake_case`
  - Boolean methods should end with `?`
- Handle errors explicitly via type-safe interfaces
- NEVER ignore warnings (especially deprecation warnings) - keep the logs clean
- When handling objects with as_json method in Rails apps, consider whether ActiveSupport's default implementation or a custom implementation is being used
- Use minitest mocks and stubs, not `def`, `Object`, etc.

## Code Comments

- Comments should explain why code exists, not what it does
- Do not reference previous versions/iterations in comments
- When receiving feedback, incorporate it into the code without mentioning the feedback
- Never use words like "proper" or "correctly" in comments as they imply previous code was improper

## Development Standards

THERE IS NO RUSH. There is NEVER any need to hurry through a feature or a fix. There are NO deadlines. Never, ever, ever say anything like "let me quickly implement this" or "for now we'll just do this" or "TODO: we'll fix this later" or ANYTHING along those lines. You are a veteran. A senior engineer. You are the most patient and thorough senior engineer of all time. Your patience is unending and your love of high quality code knows no bounds. You take the utmost care and ensure that your code is engineered to the highest standards of quality. You might need to take a detour and refactor a giant method and clean up code as you go. You might notice that some code has been architected all wrong and you need to rewrite it from scratch. This does not concern you at all. You roll up your sleeves and you do the work. YOU TAKE NO SHORTCUTS. AND YOU ALWAYS WRITE TESTS.
