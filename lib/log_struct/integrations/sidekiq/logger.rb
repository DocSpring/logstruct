# typed: true
# frozen_string_literal: true

module LogStruct
  module Integrations
    module Sidekiq
      # Formatter for Sidekiq logs that outputs structured JSON
      class Formatter < ::Sidekiq::Logger::Formatters::Base
        def call(severity, time, _program_name, message)
          log = Log::Sidekiq.new(
            process_id: ::Process.pid,
            thread_id: tid,
            level: severity,
            message: message,
            context: ::Sidekiq::Context.current || {}
          )
          # Return the hash to be processed by the JSON formatter
          ::Sidekiq.dump_json(hash) << "\n"
        end
      end
    end
  end
end

class Logger < ::Logger
  module Formatters
    COLORS = {
      "DEBUG" => "\e[1;32mDEBUG\e[0m", # green
      "INFO" => "\e[1;34mINFO \e[0m", # blue
      "WARN" => "\e[1;33mWARN \e[0m", # yellow
      "ERROR" => "\e[1;31mERROR\e[0m", # red
      "FATAL" => "\e[1;35mFATAL\e[0m" # pink
    }
    class Base < ::Logger::Formatter
      def tid
        Thread.current["sidekiq_tid"] ||= (Thread.current.object_id ^ ::Process.pid).to_s(36)
      end

      def format_context(ctxt = Sidekiq::Context.current)
        (ctxt.size == 0) ? "" : " #{ctxt.map { |k, v|
          case v
          when Array
            "#{k}=#{v.join(",")}"
          else
            "#{k}=#{v}"
          end
        }.join(" ")}"
      end
    end
    x

    class JSON < Base
      def call(severity, time, program_name, message)
        hash = {
          ts: time.utc.iso8601(3),
          pid: ::Process.pid,
          tid: tid,
          lvl: severity,
          msg: message
        }
        c = Sidekiq::Context.current
        hash["ctx"] = c unless c.empty?

        Sidekiq.dump_json(hash) << "\n"
      end
    end
  end
end
