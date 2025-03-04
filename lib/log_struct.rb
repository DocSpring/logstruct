# typed: strict
# frozen_string_literal: true

# Core library files
require "log_struct/sorbet"
require "log_struct/version"
require "log_struct/enums"  # All enums are now in the enums directory
require "log_struct/configuration"
require "log_struct/json_formatter"
require "log_struct/railtie"
require "log_struct/concerns/error_handling"
require "log_struct/concerns/configuration"
require "log_struct/concerns/logging"

# Monkey-patch ActiveSupport::TaggedLogging::Formatter to support hash input/output
require "log_struct/monkey_patches/active_support/tagged_logging/formatter"

# Require integrations
require "log_struct/integrations"

module LogStruct
  class Error < StandardError; end

  extend Concerns::ErrorHandling::ClassMethods
  extend Concerns::Configuration::ClassMethods
  extend Concerns::Logging::ClassMethods
end
