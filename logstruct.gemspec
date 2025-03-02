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
  spec.homepage = "https://github.com/docspring/logstruct"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "lograge", ">= 0.11"
  spec.add_dependency "rails", ">= 7.0"
  spec.metadata["rubygems_mfa_required"] = "true"
end
