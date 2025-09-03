# typed: strict
# frozen_string_literal: true

require "semantic_logger"
require_relative "../formatter"

module LogStruct
  module SemanticLogger
    # Custom SemanticLogger formatter that preserves all LogStruct features
    # including filtering, scrubbing, and type-safe log structs
    class Formatter < ::SemanticLogger::Formatters::Json
      extend T::Sig

      sig { void }
      def initialize
        super
        @logstruct_formatter = T.let(LogStruct::Formatter.new, LogStruct::Formatter)
      end

      sig { params(log: ::SemanticLogger::Log, logger: T.untyped).returns(String) }
      def call(log, logger)
        # Handle LogStruct types specially
        if log.payload.is_a?(LogStruct::Log::Interfaces::CommonFields)
          # Use our formatter to process LogStruct types
          @logstruct_formatter.call(log.level, log.time, log.name, log.payload)
        elsif log.payload.is_a?(Hash) || log.payload.is_a?(T::Struct)
          # Process hashes and T::Structs through our formatter
          @logstruct_formatter.call(log.level, log.time, log.name, log.payload)
        else
          # For plain messages, create a Plain log entry
          message_data = log.payload || log.message
          plain_log = LogStruct::Log::Plain.new(
            message: message_data,
            timestamp: log.time
          )
          @logstruct_formatter.call(log.level, log.time, log.name, plain_log)
        end
      end

      private

      sig { returns(LogStruct::Formatter) }
      attr_reader :logstruct_formatter
    end
  end
end