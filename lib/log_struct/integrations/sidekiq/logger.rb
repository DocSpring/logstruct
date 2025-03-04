# typed: strict
# frozen_string_literal: true

require_relative "../../../logger"
require_relative "../../../log/sidekiq"
require_relative "../../../enums/source"

module LogStruct
  module Integrations
    module Sidekiq
      # Custom Logger for Sidekiq that formats logs using LogStruct::Log::Sidekiq
      class Logger < LogStruct::Logger
        extend T::Sig

        protected

        # Override process_log_data to create Sidekiq log structs
        sig { override.params(severity: T.any(String, Integer), message: T.untyped, progname: T.nilable(String)).returns(T.untyped) }
        def process_log_data(severity, message, progname)
          # Create a Sidekiq log struct with the message
          LogStruct::Log::Sidekiq.new(
            level: LogStruct::LogLevel.from_severity(severity),
            event: LogEvent::Log,
            message: (message || progname).to_s,
            process_id: ::Process.pid,
            thread_id: tid,
            context: ::Sidekiq::Context.current || {}
          )
        end

        private

        # Get thread ID
        sig { returns(String) }
        def tid
          Thread.current["sidekiq_tid"] ||= (Thread.current.object_id ^ ::Process.pid).to_s(36)
        end
      end
    end
  end
end
