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
    "LICENSE.txt",
    "*.gemspec",
  ]
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "lograge", ">= 0.11"
  spec.add_dependency "rails", ">= 7.0"
  spec.add_dependency "sorbet-runtime", ">= 0.5"

  spec.metadata["rubygems_mfa_required"] = "true"
end
