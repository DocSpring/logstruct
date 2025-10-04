# typed: strict
# frozen_string_literal: true

# Core library files
require "log_struct/sorbet"
require "log_struct/version"
require "log_struct/enums"
require "log_struct/configuration"
require "log_struct/formatter"
require "log_struct/railtie"
require "log_struct/concerns/error_handling"
require "log_struct/concerns/configuration"
require "log_struct/concerns/logging"

# Require integrations
require "log_struct/integrations"

# SemanticLogger integration - core feature for high-performance logging
require "log_struct/semantic_logger/formatter"
require "log_struct/semantic_logger/color_formatter"
require "log_struct/semantic_logger/logger"
require "log_struct/semantic_logger/setup"
require "log_struct/rails_boot_banner_silencer"

# Monkey patches for Rails compatibility
require "log_struct/monkey_patches/active_support/tagged_logging/formatter"

module LogStruct
  extend T::Sig

  @server_mode = T.let(false, T::Boolean)

  class Error < StandardError; end

  extend Concerns::ErrorHandling::ClassMethods
  extend Concerns::Configuration::ClassMethods
  extend Concerns::Logging::ClassMethods

  sig { returns(T::Boolean) }
  def self.server_mode?
    @server_mode
  end

  sig { params(value: T::Boolean).void }
  def self.server_mode=(value)
    @server_mode = value
  end

  # Set enabled at require time based on current Rails environment.
  # (Users can disable or enable LogStruct later in an initializer.)
  set_enabled_from_rails_env!

  # Silence Rails boot banners for cleaner server output
  LogStruct::RailsBootBannerSilencer.install!

  # Patch Puma immediately for server runs so we can convert its lifecycle
  # messages into structured logs reliably.
  if ARGV.include?("server")
    begin
      require "log_struct/integrations/puma"
      LogStruct::Integrations::Puma.install_patches!

      # Patches installed now; Rack handler patch covers server boot path
    rescue => e
      if defined?(::Rails) && ::Rails.respond_to?(:env) && ::Rails.env.test?
        raise e
      else
        LogStruct.handle_exception(e, source: LogStruct::Source::Puma)
      end
    end
  end
end
