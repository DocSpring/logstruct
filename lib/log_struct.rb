# typed: strict
# frozen_string_literal: true

# Core library files
require "log_struct/sorbet"
require "log_struct/version"
require "log_struct/configuration"
require "log_struct/json_formatter"
require "log_struct/railtie"
require "log_struct/error_source"
require "log_struct/error_handler"

# Monkey-patch ActiveSupport::TaggedLogging::Formatter to support hash input/output
require "log_struct/monkey_patches/active_support/tagged_logging/formatter"

# Require integrations
require "log_struct/integrations"

module LogStruct
  class Error < StandardError; end

  class << self
    include ErrorHandler

    sig { returns(Configuration) }
    def configuration
      Configuration.configuration
    end
    alias_method :config, :configuration

    sig { params(block: T.proc.params(config: Untyped::Configuration).void).void }
    def configure(&block)
      yield(Untyped::Configuration.new(configuration))
    end

    sig { params(block: T.proc.params(config: Configuration).void).void }
    def configure_typed(&block)
      yield(configuration)
    end

    sig { returns(T::Boolean) }
    def enabled?
      configuration.enabled
    end
  end
end
