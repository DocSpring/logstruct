# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in rails_structured_logging.gemspec
gemspec

ruby File.read(File.expand_path(".ruby-version", __dir__)).strip

# Define Rails version based on environment variable
rails_version = ENV["RAILS_VERSION"] || "7.0"

case rails_version
when "7.0"
  gem "actionmailer", "~> 7.0.0"
  gem "activesupport", "~> 7.0.0"
  gem "rails", "~> 7.0.0"
when "7.1"
  gem "actionmailer", "~> 7.1.0"
  gem "activesupport", "~> 7.1.0"
  gem "rails", "~> 7.1.0"
when "8.0"
  gem "actionmailer", "~> 8.0.1"
  gem "activesupport", "~> 8.0.1"
  gem "rails", "~> 8.0.1"
end

# Add these gems to silence Ruby 3.4 warnings
gem "bigdecimal"
gem "mutex_m"

# Optional dependencies for type checking
gem "bugsnag", "~> 6.26", require: false
gem "honeybadger", "~> 5.4", require: false
gem "postmark", "~> 1.25", require: false
gem "rollbar", "~> 3.4", require: false
gem "sentry-ruby", "~> 5.15", require: false
gem "shrine", "~> 3.5", require: false
gem "sidekiq", "~> 7.2", require: false

group :development, :test do
  gem "debug"
  gem "rspec", require: false
  gem "rspec-sorbet-types", require: false
  # gem 'rubocop', require: false
  # gem 'rubocop-rake', require: false
  # gem 'rubocop-rspec', require: false
  # gem 'rubocop-sorbet', require: false
  gem "solargraph", require: false
  gem "sorbet", require: false
  gem "sorbet-runtime", require: false
  gem "standard", ">= 1.35.1", require: false
  gem "standard-sorbet", require: false
  gem "tapioca", require: false
end
