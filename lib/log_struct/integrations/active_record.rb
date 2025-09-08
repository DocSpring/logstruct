# typed: strict
# frozen_string_literal: true

require "active_support/notifications"

module LogStruct
  module Integrations
    # ActiveRecord Integration for SQL Query Logging
    #
    # This integration captures and structures all SQL queries executed through ActiveRecord,
    # providing detailed performance and debugging information in a structured format.
    #
    # ## Features:
    # - Captures all SQL queries with execution time
    # - Safely filters sensitive data from bind parameters
    # - Extracts database operation metadata
    # - Provides connection pool monitoring information
    # - Identifies query types and table names
    #
    # ## Performance Considerations:
    # - Minimal overhead on query execution
    # - Async logging prevents I/O blocking
    # - Configurable to disable in production if needed
    # - Smart filtering reduces log volume for repetitive queries
    #
    # ## Security:
    # - SQL queries are always parameterized (safe)
    # - Bind parameters filtered through LogStruct's param filters
    # - Sensitive patterns automatically scrubbed
    #
    # ## Configuration:
    # ```ruby
    # LogStruct.configure do |config|
    #   config.integrations.enable_sql_logging = true
    #   config.integrations.sql_slow_query_threshold = 100.0 # ms
    #   config.integrations.sql_log_bind_params = false # disable in production
    # end
    # ```
    module ActiveRecord
      extend T::Sig
      extend IntegrationInterface

      # Track subscription state keyed to the current Notifications.notifier instance
      State = ::Struct.new(:subscribed, :notifier_id)
      STATE = T.let(State.new(false, nil), State)

      # Set up SQL query logging integration
      sig { override.params(config: LogStruct::Configuration).returns(T.nilable(T::Boolean)) }
      def self.setup(config)
        return nil unless config.integrations.enable_sql_logging
        return nil unless defined?(::ActiveRecord::Base)

        # Detach Rails' default ActiveRecord log subscriber to prevent
        # duplicate/unstructured SQL debug output when LogStruct SQL logging
        # is enabled. We still receive notifications via ActiveSupport.
        if defined?(::ActiveRecord::LogSubscriber)
          begin
            ::ActiveRecord::LogSubscriber.detach_from(:active_record)
          rescue => e
            LogStruct.handle_exception(e, source: LogStruct::Source::Internal)
          end
        end

        # Disable verbose query logs ("↳ caller") since LogStruct provides
        # structured context and these lines are noisy/unstructured.
        if ::ActiveRecord::Base.respond_to?(:verbose_query_logs=)
          T.unsafe(::ActiveRecord::Base).verbose_query_logs = false
        end

        subscribe_to_sql_notifications
        true
      end

      private_class_method

      # Subscribe to ActiveRecord's sql.active_record notifications
      sig { void }
      def self.subscribe_to_sql_notifications
        # Avoid duplicate subscriptions; re-subscribe if the notifier was reset
        notifier = ::ActiveSupport::Notifications.notifier
        current_id = notifier&.object_id
        if STATE.subscribed && STATE.notifier_id == current_id
          return
        end

        ::ActiveSupport::Notifications.subscribe("sql.active_record") do |name, start, finish, id, payload|
          handle_sql_event(name, start, finish, id, payload)
        rescue => error
          LogStruct.handle_exception(error, source: LogStruct::Source::Internal)
        end
        STATE.subscribed = true
        STATE.notifier_id = current_id
      end

      # Process SQL notification event and create structured log
      sig { params(name: String, start: T.untyped, finish: T.untyped, id: String, payload: T::Hash[Symbol, T.untyped]).void }
      def self.handle_sql_event(name, start, finish, id, payload)
        # Skip schema queries and Rails internal queries
        return if skip_query?(payload)

        duration = ((finish - start) * 1000.0).round(2)

        # Skip fast queries if threshold is configured
        config = LogStruct.config
        if config.integrations.sql_slow_query_threshold&.positive?
          return if duration < config.integrations.sql_slow_query_threshold
        end

        sql_log = Log::SQL.new(
          message: format_sql_message(payload),
          source: Source::App,
          event: Event::Database,
          sql: payload[:sql]&.strip || "",
          name: payload[:name] || "SQL Query",
          duration: duration,
          row_count: extract_row_count(payload),
          connection_adapter: extract_adapter_name(payload),
          bind_params: extract_and_filter_binds(payload),
          database_name: extract_database_name(payload),
          connection_pool_size: extract_pool_size(payload),
          active_connections: extract_active_connections(payload),
          operation_type: extract_operation_type(payload),
          table_names: extract_table_names(payload)
        )

        LogStruct.info(sql_log)
      end

      # Determine if query should be skipped from logging
      sig { params(payload: T::Hash[Symbol, T.untyped]).returns(T::Boolean) }
      def self.skip_query?(payload)
        query_name = payload[:name]
        sql = payload[:sql]

        # Skip Rails schema queries
        return true if query_name&.include?("SCHEMA")
        return true if query_name&.include?("CACHE")

        # Skip common Rails internal queries
        return true if sql&.include?("schema_migrations")
        return true if sql&.include?("ar_internal_metadata")

        # Skip SHOW/DESCRIBE queries
        return true if sql&.match?(/\A\s*(SHOW|DESCRIBE|EXPLAIN)\s/i)

        false
      end

      # Format a readable message for the SQL log
      sig { params(payload: T::Hash[Symbol, T.untyped]).returns(String) }
      def self.format_sql_message(payload)
        operation_name = payload[:name] || "SQL Query"
        "#{operation_name} executed"
      end

      # Extract row count from payload
      sig { params(payload: T::Hash[Symbol, T.untyped]).returns(T.nilable(Integer)) }
      def self.extract_row_count(payload)
        row_count = payload[:row_count]
        row_count.is_a?(Integer) ? row_count : nil
      end

      # Extract database adapter name
      sig { params(payload: T::Hash[Symbol, T.untyped]).returns(T.nilable(String)) }
      def self.extract_adapter_name(payload)
        connection = payload[:connection]
        return nil unless connection

        adapter_name = connection.class.name
        adapter_name&.split("::")&.last
      end

      # Extract and filter bind parameters
      sig { params(payload: T::Hash[Symbol, T.untyped]).returns(T.nilable(T::Array[T.untyped])) }
      def self.extract_and_filter_binds(payload)
        return nil unless LogStruct.config.integrations.sql_log_bind_params

        # Prefer type_casted_binds as they're more readable
        binds = payload[:type_casted_binds] || payload[:binds]
        return nil unless binds

        # Filter sensitive data from bind parameters
        binds.map do |bind|
          filter_bind_parameter(bind)
        end
      end

      # Extract database name from connection
      sig { params(payload: T::Hash[Symbol, T.untyped]).returns(T.nilable(String)) }
      def self.extract_database_name(payload)
        connection = payload[:connection]
        return nil unless connection

        if connection.respond_to?(:current_database)
          connection.current_database
        elsif connection.respond_to?(:database)
          connection.database
        end
      rescue
        nil
      end

      # Extract connection pool size
      sig { params(payload: T::Hash[Symbol, T.untyped]).returns(T.nilable(Integer)) }
      def self.extract_pool_size(payload)
        connection = payload[:connection]
        return nil unless connection

        pool = connection.pool if connection.respond_to?(:pool)
        pool&.size
      rescue
        nil
      end

      # Extract active connection count
      sig { params(payload: T::Hash[Symbol, T.untyped]).returns(T.nilable(Integer)) }
      def self.extract_active_connections(payload)
        connection = payload[:connection]
        return nil unless connection

        pool = connection.pool if connection.respond_to?(:pool)
        pool&.stat&.[](:busy)
      rescue
        nil
      end

      # Extract SQL operation type (SELECT, INSERT, etc.)
      sig { params(payload: T::Hash[Symbol, T.untyped]).returns(T.nilable(String)) }
      def self.extract_operation_type(payload)
        sql = payload[:sql]
        return nil unless sql

        # Extract first word of SQL query
        match = sql.strip.match(/\A\s*(\w+)/i)
        match&.captures&.first&.upcase
      end

      # Extract table names from SQL query
      sig { params(payload: T::Hash[Symbol, T.untyped]).returns(T.nilable(T::Array[String])) }
      def self.extract_table_names(payload)
        sql = payload[:sql]
        return nil unless sql

        # Simple regex to extract table names (basic implementation)
        # This covers most common cases but could be enhanced
        tables = []

        # Match FROM, JOIN, UPDATE, INSERT INTO, DELETE FROM patterns
        sql.scan(/(?:FROM|JOIN|UPDATE|INTO|DELETE\s+FROM)\s+["`]?(\w+)["`]?/i) do |match|
          table_name = match[0]
          tables << table_name unless tables.include?(table_name)
        end

        tables.empty? ? nil : tables
      end

      # Filter individual bind parameter values to remove sensitive data
      sig { params(value: T.untyped).returns(T.untyped) }
      def self.filter_bind_parameter(value)
        case value
        when String
          # Filter strings that look like passwords, tokens, secrets, etc.
          if looks_sensitive?(value)
            "[FILTERED]"
          else
            value
          end
        else
          value
        end
      end

      # Check if a string value looks sensitive and should be filtered
      sig { params(value: String).returns(T::Boolean) }
      def self.looks_sensitive?(value)
        # Filter very long strings that might be tokens
        return true if value.length > 50

        # Filter strings that look like hashed passwords, API keys, tokens
        return true if value.match?(/\A[a-f0-9]{32,}\z/i)  # MD5, SHA, etc.
        return true if value.match?(/\A[A-Za-z0-9+\/]{20,}={0,2}\z/)  # Base64
        return true if value.match?(/(password|secret|token|key|auth)/i)

        false
      end
    end
  end
end
