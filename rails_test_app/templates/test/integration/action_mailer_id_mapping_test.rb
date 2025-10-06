# typed: true
# frozen_string_literal: true

require "test_helper"

class ActionMailerIdMappingTest < ActiveSupport::TestCase
  setup do
    @original_mapping = LogStruct.config.integrations.actionmailer_id_mapping

    # Use StringIO to capture log output
    @log_output = StringIO.new
    @original_logger = Rails.logger

    # Create a new logger with our StringIO and LogStruct's formatter
    logger = Logger.new(@log_output)
    logger.formatter = LogStruct::Formatter.new
    Rails.logger = logger
  end

  teardown do
    LogStruct.config.integrations.actionmailer_id_mapping = @original_mapping
    Rails.logger = @original_logger
  end

  # Helper method to parse log entries
  def find_log_entries(event_type)
    @log_output.rewind

    logs = []
    @log_output.each_line do |line|
      if line =~ /(\{.+\})/
        json = JSON.parse($1)
        logs << json if json["src"] == "mailer" && json["evt"] == event_type
      end
    rescue JSON::ParserError
      # Skip lines that don't contain valid JSON
    end

    logs
  end

  test "actionmailer_id_mapping extracts configured instance variables as IDs in additional_data" do
    # Clear the log buffer before the test
    @log_output.truncate(0)
    @log_output.rewind

    # Configure default ID mapping
    LogStruct.config.integrations.actionmailer_id_mapping = {
      account: :account_id,
      user: :user_id
    }

    # Create test objects
    account = Struct.new(:id).new(123)
    user = Struct.new(:id).new(456)

    # Deliver email
    TestMailer.test_email_with_ids(account, user).deliver_now

    # Find delivery logs in the captured output
    delivery_logs = find_log_entries("delivered")

    assert_not_empty delivery_logs, "Expected delivery logs to be generated"

    delivered_log = delivery_logs.first

    # Check that account_id and user_id are in the log
    assert_equal 123, delivered_log["account_id"]
    assert_equal 456, delivered_log["user_id"]
  end

  test "actionmailer_id_mapping uses custom field names" do
    # Clear the log buffer before the test
    @log_output.truncate(0)
    @log_output.rewind

    # Configure custom ID mapping
    LogStruct.config.integrations.actionmailer_id_mapping = {
      organization: :org_id
    }

    # Create test object
    organization = Struct.new(:id).new(789)

    # Deliver email
    TestMailer.test_email_with_organization(organization).deliver_now

    # Find delivery logs in the captured output
    delivery_logs = find_log_entries("delivered")

    assert_not_empty delivery_logs, "Expected delivery logs to be generated"

    delivered_log = delivery_logs.first

    # Check that org_id is in the log
    assert_equal 789, delivered_log["org_id"]
    # Should not have account_id or user_id
    assert_nil delivered_log["account_id"]
    assert_nil delivered_log["user_id"]
  end
end
