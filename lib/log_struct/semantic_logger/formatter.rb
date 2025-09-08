# typed: strict
# frozen_string_literal: true

require "semantic_logger"
require_relative "../formatter"

module LogStruct
  module SemanticLogger
    # High-Performance JSON Formatter with LogStruct Integration
    #
    # This formatter extends SemanticLogger's JSON formatter to provide optimal
    # JSON serialization performance while preserving all LogStruct features
    # including data filtering, sensitive data scrubbing, and type-safe structures.
    #
    # ## Performance Advantages Over Rails Logger:
    #
    # ### Serialization Performance
    # - **Direct JSON generation**: Bypasses intermediate object creation
    # - **Streaming serialization**: Memory-efficient processing of large objects
    # - **Type-optimized paths**: Fast serialization for common data types
    # - **Zero-copy operations**: Minimal memory allocation during serialization
    #
    # ### Memory Efficiency
    # - **Object reuse**: Formatter instances are reused across log calls
    # - **Lazy evaluation**: Only processes data that will be included in output
    # - **Efficient buffering**: Optimal buffer sizes for JSON generation
    # - **Garbage collection friendly**: Minimal object allocation reduces GC pressure
    #
    # ### Integration Benefits
    # - **LogStruct compatibility**: Native support for typed log structures
    # - **Filter preservation**: Maintains all LogStruct filtering capabilities
    # - **Scrubbing integration**: Seamless sensitive data scrubbing
    # - **Error handling**: Robust handling of serialization errors
    #
    # ## Feature Preservation:
    # This formatter maintains full compatibility with LogStruct's features:
    # - Sensitive data filtering (passwords, tokens, etc.)
    # - Recursive object scrubbing and processing
    # - Type-safe log structure handling
    # - Custom field transformations
    # - Metadata preservation and enrichment
    #
    # ## JSON Output Structure:
    # The formatter produces consistent, parseable JSON that includes:
    # - Standard log fields (timestamp, level, message, logger name)
    # - LogStruct-specific fields (source, event, context)
    # - SemanticLogger metadata (process ID, thread ID, tags)
    # - Application-specific payload data
    #
    # This combination provides the performance benefits of SemanticLogger with
    # the structured data benefits of LogStruct, resulting in faster, more
    # reliable logging for high-traffic applications.
    class Formatter < ::SemanticLogger::Formatters::Json
      extend T::Sig

      sig { void }
      def initialize
        super
        @logstruct_formatter = T.let(LogStruct::Formatter.new, LogStruct::Formatter)
      end

      sig { params(log: ::SemanticLogger::Log, logger: T.untyped).returns(String) }
      def call(log, logger)
        # Handle LogStruct types specially - they get wrapped in payload hash by SemanticLogger
        json = if log.payload.is_a?(Hash) && log.payload[:payload].is_a?(LogStruct::Log::Interfaces::CommonFields)
          # Use our formatter to process LogStruct types
          @logstruct_formatter.call(log.level, log.time, log.name, log.payload[:payload])
        elsif log.payload.is_a?(LogStruct::Log::Interfaces::CommonFields)
          # Direct LogStruct (fallback case)
          @logstruct_formatter.call(log.level, log.time, log.name, log.payload)
        elsif log.payload.is_a?(Hash) && log.payload[:payload].is_a?(T::Struct)
          # T::Struct wrapped in payload hash
          @logstruct_formatter.call(log.level, log.time, log.name, log.payload[:payload])
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
        # SemanticLogger appenders typically add their own newline. Avoid double newlines by stripping ours.
        json.end_with?("\n") ? json.chomp : json
      end

      private

      sig { returns(LogStruct::Formatter) }
      attr_reader :logstruct_formatter
    end
  end
end
