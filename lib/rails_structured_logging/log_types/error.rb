# frozen_string_literal: true
# typed: strict

require 'sorbet-runtime'
require_relative 'base'

module RailsStructuredLogging
  module LogTypes
    extend T::Sig

    # Error log data struct
    class ErrorLogData < BaseLogData
      extend T::Sig

      const :error_class, T.nilable(String)
      const :error_message, T.nilable(String)
      const :backtrace, T.nilable(T::Array[String])
    end

    # Helper method to create an error log data object
    sig do
      params(
        error: StandardError,
        source: Symbol,
        event: Symbol,
        message: T.nilable(String),
        additional_data: T::Hash[T.any(Symbol, String), T.untyped]
      ).returns(ErrorLogData)
    end
    def self.create_error_log_data(error, source, event, message = nil, additional_data = {})
      # Extract error class name safely
      error_class_name = T.unsafe(error.class).name

      # Create error log data
      ErrorLogData.new(
        src: source,
        evt: event,
        msg: message || error.message,
        error_class: error_class_name,
        error_message: error.message,
        backtrace: error.backtrace,
        additional_data: additional_data
      )
    end
  end
end
