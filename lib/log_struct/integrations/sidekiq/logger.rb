# typed: strict
# frozen_string_literal: true

require_relative "../../semantic_logger/logger"
require_relative "../../log/sidekiq"
require_relative "../../enums/source"

module LogStruct
  module Integrations
    module Sidekiq
      extend T::Sig

      # Get thread ID for Sidekiq logging
      sig { returns(String) }
      def self.tid
        Thread.current["sidekiq_tid"] ||= (Thread.current.object_id ^ ::Process.pid).to_s(36)
      end

      # Custom Logger for Sidekiq that creates LogStruct::Log::Sidekiq::Log entries
      class Logger < LogStruct::SemanticLogger::Logger
        extend T::Sig

        # Override log methods to create Sidekiq log structs
        %i[debug info warn error fatal].each do |level|
          define_method(level) do |message = nil, payload = nil, &block|
            # Hashes, LogStruct log entries and exceptions are logged as they are, so their keys are
            # filtered (Sidekiq logs some settings as a Hash)
            unless message.nil? || message.is_a?(String)
              next super(message, payload, &block)
            end
            # A message with an exception is an error line with both
            next super(message, payload, &block) if payload.is_a?(Exception)

            msg = message || (block ? block.call.to_s : "")
            # Lines logged outside a job have no context
            context = ::Sidekiq::Context.current

            # Create a Sidekiq log struct with the message
            log_struct = Log::Sidekiq::Log.new(
              level: LogStruct::Level.from_severity(level.to_s.upcase),
              event: Event::Log,
              message: msg,
              process_id: ::Process.pid,
              thread_id: Sidekiq.tid,
              # Log a copy: SemanticLogger may still be serializing the struct on its appender
              # thread when Sidekiq adds :elapsed to the live context after the job finishes.
              context: context.blank? ? nil : context.dup,
              additional_data: payload.is_a?(Hash) ? payload : nil
            )

            # Pass the struct to SemanticLogger
            super(log_struct, nil, &nil)
          end
        end
      end
    end
  end
end
