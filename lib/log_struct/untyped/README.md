# Most Ruby developers don't use Sorbet.

The "untyped" version of our config class is the default way that users interact with LogStruct.
This untyped API is more recognizable for Ruby developers - it accepts symbols and hashes
instead of Sorbet `Enum` and `T::Struct`:

```ruby
LogStruct.configure do |config|
  config.enabled = true
  config.environments = [:production]

  config.error_handling_modes = {
    type_checking_errors: :log_production,
    logstruct_errors: :log_production,
    security_errors: :report,
    standard_errors: :raise
  }

  config.filters.filter_emails = false
  config.filters.filter_phones = false

  # Or:

  config.filters = {
    filter_emails: false,
    filter_phones: false,
  }
end
```

Behind the scenes, we use case statements to convert these symbols and hashes into the
typed configuration objects used internally, and raise ArgumentErrors for invalid values.

If you are already using Sorbet in your Rails apps, you can use the typed configuration API like this:

```ruby
module LogStruct
  self.configure_typed do |config|
    config.enabled = true
    config.environments = [:production]

    config.error_handling_modes = Configuration::ErrorHandlingModes.new(
      type_checking_errors: ErrorHandlingMode::LogProduction,
      logstruct_errors: ErrorHandlingMode::LogProduction,
      security_errors: ErrorHandlingMode::Report,
      standard_errors: ErrorHandlingMode::Raise
    )

    config.filters.filter_emails = false
    config.filters.filter_phones = false

    config.filters = Configuration::Filters.new(
      filter_emails: false,
      filter_phones: false,
    )
  end
end
```
