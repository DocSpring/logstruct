# typed: true
# frozen_string_literal: true

# Core library files
require "log_struct/sorbet"
require "log_struct/version"
require "log_struct/configuration"

require "log_struct/enums"
require "log_struct/log_types"
require "log_struct/log_formatter"
require "log_struct/logstop_fork"
require "log_struct/multi_error_reporter"
require "log_struct/param_filters"
require "log_struct/railtie"

# Monkey-patch ActiveSupport::TaggedLogging::Formatter to support hash input/output
require "log_struct/monkey_patches/active_support/tagged_logging/formatter"

# Require integrations
require "log_struct/integrations"

module LogStruct
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
