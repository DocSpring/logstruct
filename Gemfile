# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in logstruct.gemspec
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

# Supported integrations
gem "bugsnag", "~> 6.26"
gem "carrierwave", "~> 3.0"
gem "honeybadger", "~> 5.4"
gem "postmark", "~> 1.25"
gem "rollbar", "~> 3.4"
gem "sentry-ruby", "~> 5.15"
gem "shrine", "~> 3.5"
gem "sidekiq", "~> 7.2"

group :development, :test do
  gem "dalli"
  gem "debug"
  gem "listen", require: false
  gem "rspec-sorbet-types"
  gem "rspec"
  gem "rubocop-performance", require: false
  gem "rubocop-rails", require: false
  gem "rubocop-rspec", require: false
  gem "rubocop-sorbet", require: false
  gem "rubocop", require: false
  gem "solargraph", require: false
  gem "sorbet"
  gem "thor"
  gem "standard", ">= 1.35.1", require: false
  gem "tapioca", require: false
end
