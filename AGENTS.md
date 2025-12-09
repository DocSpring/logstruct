# LogStruct Development Guide

## 🚨 CRITICAL RULES - MUST ALWAYS BE FOLLOWED 🚨

1. **NEVER mark a feature as done until `task ci` is passing**
2. **ALWAYS run `task ci` before claiming completion**
3. **NO EXCEPTIONS to the above rules - features are NOT complete until all checks pass**
4. **This rule must ALWAYS be followed no matter what**
5. **`additional_data` is ONLY for unknown and dynamic fields that a user or integration might send. IF YOU KNOW THE NAME OF A FIELD, IT GOES IN THE SCHEMA. NEVER use `additional_data` for known fields.**
6. **NEVER run `git tag` without `-m` flag** - it opens an interactive editor and freezes. Always use: `git tag -a v0.1.7 -m "Release v0.1.7"`

## Commands

All commands use [Task](https://taskfile.dev) - run `task --list` to see all available tasks.

### Core Commands

- Setup: `scripts/setup.sh`
- Run full CI validation: `task ci` (typecheck, lint, spellcheck, tests, etc.)
- Auto-fix lint issues then run CI: `task fix`
- Interactive console: `scripts/console.rb`

### Testing Commands

- Run all tests (unit + Rails integration): `task test`
- Run Ruby unit tests only: `task ruby:test`
- Run Rails integration tests: `task rails:test`
- Run Rails tests for all supported versions: `task rails:test:matrix`
- Run frontend tests: `task docs:test`
- Run single test file: `bundle exec ruby scripts/test.rb test/path_to_test.rb`
- Run test at specific line: `bundle exec ruby scripts/test.rb test/path_to_test.rb:LINE_NUMBER`
- Run test by name: `bundle exec ruby scripts/test.rb -n=test_method_name`
- Debug a specific test: Add `debugger` statements (developer only)
- Merge coverage reports: `task ruby:coverage:merge`

**Rails Integration Tests**: Located in `rails_test_app/templates/test/integration/`. The script automatically copies template files to the test app when you run `scripts/rails_tests.sh`.

**FORCE_RECREATE**: Do NOT use `FORCE_RECREATE=true` unless absolutely necessary. It deletes the entire test app and recreates from scratch, which is slow. Only needed when:
- Gemfile changes require reinstalling gems
- Something is fundamentally broken with the cached app
- Rails version changes (but the script auto-detects this anyway)

For template file changes (tests, rake tasks, etc.), just run `scripts/rails_tests.sh` - it copies templates automatically.

### Quality Commands

- Run all typechecking: `task typecheck`
- Run all linting: `task lint`
- Auto-fix all lint issues: `task lint:fix`
- Spellcheck: `task spellcheck`

#### Ruby Commands

- Ruby typecheck: `task ruby:typecheck`
- Lint Ruby: `task ruby:lint`
- Format Ruby: `task ruby:lint:fix`

#### Frontend Commands

- Next.js typecheck: `task docs:typecheck`
- Lint frontend: `task docs:lint`
- Auto-fix frontend lint: `task docs:lint:fix`

#### Formatting Commands

- Format all files (JS/TS/JSON/YAML/MD): `task prettier:write`
- Check formatting: `task prettier:check`

### Development Commands

- Generate all (structs + catalog): `task generate`
- Generate Sorbet RBI files: `task ruby:tapioca`
- Generate spellcheck dictionary: `scripts/generate_lockfile_words.sh`
- Check generated files are up to date: `task ruby:check-generated`

### Documentation Commands

- Generate YARD docs: `task yard:generate`
- Clean YARD docs: `task yard:clean`
- Regenerate YARD docs: `task yard:regen`
- Open YARD docs in browser: `task yard:open`

## Documentation Site (docs/)

The `docs/` directory contains a Next.js documentation site.

### Structure

- `docs/app/` - Next.js App Router pages (TSX files)
- `docs/app/docs/` - Documentation pages (e.g., `getting-started/page.tsx`, `integrations/page.tsx`)
- `docs/components/` - React components
- `docs/lib/` - Utility functions and log generation code
- `docs/generated/` - Auto-generated files (do not edit manually)
- `docs/public/` - Static assets

### Commands

- Dev server: `cd docs && pnpm dev`
- Build: `cd docs && pnpm build`
- Typecheck: `task docs:typecheck`
- Lint: `task docs:lint`
- Fix lint: `task docs:lint:fix`
- Run tests: `task docs:test`

### Adding/Editing Documentation Pages

Pages are TSX files in `docs/app/docs/`. Each page exports a default React component. Example structure:

```
docs/app/docs/
├── getting-started/page.tsx
├── integrations/page.tsx
├── configuration/page.tsx
└── guides/
    └── postmark-error-handling/page.tsx
```

### Gem Commands

- Build gem: `task gem:build`
- Install gem locally: `task gem:install`
- Install gem without network: `task gem:install:local`
- Release gem to RubyGems: `task gem:release`

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
- `TF_PROVIDER_GITHUB_TOKEN`: PAT with write access to `DocSpring/terraform-provider-logstruct` for syncing/tagging.

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
