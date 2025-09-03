# typed: strict
# frozen_string_literal: true

require_relative "interfaces/common_fields"
require_relative "interfaces/additional_data_field"
require_relative "shared/serialize_common"
require_relative "shared/merge_additional_data_fields"

module LogStruct
  module Log
    # SQL Query Log Structure
    #
    # Captures detailed information about SQL queries executed through ActiveRecord.
    # This provides structured logging for database operations, including:
    # - Query text and operation name
    # - Execution timing and performance metrics
    # - Row counts and connection information
    # - Safely filtered bind parameters
    #
    # ## Use Cases:
    # - Development debugging of N+1 queries
    # - Production performance monitoring
    # - Database query analysis and optimization
    # - Audit trails for data access patterns
    #
    # ## Security:
    # - SQL queries are safe (always parameterized with ?)
    # - Bind parameters are filtered through LogStruct's param filters
    # - Sensitive data like passwords, tokens are automatically scrubbed
    #
    # ## Example Usage:
    #
    # ```ruby
    # # Automatically captured when SQL query integration is enabled
    # LogStruct.config.integrations.enable_sql_logging = true
    #
    # # Manual logging (rare)
    # sql_log = LogStruct::Log::SQL.new(
    #   message: "User lookup query",
    #   sql: "SELECT * FROM users WHERE id = ?",
    #   name: "User Load",
    #   duration: 2.3,
    #   row_count: 1,
    #   bind_params: [123]
    # )
    # LogStruct.info(sql_log)
    # ```
    class SQL < T::Struct
      extend T::Sig
      include Interfaces::CommonFields
      include Interfaces::AdditionalDataField
      include SerializeCommon
      include MergeAdditionalDataFields

      SQLEvent = T.type_alias {
        Event::Database
      }

      # Common fields
      const :source, Source, default: T.let(Source::App, Source)
      const :event, SQLEvent, default: T.let(Event::Database, SQLEvent)
      const :level, Level, default: T.let(Level::Info, Level)
      const :timestamp, Time, factory: -> { Time.now }
      const :message, String

      # The SQL query that was executed (parameterized, safe to log)
      const :sql, String

      # The name of the database operation (e.g., "User Load", "Post Create")
      const :name, String

      # Duration of the query execution in milliseconds
      const :duration, Float

      # Number of rows affected or returned by the query
      const :row_count, T.nilable(Integer)

      # Database connection information (adapter name)
      const :connection_adapter, T.nilable(String)

      # Filtered bind parameters (sensitive data removed)
      const :bind_params, T.nilable(T::Array[T.untyped])

      # Database name (if available)
      const :database_name, T.nilable(String)

      # Connection pool size information (for monitoring)
      const :connection_pool_size, T.nilable(Integer)

      # Active connection count (for monitoring)
      const :active_connections, T.nilable(Integer)

      # SQL operation type (SELECT, INSERT, UPDATE, DELETE, etc.)
      const :operation_type, T.nilable(String)

      # Table names involved in the query (extracted from SQL)
      const :table_names, T.nilable(T::Array[String])

      # Allow additional custom data
      const :additional_data, T::Hash[Symbol, T.untyped], default: {}

      # Convert the log entry to a hash for serialization
      sig { override.params(strict: T::Boolean).returns(T::Hash[Symbol, T.untyped]) }
      def serialize(strict = true)
        hash = serialize_common(strict)
        merge_additional_data_fields(hash)

        # Add SQL-specific fields
        hash[:message] = message
        hash[:sql] = sql
        hash[:name] = name
        hash[:duration] = duration
        hash[:row_count] = row_count
        hash[:connection_adapter] = connection_adapter
        hash[:bind_params] = bind_params
        hash[:database_name] = database_name
        hash[:connection_pool_size] = connection_pool_size
        hash[:active_connections] = active_connections
        hash[:operation_type] = operation_type
        hash[:table_names] = table_names

        hash
      end
    end
  end
end
