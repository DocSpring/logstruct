# typed: true
# frozen_string_literal: true

require "test_helper"

class BootBufferTest < Minitest::Test
  def setup
    LogStruct::BootBuffer.clear
  end

  def teardown
    LogStruct::BootBuffer.clear
  end

  def test_add_and_flush_emits_logs
    log_entry = LogStruct::Log::Plain.new(
      message: "boot message",
      source: LogStruct::Source::App,
      level: LogStruct::Level::Info,
      timestamp: Time.now
    )

    emitted = []

    LogStruct.stub(:info, ->(log) { emitted << log }) do
      LogStruct::BootBuffer.add(log_entry)
      LogStruct::BootBuffer.flush
    end

    assert_equal [log_entry], emitted
  end

  def test_clear_discards_logs
    log_entry = LogStruct::Log::Plain.new(
      message: "discard me",
      source: LogStruct::Source::App,
      level: LogStruct::Level::Info,
      timestamp: Time.now
    )

    LogStruct::BootBuffer.add(log_entry)
    LogStruct::BootBuffer.clear

    LogStruct.stub(:info, ->(_log) { flunk("Boot buffer should be empty") }) do
      LogStruct::BootBuffer.flush
    end
  end
end
