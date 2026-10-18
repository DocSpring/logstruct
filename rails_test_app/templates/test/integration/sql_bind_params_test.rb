# typed: true
# frozen_string_literal: true

require "test_helper"

class SqlBindParamsTest < ActiveSupport::TestCase
  setup do
    @saved_log_binds = LogStruct.config.integrations.sql_log_bind_params
    @saved_filter_keys = LogStruct.config.filters.filter_keys
    LogStruct.config.integrations.sql_log_bind_params = true
    LogStruct.config.filters.filter_keys += [:name]
  end

  teardown do
    LogStruct.config.integrations.sql_log_bind_params = @saved_log_binds
    LogStruct.config.filters.filter_keys = @saved_filter_keys
  end

  test "bind params from real queries are filtered by their column names" do
    captured = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*_args, payload|
      if payload[:sql].to_s.include?('"users"')
        captured << LogStruct::Integrations::ActiveRecord.extract_and_filter_binds(payload)
      end
    end

    User.where(name: "Ada Lovelace", email: "ada@example.com").to_a

    assert_equal [["[FILTERED]", "ada@example.com"]], captured
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end
end
