# Rails Structured Logging

A comprehensive structured logging solution for Rails applications.

## Features

- Structured JSON logging for Rails applications
- ActionMailer integration for email delivery logging
- Error handling and reporting
- Metadata collection for rich context

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

```ruby
# Log a simple message
RailsStructuredLogging::Logger.info("User signed in")

# Log structured data
RailsStructuredLogging::Logger.info({
  event: "user_login",
  user_id: user.id,
  ip_address: request.remote_ip
})

# Log an error
begin
  # some code that might raise an exception
rescue => e
  RailsStructuredLogging::Logger.exception(e, {
    context: "user_login",
    user_id: user.id
  })
end
```

### ActionMailer Integration

Add the module to your mailer classes:

```ruby
class ApplicationMailer < ActionMailer::Base
  include RailsStructuredLogging::ActionMailer

  # ... your mailer code
end
```

This will automatically:
- Log when emails are about to be delivered
- Log when emails are successfully delivered
- Log and handle errors during email delivery

### Configuration

You can configure the gem in an initializer:

```ruby
# config/initializers/rails_structured_logging.rb
RailsStructuredLogging.configure do |config|
  config.log_level = :info
  # Add other configuration options
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/docspring/rails_structured_logging.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
