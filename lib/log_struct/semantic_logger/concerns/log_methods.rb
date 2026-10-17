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
        sig { params(message: T.untyped, payload: T.untyped, exception: T.untyped, block: T.nilable(T.proc.returns(String))).returns(T::Boolean) }
        def debug(message = nil, payload = nil, exception = nil, &block)
          result = super(*semantic_logger_args(message, payload, exception), &block)
          instrument_log(message, :debug)
          broadcast_message(:debug, message, block)
          result
        end

        sig { params(message: T.untyped, payload: T.untyped, exception: T.untyped, block: T.nilable(T.proc.returns(String))).returns(T::Boolean) }
        def info(message = nil, payload = nil, exception = nil, &block)
          result = super(*semantic_logger_args(message, payload, exception), &block)
          instrument_log(message, :info)
          broadcast_message(:info, message, block)
          result
        end

        sig { params(message: T.untyped, payload: T.untyped, exception: T.untyped, block: T.nilable(T.proc.returns(String))).returns(T::Boolean) }
        def warn(message = nil, payload = nil, exception = nil, &block)
          result = super(*semantic_logger_args(message, payload, exception), &block)
          instrument_log(message, :warn)
          broadcast_message(:warn, message, block)
          result
        end

        sig { params(message: T.untyped, payload: T.untyped, exception: T.untyped, block: T.nilable(T.proc.returns(String))).returns(T::Boolean) }
        def error(message = nil, payload = nil, exception = nil, &block)
          result = super(*semantic_logger_args(message, payload, exception), &block)
          instrument_log(message, :error)
          broadcast_message(:error, message, block)
          result
        end

        sig { params(message: T.untyped, payload: T.untyped, exception: T.untyped, block: T.nilable(T.proc.returns(String))).returns(T::Boolean) }
        def fatal(message = nil, payload = nil, exception = nil, &block)
          result = super(*semantic_logger_args(message, payload, exception), &block)
          instrument_log(message, :fatal)
          broadcast_message(:fatal, message, block)
          result
        end

        private

        # SemanticLogger's arguments for a line: a LogStruct entry or struct goes in the payload, and a Hash is the
        # payload itself, so its keys are written at the top level of the line. An exception can come second
        # (logger.error({id: 1}, error)) or third.
        sig { params(message: T.untyped, payload: T.untyped, exception: T.untyped).returns([T.untyped, T.untyped, T.untyped]) }
        def semantic_logger_args(message, payload, exception)
          if message.is_a?(LogStruct::Log::Interfaces::CommonFields) || message.is_a?(T::Struct)
            [nil, {payload: message}, nil]
          elsif message.is_a?(Hash)
            [nil, message, payload.is_a?(Exception) ? payload : exception]
          else
            [message, payload, exception]
          end
        end

        # Sends a LogStruct entry to the log.logstruct subscribers, after its line is written. A subscriber's error
        # doesn't stop the app's log call: it's handled like the app's other errors, and the lines written while
        # handling it aren't sent to the subscribers again.
        sig { params(message: T.untyped, level: Symbol).void }
        def instrument_log(message, level)
          return unless message.is_a?(LogStruct::Log::Interfaces::CommonFields) || message.is_a?(T::Struct)
          return if Thread.current[:logstruct_instrumenting_log]

          Thread.current[:logstruct_instrumenting_log] = true
          begin
            ::ActiveSupport::Notifications.instrument("log.logstruct", log: message, level: level)
          rescue => e
            LogStruct.handle_exception(e, source: Source::App, context: {notification: "log.logstruct"})
          ensure
            Thread.current[:logstruct_instrumenting_log] = false
          end
        end

        # Other loggers get String messages, and what blocks return, scrubbed like a log line's strings
        sig { params(level: Symbol, message: T.untyped, block: T.nilable(T.proc.returns(String))).void }
        def broadcast_message(level, message, block)
          broadcasts.each do |logger|
            next unless logger.respond_to?(level)

            if message.is_a?(String)
              logger.public_send(level, StringScrubber.scrub(message))
            elsif block
              logger.public_send(level) do
                # The block type says String, but nothing checks what a block returns
                text = T.let(block.call, T.untyped)
                text.is_a?(String) ? StringScrubber.scrub(text) : text
              end
            end
          end
        end
      end
    end
  end
end
