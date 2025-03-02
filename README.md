# LogStruct

Adds JSON structured logging to any Rails app. Simply add the gem to your Gemfile and add an initializer to configure it. Now your Rails app prints beautiful JSON logs to STDOUT. They're easy to search and filter, you can turn them into metrics and alerts, and they're great for building dashboards in CloudWatch, Grafana, or Datadog.

We support all your other gems too, like Sidekiq, Sentry, Shrine, Postmark, and more. (And if not, please open a PR!)

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

## Supported Gems and Versions

The following table lists the gems that LogStruct integrates with and their supported versions:

| Gem          | Supported Versions | Notes                          |
| ------------ | ------------------ | ------------------------------ |
| Rails        | >= 6.0             | Core dependency                |
| ActionMailer | >= 6.0             | Part of Rails                  |
| ActiveJob    | >= 6.0             | Part of Rails                  |
| Sidekiq      | >= 6.0             | For background job logging     |
| Shrine       | >= 3.0             | For file upload logging        |
| Lograge      | >= 0.11            | For structured request logging |
| Sorbet       | >= 0.5             | For type checking              |

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

LogStruct is designed to be highly opinionated and work out of the box with minimal configuration. However, you first need to initialize it in your application and set up some basic configuration.

### In a Rails Application

Add the following to your `config/initializers/logstruct.rb`:

```ruby
# Configure the gem
LogStruct.configure do |config|
  # Enable or disable specific integrations
  config.lograge_enabled = true
  config.actionmailer_integration_enabled = true
  config.activejob_integration_enabled = true
  config.sidekiq_integration_enabled = true
  config.shrine_integration_enabled = true
  config.rack_middleware_enabled = true
  config.host_authorization_enabled = true

  # Salt for SHA256 hashes in filtered email addresses
  config.email_hashing_salt = ENV['email_hashing_salt']

  # Other configuration options...
end

# Set up all integrations
LogStruct.initialize
```

### Important Note on Integration

Once initialized, the gem automatically includes its modules into the appropriate base classes:

- `ActionMailer::Base` automatically includes error handling and event logging modules
- `ActiveJob::Base` automatically includes job logging modules
- No manual inclusion of modules is required in your application code

This opinionated approach ensures consistent logging across your entire application with minimal setup.

## Usage

### Basic Logging

Once configured, you can use the standard Rails logger with enhanced structured logging capabilities:

```ruby
# Log a simple message
Rails.logger.info "User signed in"

# Log structured data
Rails.logger.info({
  event: "user_login",
  user_id: user.id,
  ip_address: request.remote_ip
})

# Log with tags
Rails.logger.tagged("Authentication") do
  Rails.logger.info "User signed in"
  Rails.logger.info({ user_id: user.id, ip_address: request.remote_ip })
end

# Log exceptions
begin
  # some code that might raise an exception
rescue => e
  Rails.logger.error "Error during user login: #{e.message}"
  Rails.logger.error({
    error: e.class.to_s,
    message: e.message,
    backtrace: e.backtrace.first(5),
    user_id: user&.id
  })
end
```

### Logging Approaches

LogStruct provides multiple ways to log data, accommodating both dynamic Ruby-style logging and strictly typed approaches:

#### The Ruby Way (Dynamic)

You can use the standard Ruby approach to logging, which is flexible and requires minimal setup:

```ruby
# Log a simple string
Rails.logger.info "User signed in"

# Log a number
Rails.logger.info 42

# Log a boolean
Rails.logger.info true

# Log a hash with custom fields
Rails.logger.info({
  event: "user_login",
  user_id: 123,
  ip_address: "192.168.1.1",
  custom_field: "any value you want"
})
```

This approach is ideal for most applications and follows Ruby's philosophy of flexibility and developer convenience.

#### The Typed Approach (Using Structs)

For applications that benefit from strict type checking (especially those using Sorbet), LogStruct provides typed struct classes:

```ruby
# Create a typed request log entry
request_log = LogStruct::LogEntries::Request.new(
  src: LogStruct::LogSource::Rails,
  evt: LogStruct::LogEvent::Request,
  method: "GET",
  path: "/users",
  controller: "UsersController",
  action: "index",
  status: 200,
  duration: 45.2
)

# Log the typed struct
Rails.logger.info(request_log)

# Create a typed error log entry
error_log = LogStruct::LogEntries::Error.new(
  src: LogStruct::LogSource::Rails,
  evt: LogStruct::LogEvent::Exception,
  error_class: "ArgumentError",
  message: "Invalid parameter",
  backtrace: exception.backtrace&.first(10)
)

# Log the typed error
Rails.logger.error(error_log)
```

This approach provides several benefits:

- Type checking at development time
- Consistent log structure
- IDE autocompletion for available fields
- Documentation of the expected fields for each log type

Both approaches produce the same JSON output format, so you can choose the style that best fits your application's needs and development philosophy.

### ActionMailer Integration

The gem automatically integrates with ActionMailer by including the necessary modules into `ActionMailer::Base`. This integration is enabled by default but can be configured.

When enabled, the integration will automatically:

- Log when emails are about to be delivered
- Log when emails are successfully delivered
- Log and handle errors during email delivery
- Provide delivery callbacks for Rails 7.0.x (backported from Rails 7.1)

**You do not need to manually include any modules in your mailer classes.** The gem handles this automatically when you call `LogStruct.initialize`.

#### ActionMailer Delivery Callbacks

For Rails 7.0.x applications, this gem backports the delivery callbacks that were introduced in Rails 7.1. This allows you to hook into the email delivery process:

