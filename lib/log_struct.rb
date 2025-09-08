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

module LogStruct
  class Error < StandardError; end

  extend Concerns::ErrorHandling::ClassMethods
  extend Concerns::Configuration::ClassMethods
  extend Concerns::Logging::ClassMethods

  # Set enabled at require time based on current Rails environment.
  # (Users can disable or enable LogStruct later in an initializer.)
  set_enabled_from_rails_env!
end
