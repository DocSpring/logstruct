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
- etc.

### Type Safety

- Use Sorbet type annotations for all methods
- Ensure all files have the appropriate `# typed:` annotation
- **NEVER use `T.unsafe` calls**. Instead, properly type your code or use appropriate type assertions with `T.let` or `T.cast` when absolutely necessary.
- `T.untyped` is generally ok for Hash values when they come from unknown sources.
- When dealing with external libraries, create proper type signatures or use extension methods rather than resorting to `T.unsafe`.
- **NEVER use `class.name`** anywhere - this is a Sorbet quirk that hides the `name` method from all base classes. Prefer just using Classes themselves as the type. `"#{class}"` will automatically call `.to_s`. Similarly, `to_json` will automatically call `.to_s` - but you can call `.to_s` manually if you really need it.

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

- Keep all type definitions up to date by regularly running:
  ```bash
  bundle exec tapioca gems --all
  bundle exec tapioca annotations
  bundle exec tapioca dsl
  ```

### Custom Type Overrides

- Place all custom type overrides in `sorbet/rbi/overrides/` directory
- These overrides take precedence over auto-generated RBI files
- Use overrides to fix incorrect type signatures from gems or to add missing type information
- Never modify the auto-generated RBI files directly

### Typing Included Modules, Concerns, and Helpers

When typing modules that are included in other classes (like concerns, helpers, etc.), use the following approach:

1. Create an RBI file in `sorbet/rbi/overrides/` that mirrors the module's path
2. Use `requires_ancestor` to specify that a class includes a module
3. For class methods added via `extend`, declare them in a separate `ClassMethods` module

Example from `sorbet/rbi/overrides/log_struct/integrations/action_mailer/error_handling.rbi`:

```ruby
# typed: strict

# This tells Sorbet that any class including ErrorHandling will have these methods
module LogStruct::Integrations::ActionMailer::ErrorHandling
  requires_ancestor { ActionMailer::Base }

  # Instance methods available to including classes
  def log_and_ignore_exception; end
  def log_and_report_exception; end
  def log_and_reraise_exception; end

  # For class methods added via extend
  module ClassMethods
    def some_class_method; end
  end
end
```

This approach ensures proper type checking without using `T.unsafe`.

### Automatic RBI Generation for Specs

When working with RSpec and the `rspec-sorbet-types` gem, you need to run `tapioca dsl` after adding new `rsig` or test `describe` blocks. To automate this process, you can use the spec watcher script:

```bash
# Start the spec file watcher
bin/watch_specs
```

This script will:

- Monitor the `spec/` directory for any file changes
- Automatically run `bin/tapioca dsl` when changes are detected
- Display notifications about which files changed and when the tapioca process completes

This is particularly useful when working with `T.bind(self, T.class_of(...))` and `rsig` annotations in your specs, as it eliminates the need to manually run `tapioca dsl` after each change.

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
