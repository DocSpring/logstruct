# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **Breaking**: A Hash passed to the logger (e.g. `Rails.logger.info({evt: "signup", user_id: 1})`) is written with its keys at the top level of the line, instead of nested under `payload`. A Hash can set its own `src` and `evt`; `ts` and `lvl` are reserved and are reported as an error and dropped
- **Breaking**: `Log::Error`'s `error_class` is any `Exception` class, not only `StandardError` classes, since ActiveJob and GoodJob pass any `Exception` that a job lets through
- **Breaking**: LogStruct depends on `railties`, `actionpack`, `activesupport`, `globalid` and `lograge` instead of `rails`, so apps no longer install every Rails framework to use it (#9, thanks @langalex)
- **Rails**: Integrations are set up after `config/initializers` run, so `config.integrations.*` settings and filters added in `config/initializers/logstruct.rb` take effect. `enabled` and `enabled_environments` can be set in an initializer; `LOGSTRUCT_ENABLED` overrides both
- **Rails**: Because integrations are set up after the app's initializers, LogStruct's loggers and handlers replace ones an initializer set (for example a custom Sidekiq logger or lograge settings). Configure them through LogStruct instead
- **Sidekiq**: A failed job is logged once, as a structured warn line with its `jid`, class, queue and retry count, instead of Sidekiq's default handler's three lines with the job's arguments in a JSON string. ActiveJob jobs' failures are left to the ActiveJob integration
- **Puma**: Request errors Puma handles itself (its "Rack app (...)" lines) are structured error lines with the method and path, without the query string
- **Breaking**: Production (any environment outside `config.local_environments`) logs to STDOUT only. LogStruct added a `log/<env>.log` file appender, which nothing rotated, unless `RAILS_LOG_TO_STDOUT` was set, and it overrode `config.logger = STDOUT`. Development logs to STDOUT and its log file, test to its log file; with `RAILS_LOG_TO_STDOUT` set, only to STDOUT
- **Filtering**: Rails' `filter_parameters` are matched the way Rails matches them: a Symbol or String filters every key that contains it (`:secret` filters `clientSecret`), case-insensitively, and Regexps and blocks are applied as Rails applies them. Rails' partial matches don't filter LogStruct's own top-level fields (Rails' default `:_key` would filter GoodJob's `cron_key`); exact names in the list and LogStruct's own filters still do
- **Filtering**: Blocks in `filter_parameters` get copies of the key and value, so a block that changes its value in place doesn't change the app's data
- **ActiveJob**: For `ActionMailer::MailDeliveryJob` (every `deliver_later`) and its subclasses, job lines log only the mailer, the mail and the delivery method as `arguments`, not the mail's own arguments. Devise passes its confirmation, password reset and invitation tokens there as plain strings, which key-based filtering can't find, so apps using Devise with `deliver_later` logged live tokens. Other jobs' arguments are logged as before (when the job's `log_arguments` is on). With the ActiveJob integration off, Rails' own job logs still include them
- **Breaking**: Hashed values (email addresses, `filter_keys_with_hashes`) are an HMAC-SHA256 keyed with `hash_salt`, or by default with a key derived from the app's `secret_key_base`, and are 16 characters long. They were a SHA256 with a salt shared by every install, 12 characters long, which a list of candidate emails could reverse. Every hash value changes; set `hash_salt` to keep hashes the same across apps or after a `secret_key_base` change. Hashes are pseudonyms, not anonymous data
- **Breaking**: Sensitive keys are matched by their words, whatever their case or separators, so `apiKey`, `X-Api-Key`, `HTTP_AUTHORIZATION`, `Set-Cookie` and plurals like `passwords` are filtered by default, and so are `cookie`, `session`, `jwt`, `bearer`, `otp` and `passphrase`. `filter_keys` entries match by their words too. Whole words keep `author`, `keyboard` and `signature_field_id`
- **Breaking**: A filtered String is logged as `{_filtered: {_class: "String"}}`, without its length (`_bytes`)
- **Breaking**: `Log::Sidekiq` is now `Log::Sidekiq::Log`. Sidekiq's job error line (`Log::Sidekiq::Error`), Puma's request error line (`Log::Puma::Error`) and ActiveJob's error line (`Log::ActiveJob::Error`) have typed fields instead of `additional_data`, with a new `error_context` field for what Sidekiq or Puma was doing. Error lines have the request's `path`, `method`, `source_ip`, `user_agent` and `referer` as fields
- **Breaking**: `error_handling_modes.type_checking_errors` defaults to `ReportProduction`: Sorbet type errors in the app and its gems are raised in development and test, and logged and reported in production. They were only logged
- **Breaking**: ActiveStorage `url` lines don't have the `url` field: the signed URL (S3 signatures, Disk tokens) lets anyone read the file until it expires. `url` and `exist` lines are debug lines, as Rails logs them
- **Breaking**: Lines have size limits (`config.limits`): Hashes write their first 100 keys and a `_more_keys` count, backtrace-like Arrays (an error line's `backtrace` too) 20 lines, other Arrays 10 items, and strings are cut at 32 KB after they're scrubbed (a URL password the cut separates from its `@` is replaced too). Error lines' backtraces were cut to 5 lines
- **Breaking**: The IP spoofing check no longer runs on every request and answers 403. Rails raises `IpSpoofAttackError` only where `remote_ip` is read, and responds as it would without LogStruct; LogStruct logs the error there (and reports it, in the `security_errors` mode)
- **Errors**: A message logged with an exception (`logger.error("Import failed", e)`) is an error line with the message in `msg` and the exception's in the new `error_message` field
- **Errors**: A failure building an integration's own line (ActiveModelSerializers, Dotenv, Puma, Ahoy, host authorization, GoodJob) is a LogStruct error (`logstruct_errors`: logged in production, raised in development and test), not one of the app's (`standard_errors`, raised everywhere), so it can't fail a render, a request or the boot in production
- **Host authorization**: Blocked hosts get the app's own `response_app` if it set one (LogStruct's 403 page otherwise). LogStruct replaced it
- **Puma**: The TERM and INT traps log the shutdown and then run the handler they replaced (or the signal's default action). The Puma patches, the boot banner replacement and the Puma lifecycle lines are off when LogStruct is disabled
- **Ahoy**: The tracking wrapper passes Ahoy's arguments on as given, so Ahoy's default properties still apply
- **Breaking**: LogStruct needs Ruby 3.3 or newer, the oldest version its CI tests
- **Breaking**: Keys in `filter_keys_with_hashes` (default `email` and `email_address`) are filtered, with a `_hash` of the value so lines about the same address can be found. They were only hashed when another filter matched them too
- **Breaking**: An email address has one hash however it's capitalized, and addresses in any script (`müller@example.de`) are scrubbed
- **Breaking**: Every time in a struct line (`scheduled_at`, `started_at`, `finished_at`, ...) is written with milliseconds, like `ts`
- **Breaking**: Removed fields that were never written: ActiveJob's `retries` on enqueue lines, the blocked host line's `allowed_hosts` and `allow_ip_hosts`, Shrine's `metadata` and `location` on metadata lines and `exist` on exists lines (Shrine's events don't carry them), and ActiveStorage's `filename`, `mime_type`, `size` and `metadata` on upload and download lines (Rails' events have only the blob's key). ActiveStorage metadata lines have the `mime_type` instead of `metadata`
- **Breaking**: `Log::ActiveStorage::Stream` and the `stream` event are removed: Rails sends no `service_stream` event. Streaming downloads are `download` lines
- **Requests**: Request lines have the client's IP (`source_ip`) and the `host`, as Rails' own request line does. A `lograge_custom_options` that added them can drop them
- **Tags**: Tags are written: `logger.tagged("x")` and `config.log_tags` give a `tags` array, and named tags go in `ctx` (`request_id` is written as `req_id`)
- **ActionMailer**: Mailers keep their logger, so `logger.info` in a mailer is written. LogStruct detaches Rails' ActionMailer log subscriber instead, which wrote the text lines its own mail lines replace
- **ActionMailer**: The error line says "Email delivery failed" instead of "Email delivery error, will retry" (nothing retries a mail by default), and names the mail's recipients (scrubbed) when the error doesn't say which recipients failed
- **ActiveJob**: A job the backend couldn't enqueue (`ActiveJob::EnqueueError`, or another exception) writes an `error` line instead of an `enqueue` line, and a job a `before_enqueue` callback stopped writes no line. A job a `before_perform` callback stopped has no `finish` line
- **ActiveJob**: A finish line's `ts` is when the job finished, not when it started
- **CarrierWave**: An `upload` line is written when an uploader stores a new file, with its duration, and not when a record is saved with files that are already stored. Loading a stored file (`retrieve_from_store!`) logs nothing
- **Sidekiq**: Lines logged outside a job have no `ctx` (it was `{}`)
- **Logger settings**: `prefer_json_in_development`, `enable_color_output`, `color_map`, `filter_noisy_loggers` and `local_environments` set in `config/initializers` apply: LogStruct adds its appenders again after the initializers run. Appenders the app added to SemanticLogger there are kept
- **Development**: `color_map` changes only the colors it names; the others keep their defaults
- **Config**: `config.integrations.enable_semantic_logger` has no effect. LogStruct always writes through SemanticLogger; the setting is kept so existing configs load

### Added

- **ActiveJob**: `retry`, `retry_stopped` and `discard` lines, with the exception that `retry_on` or `discard_on` caught (and the wait before the retry). The exception was in no line. `perform_all_later` writes a line per job; with an adapter that reports only how many jobs it enqueued (Sidekiq's), a line per job when it enqueued them all, and one warn line with the counts when it didn't
- **ActiveStorage**: Deleting files by prefix (a blob's variants, when an image is purged) is a `delete` line with `prefix`. It raised a type error inside LogStruct, and wrote no line
- **CarrierWave**: `download` lines (a remote file fetched with `download!`) and `delete` lines (`remove!`)
- **Shrine**: Upload lines have the file's `mime_type` and `size`, and metadata lines how long extracting the metadata took. They leave out the file's original name, which can name a person
- **Security**: Blocked host lines have `blocked_hosts`, every host Rails blocked (the Host header, and X-Forwarded-Host)
- **Filtering**: `Bearer` tokens and `Basic` credentials in strings are scrubbed (`filters.authorization_credentials`, on by default)
- **Filtering**: The default sensitive key words include `passcode`, `apikey`, `social_security`, `credit_card` and `card_number`
- **Filtering**: US phone numbers are scrubbed in their other common formats (`(555) 123-4567`, `555.123.4567`, with or without `+1`). The opt-in scrubbers also match MAC addresses written with dashes (`filters.mac_addresses`) and IPv6 addresses (`filters.ip_addresses`)
- **ActionMailer**: Where LogStruct is off (development, consoles, Rake tasks, job runners it doesn't recognize), mailers still have `log_and_ignore_error`, `log_and_report_error` and `log_and_reraise_error`, which log a text line and report or raise. A `rescue_from` naming one of them raised `NameError` there
- **Docs**: Pages for each job, mail, SQL and security integration, every log field, when LogStruct runs, upgrading to 0.2.0 and troubleshooting
- **Error handling**: `LogStruct.handle_exception` takes `log:` (default `true`). Pass `log: false` when your own structured line already logged the error, so that it's only reported (or raised) according to the mode. If your tests stub `handle_exception` with a lambda, accept `log:` too
- **Sidekiq**: Every line logged during a Sidekiq job includes the job's `jid` and class in `ctx`. A Hash logged with its own `ctx` is merged with the job's
- **Filtering**: `FilterMatcher` takes `matches_logstruct_fields:` (default `true`), and `ParamFilters.should_filter_key?` takes `logstruct_field:` and `path:`, for matchers that shouldn't apply to LogStruct's own field names and for nested keys
- **Filtering**: Rails' dotted `filter_parameters` (`"card.number"`, `/\Acard\.number\z/`) match nested keys by their path, and three-argument filter blocks get the parameters around the key, as in Rails. New `filters.path_matchers` setting
- **Filtering**: Sensitive query params in URLs are filtered (`?token=`, `?apiKey=`, `user[password]=`, OAuth's `?code=`), checked like keys. New `filters.url_query_params` setting, on by default
- **Config**: `config.limits` (`max_hash_keys`, `max_array_items`, `max_backtrace_lines`, `max_string_bytes`)
- **Forking servers**: SemanticLogger's appenders are reopened in every forked process (a `Process._fork` hook), so Unicorn, Passenger and Pitchfork workers, Resque jobs and other forked children write their lines. It replaces the Puma cluster worker patch
- **Repository**: `SECURITY.md` (report vulnerabilities privately) and weekly Dependabot updates

### Removed

- **GoodJob**: `LogStruct::Integrations::GoodJob::LogSubscriber`, which listened for events GoodJob doesn't send (`enqueue`, `start`, `finish`, `error`, `schedule`), so it never logged anything. GoodJob's jobs are logged by the ActiveJob integration
- **GoodJob**: the `Log::GoodJob::Enqueue`, `Start`, `Finish` and `Schedule` log types, which only that subscriber built. The Terraform provider's catalog lists only `error` and `log` for GoodJob; ActiveJob's job lines have the same `src` and `evt` as the removed types
- **ActionMailer**: The mailer metadata that was meant to add the current tags and job ID to a mailer's lines. It asked for methods neither TaggedLogging nor ActiveJob has, so it never added anything
- **Rack**: `LogStruct::Integrations::Rack`, which nothing loaded and which required a file that doesn't exist

### Fixed

- **Lograge**: The Hash a `lograge_custom_options` proc returns is merged into the request line, as Lograge does
- **Errors**: An error the app didn't handle (Rails' 500 page, and errors Rails turns into a 404 or 422) is an error line with `src` `rails`, the error's class and message, the trace Rails logs, the request's path, method and IP, the response's `status`, and the error's cause (`cause_class`, `cause_message`), instead of Rails' block of text. It's written at `config.action_dispatch.debug_exception_log_level`, and `config.action_dispatch.log_rescued_responses = false` still leaves out the 404s and 422s. A CSRF or IP spoofing error has only its security line
- **Sorbet**: LogStruct installs Sorbet's four runtime error handlers once. It also installed one that the next replaced
- **Security**: LogStruct no longer empties Rails' `filter_parameters` or loads ActiveRecord and the other frameworks before the app's initializers run, so `filter_attributes` and Rails' own parameter filtering keep working (GHSA-cpp6-p4hf-383g)
- **Security**: Values nested deeper than the depth limit are summarized instead of logged raw, skipping filtering and scrubbing (#15)
- **Security**: Structs, `ActionController::Parameters` and other objects in a log line are filtered and scrubbed like Hashes, instead of being serialized unfiltered
- **Fix**: A value that refers back to itself (a Hash or Array containing its own parent) is logged once instead of being expanded up to the depth limit, which took seconds and produced very large lines
- **ActiveRecord**: Verbose query logs (the "↳ caller" lines) are turned off as intended. The integration set them on `ActiveRecord::Base`, which loaded it early and never matched, because the setting is on the `ActiveRecord` module
- **Sidekiq**: Lines logged during a Sidekiq job are written once instead of twice (#13)
- **Sidekiq**: The logger logs a copy of `Sidekiq::Context` instead of the live hash, which could mark successful jobs as failed (#14)
- **Logger settings**: `filter_noisy_loggers` leaves out ActionView's, routing errors' and schema migrations' lines. It kept only those lines and left out every other one
- **GoodJob**: The GoodJob integration now sets GoodJob's logger and logs GoodJob's thread errors. It referred to its own module instead of `::GoodJob`, so neither was set up before
- **GoodJob**: LogStruct turns itself on in GoodJob's executable (`good_job start`), like Puma and Sidekiq, and stops GoodJob adding a plain text STDOUT logger beside it, so GoodJob workers log JSON, each line once
- **GoodJob**: Thread errors are logged whenever the app sets its own handler (`config.good_job.on_thread_error`, which GoodJob applies after LogStruct's setup, or `GoodJob.on_thread_error =` at any time). LogStruct logs the error, then calls the app's handler, which keeps reporting it as before. This needs GoodJob 3.0 or later
- **GoodJob**: A failed job is logged once. GoodJob passes every unhandled job exception to `on_thread_error`, and the ActiveJob integration has already logged it with the job's ID and class, so the thread error line skips it. Exceptions that aren't `StandardError`s (GoodJob's `handled_exceptions` can let them through) are logged and passed on too; outside production they raised a `TypeError` and skipped the app's handler
- **GoodJob**: GoodJob's own lines during a job have the job's ID, class, queue, execution count, scheduled time and priority. The logger read them from a thread variable GoodJob never sets
- **GoodJob**: A thread error is logged once, as LogStruct's structured line. GoodJob's own log subscriber also wrote it as a plain text "GoodJob error: ..." line with the whole backtrace. GoodJob still logs the notifier's connection errors, which it passes to `on_thread_error` only once they repeat, without the backtrace. Loggers an app adds to `GoodJob::LogSubscriber.loggers` no longer get job errors; they're in `GoodJob.logger`'s structured line
- **GoodJob**: LogStruct's GoodJob logger logs LogStruct log entries and Hashes as they are. It only took strings, so the thread error handler's entry raised a `TypeError`
- **Output**: STDOUT is written without buffering. Without it, a process whose STDOUT is a pipe (a container) held its lines back until the buffer filled; GoodJob's executable sets `$stdout.sync` only for its own logger, which LogStruct turns off
- **Sidekiq**: Sidekiq's logger is replaced as soon as Rails' logger is, so lines Sidekiq logs while the app's initializers run (connecting to Redis, setting up a fetcher) are JSON too
- **Puma**: Removed a debug line (`[logstruct] puma lifecycle init`) that Puma servers wrote to STDERR at boot
- **ActionMailer**: `log_and_reraise_error`, `log_and_ignore_error` and `log_and_report_error` also work when `ActionMailer::MailDeliveryJob` passes an error to the mailer class. Every email that failed to send in a delivery job raised `NameError: undefined method 'log_and_reraise_error' for class` instead of the real error
- **ActionMailer**: The mailer logs a failed delivery once. It logged it twice, and a third time when the error reached the mailer class (in `Raise` mode, the default for standard errors, `handle_exception` raised before the error was marked as logged); in `Log` and `Report` modes `handle_exception` logged it again too. A delivery job also has the ActiveJob integration's job error line
- **ActionMailer**: In `Raise` mode, a `deliver_later` email whose mailer handles the error with `log_and_report_error` fails its job, as `deliver_now` raises. The job succeeded and the error was never reported
- **Shrine**: Shrine's own log subscriber no longer logs the events LogStruct logs
- **ActiveModelSerializers**: AMS's own text log subscriber is detached, so renders are logged once
- **ActiveJob**: Integer `provider_job_id` values (SolidQueue) are logged as strings instead of raising a TypeError (#7, thanks @justinko)
- **Security**: Strings and Hash keys are written as valid UTF-8. A byte like `\xFF` in a header (Puma passes headers as binary strings) stopped the whole line from being written as JSON and SemanticLogger dropped it, so anyone could hide their request line and the IP spoofing and CSRF lines. A line that still can't be written is replaced by one that says so
- **Security**: The Referer is logged without its query and fragment (request, blocked host, CSRF and IP spoofing lines, and the context sent to error reporters), which can carry password reset, confirmation and magic link tokens or OAuth codes
- **Security**: Error reporters (Sentry, Bugsnag, Rollbar, Honeybadger and custom handlers) get the context filtered and scrubbed like a log line
- **Security**: The request ID, program name and Sidekiq job context are filtered and scrubbed like the rest of the line. They were added after filtering, so an `X-Request-Id` header could carry a card number into the logs
- **Security**: With `sql_log_bind_params` on, bind values are filtered by their column names, like request params. Only values that looked like tokens were filtered, so a `password` bind was logged, and values were filtered for containing a word like `key`, `auth` or `password` (`monkey`, `Author`, "Forgot password"). Values shaped like tokens still are. Binary values are logged as their size
- **Security**: `Sidekiq.logger` passes Hashes on as structured data, so their keys are filtered. It turned them into Strings first, so `{password: "hunter2"}` was logged as it was
- **Security**: Card numbers of 13 to 19 digits are scrubbed (written together, in fours, or in American Express and Diners Club groups), and numbers that fail the Luhn check are left alone. URL passwords are scrubbed whole (`user:pass:word`, `redis://:pw@host`, lowercase `%3a`/`%40`). Hash keys that aren't plain identifiers (an email address as a key), a filtered Hash's `_keys`, Symbol values and GlobalIDs are scrubbed
- **Security**: The color formatter (development, opt-in) and loggers added with `broadcast_to` get scrubbed messages
- **Security**: Formatting is bounded (see `config.limits`): one huge value held up the thread that writes every line, and memory grew
- **CSRF**: CSRF lines are logged. They never appeared: the middleware sat outside ShowExceptions, which turns `InvalidAuthenticityToken` into a 422 first. LogStruct registers a DebugExceptions interceptor instead, and Rails responds as before
- **Errors**: `logger.error(exception)` writes an error line with the class, message and backtrace (it wrote an empty line), and the message logged beside a Hash (`logger.info("Saved", id: 1)`) is kept. The log methods take SemanticLogger's exception argument, which raised an `ArgumentError`
- **Errors**: An object whose `as_json` refers back to itself is summarized instead of raising `SystemStackError` from the formatter
- **Sidekiq**: An ActiveJob job's error is logged by the Sidekiq integration unless the ActiveJob integration logged it. An error raised before ActiveJob ran the job (a job class a deploy removed) was in no line
- **Puma**: Requiring LogStruct with `server` in `ARGV` and no Puma installed raised `LoadError`, so the app didn't boot
- **GoodJob**: The app's `on_thread_error` handler runs even if LogStruct's line fails
- **Ahoy**: Symbol event names and properties that aren't a Hash (they can come from the browser) are logged without raising; a String of properties raised a type error and failed the request in production
- **TypeScript**: The generated types give `error_class` as a string, not `any`
- **Gem**: The gem packages only files committed to git
- **Logging**: `rails server` in development printed every message twice: Rails' console logger wrote it as text beside LogStruct's line. `broadcast_to` ignores a logger that writes to STDOUT or STDERR when SemanticLogger already writes there
- **Logging**: Loggers added with `broadcast_to` got each `logger << "..."` line twice
- **Notifications**: `log.logstruct` subscribers get an entry after its line is written. A subscriber that raised stopped the line being written and raised from the app's log call; its error is handled like the app's other errors (`standard_errors`)
- **ActionMailer**: The entry a mailer's own `rescue_from` handler logs has level `error`, like its line. It said `info`, which `log.logstruct` subscribers saw
- **ActiveJob**: With the inline adapter, a failed `perform_later` writes one error line. The error that raised out of `perform_later` was logged again
- **Sorbet**: Type error lines and reports have a backtrace that starts at the call that failed. Method signature errors had none, and the others started inside sorbet-runtime
- **Filtering**: US phone numbers with a leading `1` (`1-555-123-4567`) are scrubbed whole, SSN-shaped parts of longer numbers (`123-45-6789-0`) are left alone, and an IPv6 address's zone (`fe80::1%en0`) is scrubbed with it

## [0.1.12] - 2026-01-30

### Added

- **Security**: Default regex filter matchers for sensitive keys (password, token, secret, auth, cred, api_key, etc.)
- **Security**: Job argument filtering for GoodJob/ActiveJob - respects `log_arguments?` class method
- **Security**: SQL bind parameter filtering now detects JWT tokens and Bearer tokens

### Fixed

- **Security**: Reserved keys (src, evt, lvl, ts) in `additional_data` are now protected from being overwritten
- **CI**: Fixed Ruby 4.0 bundler security error on GitHub Actions (world-writable gem directory)

## [0.1.11] - 2026-01-28

### Changed

- **Dev**: Added jscpd task/config and refactored repeated helpers in tests and codegen

### Fixed

- **Fix**: Restore request logs in Puma cluster mode by reopening SemanticLogger in forked workers
- **Fix**: Normalize ActiveJob and GoodJob timestamps to real wall clock time
- **Fix**: Tagged logging now emits `msg` instead of `message` for AMS-style logs

## [0.1.10] - 2026-01-23

### Added

- **Feature**: `request_id` now appears on all logs during a request, not just the request log

## [0.1.9] - 2026-01-23

### Changed

- **Fix**: ActiveJob integration handles Rails main event reporter subscribers
- **Fix**: Rack error handler avoids deprecated CSRF exception class on Rails main
- **CI**: Added Rails main daily integration run and updated Rails test matrix (7.1.6, 7.2.3, 8.0.4, 8.1.2)

## [0.1.8] - 2026-01-22

- **Fix**: Lograge custom options now appear in request logs
- **Fix**: Request logs include request metadata fields (request_id, source_ip, user_agent, referer, host, content_type, accept)
- **Docs**: Documented Lograge custom options and request metadata fields

## [0.1.7] - 2025-12-06

- **Fix**: Puma server detection now uses `$PROGRAM_NAME` instead of checking `defined?(::Puma::Server)` which was unreliable
- **Fix**: Test isolation for `server_mode` state in configuration tests
- **CI**: Updated to Ruby 3.4.7 and Rails 8.1.1

## [0.1.6] - 2025-11-30

- Rename `PROVIDER_PUSH_TOKEN` secret to `TF_PROVIDER_GITHUB_TOKEN`

## [0.1.5] - 2025-11-30

- **Fix**: Development logs no longer wrapped in `{message: "..."}` when LogStruct is disabled
  - The TaggedLogging formatter monkey patch now checks `LogStruct.enabled?` before modifying log messages
  - This preserves original Rails logging behavior in development mode

## [0.1.4] - 2025-10-13

- Improve rack spoof handling and split integration setup

## [0.1.3] - 2025-10-11

- **Fix**: Changed storage, queue name, and format fields from `String` to `Symbol` type to match Rails conventions
  - Affected log types: ActiveStorage, CarrierWave, Shrine (storage field), ActiveJob, GoodJob (queue_name field), Request (format field)
- JSON logging now enabled for all test runs (both local and CI) to ensure tests catch production bugs
  - Previously only enabled for CI test runs, now always enabled in test environment
  - This ensures local tests match CI behavior and catch serialization issues early
- Fixed host authorization app

## [0.1.2] - 2025-10-03

Better default policy for when JSON logs are enabled: machines get JSON, humans get readable logs.
Enable LogStruct for production servers and test runs (both local and CI) to ensure tests catch production bugs.
Keep dev-friendly logging on local machines or when running interactive commands on production servers.

## [0.1.1] - 2025-09-29

Added dotenv-rails integration. Many other fixes and improvements.

## [0.1.0] - 2025-09-07

Initial beta release.
