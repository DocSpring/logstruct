# typed: strict
# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in logstruct.gemspec
gemspec

# Skip Ruby version check if RUBY_VERSION is set (e.g. on CI)
unless ENV["RUBY_VERSION"]
  ruby File.read(File.expand_path(".ruby-version", __dir__)).strip
end

# Use a stable Rails for gem development/test environment.
# Rails version for the generated test app is controlled by RAILS_VERSION in rails_tests.
gem "rails", "~> 8.0.2.1", require: false

# Add these gems to silence Ruby 3.4+ warnings
gem "bigdecimal"
gem "drb"  # For ActiveSupport::TestCase
gem "mutex_m"
gem "openssl"  # For tapioca SSL certificate verification
gem "ostruct"  # For Ruby 3.5+ compatibility

# Sorbet is needed for development
gem "sorbet", "~> 0.5"
gem "sorbet-typescript"

# Essential testing gems that don't have Ruby version restrictions
group :test do
  gem "dalli"
  gem "minitest", "~> 5.20"
  gem "minitest-reporters", "~> 1.6"
  gem "simplecov", "~> 0.22", require: false
  gem "simplecov-json", "~> 0.2", require: false
  gem "climate_control", "~> 1.2"
  gem "thor"
  gem "json_schemer"
  gem "puma"
end

# Development and linting tools that may have higher Ruby version requirements
group :development do
  # concurrent-ruby 1.3.5 stopped requiring logger.
  # This causes Rails 7.0 to crash. (Our gem works fine either way,
  # but it's annoying that we have to keep uninstalling 1.3.5 to
  # run our integration tests.)
  # See: https://github.com/rails/rails/pull/54264
  gem "concurrent-ruby", "<= 1.3.4"
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
