# LogStruct

JSON structured logging for Rails apps (Rails 7.1 or newer, Ruby 3.3 or newer). Add the gem, and in production your
app writes one JSON line per log entry to STDOUT: requests, jobs, mail, errors, security events and your own logs. The
lines are easy to search, and you can turn them into metrics, alerts and dashboards in CloudWatch, Grafana, Datadog or
any other log platform. Sensitive values are filtered and scrubbed before a line is written.

```json
{"src":"rails","evt":"request","lvl":"info","ts":"2026-10-17T03:09:30.839+00:00","path":"/orders","method":"GET","source_ip":"203.0.113.7","user_agent":"Mozilla/5.0","referer":"https://app.example.com/","format":"html","controller":"OrdersController","action":"index","status":200,"duration_ms":42.1,"view":30.2,"db":8.4,"params":{"page":"2"},"host":"app.example.com","accept":"text/html","prog":"Rails","req_id":"6f1c2b7e-0d4a-4c1e-9a55-3b8e2f7d9c10"}
```

## Features

- **On where it matters.** In production LogStruct switches on for the processes it recognizes: Puma, Unicorn,
  Thin, Falcon, `rails server`, a Sidekiq server and `good_job start`. In test it's on for every process except the
  console. It's off in development, in consoles and in production Rake tasks, unless you set `LOGSTRUCT_ENABLED=true`.
  See [When LogStruct runs](https://logstruct.com/docs/when-logstruct-runs).
- **Integrations** for Lograge (request lines), ActionMailer, ActiveJob, Sidekiq, GoodJob, Puma, ActiveStorage,
  Shrine, CarrierWave, Ahoy, ActiveModelSerializers, Dotenv, host authorization, CSRF and IP spoofing errors, and
  Sorbet's runtime type errors. SQL query logging is there too, off by default.
- **Filtering by key name.** Values under keys like `password`, `token`, `api_key`, `authorization` and `cookie` are
  replaced by a summary of the value, in request params, job arguments and anything else you log. Keys are matched by
  their words, so `apiKey`, `X-Api-Key` and `HTTP_AUTHORIZATION` are filtered too. The keys in Rails'
  `config.filter_parameters` are filtered the way Rails filters them.
- **Scrubbing inside strings** (inspired by [Logstop](https://github.com/ankane/logstop)): email addresses become a
  keyed hash (`[EMAIL:5f0c1e2a9b3d4e6f]`), so you can follow one person through your logs without logging the
  address. Card numbers that pass the Luhn check, US phone numbers, SSNs written as 123-45-6789, URL passwords,
  `Bearer` and `Basic` credentials and sensitive URL query params (`?token=`) are replaced too. IP and MAC address
  scrubbing are opt-in.
- **Limits.** Huge values are cut down (100 keys per Hash, 10 items per Array, 20 lines per backtrace, 32 KB per
  String by default), reducing log size and the work spent formatting large values.
- **Error handling.** A mode for each kind of error decides whether it's raised, logged or reported, and whether
  that differs between development and production. Reports go to Sentry, Bugsnag, Rollbar, Honeybadger or your own
  reporter.
- **Sorbet types.** Every built-in line is a typed struct, and you can define your own typed log lines.
- **STDOUT only in production**, with no log file to rotate or fill the disk.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "logstruct"
```

And then run:

```bash
bundle install
```

That's all you need: there's nothing to generate. To configure LogStruct, add an initializer
(`config/initializers/logstruct.rb`). The [configuration docs](https://logstruct.com/docs/configuration) list every
setting.

To see the JSON lines in development, start your server with `LOGSTRUCT_ENABLED=true rails server`.

## What LogStruct changes in your app

When LogStruct is on in a process:

- `Rails.logger` and the framework loggers (ActiveRecord, ActionController, ActionMailer, ActiveJob, ActionView,
  ActionCable) are replaced by LogStruct's SemanticLogger logger. A logger you set with `config.logger` only applies
  while LogStruct is off.
- Lograge is turned on and writes the request lines. Request lines include `req_id`, `source_ip`, `host`,
  `user_agent`, `referer` (without its query string), `content_type`, `accept` and the fields your
  `lograge_custom_options` proc adds.
- Every line logged during a request gets its `req_id`. Tags from `logger.tagged(...)` and `config.log_tags` are
  written in `tags`.
- Rails' own text lines for requests, mail and jobs are replaced by LogStruct's JSON lines. An error your app didn't
  handle is one error line with the request's fields and the response's status, instead of Rails' block of text.
- Mailers get a `rescue_from StandardError` that logs a failed delivery before re-raising it, and the
  `log_and_ignore_error`, `log_and_report_error` and `log_and_reraise_error` methods for your own `rescue_from`
  handlers (those methods exist where LogStruct is off too).
- CSRF and IP spoofing errors are logged as security lines and reported (`error_handling_modes.security_errors`), and
  Rails still responds to them as usual. Blocked hosts are logged too.
- Rails' `filter_parameters` list is left in place, so `request.filtered_parameters`,
  `ActiveRecord::Base.filter_attributes` and other Rails features keep filtering. Values Rails has already replaced
  are logged as `[FILTERED]`.
- Loggers you build yourself with `ActiveSupport::TaggedLogging.new(...)` write LogStruct's JSON lines too.
- In production LogStruct logs to STDOUT only. In development it logs to STDOUT and Rails' log file, and in test to
  the log file only. With `RAILS_LOG_TO_STDOUT` set, both log to STDOUT only.

## Documentation

The full documentation is at [logstruct.com/docs](https://logstruct.com/docs). Its Ruby examples are tested in this
repository's test suite.

- [Getting started](https://logstruct.com/docs/getting-started)
- [Configuration](https://logstruct.com/docs/configuration)
- [Filtering sensitive data](https://logstruct.com/docs/filtering-sensitive-data)
- [Log fields](https://logstruct.com/docs/log-fields)
- [Custom typed logs](https://logstruct.com/docs/sorbet-types#custom-log-classes)
- [Upgrading to 0.2.0](https://logstruct.com/docs/upgrading) (many breaking changes)
- [Troubleshooting](https://logstruct.com/docs/troubleshooting)
- [Changelog](CHANGELOG.md)

## Security

To report a vulnerability, see [SECURITY.md](SECURITY.md).

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
