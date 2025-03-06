# typed: strict
# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in logstruct.gemspec
gemspec

# Skip Ruby version check if RUBY_VERSION is set (e.g. on CI)
unless ENV["RUBY_VERSION"]
  ruby File.read(File.expand_path(".ruby-version", __dir__)).strip
end

# Define Rails version based on environment variable
rails_version = ENV["RAILS_VERSION"] || "7.0"

case rails_version
when "7.0"
  gem "rails", "~> 7.0"
when "7.1"
  gem "rails", "~> 7.1"
when "8.0"
  gem "rails", "~> 8.0"
end

# Add these gems to silence Ruby 3.4 warnings
gem "bigdecimal"
gem "drb"  # For ActiveSupport::TestCase
gem "mutex_m"

# Supported integrations
gem "bugsnag", "~> 6.26"
gem "carrierwave", "~> 3.0"
gem "honeybadger", "~> 5.4"
gem "rollbar", "~> 3.4"
gem "sentry-ruby", "~> 5.15"
gem "shrine", "~> 3.5"
gem "sidekiq", "~> 7.2"
gem "sorbet", "~> 0.5"

# Essential testing gems that don't have Ruby version restrictions
group :test do
  gem "dalli"
  gem "minitest", "~> 5.20"
  gem "minitest-reporters", "~> 1.6"
  gem "simplecov", "~> 0.22", require: false
  gem "thor"
end

# Development and linting tools that may have higher Ruby version requirements
group :development do
  gem "debug"
  gem "amazing_print"
  gem "listen", require: false
  gem "rubocop-performance", require: false
  gem "rubocop-rails", require: false
  gem "rubocop-minitest", require: false
  gem "rubocop-sorbet", require: false
  gem "rubocop", require: false
  gem "solargraph", require: false
  gem "standard", ">= 1.35.1", require: false
  gem "tapioca", require: false
  gem "yard"
  gem "yard-sorbet"
  gem "redcarpet"
end
