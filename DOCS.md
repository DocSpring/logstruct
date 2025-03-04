# LogStruct Documentation

## Configuration Design

LogStruct's configuration system is designed to cater to two different audiences:

1. **Ruby Developers**: Those who prefer the Rails-style configuration with symbols
2. **Type-Checked Developers**: Those who use Sorbet and want type-safe configuration

### Error Handling Configuration

The error handling configuration provides two APIs:

#### Ruby-Style API (for most developers)

```ruby
# Set all error modes to :ignore
config.mode = :ignore

# Set specific error type to :ignore
config.type_errors = :ignore
```

This API is designed to be familiar to Ruby developers who are used to Rails-style configuration. It uses symbols and provides a clean, intuitive interface.

#### Type-Checked API (for Stripe/Shopify/Gusto)

```ruby
# Set all error modes to Ignore
config.set_mode(ErrorHandlingMode::Ignore)

# Set specific error type to Ignore
config.set_mode_for_enum(:type_errors, ErrorHandlingMode::Ignore)
```

This API is designed for teams that use Sorbet and want type-safe configuration. It uses enums and provides compile-time type checking.

### Why Two APIs?

1. **Developer Experience**: Most Ruby developers are familiar with Rails-style configuration using symbols. This makes LogStruct immediately approachable.
2. **Type Safety**: Teams using Sorbet can leverage type checking to catch configuration errors at compile time.
3. **Flexibility**: Developers can choose the API that best fits their team's practices.

### Available Error Handling Modes

- `:ignore` / `ErrorHandlingMode::Ignore`: Always ignore the error
- `:log` / `ErrorHandlingMode::Log`: Always log the error
- `:report` / `ErrorHandlingMode::Report`: Always report to tracking service and continue
- `:log_production` / `ErrorHandlingMode::LogProduction`: Log in production, raise locally
- `:report_production` / `ErrorHandlingMode::ReportProduction`: Report in production, raise locally
- `:raise` / `ErrorHandlingMode::Raise`: Always raise regardless of environment

### Default Configuration

```ruby
{
  type_errors: ErrorHandlingMode::LogProduction,     # Raise in test/dev, log in prod
  logstruct_errors: ErrorHandlingMode::LogProduction, # Raise in test/dev, log in prod
  standard_errors: ErrorHandlingMode::Raise          # Always raise
}
```

### Integrations Configuration

The integrations configuration follows the same pattern, providing both Ruby-style and type-checked APIs:

#### Ruby-Style API

```ruby
# Disable all integrations
config.enabled = false

# Disable specific integration
config.lograge = false
```

#### Type-Checked API

```ruby
# Disable all integrations
config.set_enabled(false)

# Disable specific integration
config.set_enabled_for_enum(:lograge, false)
```

#### Available Integrations

- `lograge`: Enable Lograge integration
- `actionmailer`: Enable ActionMailer integration
- `host_authorization`: Enable host authorization logging
- `activejob`: Enable ActiveJob integration
- `rack_middleware`: Enable Rack middleware
- `sidekiq`: Enable Sidekiq integration
- `shrine`: Enable Shrine integration
- `active_storage`: Enable ActiveStorage integration
- `carrierwave`: Enable CarrierWave integration

### Filter Configuration

The filter configuration provides APIs for controlling sensitive data filtering:

#### Ruby-Style API

```ruby
# Disable all filters
config.enabled = false

# Disable specific filter
config.emails = false

# Configure filtered keys
config.filtered_keys = [:password, :token]

# Configure hashed keys
config.hashed_keys = [:email]

# Configure hash settings
config.hash_salt = "custom_salt"
config.hash_length = 16
```

#### Type-Checked API

```ruby
# Disable all filters
config.set_enabled(false)

# Disable specific filter
config.set_enabled_for_enum(:emails, false)

# Configure filtered keys
config.set_filtered_keys([:password, :token])

# Configure hashed keys
config.set_hashed_keys([:email])
```

#### Available Filters

- `emails`: Filter email addresses
- `url_passwords`: Filter passwords in URLs
- `credit_cards`: Filter credit card numbers
- `phones`: Filter phone numbers
- `ssns`: Filter social security numbers
- `ips`: Filter IP addresses (disabled by default)
- `macs`: Filter MAC addresses (disabled by default)

#### Default Filtered Keys

```ruby
%i[
  password password_confirmation pass pw token secret
  credentials auth authentication authorization
  credit_card ssn social_security
]
```

#### Default Hashed Keys

```ruby
%i[
  email email_address
]
```

#### Hash Settings

- `hash_salt`: Salt for SHA256 hashing (default: "l0g5t0p")
- `hash_length`: Length of the hash (default: 12)
