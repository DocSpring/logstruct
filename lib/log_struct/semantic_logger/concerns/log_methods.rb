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
          result = if message.is_a?(LogStruct::Log::Interfaces::CommonFields) || message.is_a?(T::Struct)
            super(nil, payload: message, &block)
          elsif message.is_a?(Hash)
            # As the payload itself, so its keys are written at the top level of the line
            super(nil, message, &block)
          else
            super
          end
          broadcast_message(:debug, message, block)
          result
        end

        sig { params(message: T.untyped, payload: T.untyped, block: T.nilable(T.proc.returns(String))).returns(T::Boolean) }
        def info(message = nil, payload = nil, &block)
          instrument_log(message, :info)
          result = if message.is_a?(LogStruct::Log::Interfaces::CommonFields) || message.is_a?(T::Struct)
            super(nil, payload: message, &block)
          elsif message.is_a?(Hash)
            # As the payload itself, so its keys are written at the top level of the line
            super(nil, message, &block)
          else
            super
          end
          broadcast_message(:info, message, block)
          result
        end

        sig { params(message: T.untyped, payload: T.untyped, block: T.nilable(T.proc.returns(String))).returns(T::Boolean) }
        def warn(message = nil, payload = nil, &block)
          instrument_log(message, :warn)
          result = if message.is_a?(LogStruct::Log::Interfaces::CommonFields) || message.is_a?(T::Struct)
            super(nil, payload: message, &block)
          elsif message.is_a?(Hash)
            # As the payload itself, so its keys are written at the top level of the line
            super(nil, message, &block)
          else
            super
          end
          broadcast_message(:warn, message, block)
          result
        end

        sig { params(message: T.untyped, payload: T.untyped, block: T.nilable(T.proc.returns(String))).returns(T::Boolean) }
        def error(message = nil, payload = nil, &block)
          instrument_log(message, :error)
          result = if message.is_a?(LogStruct::Log::Interfaces::CommonFields) || message.is_a?(T::Struct)
            super(nil, payload: message, &block)
          elsif message.is_a?(Hash)
            # As the payload itself, so its keys are written at the top level of the line
            super(nil, message, &block)
          else
            super
          end
          broadcast_message(:error, message, block)
          result
        end

        sig { params(message: T.untyped, payload: T.untyped, block: T.nilable(T.proc.returns(String))).returns(T::Boolean) }
        def fatal(message = nil, payload = nil, &block)
          instrument_log(message, :fatal)
          result = if message.is_a?(LogStruct::Log::Interfaces::CommonFields) || message.is_a?(T::Struct)
            super(nil, payload: message, &block)
          elsif message.is_a?(Hash)
            # As the payload itself, so its keys are written at the top level of the line
            super(nil, message, &block)
          else
            super
          end
          broadcast_message(:fatal, message, block)
          result
        end

        private

        # Instrument log events for subscribers
        sig { params(message: T.untyped, level: Symbol).void }
        def instrument_log(message, level)
          return unless message.is_a?(LogStruct::Log::Interfaces::CommonFields) || message.is_a?(T::Struct)

          ::ActiveSupport::Notifications.instrument("log.logstruct", log: message, level: level)
        end

        private

        # Other loggers get String messages, and the block to call for the rest
        sig { params(level: Symbol, message: T.untyped, block: T.nilable(T.proc.returns(String))).void }
        def broadcast_message(level, message, block)
          broadcasts.each do |logger|
            next unless logger.respond_to?(level)

            if message.is_a?(String)
              logger.public_send(level, message)
            elsif block
              logger.public_send(level, &block)
            end
          end
        end
      end
    end
  end
end
