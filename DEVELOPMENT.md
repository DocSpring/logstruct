# Development Guidelines

# Setup

Install Watchman (used by Sorbet):

```bash
brew install watchman
```

For other platforms: https://facebook.github.io/watchman/docs/install.html

## Code Style and Conventions

### Module References

- **Always use `::` prefixes for external modules**: All references to Rails modules and third-party gems (`ActiveSupport`, `ActionMailer`, `ActiveJob`, `Sidekiq`, `Bugsnag`, etc.) MUST use the `::` prefix, even at the top-level. This is because we define our own nested modules with similar names, so we must follow this convention for clarity, maintainability, and to avoid conflicts.

  ```ruby
  # GOOD
  if defined?(::Sidekiq)
    # ...
  end

  # BAD
  if defined?(Sidekiq)
    # ...
  end
  ```

- This applies to all external modules including but not limited to:
  - Rails modules: `::ActiveSupport`, `::ActionMailer`, `::ActiveJob`, `::ActionDispatch`, `::ActionController`
  - Error reporting: `::Sentry`, `::Bugsnag`, `::Rollbar`, `::Honeybadger`
  - Background jobs: `::Sidekiq`
  - File uploads: `::Shrine`

### Available Modules

This gem doesn't work without Rails, so you can be sure that the core classes are always available. You don't need to check if these are defined:

- `::Rails`
- `::ActiveSupport`
- `::ActionDispatch`
- `::ActionController`

However, some apps might skip certain parts of Rails and only require what they need. You must check if these are defined:

- `defined?(::ActionMailer)`
- `defined?(::ActiveJob)`

And you always need to check for any third-party gems that are not part of Rails:

- `defined?(::Sentry)`
- `defined?(::Shrine)`
- `defined?(::Postmark)`
- etc.

### Type Safety

- Use Sorbet type annotations for all methods
- Ensure all files have the appropriate `# typed:` annotation
- Use `T.unsafe` when necessary, but try to minimize its usage

### Testing

- Follow test-driven development principles
- Write tests for all new features
- Ensure all tests pass before submitting a pull request

## Working with Sorbet and Tapioca

### Managing RBI Files

- Generate RBI files for gems:

  ```bash
  bundle exec tapioca gems
  ```

- Generate RBI files for your application code:

  ```bash
  bundle exec tapioca dsl
  ```

- Regenerate the todo.rbi file:
  ```bash
  bundle exec tapioca todo
  ```

### Common Type Annotations

```ruby
# Method with typed parameters and return value
sig { params(name: String, count: Integer).returns(T::Array[String]) }
def process_items(name, count)
  # ...
end

# Method with nilable parameters
sig { params(user_id: T.nilable(Integer)).void }
def log_user_activity(user_id)
  # ...
end

# Method with union types
sig { params(value: T.any(String, Symbol)).void }
def process_value(value)
  # ...
end

# Method with generic types
sig { params(items: T::Array[T.untyped]).returns(T::Hash[String, Integer]) }
def count_items(items)
  # ...
end
```

### Handling External Code

When working with external libraries that don't have type definitions:

1. Create custom RBI files in `sorbet/rbi/custom/`
2. Use `T.unsafe` when necessary, but document why it's needed
3. Consider contributing type definitions back to the original projects

## Development Workflow

1. Fork the repository
2. Create a feature branch
3. Write tests for your changes
4. Implement your changes
5. Run tests to ensure they pass
6. Submit a pull request

## Releasing

1. Update the version number in `version.rb`
2. Update the `CHANGELOG.md` file
3. Create a git tag for the version
4. Push the tag to GitHub
5. Build and push the gem to RubyGems

## Documentation

- Keep the README up to date
- Document all public methods
- Use YARD documentation format
