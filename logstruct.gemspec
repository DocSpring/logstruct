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
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/DocSpring/logstruct"
  spec.metadata["changelog_uri"] = "#{spec.metadata["source_code_uri"]}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released: only files committed to git, so a
  # local build can't pick up untracked files. Without git (an unpacked gem), it falls back to Dir.
  patterns = ["lib/**/*", "README.md", "CHANGELOG.md", "LICENSE", "*.gemspec"]
  tracked_files = begin
    output = IO.popen(%w[git ls-files -z], chdir: __dir__, err: File::NULL, &:read)
    output.split("\x0") if $?.success?
  rescue Errno::ENOENT
    nil
  end
  spec.files = if tracked_files
    tracked_files.select { |file| patterns.any? { |pattern| File.fnmatch?(pattern, file, File::FNM_PATHNAME) } }
  else
    Dir[*patterns].select { |file| File.file?(file) }
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "actionpack", ">= 7.1"
  spec.add_dependency "activesupport", ">= 7.1"
  spec.add_dependency "globalid", ">= 1.0"
  spec.add_dependency "lograge", ">= 0.11"
  spec.add_dependency "railties", ">= 7.1"
  spec.add_dependency "semantic_logger", "~> 4.15"
  spec.add_dependency "sorbet-runtime", ">= 0.5"

  # Optional integrations
  spec.add_development_dependency "bugsnag", "~> 6.26"
  spec.add_development_dependency "carrierwave", "~> 3.0"
  spec.add_development_dependency "honeybadger", "~> 6.9"
  spec.add_development_dependency "rollbar", "~> 3.4"
  spec.add_development_dependency "sentry-ruby", "~> 5.15"
  spec.add_development_dependency "shrine", "~> 3.5"
  spec.add_development_dependency "sidekiq", "~> 7.2"
  spec.add_development_dependency "sorbet", "~> 0.5"
  spec.add_development_dependency "ahoy_matey", ">= 4.1", "< 6.0"
  spec.add_development_dependency "active_model_serializers", "~> 0.10.13"
  spec.add_development_dependency "dotenv-rails", "~> 3.1"

  spec.metadata["rubygems_mfa_required"] = "true"
end
