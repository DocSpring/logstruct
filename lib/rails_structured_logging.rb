# typed: true
# frozen_string_literal: true

# Core files
require "rails_structured_logging/sorbet"
require "rails_structured_logging/version"
require "rails_structured_logging/enums"
require "rails_structured_logging/log_types"
require "rails_structured_logging/configuration"
require "rails_structured_logging/log_formatter"
require "rails_structured_logging/logstop_fork"
require "rails_structured_logging/param_filters"
require "rails_structured_logging/railtie"

# Monkey-patch ActiveSupport::TaggedLogging::Formatter to support hash input/output
require "rails_structured_logging/monkey_patches/active_support/tagged_logging/formatter"

# Integrations
require "rails_structured_logging/action_mailer"
require "rails_structured_logging/active_job"
require "rails_structured_logging/host_authorization_response_app"
require "rails_structured_logging/lograge"
require "rails_structured_logging/rack"
require "rails_structured_logging/shrine"
require "rails_structured_logging/sidekiq"

module RailsStructuredLogging
  extend T::Sig

  class Error < StandardError; end

  class << self
    extend T::Sig

    attr_accessor :configuration

    sig { params(block: T.nilable(T.proc.params(config: Configuration).void)).void }
    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
    end

    sig { returns(T::Boolean) }
    def enabled?
      configuration&.enabled || false
    end
  end

  # Initialize with defaults
  configure
end
