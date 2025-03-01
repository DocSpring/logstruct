# Rails Structured Logging

A comprehensive structured logging solution for Rails applications.

## Features

- Structured JSON logging for Rails applications
- ActionMailer integration for email delivery logging
- ActiveJob integration for job execution logging
- Sidekiq integration for background job logging
- Shrine integration for file upload logging
- Error handling and reporting
- Metadata collection for rich context
- Lograge integration for structured request logging
- Sensitive data scrubbing with Logstop (forked copy)
- Host authorization logging for security violations
- Rack middleware for enhanced error logging
- ActionMailer delivery callbacks for Rails 7.0.x (backported from Rails 7.1)

## Supported Gems and Versions

The following table lists the gems that Rails Structured Logging integrates with and their supported versions:

| Gem | Supported Versions | Notes |
|-----|-------------------|-------|
| Rails | >= 6.0 | Core dependency |
| ActionMailer | >= 6.0 | Part of Rails |
| ActiveJob | >= 6.0 | Part of Rails |
| Sidekiq | >= 6.0 | For background job logging |
| Shrine | >= 3.0 | For file upload logging |
| Lograge | >= 0.11 | For structured request logging |

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rails_structured_logging'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install rails_structured_logging
```

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
    error: e.class.name,
    message: e.message,
    backtrace: e.backtrace.first(5),
    user_id: user&.id
  })
end
```

### ActionMailer Integration

The gem automatically integrates with ActionMailer by including the necessary module into `ActionMailer::Base`. This integration is enabled by default but can be configured.

When enabled, the integration will automatically:
- Log when emails are about to be delivered
- Log when emails are successfully delivered
- Log and handle errors during email delivery
- Provide delivery callbacks for Rails 7.0.x (backported from Rails 7.1)

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
RailsStructuredLogging.configure do |config|
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
RailsStructuredLogging.configure do |config|
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
RailsStructuredLogging.configure do |config|
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
RailsStructuredLogging.configure do |config|
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
RailsStructuredLogging.configure do |config|
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
RailsStructuredLogging.configure do |config|
  config.host_authorization_enabled = false
end
```

### Configuration

You can configure the gem in an initializer:

```ruby
# config/initializers/rails_structured_logging.rb
RailsStructuredLogging.configure do |config|
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

  # Configure the email salt used by Logstop (forked copy) for email hashing
  config.logstop_email_salt = 'custom_salt'

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
