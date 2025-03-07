# LogStruct Development Guide

## Commands

### Core Commands

- Setup: `bin/setup`
- Run all checks: `bin/all` (runs typecheck, export, lint, test, etc.)
- Interactive console: `bin/console`

### Testing Commands

- Run all Ruby tests: `bin/test`
- Run single test file: `bin/test test/path_to_test.rb`
- Run test at specific line: `bin/test test/path_to_test.rb:LINE_NUMBER`
- Run test by name: `bin/test -n=test_method_name`
- Debug a specific test: Add `debugger` statements (developer only)
- Run Rails integration tests: `bin/test_with_rails`
- Run Next.js TypeScript tests: `cd site && npm test`

### Quality Commands

- Ruby typecheck: `bin/typecheck`
- Next.js typecheck: `cd site && npx tsc --noEmit`
- Lint Ruby: `bin/rubocop`
- Format Ruby: `bin/rubocop -A`
- Format JS/TS/JSON: `bin/prettier --write`
- Lint JS/TS/JSON: `bin/prettier --check`
- Spellcheck: `bin/spellcheck`

### Development Commands

- Generate Sorbet RBI files: `bin/tapioca`
- Generate spellcheck dictionary: `bin/generate_lockfile_words`
- Generate TypeScript types from Ruby log structs: `ruby scripts/export_typescript_types.rb`

# Core Dependencies

This gem requires Rails 7.0+ and will always have access to these core Rails modules:

- `::Rails`
- `::ActiveSupport`
- `::ActionDispatch`
- `::ActionController`

You do not need to check if these are defined with `defined?` - they are guaranteed to be available.

## Code Style

- Use strict Sorbet typing with `# typed: strict` annotations
- You can use `# typed: true` in tests, `T.let` can be annoying
- Method signatures must include proper return types
- Use `::` prefixes for external modules (Rails/third-party gems)
- Avoid `T.unsafe` - use proper typing or `T.let`/`T.cast` when necessary
- For modules included in other classes, use `requires_ancestor`
- Custom type overrides belong in `sorbet/rbi/overrides/`
- Follow standard Ruby naming conventions:
  - Classes: `CamelCase`
  - Methods/variables: `snake_case`
  - Boolean methods should end with `?`
- Handle errors explicitly via type-safe interfaces
- NEVER ignore warnings (especially deprecation warnings) - keep the logs clean
- When handling objects with as_json method in Rails apps, consider whether ActiveSupport's default implementation or a custom implementation is being used

## Code Comments

- Comments should explain why code exists, not what it does
- Do not reference previous versions/iterations in comments
- When receiving feedback, incorporate it into the code without mentioning the feedback
- Never use words like "proper" or "correctly" in comments as they imply previous code was improper
