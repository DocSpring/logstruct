# Migration Guide: JSON Logging to RailsStructuredLogging

This guide outlines the steps to migrate from the existing JSON logging implementation to the new RailsStructuredLogging gem.

## Overview

The RailsStructuredLogging gem consolidates all structured logging functionality that was previously scattered across various initializers and libraries in the main application. This migration involves:

1. Replacing the `JSON_LOGGING_ENABLED` flag with the gem's configuration system
2. Migrating custom param filters and sensitive data handling
3. Updating initializers to use the gem's setup methods
4. Adapting any application-specific logging code to work with the gem

## Step 1: Install the Gem

Add the gem to your Gemfile:

```ruby
gem 'rails_structured_logging'
```

And run:

```bash
bundle install
```

## Step 2: Create a Configuration Initializer

Create a new initializer at `config/initializers/rails_structured_logging.rb`:

```ruby
# config/initializers/rails_structured_logging.rb
RailsStructuredLogging.configure do |config|
  # Enable structured logging (replaces JSON_LOGGING_ENABLED)
  config.enabled = Rails.env.production? || Rails.env.test? || ENV['JSON_LOGGING'] == 'true'

  # Enable integrations
  config.lograge_enabled = true
  config.actionmailer_integration_enabled = true
  config.activejob_integration_enabled = true
  config.sidekiq_integration_enabled = true
  config.shrine_integration_enabled = true
  config.rack_middleware_enabled = true
  config.host_authorization_enabled = true

  # Configure LogstopFork
  config.logstop_email_salt = 'your_custom_salt_here' # Replace with your actual salt

  # Silence noisy loggers
  config.silence_noisy_loggers = true

  # Custom Lograge options (migrate from _json_logging.rb)
  config.lograge_custom_options = lambda do |event|
    options = event.payload.slice(
      :request_id,
      :host,
      :source_ip,
      :user_id,
      :account_id,
      :api_token_id,
      :error_message,
      :mem_usage,
      :mem_growth,
      :invalid_request_json,
      :json_schema_errors
    ).compact
    options[:src] = 'rails'
    options[:evt] = 'request'

    if event.payload[:params].present?
      options[:params] = event.payload[:params].except('controller', 'action')
    end

    headers = event.payload[:headers]

    options[:basic_auth] = !!headers['basic_auth']
    if options[:basic_auth]
      options[:api_token_uid] = headers['basic_auth.username']
      options[:api_token_secret] = headers['basic_auth.password']
      options[:user_agent] = headers['HTTP_USER_AGENT']
      options[:content_type] = headers['CONTENT_TYPE']
      options[:accept] = headers['HTTP_ACCEPT']
    end

    options
  end
end
```

## Step 3: Migrate Custom Param Filters

If you have application-specific JSON column filtering rules in `JSONLogParamFilters`, you'll need to extend the gem's `ParamFilters` class:

```ruby
# config/initializers/rails_structured_logging_param_filters.rb
RailsStructuredLogging::ParamFilters.configure do
  # Add your application-specific filtered JSON columns
  @filtered_json_columns = {
    accounts: %i[default_template_settings],
    combined_submissions: %i[metadata pdf_data source_pdfs],
    submission_batches: %i[metadata],
    submission_data_requests: %i[data fields metadata],
    submissions: %i[data metadata field_overrides webhook_data],
    templates: %i[
      defaults
      field_order
      fields
      shared_field_data
      predefined_fields
      predefined_fields_sample_data
      fields_patch
      shared_field_data_patch
      predefined_fields_patch
    ],
    users: %i[stripe_card_data otp_auth_secret otp_recovery_secret otp_persistence_seed],
  }

  # Add your application-specific ignored JSON columns
  @ignored_json_columns = {
    accounts: %i[company_logo_data usage_notification_settings field_import_settings],
    combined_submissions: %i[profiling_data],
    submissions: %i[
      chainpoint_proof
      json_schema_errors
      pdf_data
      profiling_data
      truncated_text
      pdf_preview_data
      audit_trail_pdf_data
    ],
    templates: %i[document_data formstack_field_mapping html_engine_options pdf_preview_data webhook_options],
  }

  # Add your application-specific ignored tables
  @ignored_tables = %i[
    account_integrations
    account_migration_batch_parts
    account_migrations
    ahoy_events
    api_logs
    audits
    combined_submission_actions
    combined_submission_partitions
    custom_files
    form_library_templates
    good_job_batches
    good_job_executions
    good_job_processes
    good_job_settings
    good_jobs
    linked_accounts
    onsite_licenses
    submission_actions
    submission_images
    template_actions
    template_images
  ]
end
```

## Step 4: Update Application Code

### Replace Direct References to JSON_LOGGING_ENABLED

Search for all instances of `JSON_LOGGING_ENABLED` in your codebase and replace them with `RailsStructuredLogging.enabled?`.

For example, in `app/jobs/internal_slack_notification_job.rb`:

```ruby
def perform(options)
  if Rails.env.development?
    if RailsStructuredLogging.enabled?
      Rails.logger.info(
        message: 'Called InternalSlackNotificationJob perform',
        options: options
      )
    else
      ap options # rubocop:disable Rails/Output
    end
    return
  end
  # ...
end
```

### Remove Redundant Initializers

The following initializers can be removed as their functionality is now provided by the gem:

- `config/initializers/_json_logging.rb`
- `config/initializers/action_mailer_hash_logging.rb`
- `config/initializers/active_job_hash_logs.rb`
- `config/initializers/host_authorization_hash_logs.rb`

### Update Sidekiq Configuration

In `config/initializers/_sidekiq.rb`, replace the custom formatter with the gem's formatter:

```ruby
if RailsStructuredLogging.enabled?
  config.logger.formatter = RailsStructuredLogging::Sidekiq::Formatter.new
end
```

### Update Shrine Configuration

In `config/initializers/shrine.rb`, replace the custom log subscriber with the gem's implementation:

```ruby
if RailsStructuredLogging.enabled?
  Shrine.plugin :instrumentation,
                log_events: [:upload, :exists, :download, :delete],
                log_subscriber: RailsStructuredLogging::Shrine.log_subscriber
else
  Shrine.plugin :instrumentation
end
```

## Step 5: Testing

After migrating, thoroughly test your application to ensure that:

1. All logs are properly formatted as JSON in environments where structured logging is enabled
2. Sensitive data is properly filtered
3. All integrations (ActionMailer, ActiveJob, Sidekiq, Shrine, etc.) are working correctly
4. Error handling and security violation logging work as expected

## Troubleshooting

### Log Format Issues

If logs are not properly formatted as JSON, check:
- The `enabled` configuration is set correctly
- The Rails logger formatter is properly set
- There are no conflicts with other logging configurations

### Missing Context in Logs

If logs are missing expected context (e.g., request_id, user_id):
- Check the Lograge custom options configuration
- Ensure that the appropriate middleware is enabled

### Performance Issues

If you notice performance degradation:
- Check for excessive logging or redundant log calls
- Consider optimizing the param filters for your specific application

## Additional Resources

- [RailsStructuredLogging README](https://github.com/docspring/rails_structured_logging/blob/main/README.md)
- [Lograge Documentation](https://github.com/roidrage/lograge)
- [LogstopFork Documentation](https://github.com/docspring/rails_structured_logging/blob/main/lib/rails_structured_logging/logstop_fork.rb)
