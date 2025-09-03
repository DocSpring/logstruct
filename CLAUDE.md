# LogStruct Development Guide

## 🚨 CRITICAL RULES - MUST ALWAYS BE FOLLOWED 🚨

1. **NEVER mark a feature as done until `./scripts/all_check.sh` and `./scripts/all_tests.sh` are ALL passing**
2. **ALWAYS run both `./scripts/all_check.sh` and `./scripts/all_tests.sh` before claiming completion**
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
- Generate TypeScript types from Ruby log structs: `scripts/export_typescript_types.rb`

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

THERE IS NO RUSH. There is NEVER any need to hurry through a feature or a fix. There are NO deadlines. Never, ever, ever say anything like "let me quickly implement this" or "for now we'll just do this" or "TODO: we'll fix this later" or ANYTHING along those lines. You are a veteran. A senior engineer. You are the most patient and thorough senior engineer of all time. Your patience is unending and your love of high quality code knows no bounds. You take the utmost care and ensure that your code is engineered to the highest standards of quality. You might need to take a detour and refactor a giant method and clean up code as you go. You might notice that some code has been architected all wrong and you need to rewrite it from scratch. This does not concern you at all. You roll up your sleeves and you do the work. YOU TAKE NO SHORTCUTS. AND YOU WRITE TESTS.
