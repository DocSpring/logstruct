# typed: strict
# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in logstruct.gemspec. Its development dependencies are the
# integrations' gems, which the tests need: they go in the test group, because CI installs the
# gems without the development group (its tools need newer Rubies).
gemspec development_group: :test

# Skip Ruby version check if RUBY_VERSION is set (e.g. on CI)
unless ENV["RUBY_VERSION"]
  ruby File.read(File.expand_path(".ruby-version", __dir__)).strip
end

# Use a stable Rails for gem development/test environment.
# Rails version for the generated test app is controlled by RAILS_VERSION in rails_tests.
gem "rails", "~> 8.1.4", require: false

# Add these gems to silence Ruby 3.4+ warnings
gem "bigdecimal"
gem "drb"  # For ActiveSupport::TestCase
gem "mutex_m"
gem "openssl"  # For tapioca SSL certificate verification
gem "ostruct"  # For Ruby 3.5+ compatibility

# ActiveSupport 8.0's JSON encoder passes quirks_mode to JSON.generate, which json 3 rejects
# (fixed on Rails main). rails_test_app/create_app.rb pins it for the test apps too.
gem "json", "< 3"

# Sorbet is needed for development
gem "sorbet", "~> 0.6"
gem "sorbet-typescript"

# Essential testing gems that don't have Ruby version restrictions
group :test do
  gem "dalli", "~> 3.2.13"
  gem "bundler-audit", require: false
  gem "minitest", "~> 5.20"
  gem "minitest-reporters", "~> 1.8"
  gem "simplecov", "~> 0.22", require: false
  gem "simplecov-json", "~> 0.2", require: false
  gem "climate_control", "~> 1.2"
  gem "thor"
  gem "json_schemer"
end

# Development and linting tools that may have higher Ruby version requirements
group :development do
  gem "debug"
  gem "amazing_print"
  gem "listen", require: false
  gem "rubocop-performance", require: false
  # gem "rubocop-rails", require: false
  gem "rubocop-minitest", require: false
  gem "rubocop-sorbet", require: false
  gem "rubocop-inflector", require: false
  gem "rubocop", require: false
  gem "solargraph", require: false
  gem "standard", ">= 1.35.1", require: false
  gem "tapioca", require: false
  gem "yard"
  gem "yard-sorbet"
  gem "redcarpet"
end
