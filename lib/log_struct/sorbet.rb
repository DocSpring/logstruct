# typed: strict
# frozen_string_literal: true

# Note: We use T::Struct for our Log classes so Sorbet is a hard requirement,
# not an optional dependency.
require "sorbet-runtime"
require_relative "multi_error_reporter"
require_relative "error_handling_mode"

# Don't extend T::Sig to all modules. We're just a library, not a private application
# See: https://sorbet.org/docs/sigs
# class Module
#   include T::Sig
# end

current_inline_type_error_handler = T::Configuration.instance_variable_get(:@inline_type_error_handler)
T::Configuration.inline_type_error_handler = lambda do |error, opts|
  LogStruct.handle_exception(error, source: LogStruct::Source::TypeChecking)
  current_inline_type_error_handler&.call(error, opts)
end

current_validation_error_handler = T::Configuration.instance_variable_get(:@call_validation_error_handler)
T::Configuration.call_validation_error_handler = lambda do |signature, opts|
  if signature.method.owner.name.start_with?("LogStruct")
    error = TypeError.new(opts[:pretty_message])
    LogStruct.handle_exception(error, source: LogStruct::Source::TypeChecking)
  elsif current_validation_error_handler
    current_validation_error_handler.call(signature, opts)
  end
end

current_sig_builder_error_handler = T::Configuration.instance_variable_get(:@sig_builder_error_handler)
T::Configuration.sig_builder_error_handler = lambda do |error, location|
  LogStruct.handle_exception(error, source: LogStruct::Source::TypeChecking)
  current_sig_builder_error_handler&.call(error, location)
end

current_sig_validation_error_handler = T::Configuration.instance_variable_get(:@sig_validation_error_handler)
T::Configuration.sig_validation_error_handler = lambda do |error, opts|
  LogStruct.handle_exception(error, source: LogStruct::Source::TypeChecking)
  current_sig_validation_error_handler&.call(error, opts)
end
