# typed: true
# frozen_string_literal: true

require "test_helper"

class DotenvIntegrationTest < ActiveSupport::TestCase
  def setup
    # Define a minimal Dotenv constant so integration will set up
    unless Object.const_defined?(:Dotenv)
      Object.const_set(:Dotenv, Module.new)
    end
    dotenv_mod = Object.const_get(:Dotenv) # rubocop:disable Sorbet/ConstantsFromStrings
    unless dotenv_mod.const_defined?(:LogSubscriber)
      dotenv_mod.const_set(:LogSubscriber,
        Class.new do
          def self.detach_from(_event)
          end
        end)
    end

    # Capture logs with our formatter
    @original_logger = ::Rails.logger
    @buffer = StringIO.new
    logger = ::Logger.new(@buffer)
    logger.formatter = LogStruct::Formatter.new
    ::Rails.logger = logger

    # Ensure integration subscriptions are active
    LogStruct::Integrations::Dotenv.setup(LogStruct.config)
  end

  def teardown
    ::Rails.logger = @original_logger
    # Reset subscription state so each test can resubscribe
    LogStruct::Integrations::Dotenv::STATE.subscribed = false
  end

  test "logs load event with file path" do
    @buffer.truncate(0)
    @buffer.rewind

    env = OpenStruct.new(filename: Rails.root.join(".env.test").to_s)
    ActiveSupport::Notifications.instrument("load.dotenv", env: env) {}

    # Ensure all writes are flushed
    if ::Rails.logger.instance_variable_defined?(:@logdev)
      logdev = ::Rails.logger.instance_variable_get(:@logdev)
      logdev&.instance_variable_get(:@dev)&.flush
    end

    buffer_content = @buffer.string
    # Parse only the first line (subscription might be called multiple times)
    first_line = buffer_content.lines.first || ""
    json = JSON.parse(first_line)

    assert_equal "dotenv", json["src"]
    assert_equal "load", json["evt"]
    assert_equal ".env.test", json["file"]
    assert_equal "info", json["lvl"]
  end

  test "logs update and restore events with var names" do
    # Update
    @buffer.truncate(0)
    @buffer.rewind
    diff = OpenStruct.new(env: {"FOO" => "1", "BAR" => "2"})
    ActiveSupport::Notifications.instrument("update.dotenv", diff: diff) {}

    # Ensure all writes are flushed
    if ::Rails.logger.instance_variable_defined?(:@logdev)
      logdev = ::Rails.logger.instance_variable_get(:@logdev)
      logdev&.instance_variable_get(:@dev)&.flush
    end

    # Parse only the first line (subscription might be called multiple times)
    json = JSON.parse(@buffer.string.lines.first)

    assert_equal "dotenv", json["src"]
    assert_equal "update", json["evt"]
    assert_equal %w[BAR FOO], json["vars"].sort
    assert_equal "debug", json["lvl"]

    # Restore
    @buffer.truncate(0)
    @buffer.rewind
    ActiveSupport::Notifications.instrument("restore.dotenv", diff: diff) {}

    # Ensure all writes are flushed
    if ::Rails.logger.instance_variable_defined?(:@logdev)
      logdev = ::Rails.logger.instance_variable_get(:@logdev)
      logdev&.instance_variable_get(:@dev)&.flush
    end

    # Parse only the first line (subscription might be called multiple times)
    json = JSON.parse(@buffer.string.lines.first)

    assert_equal "dotenv", json["src"]
    assert_equal "restore", json["evt"]
    assert_equal %w[BAR FOO], json["vars"].sort
    assert_equal "info", json["lvl"]
  end

  test "errors in subscribers raise in test env (no suppression)" do
    # Reset and resubscribe with fresh handlers that will use the stub
    LogStruct::Integrations::Dotenv::STATE.subscribed = false

    # Force an error inside the subscriber by stubbing Log::Dotenv.new
    LogStruct::Log::Dotenv.stub(:new, ->(*args, **kwargs) { raise "boom" }) do
      # Resubscribe with the stub in place
      LogStruct::Integrations::Dotenv.setup(LogStruct.config)

      assert_raises(RuntimeError) do
        ActiveSupport::Notifications.instrument("load.dotenv", env: OpenStruct.new(filename: ".env")) {}
      end
      assert_raises(RuntimeError) do
        ActiveSupport::Notifications.instrument("update.dotenv", diff: OpenStruct.new(env: {"A" => "1"})) {}
      end
      assert_raises(RuntimeError) do
        ActiveSupport::Notifications.instrument("restore.dotenv", diff: OpenStruct.new(env: {"A" => "1"})) {}
      end
    end

    # Clean up - reset for next test
    LogStruct::Integrations::Dotenv::STATE.subscribed = false
  end
end
