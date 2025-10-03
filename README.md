# LogStruct

Adds JSON structured logging to any Rails app. Simply add the gem to your Gemfile and add an initializer to configure it. By default, your Rails app prints JSON logs to STDOUT (or to the configured destination when `RAILS_LOG_TO_STDOUT` is set). They're easy to search and filter, you can turn them into metrics and alerts, and they're great for building dashboards in CloudWatch, Grafana, or Datadog.

We support all your other favorite gems too, like Sidekiq, Sentry, and Shrine. (And if not, please open a PR!)

## Features

- JSON logging enabled by default for server processes in production and test environments, and for CI test runs (automatically disabled for console, local tests, and other Rake tasks)
- ActionMailer integration for email delivery logging
- ActiveJob integration for job execution logging
- Sidekiq integration for background job logging
- Shrine integration for file upload logging
- Error handling and reporting
- Metadata collection for rich context
- Lograge integration for structured request logging
- Sensitive data scrubbing for strings (inspired by the Logstop gem)
- Host authorization logging for security violations
- Rack middleware for enhanced error logging
- ActionMailer delivery callbacks for Rails 7.0.x (backported from Rails 7.1)
- Type checking with Sorbet and RBS annotations

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'logstruct'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install logstruct
```

## Configuration and Initialization

LogStruct is designed to be highly opinionated and work out of the box with minimal configuration.

Please see the [documentation](https://logstruct.com/docs/configuration/) for configuration options.

### Important Notes on Integration

Once initialized (and enabled), the gem automatically includes its modules into the appropriate base classes:

- `ActiveSupport::TaggedLogging` is patched to support both Hashes and Strings (only when LogStruct is enabled)
- `ActionMailer::Base` includes error handling and event logging modules
- We configure `Lograge` for request logging
- A Rack middleware is inserted to catch and log errors, including security violations (IP spoofing, CSRF, blocked hosts, etc.)
- Structured logging is set up for ActiveJob, Sidekiq, Shrine, etc.
- Rails `config.filter_parameters` are merged into LogStruct's filters and then cleared (to avoid double filtering). Configure sensitive keys via `LogStruct.config.filters`.
- When `RAILS_LOG_TO_STDOUT` is set, we log to STDOUT only. Otherwise, we log to STDOUT by default without adding a file appender to avoid duplicate logs.

### Default behavior by process type

- **Server processes** (`rails server`): JSON logging is enabled by default in production and test environments
- **CI test runs** (`rails test` when `CI=true`): JSON logging is enabled by default to catch production bugs in your automated tests
- **Local test runs** (`rails test` locally): JSON logging is disabled by default, providing human-readable logs for debugging
- **Console** (`rails console`): JSON logging is disabled by default in all environments, providing human-readable logs instead
- **Other Rake tasks** (`rake db:migrate`, etc.): JSON logging is disabled by default in production, providing human-readable logs instead
- **Development environment**: Disabled by default for all process types. Enable explicitly via `LOGSTRUCT_ENABLED=true` or `LogStruct.configure { |c| c.enabled = true }`.

When enabled in development, LogStruct defaults to production‑style JSON output so you can preview exactly what will be shipped in prod. You can opt back into the colorful human formatter with:

```ruby
LogStruct.configure do |c|
  c.prefer_json_in_development = false
  c.enable_color_output = true
end
```

To force JSON logs in console, local test runs, or other Rake tasks (e.g., for debugging), set `LOGSTRUCT_ENABLED=true` in your environment.

## Documentation

Please see the [documentation](https://logstruct.com/docs) for more details. (All code examples are type-checked and tested, and it's harder to keep a README up to date.)

### Custom Typed Logs

In addition to the built‑in, strictly typed log structures (Request, Error, SQL, etc.), you can define your own app‑specific typed logs while still using the public `LogStruct.info/error/...` methods.

- Compose the public interfaces: include `LogStruct::Log::Interfaces::PublicCommonFields` and the helpers `SerializeCommonPublic` + `MergeAdditionalDataFields` in your `T::Struct`.
- Fix your `source` to a constant (e.g., return the string `"payments"`), and restrict `event` with a `T::Enum` (e.g., `processed|failed|refunded`).
- The `LogStruct.info` signature accepts either the internal `CommonFields` (for built‑ins) or your public custom type, so you keep type safety at the call site.

See the docs page for a complete example: [Sorbet Types → Custom Typed Logs](https://logstruct.com/docs/sorbet-types#custom-log-classes).

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
