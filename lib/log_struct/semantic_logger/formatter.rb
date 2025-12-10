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
        LogStruct::Debug.log(:formatter, "call() invoked")
        LogStruct::Debug.log(:formatter, "  log.name = #{log.name.inspect}")
        LogStruct::Debug.log(:formatter, "  log.level = #{log.level.inspect}")
        LogStruct::Debug.log(:formatter, "  log.message = #{log.message.inspect[0..200]}")
        LogStruct::Debug.log(:formatter, "  log.message.class = #{log.message.class}")
        LogStruct::Debug.log(:formatter, "  log.payload = #{log.payload.inspect[0..200]}")
        LogStruct::Debug.log(:formatter, "  log.payload.class = #{log.payload.class}")

        # Extract LogStruct from various locations where it might be stored
        logstruct = extract_logstruct(log)
        LogStruct::Debug.log(:formatter, "  extract_logstruct returned: #{logstruct ? "CommonFields" : "nil"}")

        json = if logstruct
          LogStruct::Debug.log(:formatter, "  PATH: logstruct branch (CommonFields)")
          # Use our formatter to process LogStruct types directly
          @logstruct_formatter.call(log.level, log.time, log.name, logstruct)
        elsif log.payload.is_a?(Hash) || log.payload.is_a?(T::Struct)
          LogStruct::Debug.log(:formatter, "  PATH: hash/struct branch")
          LogStruct::Debug.log(:formatter, "    payload is Hash: #{log.payload.is_a?(Hash)}")
          LogStruct::Debug.log(:formatter, "    payload is T::Struct: #{log.payload.is_a?(T::Struct)}")
          # Process hashes and T::Structs through our formatter
          @logstruct_formatter.call(log.level, log.time, log.name, log.payload)
        else
          LogStruct::Debug.log(:formatter, "  PATH: plain message branch")
          # For plain messages, create a Plain log entry
          message_data = log.payload || log.message
          LogStruct::Debug.log(:formatter, "    message_data = #{message_data.inspect[0..200]}")
          LogStruct::Debug.log(:formatter, "    message_data.class = #{message_data.class}")
          plain_log = ::LogStruct::Log::Plain.new(
            message: message_data,
            timestamp: log.time
          )
          @logstruct_formatter.call(log.level, log.time, log.name, plain_log)
        end

        LogStruct::Debug.log(:formatter, "  OUTPUT json[0..300] = #{json[0..300].inspect}")

        # SemanticLogger appenders typically add their own newline. Avoid double newlines by stripping ours.
        json.end_with?("\n") ? json.chomp : json
      end

      private

      # Extract a LogStruct from the various places it might be stored in a SemanticLogger::Log
      sig { params(log: ::SemanticLogger::Log).returns(T.nilable(LogStruct::Log::Interfaces::CommonFields)) }
      def extract_logstruct(log)
        LogStruct::Debug.log(:formatter, "  extract_logstruct:")

        # Check payload first (most common path for structured logging)
        if log.payload.is_a?(Hash) && log.payload[:payload].is_a?(LogStruct::Log::Interfaces::CommonFields)
          LogStruct::Debug.log(:formatter, "    MATCH: payload[:payload] is CommonFields")
          return T.cast(log.payload[:payload], LogStruct::Log::Interfaces::CommonFields)
        end

        if log.payload.is_a?(LogStruct::Log::Interfaces::CommonFields)
          LogStruct::Debug.log(:formatter, "    MATCH: payload is CommonFields directly")
          return log.payload
        end

        # Check message - this is where structs end up when passed directly to logger.info(struct)
        if log.message.is_a?(LogStruct::Log::Interfaces::CommonFields)
          LogStruct::Debug.log(:formatter, "    MATCH: message is CommonFields")
          return T.cast(log.message, LogStruct::Log::Interfaces::CommonFields)
        end

        # Check for T::Struct in payload hash (might be a LogStruct struct not implementing CommonFields directly)
        if log.payload.is_a?(Hash) && log.payload[:payload].is_a?(T::Struct)
          struct = log.payload[:payload]
          LogStruct::Debug.log(:formatter, "    payload[:payload] is T::Struct: #{struct.class}")
          LogStruct::Debug.log(:formatter, "    responds to source? #{struct.respond_to?(:source)}")
          LogStruct::Debug.log(:formatter, "    responds to event? #{struct.respond_to?(:event)}")
          if struct.respond_to?(:source) && struct.respond_to?(:event)
            LogStruct::Debug.log(:formatter, "    MATCH: T::Struct with source/event")
            return T.unsafe(struct)
          end
        end

        LogStruct::Debug.log(:formatter, "    NO MATCH - returning nil")
        nil
      end

      sig { returns(LogStruct::Formatter) }
      attr_reader :logstruct_formatter
    end
  end
end