```ruby
class ApplicationMailer < ActionMailer::Base
  # Called before the email is delivered
  before_deliver :track_email_sent

  # Called after the email is delivered
  after_deliver :update_user_last_emailed_at

  # Called around the email delivery
  around_deliver :set_delivery_context

  private

  def track_email_sent
    # Log or track that an email is about to be sent
  end

  def update_user_last_emailed_at
    # Update the user's last_emailed_at timestamp
  end

  def set_delivery_context
    # Set up context before delivery
    yield
    # Clean up after delivery
  end
end
```

These callbacks are automatically enabled for Rails 7.0.x and are not needed for Rails 7.1+ as they're already included in the framework.

You can disable the ActionMailer integration in your configuration if needed:

```ruby
LogStruct.configure do |config|
  config.actionmailer_integration_enabled = false
end
```

### ActiveJob Integration

The gem automatically integrates with ActiveJob to provide structured logging for job execution. When enabled, it will:

- Replace the default ActiveJob logger with a structured JSON logger
- Log job enqueuing, execution, and completion events
- Include detailed information such as job ID, class, queue, arguments (if allowed), and execution time
- Capture and log exceptions that occur during job execution

You can disable this integration in your configuration if needed:

```ruby
LogStruct.configure do |config|
  config.activejob_integration_enabled = false
end
```

### Sidekiq Integration

The gem automatically integrates with Sidekiq to provide structured logging for background jobs. When enabled, it will:

- Configure Sidekiq to use a structured JSON formatter for both server (worker) and client (Rails app) logs
- Include detailed information such as process ID, thread ID, severity level, and Sidekiq context
- Format logs in a consistent JSON structure that matches other logs in your application

This integration is enabled by default but can be disabled:

```ruby
LogStruct.configure do |config|
  config.sidekiq_integration_enabled = false
end
```

### Shrine Integration

The gem automatically integrates with Shrine to provide structured logging for file uploads and processing. When enabled, it will:

- Configure Shrine to use a structured JSON formatter for all file operations
- Log events such as uploads, downloads, existence checks, and deletions
- Include detailed information such as storage, file metadata, and operation duration
- Safely handle record references by extracting only the necessary information

This integration is enabled by default but can be disabled:

```ruby
LogStruct.configure do |config|
  config.shrine_integration_enabled = false
end
```

### Rack Middleware for Error Logging

The gem includes a Rack middleware that enhances error logging with structured data. When enabled, it will:

- Catch and log security violations like IP spoofing attacks and CSRF token errors
- Log detailed information about exceptions that occur during request processing
- Include request context such as path, method, IP, user agent, etc.
- Return appropriate responses for security violations

The middleware is automatically inserted after `ActionDispatch::ShowExceptions` to ensure it can catch IP spoofing errors. This feature is enabled by default but can be disabled:

```ruby
LogStruct.configure do |config|
  config.rack_middleware_enabled = false
end
```

### Host Authorization Logging

The gem provides structured logging for blocked host attempts when using Rails' host authorization feature. When enabled, it will:

- Log detailed information about blocked host attempts in structured JSON format
- Include request details such as path, method, IP, user agent, etc.
- Configure a custom response app for ActionDispatch::HostAuthorization

This feature is enabled by default but can be disabled:

```ruby
LogStruct.configure do |config|
  config.host_authorization_enabled = false
end
```

### Type Checking with Sorbet

This gem includes Sorbet type definitions using RBS annotations. This provides several benefits:

- Static type checking to catch errors before runtime
- Better code documentation through type annotations
- Improved IDE integration with type-aware autocompletion and error detection

To use Sorbet with this gem in your application:

1. Add Sorbet to your Gemfile:

```ruby
gem 'sorbet', group: :development
gem 'sorbet-runtime'
```

2. Initialize Sorbet in your project:

```bash
$ bundle exec srb init
```

3. Enable RBS signatures in your Sorbet config:

```
# sorbet/config
--enable-experimental-rbs-signatures
```

4. Run type checking:

```bash
$ bundle exec srb tc
```

For more information on using Sorbet with RBS annotations, see the [Sorbet documentation](https://sorbet.org/docs/rbs-support).

### Configuration

You can configure the gem in an initializer:

```ruby
# config/initializers/logstruct.rb
LogStruct.configure do |config|
  # Enable or disable structured logging (defaults to true in production)
  config.enabled = true

  # Enable or disable Lograge integration
  config.lograge_enabled = true

  # Enable or disable ActionMailer integration
  config.actionmailer_integration_enabled = true

  # Enable or disable ActiveJob integration
  config.activejob_integration_enabled = true

  # Enable or disable Sidekiq integration
  config.sidekiq_integration_enabled = true

  # Enable or disable Shrine integration
  config.shrine_integration_enabled = true

  # Enable or disable Rack middleware for error logging
  config.rack_middleware_enabled = true

  # Enable or disable host authorization logging
  config.host_authorization_enabled = true

  # Configure the email salt used by Logstop for email hashing
  config.email_hashing_salt = 'custom_salt'

  # Logstop filtering options
  config.filter_emails = true        # Filter email addresses (default: true)
  config.filter_url_passwords = true # Filter passwords in URLs (default: true)
  config.filter_credit_cards = true  # Filter credit card numbers (default: true)
  config.filter_phones = true        # Filter phone numbers (default: true)
  config.filter_ssns = true          # Filter social security numbers (default: true)
  config.filter_ips = false          # Filter IP addresses (default: false)
  config.filter_macs = false         # Filter MAC addresses (default: false)

  # Silence noisy loggers (defaults to true)
  config.silence_noisy_loggers = true

  # Provide a custom proc to extend Lograge options
  config.lograge_custom_options = ->(event, options) do
    # Add custom fields to the options hash
    options[:user_id] = event.payload[:user_id]
    options[:account_id] = event.payload[:account_id]

    # You can add any other custom fields from the event payload
    # or from your application context
  end
end
```
