# typed: strict
# frozen_string_literal: true

# Core library files
require "log_struct/sorbet"
require "log_struct/version"
require "log_struct/configuration"
require "log_struct/configuration_untyped"
require "log_struct/json_formatter"
require "log_struct/railtie"
require "log_struct/error_source"
require "log_struct/error_handling_mode"
require "log_struct/error_handler"

# Monkey-patch ActiveSupport::TaggedLogging::Formatter to support hash input/output
require "log_struct/monkey_patches/active_support/tagged_logging/formatter"

# Require integrations
require "log_struct/integrations"

module LogStruct
  extend T::Sig

  class Error < StandardError; end

  class << self
    include ErrorHandler

    sig { returns(Configuration) }
    def config
      Configuration.config
    end

    sig { returns(Configuration) }
    def configuration
      Configuration.configuration
    end

    sig { returns(Configuration) }
    def configuration_typed
      Configuration.configuration_typed
    end

    sig { params(block: T.proc.params(config: ConfigurationUntyped).void).void }
    def configure(&block)
      config = ConfigurationUntyped.instance
      yield(config)
      config.apply_to_typed
    end

    sig { params(block: T.proc.params(config: Configuration).void).void }
    def configure_typed(&block)
      Configuration.configure_typed(&block)
    end

    sig { returns(T::Boolean) }
    def enabled?
      configuration.enabled_for_environment?
    end
  end
end
