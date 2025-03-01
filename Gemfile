# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in rails_structured_logging.gemspec
gemspec

# Define Rails version based on environment variable
rails_version = ENV["RAILS_VERSION"] || "7.0"

case rails_version
when "7.0"
  gem "rails", "~> 7.0.0"
  gem "actionmailer", "~> 7.0.0"
  gem "activesupport", "~> 7.0.0"
when "7.1"
  gem "rails", "~> 7.1.0"
  gem "actionmailer", "~> 7.1.0"
  gem "activesupport", "~> 7.1.0"
when "8.0"
  gem "rails", "~> 8.0.1"
  gem "actionmailer", "~> 8.0.1"
  gem "activesupport", "~> 8.0.1"
end

# Add these gems to silence Ruby 3.4 warnings
gem "bigdecimal"
gem "mutex_m"

group :development, :test do
  gem "rspec", "~> 3.0"
  gem "rspec-sorbet-types", "~> 0.3.0"
  gem "rubocop", "~> 1.21"
  gem "rubocop-rspec", "~> 2.11"
  gem "sorbet", "~> 0.5"
  gem "sorbet-runtime", "~> 0.5.11874"
  gem "tapioca", "~> 0.16.0"
end
