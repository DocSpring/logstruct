# typed: strict
# frozen_string_literal: true

require_relative "base"

module RailsStructuredLogging
  module LogTypes
    # Error log data class
    class ErrorLogData < BaseLogData
      sig { returns(T.nilable(String)) }
      attr_reader :error_class

      sig { returns(T.nilable(String)) }
      attr_reader :error_message

      sig { returns(T.nilable(T::Array[String])) }
      attr_reader :backtrace

      # Initialize with all fields
      sig do
        params(
          src: Symbol,
          evt: Symbol,
          ts: T.nilable(Time),
          msg: T.nilable(String),
          error_class: T.nilable(String),
          error_message: T.nilable(String),
          backtrace: T.nilable(T::Array[String]),
          additional_data: T::Hash[T.any(Symbol, String), T.untyped]
        ).void
      end
      def initialize(src:, evt:, ts: nil, msg: nil, error_class: nil,
        error_message: nil, backtrace: nil, additional_data: {})
        super(src: src, evt: evt, ts: ts, msg: msg)
        @error_class = error_class
        @error_message = error_message
        @backtrace = backtrace
        @additional_data = additional_data
      end

      # Convert to hash for logging
      sig { returns(T::Hash[Symbol, T.untyped]) }
      def to_h
        result = super.merge({
          error_class: @error_class,
          error_message: @error_message,
          backtrace: @backtrace
        }.compact)

        # Merge any additional data
        result.merge!(@additional_data) if @additional_data.present?
        result
      end
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
