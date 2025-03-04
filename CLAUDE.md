# LogStruct Development Guide

## Commands

- Setup: `bin/setup`
- Run all tests: `bin/test`
- Run single test file: `bin/test test/path_to_test.rb`
- Run test at specific line: `bin/test test/path_to_test.rb:LINE_NUMBER`
- Run test by name: `bin/test -n=test_method_name`
- Debug a specific test: Add `debugger` statements (developer only)
- Typecheck: `bin/typecheck`
- Format code: `bin/format`
- Lint: `bin/rubocop`
- Spellcheck: `bin/spellcheck`

## Code Style

- Use strict Sorbet typing with `# typed: strict` annotations
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
