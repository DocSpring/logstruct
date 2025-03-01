# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in rails_structured_logging.gemspec
gemspec

gem "rake", "~> 13.0"
gem "rspec", "~> 3.0"
gem "rubocop", "~> 1.21"

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
  gem "rails", "~> 8.0.0.alpha"
  gem "actionmailer", "~> 8.0.0.alpha"
  gem "activesupport", "~> 8.0.0.alpha"
end
