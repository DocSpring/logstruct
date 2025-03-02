# typed: true
# frozen_string_literal: true

# Core library files
require "rails_structured_logging/sorbet"
require "rails_structured_logging/version"
require "rails_structured_logging/configuration"

require "rails_structured_logging/enums"
require "rails_structured_logging/log_types"
require "rails_structured_logging/log_formatter"
require "rails_structured_logging/logstop_fork"
require "rails_structured_logging/multi_error_reporter"
require "rails_structured_logging/param_filters"
require "rails_structured_logging/railtie"

# Monkey-patch ActiveSupport::TaggedLogging::Formatter to support hash input/output
require "rails_structured_logging/monkey_patches/active_support/tagged_logging/formatter"

# Require integrations
require "rails_structured_logging/integrations"

module RailsStructuredLogging
  class Error < StandardError; end

  class << self
    sig { returns(Configuration) }
    def configuration
      @configuration ||= Configuration.new
    end

    sig { params(configuration: Configuration).void }
    attr_writer :configuration

    sig { returns(Configuration) }
    def configure
      yield(configuration) if block_given?
    end

    sig { returns(T::Boolean) }
    def enabled?
      configuration.enabled
    end
  end

  # Initialize with defaults
  configure
end
