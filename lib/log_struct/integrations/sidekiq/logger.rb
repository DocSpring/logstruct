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

      # Custom Logger for Sidekiq that creates LogStruct::Log::Sidekiq entries
      class Logger < LogStruct::SemanticLogger::Logger
        extend T::Sig

        # Override log methods to create Sidekiq log structs
        %i[debug info warn error fatal].each do |level|
          define_method(level) do |message = nil, payload = nil, &block|
            # Create a Sidekiq log struct with the message
            log_struct = Log::Sidekiq.new(
              level: LogStruct::Level.from_severity(level.to_s.upcase),
              event: Event::Log,
              message: message || (block ? block.call : ""),
              process_id: ::Process.pid,
              thread_id: Sidekiq.tid,
              context: ::Sidekiq::Context.current || {}
            )

            # Pass the struct to SemanticLogger
            super(log_struct, payload, &nil)
          end
        end
      end
    end
  end
end
