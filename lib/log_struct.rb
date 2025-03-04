# typed: true
# frozen_string_literal: true

# Core library files
require "log_struct/sorbet"
require "log_struct/version"
require "log_struct/configuration"
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
  class Error < StandardError; end

  class << self
    include ErrorHandler

    sig { returns(Configuration) }
    def configuration
      @configuration ||= Configuration.new
    end
    alias_method :config, :configuration

    sig { params(configuration: Configuration).void }
    attr_writer :configuration

    # Configure with a required block
    sig { params(blk: T.proc.params(config: Configuration).void).returns(Configuration) }
    def configure(&blk)
      yield(configuration)
      configuration
    end

    sig { returns(T::Boolean) }
    def enabled?
      configuration.enabled_for_environment?
    end
  end
end
