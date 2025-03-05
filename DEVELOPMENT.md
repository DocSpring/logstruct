# Development Guidelines

# Sorbet Usage

- `T::Sig` is not available globally, we must extend it whenever we need it (we're building a library, not an application.)
- We use `sorbet-runtime` for runtime type checking. This is a hard dependency for the gem.
- You do need to `extend T::Helpers` in modules if they use other Sorbet features (e.g `requires_ancestor`)
- Never use `LogStruct::` when you're inside the `module LogStruct` scope (same for nested modules/classes.)

# Core Dependencies

This gem requires Rails 7.0+ and will always have access to these core Rails modules:

- `::Rails`
- `::ActiveSupport`
- `::ActionDispatch`
- `::ActionController`

You do not need to check if these are defined with `defined?` - they are guaranteed to be available.

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
  - Rails modules: `::ActiveSupport`, `::ActionMailer`, `::ActiveJob`, `::ActionDispatch`, `::ActionController`, `::ActiveStorage`
  - Error reporting: `::Sentry`, `::Bugsnag`, `::Rollbar`, `::Honeybadger`
  - Background jobs: `::Sidekiq`
  - File uploads: `::Shrine`, `::CarrierWave`

### Available Modules

This gem doesn't work without Rails, so you can be sure that the core classes are always available. You don't need to check if these are defined:

- `::Rails`
- `::ActiveSupport`
- `::ActionDispatch`
- `::ActionController`

However, some apps might skip certain parts of Rails and only require what they need. You must check if these are defined:

- `defined?(::ActionMailer)`
- `defined?(::ActiveJob)`
- `defined?(::ActiveStorage)`

And you always need to check for any third-party gems that are not part of Rails:

- `defined?(::Sentry)`
- `defined?(::Shrine)`
- `defined?(::CarrierWave)`
- `defined?(::Sidekiq)`
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
- Regular tests: `bin/test`
- Rails integration tests: `bin/test_with_rails`
- You can specify Rails version for integration tests: `RAILS_VERSION=7.1.3 bin/test_with_rails`

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

#### Typing ActiveSupport::Concern included blocks

When using `ActiveSupport::Concern` with an `included` block, you need to use `T.bind` to inform Sorbet about the correct context:

```ruby
module MyModule
  extend ActiveSupport::Concern

  requires_ancestor { ParentClass }

  included do
    # Within the included block, self is the class including this module
    # Use T.bind to tell Sorbet what class methods are available
    T.bind(self, ParentClassCallbacks::ClassMethods)

    # Now Sorbet knows these callback methods exist
    before_action :some_method
    after_action :another_method
  end
end
```

This pattern is especially important for Rails concerns that set up callbacks, validations, or associations, since these are class methods defined in modules like `ActionController::Callbacks::ClassMethods`, `ActiveRecord::Validations::ClassMethods`, etc.

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

### Sorbet Best Practices

#### Block Context Typing

When working with blocks where methods are called on `self` that belong to a different class (like in configuration blocks), always use `T.bind`:

```ruby
# GOOD
SomeGem.configure do
  T.bind(self, SomeGem::Configuration)
  add_option "value"  # Now Sorbet knows this method exists
end

# BAD
SomeGem.configure do
  T.unsafe(self).add_option "value"  # NEVER do this!
end
```

#### Method Resolution

For methods that are defined in modules like `Kernel` but called without an explicit receiver:

```ruby
# GOOD
sig { params(blk: T.nilable(T.proc.params(arg0: String).void)).void }
def some_method(&blk)
  yield "value" if Kernel.block_given?
end

# BAD
def some_method(&blk)
  yield "value" if block_given?  # Sorbet doesn't know where this method comes from
end
```

#### Working with SimpleCov and Other DSLs

When using gems with DSLs like SimpleCov:

```ruby
# GOOD
SimpleCov.start do
  T.bind(self, SimpleCov::Configuration)
  add_filter "test/"
  enable_coverage :branch
end

# BAD
SimpleCov.start do
  T.unsafe(self).add_filter "test/"  # NEVER do this!
end
```

#### Handling External Libraries

1. **Always check the RBI files first**: Before resorting to `T.unsafe` or other workarounds, check the generated RBI files to understand the proper types.

2. **Use proper binding for DSLs**: Many Ruby libraries use DSLs where the context (`self`) inside a block is an instance of a specific class. Always use `T.bind(self, CorrectClass)` to inform Sorbet about this.

3. **Add missing type signatures**: If a gem lacks proper type definitions, contribute by adding them to your project's `sorbet/rbi/overrides/` directory.

#### Common Sorbet Patterns

1. **Binding `self` in class methods**:

   ```ruby
   class MyClass
     class << self
       extend T::Sig

       sig { params(value: String).void }
       def configure(value)
         yield(new(value))
       end
     end

     sig { params(config: T.untyped).void }
     def initialize(config)
       @config = config
     end
   end

   MyClass.configure("test") do |instance|
     T.bind(self, MyClass)
     # Now you can call MyClass instance methods
   end
   ```

2. **Typing procs and blocks**:

   ```ruby
   sig { params(blk: T.proc.params(arg0: String).returns(Integer)).returns(Integer) }
   def process_with_block(&blk)
     yield("test")
   end
   ```

3. **Using `T.cast` for narrowing types**:
   ```ruby
   sig { params(value: T.any(String, Symbol, Integer)).returns(String) }
   def normalize(value)
     case value
     when String
       T.cast(value, String)
     when Symbol
       T.cast(value, Symbol).to_s
     else
       T.cast(value, Integer).to_s
     end
   end
   ```

Remember: Taking shortcuts with Sorbet defeats the purpose of having static type checking. Always invest the time to properly type your code.

## Development Workflow

1. Fork the repository
2. Create a feature branch
3. Write tests for your changes
4. Implement your changes
5. Run tests to ensure they pass
6. Submit a pull request

## Releasing

1. Update the version number in `lib/log_struct/version.rb`
2. Update the `CHANGELOG.md` file
3. Create a git tag for the version
4. Push the tag to GitHub
5. Build and push the gem to RubyGems

```bash
# Update version in lib/log_struct/version.rb first!
bundle exec rake build
gem push pkg/logstruct-x.y.z.gem
```

## Documentation

- Keep the README up to date
- Document all public methods
- Use YARD documentation format

## Principles

### Exception Handling

#### Use StandardError, not Exception

In Ruby, `StandardError` is a subclass of `Exception`. We use the term "exception" generically in our code to refer to errors, but we specifically use the `StandardError` class (or its subclasses) in our method signatures and error handling code. We NEVER use the base `Exception` class because:

- `Exception` includes critical system errors like `NoMemoryError`, `SystemExit`, `SignalException`, etc. which should not be caught by normal application code.
- Catching `Exception` can interfere with Ruby's process management and signal handling.
- Rescuing `Exception` may prevent normal program termination or proper cleanup.

Always specify `StandardError` (or specific subclasses) in your method signatures and rescue blocks:

```ruby
# GOOD
sig { params(exception: StandardError, context: T::Hash[Symbol, T.untyped]).void }
def report_exception(exception, context = {})
  # ...
end

# BAD
sig { params(exception: Exception, context: T::Hash[Symbol, T.untyped]).void }
def report_exception(exception, context = {})
  # ...
end
```

### Error Handling: Fail Hard in Tests, Fail Soft in Production

We follow the principle of "fail hard in tests, fail soft in production":

- In local (test/dev) environments, we raise errors to catch issues early
- In production environments, we log or report errors but allow the application to continue running
- This applies to both our own errors and errors from dependencies (e.g. Sorbet type checking failures)

This principle is important for both testing our code and for users' applications:

- During development and testing, we want to catch type errors and other issues as early as possible
- In production, we don't want to crash users' applications due to errors in our code
