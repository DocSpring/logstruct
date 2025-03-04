# typed: true
# frozen_string_literal: true

module LogStruct
  module Integrations
    module Sidekiq
      # Formatter for Sidekiq logs that outputs structured JSON
      class Formatter < ::Sidekiq::Logger::Formatters::Base
        def call(severity, time, _program_name, message)
          log = Log::Sidekiq.new(
            src: "sidekiq",
            ts: time.utc.iso8601(3),
            pid: ::Process.pid,
            tid: tid,
            lvl: severity,
            msg: message
          )

          c = ::Sidekiq::Context.current
          hash[:ctx] = c unless c.empty?

          # Return the hash to be processed by the JSON formatter
          ::Sidekiq.dump_json(hash) << "\n"
        end
      end
    end
  end
end
