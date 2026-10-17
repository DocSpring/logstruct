# typed: strict
# frozen_string_literal: true

require "semantic_logger"
require_relative "concerns/log_methods"

module LogStruct
  module SemanticLogger
    # Rails.logger's replacement: a SemanticLogger logger that also takes LogStruct's typed entries and Hashes, and
    # passes each line on to the loggers added with broadcast_to.
    #
    # ```ruby
    # logger = LogStruct::SemanticLogger::Logger.new("MyApp")
    #
    # # A typed entry
    # logger.info(LogStruct::Log::Plain.new(message: "User authenticated", additional_data: {user_id: 123}))
    #
    # # A Hash: its keys are written at the top level of the line
    # logger.info(action: "user_login", user_id: 123)
    #
    # # A message, with a Hash or an exception beside it
    # logger.info("User logged in", user_id: 123)
    # logger.error("Import failed", error)
    # ```
    class Logger < ::SemanticLogger::Logger
      extend T::Sig

      sig { params(name: T.any(String, Symbol, Module, T::Class[T.anything]), level: T.nilable(Symbol), filter: T.untyped).void }
      def initialize(name = "Application", level: nil, filter: nil)
        # SemanticLogger::Logger expects positional arguments, not named arguments
        super(name, level, filter)
        # T.untyped because users can pass any logger: ::Logger, ActiveSupport::Logger,
        # custom loggers (FakeLogger in tests), or third-party loggers
        @broadcasts = T.let([], T::Array[T.untyped])
        # ActiveJob expects logger.formatter to exist and respond to current_tags
        @formatter = T.let(FormatterProxy.new, FormatterProxy)
      end

      # ActiveSupport::BroadcastLogger compatibility
      # These methods allow Rails.logger to broadcast to multiple loggers
      sig { returns(T::Array[T.untyped]) }
      attr_reader :broadcasts

      # ActiveJob compatibility - expects logger.formatter.current_tags
      sig { returns(FormatterProxy) }
      attr_reader :formatter

      # T.untyped for logger param because we accept any logger-like object:
      # ::Logger, ActiveSupport::Logger, test doubles, etc.
      sig { params(logger: T.untyped).returns(T.untyped) }
      def broadcast_to(logger)
        # Every SemanticLogger logger writes to the same appenders, so broadcasting to one
        # would write each message twice. Sidekiq's Rails integration broadcasts Rails.logger
        # to Sidekiq's logger, for example.
        @broadcasts << logger unless logger.is_a?(::SemanticLogger::Logger)
        logger
      end

      sig { params(logger: T.untyped).void }
      def stop_broadcasting_to(logger)
        @broadcasts.delete(logger)
      end

      include Concerns::LogMethods

      # Support for tagged logging
      sig { params(tags: T.untyped, block: T.proc.returns(T.untyped)).returns(T.untyped) }
      def tagged(*tags, &block)
        tag_array = tags.flatten
        if tag_array.empty?
          super(&block)
        else
          # Sorbet can't check a splat of an Array whose size it doesn't know
          super(*T.unsafe(tag_array), &block)
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

      sig { params(tags: T.untyped).returns(T::Array[T.untyped]) }
      def push_tags(*tags)
        flat = tags.flatten.compact
        flat.each { |tag| ::SemanticLogger.push_tags(tag) }
        flat
      end

      sig { params(count: Integer).void }
      def pop_tags(count = 1)
        ::SemanticLogger.pop_tags(count)
      end

      # Support for << operator (used by RailsLogSplitter)
      sig { params(msg: String).returns(T.self_type) }
      def <<(msg)
        info(msg)
        @broadcasts.each { |logger| logger << msg if logger.respond_to?(:<<) }
        self
      end
    end

    # Proxy object to provide ActiveJob-compatible formatter interface
    # Also implements the standard Logger formatter interface (call method)
    # for compatibility with Ruby's Logger (especially logger gem 1.7.0+)
    class FormatterProxy < ::Logger::Formatter
      extend T::Sig

      sig { returns(T::Array[T.any(String, Symbol)]) }
      def current_tags
        Thread.current[:activesupport_tagged_logging_tags] || []
      end
    end
  end
end
