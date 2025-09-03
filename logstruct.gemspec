# frozen_string_literal: true

require_relative "lib/log_struct/version"

Gem::Specification.new do |spec|
  spec.name = "logstruct"
  spec.version = LogStruct::VERSION
  spec.authors = ["DocSpring"]
  spec.email = ["support@docspring.com"]

  spec.summary = "Type-Safe JSON Structured Logging for Rails Apps"
  spec.description = "An opinionated and type-safe structured logging solution. " \
    "Configures any Rails app to log JSON to stdout. " \
    "Structured logging is automatically configured for many gems, including Sidekiq, Carrierwave, Shrine, etc. " \
    "Log messages, params, and job args are automatically filtered and scrubbed to remove any sensitive info."
  spec.homepage = "https://logstruct.com"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/DocSpring/logstruct"
  spec.metadata["changelog_uri"] = "#{spec.metadata["source_code_uri"]}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir[
    "lib/**/*",
    "README.md",
    "CHANGELOG.md",
    "LICENSE",
    "*.gemspec",
  ]
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "lograge", ">= 0.11"
  spec.add_dependency "rails", ">= 7.0"
  spec.add_dependency "semantic_logger", "~> 4.15"
  spec.add_dependency "sorbet-runtime", ">= 0.5"

  # Optional integrations
  spec.add_development_dependency "bugsnag", "~> 6.26"
  spec.add_development_dependency "carrierwave", "~> 3.0"
  spec.add_development_dependency "honeybadger", "~> 5.4"
  spec.add_development_dependency "rollbar", "~> 3.4"
  spec.add_development_dependency "sentry-ruby", "~> 5.15"
  spec.add_development_dependency "shrine", "~> 3.5"
  spec.add_development_dependency "sidekiq", "~> 7.2"
  spec.add_development_dependency "sorbet", "~> 0.5"

  spec.metadata["rubygems_mfa_required"] = "true"
end
