# typed: true
# frozen_string_literal: true

require "test_helper"

module LogStruct
  module Log
    class SQLTest < ActiveSupport::TestCase
      test "includes required interfaces" do
        log = create_sql_log

        assert_includes log.class.included_modules, Interfaces::CommonFields
        assert_includes log.class.included_modules, Interfaces::AdditionalDataField
        assert_includes log.class.included_modules, Shared::SerializeCommon
        assert_includes log.class.included_modules, Shared::MergeAdditionalDataFields
      end

      test "creates log with required fields" do
        log = create_sql_log(
          sql: "SELECT * FROM users WHERE id = ?",
          name: "User Load",
          duration_ms: 2500.0
        )

        assert_equal "SELECT * FROM users WHERE id = ?", log.sql
        assert_equal "User Load", log.name
        assert_in_delta(2500.0, log.duration_ms)
        assert_equal LogStruct::Source::App, log.source
        assert_equal LogStruct::Event::Database, log.event
        assert_equal "SQL query executed", log.message
      end

      test "creates log with optional fields" do
        log = create_sql_log(
          row_count: 5,
          adapter: "PostgreSQLAdapter",
          bind_params: [123, "test@example.com"],
          database_name: "app_production",
          connection_pool_size: 10,
          active_connections: 3,
          operation_type: "SELECT",
          table_names: ["users", "posts"]
        )

        assert_equal 5, log.row_count
        assert_equal "PostgreSQLAdapter", log.adapter
        assert_equal [123, "test@example.com"], log.bind_params
        assert_equal "app_production", log.database_name
        assert_equal 10, log.connection_pool_size
        assert_equal 3, log.active_connections
        assert_equal "SELECT", log.operation_type
        assert_equal ["users", "posts"], log.table_names
      end

      test "allows nil for optional fields" do
        log = create_sql_log(
          row_count: nil,
          adapter: nil,
          bind_params: nil,
          database_name: nil,
          connection_pool_size: nil,
          active_connections: nil,
          operation_type: nil,
          table_names: nil
        )

        assert_nil log.row_count
        assert_nil log.adapter
        assert_nil log.bind_params
        assert_nil log.database_name
        assert_nil log.connection_pool_size
        assert_nil log.active_connections
        assert_nil log.operation_type
        assert_nil log.table_names
      end

      test "serializes to JSON with all fields" do
        log = create_sql_log(
          sql: "INSERT INTO users (email) VALUES (?)",
          name: "User Create",
          duration_ms: 5200.0,
          row_count: 1,
          adapter: "SQLiteAdapter",
          bind_params: ["user@example.com"],
          database_name: "app_development",
          connection_pool_size: 5,
          active_connections: 2,
          operation_type: "INSERT",
          table_names: ["users"]
        )

        json = JSON.parse(log.to_json)

        assert_equal "SQL query executed", json["msg"]
        assert_equal "app", json["src"]
        assert_equal "database", json["evt"]
        assert_kind_of String, json["ts"]

        assert_equal "INSERT INTO users (email) VALUES (?)", json["sql"]
        assert_equal "User Create", json["name"]
        assert_in_delta(5200.0, json["duration_ms"])
        assert_equal 1, json["row_count"]
        assert_equal "SQLiteAdapter", json["adapter"]
        assert_equal ["user@example.com"], json["bind_params"]
        assert_equal "app_development", json["db_name"]
        assert_equal 5, json["pool_size"]
        assert_equal 2, json["active_count"]
        assert_equal "INSERT", json["op_type"]
        assert_equal ["users"], json["table_names"]
      end

      test "serializes to JSON with minimal fields" do
        log = create_sql_log(
          sql: "SELECT 1",
          name: "Test Query",
          duration_ms: 100.0
        )

        json = JSON.parse(log.to_json)

        # Required fields
        assert_equal "SQL query executed", json["msg"]
        assert_equal "app", json["src"]
        assert_equal "database", json["evt"]
        assert_kind_of String, json["ts"]
        assert_equal "SELECT 1", json["sql"]
        assert_equal "Test Query", json["name"]
        assert_in_delta(100.0, json["duration_ms"])

        # Optional fields should be nil and excluded from JSON
        assert_nil json["row_count"]
        assert_nil json["connection_adapter"]
        assert_nil json["bind_params"]
        assert_nil json["database_name"]
        assert_nil json["connection_pool_size"]
        assert_nil json["active_connections"]
        assert_nil json["operation_type"]
        assert_nil json["table_names"]
      end

      test "supports additional_data field" do
        log = create_sql_log(
          additional_data: {
            custom_metric: "value",
            debug_info: {nested: true}
          }
        )

        # Check that additional_data is set correctly
        assert_equal 2, log.additional_data.keys.size
        assert log.additional_data.key?(:custom_metric)
        assert log.additional_data.key?(:debug_info)

        # Check serialization flattens additional data at top level
        serialized = log.serialize

        assert_equal "value", serialized[:custom_metric]
        assert_equal({nested: true}, serialized[:debug_info])

        # Check JSON serialization also flattens additional data at top level
        json = JSON.parse(log.to_json)

        assert_equal "value", json["custom_metric"]
        assert_equal({"nested" => true}, json["debug_info"])
      end

      test "handles complex bind parameters" do
        complex_params = [
          123,                    # Integer
          "string value",         # String
          true,                   # Boolean
          nil,                    # Nil
          Time.now,              # Time object
          {nested: "hash"},    # Hash
          ["array", "values"]    # Array
        ]

        log = create_sql_log(bind_params: complex_params)

        assert_equal complex_params, log.bind_params

        json = JSON.parse(log.to_json)

        assert_kind_of Array, json["bind_params"]
        assert_equal 7, json["bind_params"].size
      end

      test "immutable struct behavior" do
        log = create_sql_log(sql: "SELECT * FROM users")

        assert_equal "SELECT * FROM users", log.sql

        # Should not be able to modify the struct
        assert_raises(NoMethodError) do
          log.sql = "SELECT * FROM posts"
        end
      end

      test "equality and comparison" do
        # Use fixed timestamp to avoid timing differences
        fixed_time = Time.new(2023, 1, 1, 12, 0, 0, 0)

        log1 = create_sql_log(
          sql: "SELECT * FROM users",
          name: "User Load",
          duration_ms: 2500.0,
          timestamp: fixed_time
        )

        log3 = create_sql_log(
          sql: "SELECT * FROM posts",
          name: "Post Load",
          duration_ms: 1500.0,
          timestamp: fixed_time
        )

        # Test that different logs are not equal
        refute_equal log1, log3
        refute_equal log1.hash, log3.hash

        # Test that same data produces same serialized output
        assert_equal log1.serialize, log1.serialize
        refute_equal log1.serialize, log3.serialize
      end

      test "handles empty and edge case values" do
        log = create_sql_log(
          sql: "",                    # Empty SQL
          name: "",                   # Empty name
          duration_ms: 0.0,           # Zero duration
          row_count: 0,               # Zero rows
          bind_params: [],            # Empty array
          table_names: []             # Empty array
        )

        assert_equal "", log.sql
        assert_equal "", log.name
        assert_in_delta(0.0, log.duration_ms)
        assert_equal 0, log.row_count
        assert_empty log.bind_params
        assert_empty log.table_names
      end

      private

      def create_sql_log(**attributes)
        default_attributes = {
          sql: "SELECT * FROM test_table",
          name: "Test Query",
          duration_ms: 1000.0,
          message: "SQL query executed",
          row_count: nil,
          adapter: nil,
          bind_params: nil,
          database_name: nil,
          connection_pool_size: nil,
          active_connections: nil,
          operation_type: nil,
          table_names: nil,
          additional_data: {}
        }

        LogStruct::Log::SQL.new(**T.unsafe(default_attributes.merge(attributes)))
      end
    end
  end
end
