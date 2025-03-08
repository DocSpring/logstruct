# LogStruct

Adds JSON structured logging to any Rails app. Simply add the gem to your Gemfile and add an initializer to configure it. Now your Rails app prints beautiful JSON logs to STDOUT. They're easy to search and filter, you can turn them into metrics and alerts, and they're great for building dashboards in CloudWatch, Grafana, or Datadog.

We support all your other favorite gems too, like Sidekiq, Sentry, and Shrine. (And if not, please open a PR!)

## Features

- JSON logging enabled by default in production and test environments
- ActionMailer integration for email delivery logging
- ActiveJob integration for job execution logging
- Sidekiq integration for background job logging
- Shrine integration for file upload logging
- Error handling and reporting
- Metadata collection for rich context
- Lograge integration for structured request logging
- Sensitive data scrubbing with Logstop (vendored fork)
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

### Important Note on Integration

Once initialized, the gem automatically includes its modules into the appropriate base classes:

- `ActiveSupport::TaggedLogging` is patched to support both Hashes and Strings
- `ActionMailer::Base` includes error handling and event logging modules
- We configure `Lograge` for request logging
- A Rack middleware is inserted to catch and log errors, including security violations (IP spoofing, CSRF, blocked hosts, etc.)
- Structured logging is set up for ActiveJob, Sidekiq, Shrine, etc.

## Documentation

Please see the [documentation](https://logstruct.com/docs) for more details. (All code examples are type-checked and tested, and it's harder to keep a README up to date.)

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
