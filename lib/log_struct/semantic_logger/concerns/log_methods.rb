# typed: strict
# frozen_string_literal: true

module LogStruct
  module SemanticLogger
    module Concerns
      module LogMethods
        extend T::Sig
        extend T::Helpers
        requires_ancestor { LogStruct::SemanticLogger::Logger }

        # Override log methods to handle LogStruct types and broadcast
        sig { params(message: T.untyped, payload: T.untyped, block: T.nilable(T.proc.returns(String))).returns(T::Boolean) }
        def debug(message = nil, payload = nil, &block)
          instrument_log(message, :debug)
          result = if message.is_a?(LogStruct::Log::Interfaces::CommonFields) || message.is_a?(T::Struct) || message.is_a?(Hash)
            super(nil, payload: message, &block)
          else
            super
          end
          broadcasts.each do |logger|
            next unless logger.respond_to?(:debug)
            message.is_a?(String) ? logger.debug(message) : (logger.debug(&block) if block)
          end
          result
        end

        sig { params(message: T.untyped, payload: T.untyped, block: T.nilable(T.proc.returns(String))).returns(T::Boolean) }
        def info(message = nil, payload = nil, &block)
          if ENV["LOGSTRUCT_DEBUG"] == "true"
            $stderr.puts "[LOGSTRUCT_DEBUG] [LogMethods] info() called"
            $stderr.puts "[LOGSTRUCT_DEBUG] [LogMethods]   message.class = #{message.class}"
            $stderr.puts "[LOGSTRUCT_DEBUG] [LogMethods]   message.is_a?(T::Struct) = #{message.is_a?(T::Struct)}"
          end
          instrument_log(message, :info)
          result = if message.is_a?(LogStruct::Log::Interfaces::CommonFields) || message.is_a?(T::Struct) || message.is_a?(Hash)
            if ENV["LOGSTRUCT_DEBUG"] == "true"
              $stderr.puts "[LOGSTRUCT_DEBUG] [LogMethods]   PATH: wrapping message in payload"
            end
            super(nil, payload: message, &block)
          else
            if ENV["LOGSTRUCT_DEBUG"] == "true"
              $stderr.puts "[LOGSTRUCT_DEBUG] [LogMethods]   PATH: passing through as-is"
            end
            super
          end
          if ENV["LOGSTRUCT_DEBUG"] == "true"
            $stderr.puts "[LOGSTRUCT_DEBUG] [LogMethods]   super returned: #{result.inspect}"
            $stderr.puts "[LOGSTRUCT_DEBUG] [LogMethods]   SemanticLogger.appenders:"
            ::SemanticLogger.appenders.each_with_index do |a, i|
              $stderr.puts "[LOGSTRUCT_DEBUG] [LogMethods]     [#{i}] #{a.class}(level=#{a.level}, formatter=#{a.formatter.class})"
            end
            $stderr.puts "[LOGSTRUCT_DEBUG] [LogMethods]   SemanticLogger.default_level: #{::SemanticLogger.default_level}"
          end
          broadcasts.each do |logger|
            next unless logger.respond_to?(:info)
            message.is_a?(String) ? logger.info(message) : (logger.info(&block) if block)
          end
          result
        end

        sig { params(message: T.untyped, payload: T.untyped, block: T.nilable(T.proc.returns(String))).returns(T::Boolean) }
        def warn(message = nil, payload = nil, &block)
          instrument_log(message, :warn)
          result = if message.is_a?(LogStruct::Log::Interfaces::CommonFields) || message.is_a?(T::Struct) || message.is_a?(Hash)
            super(nil, payload: message, &block)
          else
            super
          end
          broadcasts.each do |logger|
            next unless logger.respond_to?(:warn)
            message.is_a?(String) ? logger.warn(message) : (logger.warn(&block) if block)
          end
          result
        end

        sig { params(message: T.untyped, payload: T.untyped, block: T.nilable(T.proc.returns(String))).returns(T::Boolean) }
        def error(message = nil, payload = nil, &block)
          instrument_log(message, :error)
          result = if message.is_a?(LogStruct::Log::Interfaces::CommonFields) || message.is_a?(T::Struct) || message.is_a?(Hash)
            super(nil, payload: message, &block)
          else
            super
          end
          broadcasts.each do |logger|
            next unless logger.respond_to?(:error)
            message.is_a?(String) ? logger.error(message) : (logger.error(&block) if block)
          end
          result
        end

        sig { params(message: T.untyped, payload: T.untyped, block: T.nilable(T.proc.returns(String))).returns(T::Boolean) }
        def fatal(message = nil, payload = nil, &block)
          instrument_log(message, :fatal)
          result = if message.is_a?(LogStruct::Log::Interfaces::CommonFields) || message.is_a?(T::Struct) || message.is_a?(Hash)
            super(nil, payload: message, &block)
          else
            super
          end
          broadcasts.each do |logger|
            next unless logger.respond_to?(:fatal)
            message.is_a?(String) ? logger.fatal(message) : (logger.fatal(&block) if block)
          end
          result
        end

        private

        # Instrument log events for subscribers
        sig { params(message: T.untyped, level: Symbol).void }
        def instrument_log(message, level)
          return unless message.is_a?(LogStruct::Log::Interfaces::CommonFields) || message.is_a?(T::Struct)

          ::ActiveSupport::Notifications.instrument("log.logstruct", log: message, level: level)
        end
      end
    end
  end
end
