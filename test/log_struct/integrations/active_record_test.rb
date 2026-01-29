# typed: true
# frozen_string_literal: true

require "test_helper"
require "active_support/notifications"

module LogStruct
  module Integrations
    class ActiveRecordTest < ActiveSupport::TestCase
      setup do
        @original_config = LogStruct.config
        LogStruct.configuration = LogStruct::Configuration.new
        LogStruct.config.enabled = true
        LogStruct.config.integrations.enable_sql_logging = true

        # Clear any existing subscribers
        ActiveSupport::Notifications.notifier = ActiveSupport::Notifications::Fanout.new
      end

      teardown do
        LogStruct.configuration = @original_config
        # Reset notifications
        ActiveSupport::Notifications.notifier = ActiveSupport::Notifications::Fanout.new
      end

      test "responds to setup method" do
        assert_respond_to ActiveRecord, :setup
      end

      test "implements IntegrationInterface" do
        assert_includes ActiveRecord.singleton_class.included_modules, IntegrationInterface
      end

      test "returns early when SQL logging is disabled" do
        LogStruct.config.integrations.enable_sql_logging = false
        result = ActiveRecord.setup(LogStruct.config)

        assert_nil result
      end

      test "returns early when ActiveRecord is not defined" do
        # Mock ActiveRecord as not being defined
        original_ar = defined?(::ActiveRecord) ? ::ActiveRecord : nil
        Object.send(:remove_const, :ActiveRecord) if Object.const_defined?(:ActiveRecord)

        result = ActiveRecord.setup(LogStruct.config)

        assert_nil result
      ensure
        Object.const_set(:ActiveRecord, original_ar) if original_ar
      end

      test "subscribes to sql.active_record notifications when properly configured" do
        # First create the ActiveRecord module if it doesn't exist
        unless defined?(::ActiveRecord)
          Object.const_set(:ActiveRecord, Module.new)
        end

        # Then set ActiveRecord::Base
        unless defined?(::ActiveRecord::Base)
          ::ActiveRecord.const_set(:Base, Class.new)
        end

        begin
          result = ActiveRecord.setup(LogStruct.config)

          assert result

          # Verify subscription exists
          subscribers = ActiveSupport::Notifications.notifier.listeners_for("sql.active_record")

          assert_equal 1, subscribers.size
        ensure
          # Clean up
          if defined?(::ActiveRecord::Base)
            ::ActiveRecord.send(:remove_const, :Base)
          end
          # Clean up ActiveRecord if it has no more constants
          begin
            if defined?(::ActiveRecord) && defined?(::ActiveRecord::Base).nil?
              Object.send(:remove_const, :ActiveRecord)
            end
          rescue
            # Ignore errors during cleanup
          end
        end
      end

      test "skips schema queries" do
        stub_const("::ActiveRecord::Base", Class.new)
        ActiveRecord.setup(LogStruct.config)

        logged_events = []
        LogStruct.stub(:info, ->(log) { logged_events << log }) do
          # Trigger a schema query notification
          ActiveSupport::Notifications.instrument(
            "sql.active_record",
            name: "SCHEMA",
            sql: "SELECT * FROM schema_migrations"
          )
        end

        assert_empty logged_events
      end

      test "skips cache queries" do
        stub_const("::ActiveRecord::Base", Class.new)
        ActiveRecord.setup(LogStruct.config)

        logged_events = []
        LogStruct.stub(:info, ->(log) { logged_events << log }) do
          ActiveSupport::Notifications.instrument(
            "sql.active_record",
            name: "CACHE User Load",
            sql: "SELECT * FROM users WHERE id = ?"
          )
        end

        assert_empty logged_events
      end

      test "skips Rails internal queries" do
        stub_const("::ActiveRecord::Base", Class.new)
        ActiveRecord.setup(LogStruct.config)

        logged_events = []
        LogStruct.stub(:info, ->(log) { logged_events << log }) do
          # Schema migrations query
          ActiveSupport::Notifications.instrument(
            "sql.active_record",
            name: "SQL",
            sql: "SELECT * FROM schema_migrations"
          )

          # AR internal metadata query
          ActiveSupport::Notifications.instrument(
            "sql.active_record",
            name: "SQL",
            sql: "SELECT * FROM ar_internal_metadata"
          )
        end

        assert_empty logged_events
      end

      test "skips SHOW and DESCRIBE queries" do
        stub_const("::ActiveRecord::Base", Class.new)
        ActiveRecord.setup(LogStruct.config)

        logged_events = []
        LogStruct.stub(:info, ->(log) { logged_events << log }) do
          # SHOW query
          ActiveSupport::Notifications.instrument(
            "sql.active_record",
            name: "SQL",
            sql: "SHOW TABLES"
          )

          # DESCRIBE query
          ActiveSupport::Notifications.instrument(
            "sql.active_record",
            name: "SQL",
            sql: "DESCRIBE users"
          )

          # EXPLAIN query
          ActiveSupport::Notifications.instrument(
            "sql.active_record",
            name: "SQL",
            sql: "EXPLAIN SELECT * FROM users"
          )
        end

        assert_empty logged_events
      end

      test "logs valid SQL queries with complete payload" do
        setup_activerecord_for_test

        # Mock connection
        connection = mock_connection

        logged_events = []
        LogStruct.stub(:info, ->(log) { logged_events << log }) do
          Time.now # 50ms

          ActiveSupport::Notifications.instrument(
            "sql.active_record",
            name: "User Load",
            sql: "SELECT * FROM users WHERE id = ?",
            binds: [123],
            type_casted_binds: [123],
            row_count: 1,
            connection: connection
          ) do
            # Simulate query execution time
            sleep(0.01)
          end
        end

        assert_equal 1, logged_events.size
        log = T.let(logged_events.first, T.nilable(LogStruct::Log::SQL))

        assert_not_nil log

        assert_instance_of LogStruct::Log::SQL, log
        assert_equal "User Load executed", T.must(log).message
        assert_equal LogStruct::Source::App, T.must(log).source
        assert_equal LogStruct::Event::Database, T.must(log).event
        assert_equal "SELECT * FROM users WHERE id = ?", T.must(log).sql
        assert_equal "User Load", T.must(log).name
        assert_operator T.must(log).duration_ms, :>, 0.0
        assert_equal 1, T.must(log).row_count
        assert_equal "MockAdapter", T.must(log).adapter
        assert_equal [123], T.must(log).bind_params
        assert_equal "test_db", T.must(log).database_name
        assert_equal 5, T.must(log).connection_pool_size
        assert_equal 2, T.must(log).active_connections
        assert_equal "SELECT", T.must(log).operation_type
        assert_equal ["users"], T.must(log).table_names
      end

      test "respects slow query threshold" do
        stub_const("::ActiveRecord::Base", Class.new)
        LogStruct.config.integrations.sql_slow_query_threshold = 100.0
        ActiveRecord.setup(LogStruct.config)

        logged_events = []
        LogStruct.stub(:info, ->(log) { logged_events << log }) do
          # Fast query - should be skipped
          simulate_sql_notification(duration: 0.05) # 50ms

          # Slow query - should be logged
          simulate_sql_notification(duration: 0.15) # 150ms
        end

        assert_equal 1, logged_events.size
        first_log = T.let(logged_events.first, T.nilable(LogStruct::Log::SQL))

        assert_not_nil first_log
        assert_operator T.must(first_log).duration_ms, :>=, 100.0
      end

      test "logs all queries when threshold is disabled" do
        stub_const("::ActiveRecord::Base", Class.new)
        LogStruct.config.integrations.sql_slow_query_threshold = 0.0
        ActiveRecord.setup(LogStruct.config)

        logged_events = []
        LogStruct.stub(:info, ->(log) { logged_events << log }) do
          simulate_sql_notification(duration: 0.001) # 1ms - very fast
          simulate_sql_notification(duration: 0.05)  # 50ms - medium
          simulate_sql_notification(duration: 0.15)  # 150ms - slow
        end

        assert_equal 3, logged_events.size
      end

      test "logs all queries when threshold is nil" do
        stub_const("::ActiveRecord::Base", Class.new)
        LogStruct.config.integrations.sql_slow_query_threshold = nil
        ActiveRecord.setup(LogStruct.config)

        logged_events = []
        LogStruct.stub(:info, ->(log) { logged_events << log }) do
          simulate_sql_notification(duration: 0.001) # 1ms - very fast
          simulate_sql_notification(duration: 0.05)  # 50ms - medium
        end

        assert_equal 2, logged_events.size
      end

      test "handles bind parameter filtering when enabled" do
        LogStruct.config.integrations.sql_log_bind_params = true
        setup_activerecord_for_test

        logged_events = []
        LogStruct.stub(:info, ->(log) { logged_events << log }) do
          simulate_sql_notification(
            binds: ["secret_password", "user@example.com", 123],
            type_casted_binds: ["secret_password", "user@example.com", 123]
          )
        end

        assert_equal 1, logged_events.size
        log = T.let(logged_events.first, T.nilable(LogStruct::Log::SQL))

        assert_not_nil log

        # Check that sensitive data was filtered
        assert_includes T.must(log).bind_params, "[FILTERED]"
        assert_includes T.must(log).bind_params, "user@example.com"
        assert_includes T.must(log).bind_params, 123
      end

      test "filters JWT tokens in bind parameters" do
        LogStruct.config.integrations.sql_log_bind_params = true
        setup_activerecord_for_test

        # Real-looking JWT token (header.payload.signature format, starts with "ey")
        # cspell:disable-next-line
        jwt_token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"

        logged_events = []
        LogStruct.stub(:info, ->(log) { logged_events << log }) do
          simulate_sql_notification(
            binds: [jwt_token, "normal_value"],
            type_casted_binds: [jwt_token, "normal_value"]
          )
        end

        assert_equal 1, logged_events.size
        log = T.let(logged_events.first, T.nilable(LogStruct::Log::SQL))

        assert_not_nil log

        # JWT token should be filtered
        assert_includes T.must(log).bind_params, "[FILTERED]"
        # Normal value should pass through
        assert_includes T.must(log).bind_params, "normal_value"
      end

      test "filters Bearer tokens in bind parameters" do
        LogStruct.config.integrations.sql_log_bind_params = true
        setup_activerecord_for_test

        bearer_token = "Bearer abc123def456"

        logged_events = []
        LogStruct.stub(:info, ->(log) { logged_events << log }) do
          simulate_sql_notification(
            binds: [bearer_token, "safe_value"],
            type_casted_binds: [bearer_token, "safe_value"]
          )
        end

        assert_equal 1, logged_events.size
        log = T.let(logged_events.first, T.nilable(LogStruct::Log::SQL))

        assert_not_nil log

        # Bearer token should be filtered
        assert_includes T.must(log).bind_params, "[FILTERED]"
        # Safe value should pass through
        assert_includes T.must(log).bind_params, "safe_value"
      end

      test "excludes bind parameters when disabled" do
        LogStruct.config.integrations.sql_log_bind_params = false
        setup_activerecord_for_test

        logged_events = []
        LogStruct.stub(:info, ->(log) { logged_events << log }) do
          simulate_sql_notification(
            binds: ["secret_password", "user@example.com"],
            type_casted_binds: ["secret_password", "user@example.com"]
          )
        end

        assert_equal 1, logged_events.size
        log = T.let(logged_events.first, T.nilable(LogStruct::Log::SQL))

        assert_not_nil log

        assert_nil T.must(log).bind_params
      end

      test "extracts operation types correctly" do
        setup_activerecord_for_test

        test_cases = [
          {sql: "SELECT * FROM users", expected: "SELECT"},
          {sql: "INSERT INTO users (name) VALUES (?)", expected: "INSERT"},
          {sql: "UPDATE users SET name = ?", expected: "UPDATE"},
          {sql: "DELETE FROM users WHERE id = ?", expected: "DELETE"},
          {sql: "  select * from posts", expected: "SELECT"},
          {sql: "CREATE TABLE test (id INT)", expected: "CREATE"}
        ]

        assert_sql_attribute(test_cases, :operation_type)
      end

      test "extracts table names correctly" do
        setup_activerecord_for_test

        test_cases = [
          {sql: "SELECT * FROM users", expected: ["users"]},
          {sql: "INSERT INTO posts (title) VALUES (?)", expected: ["posts"]},
          {sql: "UPDATE comments SET body = ?", expected: ["comments"]},
          {sql: "DELETE FROM sessions WHERE id = ?", expected: ["sessions"]},
          {sql: "SELECT u.*, p.* FROM users u JOIN posts p ON u.id = p.user_id",
           expected: ["users", "posts"]},
          {sql: "SELECT * FROM `quoted_table`", expected: ["quoted_table"]},
          {sql: "UPDATE table1 SET col = (SELECT col FROM table2)", expected: ["table1", "table2"]}
        ]

        assert_sql_attribute(test_cases, :table_names)
      end

      test "handles exceptions gracefully during event processing" do
        setup_activerecord_for_test

        exceptions_logged = []

        # Stub Log::SQL.new to raise an error to test exception handling
        LogStruct::Log::SQL.method(:new)
        LogStruct::Log::SQL.stub(:new, ->(*args, **kwargs) { raise "Test error" }) do
          LogStruct.stub(:handle_exception, ->(exc, source:) { exceptions_logged << [exc, source] }) do
            # Trigger a normal notification that will try to create a Log::SQL and fail
            ActiveSupport::Notifications.instrument("sql.active_record",
              {
                sql: "SELECT 1",
                name: "Test"
              }) do
              # This should not raise an exception due to rescue in subscribe_to_sql_notifications
            end
          end
        end

        assert_equal 1, exceptions_logged.size
        first_exception = T.let(exceptions_logged.first, T.nilable(T::Array[T.untyped]))

        assert_not_nil first_exception
        assert_equal LogStruct::Source::Internal, T.must(first_exception)[1]
      end

      test "integration is included in automatic setup" do
        # Check that ActiveRecord is required in integrations.rb
        integrations_file = File.read(
          File.join(__dir__, "../../../lib/log_struct/integrations.rb")
        )

        assert_includes integrations_file, 'require_relative "integrations/active_record"'

        # Check that setup is called conditionally
        assert_includes integrations_file,
          "Integrations::ActiveRecord.setup(config) if config.integrations.enable_sql_logging"
      end

      test "configuration options exist with correct defaults" do
        config = LogStruct::Configuration.new

        assert_respond_to config.integrations, :enable_sql_logging
        refute config.integrations.enable_sql_logging

        assert_respond_to config.integrations, :sql_slow_query_threshold
        assert_in_delta(100.0, config.integrations.sql_slow_query_threshold)

        assert_respond_to config.integrations, :sql_log_bind_params
        # Should default to true in test environment (non-production)
        assert config.integrations.sql_log_bind_params
      end

      private

      def setup_activerecord_for_test
        # Create ActiveRecord::Base for this test
        unless defined?(::ActiveRecord)
          Object.const_set(:ActiveRecord, Module.new)
        end
        unless defined?(::ActiveRecord::Base)
          ::ActiveRecord.const_set(:Base, Class.new)
        end

        # Disable slow query threshold for tests
        LogStruct.config.integrations.sql_slow_query_threshold = 0.0
        ActiveRecord.setup(LogStruct.config)
      end

      def mock_connection
        connection = Minitest::Mock.new
        connection.expect(:class, mock_connection_class)
        connection.expect(:current_database, "test_db")

        pool = mock_pool
        connection.expect(:pool, pool)
        connection.expect(:pool, pool) # Called twice

        connection
      end

      def mock_connection_class
        klass = Minitest::Mock.new
        klass.expect(:name, "Connection::MockAdapter")
        klass
      end

      def mock_pool
        pool = Minitest::Mock.new
        pool.expect(:size, 5)

        stat = {busy: 2}
        pool.expect(:stat, stat)

        pool
      end

      def simulate_sql_notification(
        name: "User Load",
        sql: "SELECT * FROM users WHERE id = ?",
        duration: 0.05,
        binds: nil,
        type_casted_binds: nil,
        row_count: nil,
        connection: nil
      )
        start_time = Time.now
        end_time = start_time + duration

        payload = {
          name: name,
          sql: sql
        }

        payload[:binds] = binds if binds
        payload[:type_casted_binds] = type_casted_binds if type_casted_binds
        payload[:row_count] = row_count if row_count
        payload[:connection] = connection || mock_connection

        # Simulate the timing by directly calling the handler
        ActiveRecord.send(:handle_sql_event, "sql.active_record", start_time, end_time, "unique_id", payload)
      end

      def stub_const(name, value)
        # Simple constant stubbing for test isolation
        # This method only supports ::ActiveRecord::Base for now
        case name
        when "::ActiveRecord::Base"
          had_active_record = Object.const_defined?(:ActiveRecord)
          unless had_active_record
            Object.const_set(:ActiveRecord, Module.new)
          end

          had_const = ::ActiveRecord.const_defined?(:Base, false)
          original = had_const ? ::ActiveRecord::Base : nil

          if had_const
            ::ActiveRecord.send(:remove_const, :Base)
          end
          ::ActiveRecord.const_set(:Base, value)

          return original unless block_given?

          begin
            yield
          ensure
            if ::ActiveRecord.const_defined?(:Base, false)
              ::ActiveRecord.send(:remove_const, :Base)
            end

            if had_const && original
              ::ActiveRecord.const_set(:Base, original)
            end

            unless had_active_record
              Object.send(:remove_const, :ActiveRecord)
            end
          end
        else
          raise ArgumentError, "stub_const only supports ::ActiveRecord::Base"
        end
      end

      private

      def assert_sql_attribute(test_cases, attribute)
        logged_events = []
        LogStruct.stub(:info, ->(log) { logged_events << log }) do
          test_cases.each do |test_case|
            simulate_sql_notification(sql: test_case[:sql])
          end
        end

        assert_equal test_cases.size, logged_events.size

        test_cases.each_with_index do |test_case, index|
          assert_equal test_case[:expected], logged_events[index].public_send(attribute)
        end
      end
    end
  end
end
