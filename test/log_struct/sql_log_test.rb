# typed: true
# frozen_string_literal: true

require "test_helper"

module LogStruct
  class SQLLogTest < ActiveSupport::TestCase
    test "serialize uses LOG_KEYS mapping for message and SQL fields" do
      log = LogStruct::Log::SQL.new(
        message: "User load",
        sql: "SELECT * FROM users WHERE id = ?",
        name: "User Load",
        duration_ms: 12.3,
        row_count: 1
      )

      data = log.serialize

      # Verify standardized keys are used
      assert data.key?(:msg), "expected :msg key for message"
      assert_equal "User load", data[:msg]
      assert data.key?(:sql), "expected :sql key"
      assert_equal "SELECT * FROM users WHERE id = ?", data[:sql]
      assert data.key?(:name), "expected :name key"
      assert_equal "User Load", data[:name]
      assert data.key?(:duration_ms), "expected :duration_ms key"
      assert_in_delta 12.3, data[:duration_ms]
      assert_equal 1, data[:row_count]
    end
  end
end
