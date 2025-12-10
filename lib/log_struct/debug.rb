# typed: false
# frozen_string_literal: true

module LogStruct
  # Internal debug logging for LogStruct itself.
  #
  # LogStruct cannot use itself for internal debugging (circular dependency),
  # so this module provides a simple, direct logging mechanism that bypasses
  # both LogStruct and SemanticLogger entirely.
  #
  # IMPORTANT: This module must have NO external dependencies (including sorbet-runtime)
  # because it's loaded before any other LogStruct files.
  #
  # ## Environment Variables
  #
  # - `LOGSTRUCT_DEBUG=true` - Enable debug logging (all topics)
  # - `LOGSTRUCT_DEBUG_TOPICS=formatter,puma` - Only log specific topics
  # - `LOGSTRUCT_LOG_FILE=/tmp/logstruct.log` - Also write to a file
  #
  # ## Available Topics
  #
  # - `:formatter` - SemanticLogger formatter processing
  # - `:lograge` - Lograge integration and request formatting
  # - `:puma` - Puma lifecycle events and patching
  # - `:log_methods` - LogMethods module routing
  # - `:setup` - SemanticLogger setup and appender configuration
  # - `:railtie` - Rails integration initialization
  # - `:active_job` - ActiveJob integration
  # - `:active_storage` - ActiveStorage integration
  # - `:sql` - SQL query logging
  #
  # ## Usage
  #
  #   LogStruct::Debug.log(:formatter, "Processing payload")
  #   LogStruct::Debug.log(:puma, "emit_shutdown! called, pid=#{Process.pid}")
  #
  module Debug
    TOPICS = %i[
      formatter
      lograge
      puma
      log_methods
      setup
      railtie
      active_job
      active_storage
      shrine
      sql
    ].freeze

    @enabled = false
    @topics = nil
    @file = nil
    @mutex = Mutex.new
    @initialized = false

    class << self
      def initialize!
        @mutex.synchronize do
          return if @initialized

          @enabled = ENV["LOGSTRUCT_DEBUG"] == "true"

          if @enabled && ENV["LOGSTRUCT_DEBUG_TOPICS"].to_s.strip != ""
            @topics = ENV["LOGSTRUCT_DEBUG_TOPICS"]
              .to_s
              .split(",")
              .map { |t| t.strip.downcase.to_sym }
              .select { |t| TOPICS.include?(t) }
          end

          if @enabled && ENV["LOGSTRUCT_LOG_FILE"].to_s.strip != ""
            begin
              @file = File.open(ENV.fetch("LOGSTRUCT_LOG_FILE"), "a")
              @file.sync = true
            rescue => e
              warn "[LOGSTRUCT_DEBUG] Failed to open log file: #{e.message}"
            end
          end

          @initialized = true

          if @enabled
            # Write directly here since we already hold the mutex
            write_log(:setup, "Debug logging enabled")
            write_log(:setup, "Topics: #{@topics&.join(", ") || "all"}")
            write_log(:setup, "Log file: #{ENV["LOGSTRUCT_LOG_FILE"] || "none"}")
          end
        end
      end

      def log(topic, message)
        initialize! unless @initialized
        return unless topic_enabled?(topic)

        @mutex.synchronize do
          write_log(topic, message)
        end
      end

      def topic_enabled?(topic)
        return false unless @enabled
        return true if @topics.nil? || @topics.empty?

        @topics.include?(topic)
      end

      def enabled?
        initialize! unless @initialized
        @enabled
      end

      def reset!
        @mutex.synchronize do
          @file&.close
          @file = nil
          @enabled = false
          @topics = nil
          @initialized = false
        end
      end

      private

      def write_log(topic, message)
        timestamp = Time.now.strftime("%H:%M:%S.%L")
        line = "[#{timestamp}] [LOGSTRUCT_DEBUG] [#{topic}] #{message}"
        @file&.puts(line)
        warn(line)
      end
    end
  end
end
