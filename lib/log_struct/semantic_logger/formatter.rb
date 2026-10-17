# typed: strict
# frozen_string_literal: true

require "semantic_logger"
require_relative "../formatter"
require_relative "../params_errors"

module LogStruct
  module SemanticLogger
    # Writes each SemanticLogger line as LogStruct's JSON: LogStruct entries, Hashes, messages and exceptions, with
    # SemanticLogger's tags and named tags (the request ID and the running Sidekiq job's context among them). LogStruct::Formatter
    # filters and scrubs every value, within the size limits in config.limits.
    class Formatter < ::SemanticLogger::Formatters::Json
      extend T::Sig

      sig { void }
      def initialize
        super
        @logstruct_formatter = T.let(LogStruct::Formatter.new, LogStruct::Formatter)
      end

      sig { params(log: ::SemanticLogger::Log, logger: T.untyped).returns(String) }
      def call(log, logger)
        # Extract LogStruct from various locations where it might be stored
        logstruct = extract_logstruct(log)

        # The request ID, the running Sidekiq job's context and the other named tags (logger.tagged(user_id: 1))
        # go in req_id and ctx, and tags (logger.tagged("billing"), config.log_tags, ActiveJob's) in tags
        named_tags = log.named_tags
        request_id = named_tags[:request_id]
        job_context = named_tags[:sidekiq_context]
        context = named_tags.except(:request_id, :sidekiq_context)
        context = context.merge(job_context) if job_context.is_a?(Hash)
        metadata = {
          request_id: request_id.is_a?(String) ? request_id : nil,
          context: context.empty? ? nil : context,
          tags: log.tags.empty? ? nil : log.tags
        }

        json = if logstruct
          # Use our formatter to process LogStruct types directly
          @logstruct_formatter.call(log.level, log.time, log.name, logstruct, **metadata)
        elsif log.exception
          @logstruct_formatter.call(log.level, log.time, log.name, exception_log(log), **metadata)
        elsif log.payload.is_a?(Hash)
          # Process hashes through our formatter
          payload = with_message(without_reserved_keys(log.payload), log.message)
          @logstruct_formatter.call(log.level, log.time, log.name, payload, **metadata)
        elsif log.payload.is_a?(T::Struct)
          @logstruct_formatter.call(log.level, log.time, log.name, log.payload, **metadata)
        else
          # For plain messages, create a Plain log entry
          message_data = log.payload || log.message
          plain_log = ::LogStruct::Log::Plain.new(
            message: message_data,
            timestamp: log.time
          )
          @logstruct_formatter.call(log.level, log.time, log.name, plain_log, **metadata)
        end

        # SemanticLogger appenders typically add their own newline. Avoid double newlines by stripping ours.
        json.end_with?("\n") ? json.chomp : json
      end

      private

      # logger.error(exception) and logger.error("Message", exception): an error line with the
      # exception's class, message and backtrace. A logged message goes in msg, and the exception's
      # message in error_message. A Hash logged with them adds its keys to the line.
      sig { params(log: ::SemanticLogger::Log).returns(LogStruct::Log::Error) }
      def exception_log(log)
        exception = T.let(log.exception, Exception)
        message = log.message
        logged_message = (message.is_a?(String) && !message.empty?) ? message : nil
        payload = log.payload
        # Without the input a params parser quoted
        exception_message = ParamsErrors.messages(exception).first
        LogStruct::Log::Error.new(
          source: Source::App,
          error_class: exception.class,
          message: logged_message || exception_message,
          error_message: logged_message ? exception_message : nil,
          backtrace: exception.backtrace,
          additional_data: payload.is_a?(Hash) ? without_reserved_keys(payload) : nil,
          timestamp: log.time
        )
      end

      # A message logged beside a Hash (logger.info("Saved", id: 1)) goes in msg, unless the Hash
      # has its own
      sig { params(payload: T::Hash[T.untyped, T.untyped], message: T.untyped).returns(T::Hash[T.untyped, T.untyped]) }
      def with_message(payload, message)
        return payload unless message.is_a?(String) && !message.empty?
        return payload if payload.key?(:msg) || payload.key?("msg")

        {msg: message}.merge(payload)
      end

      # A logged Hash may set its own src and evt, but the line's timestamp and level come from the logger
      HASH_RESERVED_KEYS = T.let(%w[ts lvl].freeze, T::Array[String])

      sig { params(hash: T::Hash[T.untyped, T.untyped]).returns(T::Hash[T.untyped, T.untyped]) }
      def without_reserved_keys(hash)
        reserved = hash.keys.select { |key| HASH_RESERVED_KEYS.include?(key.to_s) }
        return hash if reserved.empty?

        # A copy, since other appenders format the same Hash
        copy = hash.dup
        reserved.each do |key|
          LogStruct.handle_exception(
            ArgumentError.new("A logged Hash attempted to set reserved key: #{key}"),
            source: Source::Internal
          )
          copy.delete(key)
        end
        copy
      end

      # Extract a LogStruct from the various places it might be stored in a SemanticLogger::Log
      sig do
        params(log: ::SemanticLogger::Log).returns(
          T.nilable(
            T.any(
              LogStruct::Log::Interfaces::CommonFields,
              LogStruct::Log::Interfaces::PublicCommonFields,
              T::Struct
            )
          )
        )
      end
      def extract_logstruct(log)
        # Check payload first (most common path for structured logging)
        if log.payload.is_a?(Hash) && log.payload[:payload].is_a?(LogStruct::Log::Interfaces::CommonFields)
          return T.cast(log.payload[:payload], LogStruct::Log::Interfaces::CommonFields)
        end

        if log.payload.is_a?(LogStruct::Log::Interfaces::CommonFields)
          return log.payload
        end

        if log.payload.is_a?(LogStruct::Log::Interfaces::PublicCommonFields)
          return log.payload
        end

        # Check message - this is where structs end up when passed directly to logger.info(struct)
        if log.message.is_a?(LogStruct::Log::Interfaces::CommonFields)
          return T.cast(log.message, LogStruct::Log::Interfaces::CommonFields)
        end

        # Check for T::Struct in payload hash (might be a LogStruct struct not implementing CommonFields directly)
        if log.payload.is_a?(Hash) && log.payload[:payload].is_a?(T::Struct)
          struct = log.payload[:payload]
          if struct.respond_to?(:source) && struct.respond_to?(:event)
            return struct
          end
        end

        nil
      end

      sig { returns(LogStruct::Formatter) }
      attr_reader :logstruct_formatter
    end
  end
end
