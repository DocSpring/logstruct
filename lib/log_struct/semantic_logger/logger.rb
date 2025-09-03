# typed: strict
# frozen_string_literal: true

require "semantic_logger"

module LogStruct
  module SemanticLogger
    # Custom logger that wraps SemanticLogger while maintaining LogStruct API
    class Logger < ::SemanticLogger::Logger
      extend T::Sig

      sig { params(name: T.any(String, Symbol, Module, T::Class[T.anything]), level: T.nilable(Symbol), filter: T.untyped).void }
      def initialize(name = "Application", level: nil, filter: nil)
        # SemanticLogger::Logger expects positional arguments, not named arguments
        super(name, level, filter)
      end

      # Override log methods to handle LogStruct types
      %i[debug info warn error fatal].each do |level|
        define_method(level) do |message = nil, payload = nil, &block|
          # If message is a LogStruct type, use it as payload
          if message.is_a?(LogStruct::Log::Interfaces::CommonFields) ||
              message.is_a?(T::Struct) ||
              message.is_a?(Hash)
            payload = message
            message = nil
            super(message, payload: payload, &block)
          else
            # For plain string messages, pass them through normally
            super(message, payload, &block)
          end
        end
      end

      # Support for tagged logging
      sig { params(tags: T.untyped, block: T.proc.void).void }
      def tagged(*tags, &block)
        # Convert tags to array and pass individually to avoid splat issues
        tag_array = tags.flatten
        if tag_array.empty?
          super(&block)
        else
          super(T.unsafe(tag_array), &block)
        end
      end

      # Ensure compatibility with Rails.logger interface
      sig { returns(T::Array[T.any(String, Symbol)]) }
      def current_tags
        ::SemanticLogger.tags
      end

      sig { void }
      def clear_tags!
        # SemanticLogger doesn't have clear_tags!, use pop_tags instead
        count = ::SemanticLogger.tags.length
        ::SemanticLogger.pop_tags(count) if count > 0
      end

      sig { params(tags: T.untyped).void }
      def push_tags(*tags)
        tags.flatten.each { |tag| ::SemanticLogger.push_tags(tag) }
      end

      sig { params(count: Integer).void }
      def pop_tags(count = 1)
        ::SemanticLogger.pop_tags(count)
      end
    end
  end
end
