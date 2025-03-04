# typed: strict
# frozen_string_literal: true

# Note: We use T::Struct for our Log classes so Sorbet is a hard requirement,
# not an optional dependency.
require "sorbet-runtime"
require_relative "multi_error_reporter"
require_relative "error_handling_mode"

# Configure sorbet-runtime to use our error reporter for type checking failures
# https://sorbet.org/docs/runtime#on_failure-changing-what-happens-on-runtime-errors
T::Configuration.call_validation_error_handler = lambda do |signature, opts|
  error = TypeError.new(opts[:pretty_message])
  mode = LogStruct.config.mode_for(:type_errors)
  mode.handle(error)
end

# Extend T::Sig to all modules so we don't have to write `extend T::Sig` everywhere.
# See: https://sorbet.org/docs/sigs
class Module
  include T::Sig
end
